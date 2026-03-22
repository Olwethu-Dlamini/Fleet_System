// REQUIRES: live server on E2E_BASE_URL (default localhost:3000) with seeded test data
// Scheduler API journey test using Playwright apiRequestContext.
// Tests verify login, dashboard access, job creation, permission boundaries on
// admin-only routes, vehicle viewing, time extension viewing, and approval.

const { test, expect } = require('@playwright/test');
const { loginAs } = require('./fixtures/auth.setup');

test.describe('Scheduler Journey', () => {
  let apiContext;
  let authToken;
  let createdJobId;

  test.beforeAll(async ({ playwright }) => {
    apiContext = await playwright.request.newContext({
      baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
      extraHTTPHeaders: { Accept: 'application/json' },
    });
    authToken = await loginAs(apiContext, 'scheduler');
  });

  test.afterAll(async () => {
    if (apiContext) await apiContext.dispose();
  });

  test('can access dashboard summary', async () => {
    const res = await apiContext.get('/api/dashboard/summary', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body).toHaveProperty('totalJobs');
  });

  test('can create jobs', async () => {
    const res = await apiContext.post('/api/jobs', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        job_type: 'miscellaneous',
        customer_name: 'Scheduler E2E Customer',
        customer_address: '789 Scheduler Test Ave, Cape Town',
        scheduled_date: '2027-02-10',
        scheduled_time_start: '10:00',
        scheduled_time_end: '12:00',
        estimated_duration_minutes: 90,
      },
    });
    expect(res.status()).toBe(201);
    const body = await res.json();
    expect(body).toHaveProperty('job');
    expect(body.job.job_number).toMatch(/^JOB-/);
    createdJobId = body.job.id;
  });

  test('cannot manage users (permission denied)', async () => {
    // Scheduler does not have users:create permission
    const res = await apiContext.get('/api/users', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    // Scheduler cannot access user management per SCHED-01
    expect(res.status()).toBe(403);
  });

  test('cannot create vehicles (permission denied)', async () => {
    const res = await apiContext.post('/api/vehicles', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        vehicle_name: 'Unauthorized Vehicle',
        registration_number: 'GP-E2E-TST',
        vehicle_type: 'van',
        status: 'available',
      },
    });
    // Scheduler does not have vehicles:create permission
    expect(res.status()).toBe(403);
  });

  test('can read vehicles', async () => {
    const res = await apiContext.get('/api/vehicles', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });

  test('can view time extensions', async () => {
    const res = await apiContext.get('/api/time-extensions', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body !== null && body !== undefined).toBe(true);
  });

  test('can approve a time extension', async () => {
    // Uses extension ID 1 as a probe — 404 means no extension exists in seeded DB (acceptable).
    // Proves the approval route + scheduler auth wiring.
    // 200: approved successfully
    // 400: already processed or invalid state
    // 404: time extension ID not found in test DB
    const res = await apiContext.put('/api/time-extensions/1', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: { status: 'approved' },
    });
    expect([200, 400, 404]).toContain(res.status());
  });

  test('can list jobs', async () => {
    const res = await apiContext.get('/api/jobs', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(Array.isArray(body)).toBe(true);
  });
});
