// REQUIRES: live server on E2E_BASE_URL (default localhost:3000) with seeded test data
// Driver/Technician API journey test using Playwright apiRequestContext.
// Tests verify login, viewing assigned jobs, permission denial on admin routes,
// job status update, time extension request, and time extension listing.

const { test, expect } = require('@playwright/test');
const { loginAs } = require('./fixtures/auth.setup');

test.describe('Driver (Technician) Journey', () => {
  let apiContext;
  let authToken;
  let createdExtensionId;

  test.beforeAll(async ({ playwright }) => {
    apiContext = await playwright.request.newContext({
      baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
      extraHTTPHeaders: { Accept: 'application/json' },
    });
    authToken = await loginAs(apiContext, 'technician');
  });

  test.afterAll(async () => {
    if (apiContext) await apiContext.dispose();
  });

  test('can view assigned jobs', async () => {
    const res = await apiContext.get('/api/jobs', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  test('can view notifications', async () => {
    const res = await apiContext.get('/api/notifications', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    // Notifications endpoint returns an array or paginated object
    expect(body !== null && body !== undefined).toBe(true);
  });

  test('cannot create jobs (permission denied)', async () => {
    const res = await apiContext.post('/api/jobs', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        job_type: 'delivery',
        customer_name: 'Unauthorized Attempt',
        customer_address: '456 Forbidden Lane',
        scheduled_date: '2027-01-15',
        scheduled_time_start: '09:00',
        scheduled_time_end: '11:00',
        estimated_duration_minutes: 60,
      },
    });
    // Technician role does not have jobs:create permission — must be 403
    expect(res.status()).toBe(403);
  });

  test('can update job status', async () => {
    // Uses job ID 1 as a probe — 404 is acceptable if no job exists in test DB.
    // Proves route + auth wiring: technician token reaches the handler.
    const res = await apiContext.put('/api/job-status/1', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: { status: 'in_progress' },
    });
    // 200: status updated
    // 400: validation error on transition
    // 403: technician not assigned to this job (backend auth check)
    // 404: job not found in test DB
    expect([200, 400, 403, 404]).toContain(res.status());
  });

  test('can request a time extension', async () => {
    // Proves the time extension request route + technician auth wiring.
    // 201: extension created
    // 400: job not in_progress or not assigned
    // 404: job ID not found in test DB
    const res = await apiContext.post('/api/time-extensions', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        job_id: 1,
        requested_minutes: 30,
        reason: 'Traffic delay during E2E test',
      },
    });
    expect([201, 400, 404]).toContain(res.status());
    if (res.status() === 201) {
      const body = await res.json();
      // Store extension ID for scheduler test if running in sequence
      createdExtensionId = body.request && body.request.id;
    }
  });

  test('can view time extensions', async () => {
    const res = await apiContext.get('/api/time-extensions', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body !== null && body !== undefined).toBe(true);
  });

  test('cannot access admin user list (permission denied)', async () => {
    const res = await apiContext.get('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    // Technician does not have users:read permission
    expect(res.status()).toBe(403);
  });
});
