// ============================================
// FILE: tests/api/vehicle-maintenance.test.js
// PURPOSE: Tests for /api/vehicle-maintenance routes
//
// Routes (from src/routes/vehicle-maintenance.js):
//   GET    /api/vehicle-maintenance?vehicle_id=X — requireMaintRead (verifyToken + maintenance:read)
//   GET    /api/vehicle-maintenance/active        — requireMaintRead
//   POST   /api/vehicle-maintenance               — requireMaintAdmin (verifyToken + maintenance:create)
//   PUT    /api/vehicle-maintenance/:id           — requireMaintAdmin
//   DELETE /api/vehicle-maintenance/:id           — requireMaintAdmin
//
// maintenance:read  → admin, scheduler, dispatcher, technician
// maintenance:create → admin only
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
// GET /api/vehicle-maintenance
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/vehicle-maintenance', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/vehicle-maintenance?vehicle_id=1');
    expect(res.status).toBe(401);
  });

  test('400 when vehicle_id query param is missing', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/vehicle-maintenance')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 for admin with vehicle_id param', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/vehicle-maintenance?vehicle_id=1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.maintenance)).toBe(true);
  });

  test('200 for technician — maintenance:read includes all roles', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/vehicle-maintenance?vehicle_id=1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/vehicle-maintenance/active
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/vehicle-maintenance/active', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/vehicle-maintenance/active');
    expect(res.status).toBe(401);
  });

  test('200 for admin', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/vehicle-maintenance/active')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/vehicle-maintenance
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/vehicle-maintenance', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/vehicle-maintenance')
      .send({ vehicle_id: 1, maintenance_type: 'service', start_date: '2026-04-01', end_date: '2026-04-02' });
    expect(res.status).toBe(401);
  });

  test('403 for technician — maintenance:create is admin-only', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .post('/api/vehicle-maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send({ vehicle_id: 1, maintenance_type: 'service', start_date: '2026-04-01', end_date: '2026-04-02' });
    expect(res.status).toBe(403);
  });

  test('201 for admin with valid maintenance record', async () => {
    // POST handler checks:
    // 1. overlap check (returns no overlap)
    // 2. INSERT maintenance record
    // 3. SELECT the new record with join
    db.query
      .mockResolvedValueOnce([[], {}])                                          // overlap check (no overlap)
      .mockResolvedValueOnce([{ insertId: 5, affectedRows: 1 }, {}])            // INSERT
      .mockResolvedValueOnce([[{                                                 // SELECT new record
        id: 5, vehicle_id: 1, maintenance_type: 'service',
        status: 'scheduled', start_date: '2026-04-01', end_date: '2026-04-02',
        vehicle_name: 'Van 1',
      }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/vehicle-maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicle_id      : 1,
        maintenance_type: 'service',
        start_date      : '2026-04-01',
        end_date        : '2026-04-02',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });
});
