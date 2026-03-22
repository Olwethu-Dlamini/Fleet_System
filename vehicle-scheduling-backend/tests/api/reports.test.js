// ============================================
// FILE: tests/api/reports.test.js
// PURPOSE: Tests for /api/reports routes
//
// Routes (from src/routes/reports.js):
//   Uses: router.use(verifyToken, schedulerOrAbove) — applies to ALL routes
//   GET /api/reports/summary
//   GET /api/reports/jobs-by-vehicle
//   GET /api/reports/jobs-by-technician
//   GET /api/reports/jobs-by-type
//   GET /api/reports/cancellations
//   GET /api/reports/daily-volume
//   GET /api/reports/vehicle-utilisation
//   GET /api/reports/technician-performance
//   GET /api/reports/executive-dashboard
//
// schedulerOrAbove = requireRole('admin', 'scheduler')
// technician is NOT allowed.
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
// GET /api/reports/summary
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/reports/summary', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/reports/summary');
    expect(res.status).toBe(401);
  });

  test('403 for technician', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/reports/summary')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('200 for admin', async () => {
    // Reports summary makes multiple db.query calls — mock all to return empty arrays
    // statusRows, activeVehicles (scalar), activeTechs (scalar)
    db.query
      .mockResolvedValueOnce([[], {}])                       // statusRows
      .mockResolvedValueOnce([[{ activeVehicles: 0 }], {}]) // activeVehicles
      .mockResolvedValueOnce([[{ activeTechs: 0 }], {}]);   // activeTechs

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/reports/summary')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('200 for scheduler', async () => {
    db.query
      .mockResolvedValueOnce([[], {}])
      .mockResolvedValueOnce([[{ activeVehicles: 0 }], {}])
      .mockResolvedValueOnce([[{ activeTechs: 0 }], {}]);

    const token = makeToken('scheduler');
    const res = await request(app)
      .get('/api/reports/summary')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/reports/jobs-by-vehicle
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/reports/jobs-by-vehicle', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/reports/jobs-by-vehicle');
    expect(res.status).toBe(401);
  });

  test('200 for admin with mocked data', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/reports/jobs-by-vehicle')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
