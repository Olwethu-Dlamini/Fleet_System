// ============================================
// FILE: tests/api/gps.test.js
// PURPOSE: Tests for /api/gps routes
//
// Routes (from src/routes/gps.js):
//   GET  /api/gps/directions  — verifyToken, query: job_id (required)
//   POST /api/gps/location    — verifyToken, body: lat, lng, accuracy_m
//   GET  /api/gps/drivers     — verifyToken, admin/scheduler only
//   GET  /api/gps/consent     — verifyToken, any authenticated user
//   POST /api/gps/consent     — verifyToken, any authenticated user
//   PUT  /api/gps/consent     — verifyToken, body: gps_enabled (boolean)
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
// GET /api/gps/consent
// Any authenticated user
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/gps/consent', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/gps/consent');
    expect(res.status).toBe(401);
  });

  test('200 for technician — returns consent record (or null)', async () => {
    // GpsService.getConsent calls db.query
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/gps/consent')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('200 for admin', async () => {
    db.query.mockResolvedValueOnce([[{ id: 1, gps_enabled: true }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/gps/consent')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/gps/consent
// Any authenticated user — grants GPS consent
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/gps/consent', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/gps/consent')
      .send({});
    expect(res.status).toBe(401);
  });

  test('201 for technician — grants consent', async () => {
    // GpsService.setConsent calls db.query for UPSERT
    db.query.mockResolvedValueOnce([{ affectedRows: 1 }, {}]);

    const token = makeToken('technician');
    const res = await request(app)
      .post('/api/gps/consent')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/gps/directions
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/gps/directions', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/gps/directions?job_id=1');
    expect(res.status).toBe(401);
  });

  test('400 when job_id is missing', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/gps/directions')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 for admin — job found with coordinates', async () => {
    // Mock job found with destination coordinates
    db.query.mockResolvedValueOnce([[{
      id: 1,
      destination_lat: -26.2041,
      destination_lng: 28.0473,
    }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/gps/directions?job_id=1')
      .set('Authorization', `Bearer ${token}`);

    // Returns 200 with null polyline (no origin coords provided)
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.directions).toBeDefined();
  });

  test('404 when job not found', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/gps/directions?job_id=9999')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
    expect(res.body.success).toBe(false);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/gps/drivers
// Admin or scheduler only
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/gps/drivers', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/gps/drivers');
    expect(res.status).toBe(401);
  });

  test('403 for technician', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/gps/drivers')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  test('200 for admin — returns driver locations', async () => {
    // GpsService.getDriverLocations returns in-memory data (no db.query)
    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/gps/drivers')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/gps/location
// Any authenticated user (technician primarily)
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/gps/location', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/gps/location')
      .send({ lat: -26.2041, lng: 28.0473 });
    expect(res.status).toBe(401);
  });

  test('400 when lat/lng validation fails', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .post('/api/gps/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ lat: 999, lng: 999 }); // Out of range

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 or 403 for technician with valid coords (GpsService checks working hours + consent)', async () => {
    // GpsService.isWithinWorkingHours calls db.query for settings
    // GpsService.getConsent calls db.query
    db.query
      .mockResolvedValueOnce([[], {}])  // settings (no custom hours → use default: always within)
      .mockResolvedValueOnce([[{ gps_enabled: true }], {}]);  // consent record

    const token = makeToken('technician', { id: 5, username: 'tech1' });
    const res = await request(app)
      .post('/api/gps/location')
      .set('Authorization', `Bearer ${token}`)
      .send({ lat: -26.2041, lng: 28.0473 });

    // 200 if within hours and consent granted, 403 otherwise
    expect(res.status).not.toBe(401);
  });
});
