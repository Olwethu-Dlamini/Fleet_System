// ============================================
// FILE: tests/api/dashboard.test.js
// PURPOSE: Tests for /api/dashboard routes
//
// Routes (from src/routes/dashboard.js):
//   GET /api/dashboard/summary    — verifyToken
//   GET /api/dashboard/stats      — verifyToken
//   GET /api/dashboard/chart-data — verifyToken
//
// All routes require verifyToken (any authenticated role).
// ============================================
process.env.JWT_SECRET = 'test-secret-value-minimum-32-chars-ok';
process.env.NODE_ENV   = 'test';

const { db, resetDbMocks } = require('./helpers/db.mock');
const { makeToken }        = require('./helpers/auth');

const request = require('supertest');
const app     = require('../../src/server');

beforeEach(() => {
  resetDbMocks();
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/summary
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/dashboard/summary', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/dashboard/summary');
    expect(res.status).toBe(401);
  });

  test('200 for admin — returns dashboard summary', async () => {
    // getDashboardSummary uses Promise.all with 5 concurrent db.query calls.
    // Job.getJobsByDate is also called (1 more db.query inside it).
    // Total db.query calls (in Promise.all order):
    //  1. status counts (statusRows)       → [[], fields]
    //  2. Job.getJobsByDate (today's jobs) → [[], fields]  (returns rows directly)
    //  3. recent status changes            → [[], fields]
    //  4. vehicles list                    → [[], fields]
    //  5. active vehicles scalar           → [[{activeVehicles: 0}], fields]
    db.query
      .mockResolvedValueOnce([[], {}])                                 // 1. status counts
      .mockResolvedValueOnce([[], {}])                                 // 2. getJobsByDate
      .mockResolvedValueOnce([[], {}])                                 // 3. recent changes
      .mockResolvedValueOnce([[], {}])                                 // 4. vehicles list
      .mockResolvedValueOnce([[{ activeVehicles: 0 }], {}]);           // 5. active vehicles scalar

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/dashboard/summary')
      .set('Authorization', `Bearer ${token}`);

    // Route should return 200 even with empty DB mock
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/stats
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/dashboard/stats', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/dashboard/stats');
    expect(res.status).toBe(401);
  });

  test('200 for technician — all roles can read dashboard', async () => {
    // getQuickStats uses Promise.all with 2 db.query calls
    db.query
      .mockResolvedValueOnce([[], {}])   // all-time status counts
      .mockResolvedValueOnce([[], {}]);  // today status counts

    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/dashboard/stats')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/dashboard/chart-data
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/dashboard/chart-data', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/dashboard/chart-data');
    expect(res.status).toBe(401);
  });

  test('200 for scheduler', async () => {
    // getChartData: 1 db.query call
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('scheduler');
    const res = await request(app)
      .get('/api/dashboard/chart-data')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
