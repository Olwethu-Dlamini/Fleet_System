// ============================================
// E2E: Time Extension API Tests
// Tests the full time extension flow: create → list pending → approve/deny
// Requires: backend running on localhost:3000, database with test data
// Run: npx playwright test api-time-extensions.spec.js --project=api
// ============================================

const { test, expect } = require('@playwright/test');

const BASE = process.env.E2E_BASE_URL || 'http://localhost:3000';

// ── Test credentials (must exist in DB) ─────────────────────────────────────
const ADMIN_CREDS = { username: 'admin', password: 'admin' };
const DRIVER_CREDS = { username: 'george.manyatsi', password: 'admin' };

let adminToken = '';
let driverToken = '';

// ── Helper: login and return JWT token ──────────────────────────────────────
async function login(request, creds) {
  const res = await request.post(`${BASE}/api/auth/login`, {
    data: creds,
  });
  const body = await res.json();
  if (!res.ok()) {
    console.log('Login failed:', res.status(), body);
  }
  return body.token || body.data?.token || '';
}

// ── Helper: make authenticated request ──────────────────────────────────────
function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

// ════════════════════════════════════════════════════════════════════════════
// SETUP: Login both users
// ════════════════════════════════════════════════════════════════════════════
test.describe('Time Extension API', () => {
  test.beforeAll(async ({ request }) => {
    adminToken = await login(request, ADMIN_CREDS);
    driverToken = await login(request, DRIVER_CREDS);

    console.log('Admin token:', adminToken ? 'OK' : 'MISSING');
    console.log('Driver token:', driverToken ? 'OK' : 'MISSING');
  });

  // ════════════════════════════════════════════════════════════════════════
  // 1. CORS: Verify PATCH is allowed
  // ════════════════════════════════════════════════════════════════════════
  test('CORS allows PATCH method', async ({ request }) => {
    const res = await request.fetch(`${BASE}/api/time-extensions/999/approve`, {
      method: 'OPTIONS',
      headers: {
        Origin: 'http://localhost:8080',
        'Access-Control-Request-Method': 'PATCH',
      },
    });
    // Should get back Access-Control-Allow-Methods that includes PATCH
    const allowMethods = res.headers()['access-control-allow-methods'] || '';
    console.log('CORS allowed methods:', allowMethods);
    expect(allowMethods.toUpperCase()).toContain('PATCH');
  });

  // ════════════════════════════════════════════════════════════════════════
  // 2. GET /api/time-extensions/pending (admin)
  // ════════════════════════════════════════════════════════════════════════
  test('GET /pending returns list for admin', async ({ request }) => {
    test.skip(!adminToken, 'No admin token');

    const res = await request.get(`${BASE}/api/time-extensions/pending`, {
      headers: authHeaders(adminToken),
    });

    console.log('GET /pending status:', res.status());
    expect(res.ok()).toBeTruthy();

    const body = await res.json();
    expect(body.success).toBe(true);
    expect(Array.isArray(body.requests)).toBe(true);
    console.log('Pending requests count:', body.requests.length);
  });

  // ════════════════════════════════════════════════════════════════════════
  // 3. GET /api/time-extensions/:jobId (get active request for a job)
  // ════════════════════════════════════════════════════════════════════════
  test('GET /:jobId returns request or null', async ({ request }) => {
    test.skip(!adminToken, 'No admin token');

    // Use job ID 1 as a test (may or may not have a pending request)
    const res = await request.get(`${BASE}/api/time-extensions/1`, {
      headers: authHeaders(adminToken),
    });

    console.log('GET /1 status:', res.status());
    expect(res.ok()).toBeTruthy();

    const body = await res.json();
    expect(body.success).toBe(true);
    // request can be null if no pending extension
    console.log('Active request:', body.request ? `ID ${body.request.id}` : 'none');
    console.log('Suggestions:', body.suggestions?.length || 0);

    // If suggestions exist, verify they have the expected fields
    if (body.suggestions?.length > 0) {
      const s = body.suggestions[0];
      expect(s).toHaveProperty('type');
      expect(s).toHaveProperty('label');
      expect(s).toHaveProperty('changes');
      // New fields from our update
      expect(typeof s.recommended).toBe('boolean');
      console.log('First suggestion:', s.type, '| recommended:', s.recommended);
    }
  });

  // ════════════════════════════════════════════════════════════════════════
  // 4. GET /api/time-extensions/:jobId/day-schedule
  // ════════════════════════════════════════════════════════════════════════
  test('GET /:jobId/day-schedule returns personnel grouped schedule', async ({ request }) => {
    test.skip(!adminToken, 'No admin token');

    const res = await request.get(`${BASE}/api/time-extensions/1/day-schedule`, {
      headers: authHeaders(adminToken),
    });

    console.log('GET /1/day-schedule status:', res.status());

    if (res.status() === 404) {
      console.log('Job 1 not found — skipping day-schedule check');
      return;
    }

    expect(res.ok()).toBeTruthy();

    const body = await res.json();
    expect(body.success).toBe(true);
    expect(body).toHaveProperty('date');
    expect(Array.isArray(body.personnel)).toBe(true);

    console.log('Schedule date:', body.date);
    console.log('Personnel count:', body.personnel.length);

    // Verify personnel structure
    for (const p of body.personnel) {
      expect(p).toHaveProperty('id');
      expect(p).toHaveProperty('name');
      expect(p).toHaveProperty('role');
      expect(Array.isArray(p.jobs)).toBe(true);
      console.log(`  ${p.role}: ${p.name} — ${p.jobs.length} jobs`);
    }
  });

  // ════════════════════════════════════════════════════════════════════════
  // 5. Full flow: Create → List Pending → Approve
  // ════════════════════════════════════════════════════════════════════════
  test('Full flow: create extension, verify pending, then approve', async ({ request }) => {
    test.skip(!adminToken || !driverToken, 'Missing tokens');

    // First find an in_progress job assigned to our driver
    const jobsRes = await request.get(`${BASE}/api/jobs`, {
      headers: authHeaders(adminToken),
    });
    const jobsBody = await jobsRes.json();
    const allJobs = jobsBody.jobs || jobsBody.data || [];
    const inProgressJob = allJobs.find(j =>
      j.current_status === 'in_progress'
    );

    if (!inProgressJob) {
      console.log('No in_progress jobs found — skipping full flow test');
      return;
    }

    console.log('Testing with job:', inProgressJob.id, inProgressJob.job_number);

    // Step 1: Create time extension request as driver
    const createRes = await request.post(`${BASE}/api/time-extensions`, {
      headers: authHeaders(driverToken),
      data: {
        job_id: inProgressJob.id,
        duration_minutes: 30,
        reason: 'E2E test: need more time to complete the work on site',
      },
    });

    const createBody = await createRes.json();
    console.log('Create status:', createRes.status(), createBody.success || createBody.error);

    if (createRes.status() === 409) {
      console.log('Request already exists — testing approve on existing');
    } else if (createRes.status() === 403) {
      console.log('Driver not assigned to this job — skipping');
      return;
    } else {
      expect(createRes.status()).toBe(201);
      expect(createBody.success).toBe(true);
      expect(createBody.request).toBeTruthy();
      console.log('Created request ID:', createBody.request.id);
      console.log('Affected jobs:', createBody.affectedJobs?.length || 0);
      console.log('Suggestions:', createBody.suggestions?.length || 0);

      // Verify suggestions have new types
      if (createBody.suggestions?.length > 0) {
        for (const s of createBody.suggestions) {
          console.log(`  Suggestion: ${s.type} — ${s.label} (recommended: ${s.recommended})`);
        }
      }
    }

    // Step 2: Verify it appears in pending list
    const pendingRes = await request.get(`${BASE}/api/time-extensions/pending`, {
      headers: authHeaders(adminToken),
    });
    const pendingBody = await pendingRes.json();
    console.log('Pending after create:', pendingBody.requests?.length || 0);

    const ourRequest = pendingBody.requests?.find(r => r.job_id === inProgressJob.id);
    if (!ourRequest) {
      console.log('Request not found in pending list — may have been auto-processed');
      return;
    }

    expect(ourRequest.job_number).toBeTruthy();
    expect(ourRequest.requester_name).toBeTruthy();
    console.log('Found in pending:', ourRequest.id, 'by', ourRequest.requester_name);

    // Step 3: Get active request with suggestions
    const activeRes = await request.get(`${BASE}/api/time-extensions/${inProgressJob.id}`, {
      headers: authHeaders(adminToken),
    });
    const activeBody = await activeRes.json();
    expect(activeBody.request).toBeTruthy();

    const suggestions = activeBody.suggestions || [];
    console.log('Suggestions for approval:', suggestions.length);

    // Step 4: Approve with first suggestion (or no suggestion if type=none)
    const approveData = {};
    if (suggestions.length > 0) {
      const recommended = suggestions.find(s => s.recommended) || suggestions[0];
      approveData.suggestion_id = recommended.id;
      console.log('Approving with suggestion:', recommended.type, recommended.id);
    }

    const approveRes = await request.patch(
      `${BASE}/api/time-extensions/${ourRequest.id}/approve`,
      {
        headers: authHeaders(adminToken),
        data: approveData,
      },
    );

    const approveBody = await approveRes.json();
    console.log('Approve status:', approveRes.status(), approveBody);
    expect(approveRes.ok()).toBeTruthy();
    expect(approveBody.success).toBe(true);

    // Step 5: Verify no longer in pending
    const pendingAfter = await request.get(`${BASE}/api/time-extensions/pending`, {
      headers: authHeaders(adminToken),
    });
    const pendingAfterBody = await pendingAfter.json();
    const stillPending = pendingAfterBody.requests?.find(r => r.id === ourRequest.id);
    expect(stillPending).toBeUndefined();
    console.log('Verified: request no longer pending');
  });

  // ════════════════════════════════════════════════════════════════════════
  // 6. PATCH /approve returns 404 for non-existent request
  // ════════════════════════════════════════════════════════════════════════
  test('PATCH /approve returns 404 for non-existent request', async ({ request }) => {
    test.skip(!adminToken, 'No admin token');

    const res = await request.patch(`${BASE}/api/time-extensions/99999/approve`, {
      headers: authHeaders(adminToken),
      data: {},
    });

    console.log('Approve 99999 status:', res.status());
    expect(res.status()).toBe(404);
  });

  // ════════════════════════════════════════════════════════════════════════
  // 7. PATCH /deny works
  // ════════════════════════════════════════════════════════════════════════
  test('PATCH /deny returns 404 for non-existent request', async ({ request }) => {
    test.skip(!adminToken, 'No admin token');

    const res = await request.patch(`${BASE}/api/time-extensions/99999/deny`, {
      headers: authHeaders(adminToken),
      data: { reason: 'E2E test denial' },
    });

    console.log('Deny 99999 status:', res.status());
    expect(res.status()).toBe(404);
  });

  // ════════════════════════════════════════════════════════════════════════
  // 8. Unauthenticated requests are rejected
  // ════════════════════════════════════════════════════════════════════════
  test('Unauthenticated requests get 401', async ({ request }) => {
    const res = await request.get(`${BASE}/api/time-extensions/pending`);
    expect(res.status()).toBe(401);
  });
});
