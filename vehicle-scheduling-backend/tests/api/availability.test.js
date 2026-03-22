// ============================================
// FILE: tests/api/availability.test.js
// PURPOSE: Tests for /api/availability routes
//
// Routes (from src/routes/availabilityRoutes.js):
//   Uses: router.use(verifyToken) — ALL routes require auth
//   GET  /api/availability/drivers        — query: date, start_time, end_time (all required)
//   GET  /api/availability/vehicles       — query: date, start_time, end_time (all required)
//   POST /api/availability/check-drivers  — body: technician_ids, date, start_time, end_time
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
// GET /api/availability/drivers
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/availability/drivers', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .get('/api/availability/drivers?date=2026-04-01&start_time=09:00:00&end_time=11:00:00');
    expect(res.status).toBe(401);
  });

  test('400 when required query params are missing', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/availability/drivers')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 for admin with all required params', async () => {
    // VehicleAvailabilityService.findAvailableDrivers calls db.query
    db.query
      .mockResolvedValueOnce([[], {}])  // get all drivers
      .mockResolvedValueOnce([[], {}]); // get busy drivers

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/availability/drivers?date=2026-04-01&start_time=09:00:00&end_time=11:00:00')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/availability/vehicles
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/availability/vehicles', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .get('/api/availability/vehicles?date=2026-04-01&start_time=09:00:00&end_time=11:00:00');
    expect(res.status).toBe(401);
  });

  test('400 when required query params are missing', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/availability/vehicles')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 for admin with all required params', async () => {
    // Vehicle.getAvailableVehicles calls db.query
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/availability/vehicles?date=2026-04-01&start_time=09:00:00&end_time=11:00:00')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/availability/check-drivers
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/availability/check-drivers', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/availability/check-drivers')
      .send({ technician_ids: [1], date: '2026-04-01', start_time: '09:00:00', end_time: '11:00:00' });
    expect(res.status).toBe(401);
  });

  test('400 when technician_ids is empty', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/availability/check-drivers')
      .set('Authorization', `Bearer ${token}`)
      .send({ technician_ids: [], date: '2026-04-01', start_time: '09:00:00', end_time: '11:00:00' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 for admin with valid body', async () => {
    // VehicleAvailabilityService.checkDriversAvailability calls db.query
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/availability/check-drivers')
      .set('Authorization', `Bearer ${token}`)
      .send({
        technician_ids: [1, 2],
        date          : '2026-04-01',
        start_time    : '09:00:00',
        end_time      : '11:00:00',
      });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
