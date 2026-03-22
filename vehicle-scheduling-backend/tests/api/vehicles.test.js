// ============================================
// FILE: tests/api/vehicles.test.js
// PURPOSE: Tests for /api/vehicles routes
//
// Routes (from src/routes/vehicles.js):
//   GET    /api/vehicles        — public (no auth required in route)
//   GET    /api/vehicles/:id    — public (no auth required in route)
//   POST   /api/vehicles        — requireAdmin (verifyToken + adminOnly)
//   PUT    /api/vehicles/:id    — requireAdmin
//   DELETE /api/vehicles/:id    — requireAdmin
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
// GET /api/vehicles — public endpoint (no auth needed)
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/vehicles', () => {
  test('200 without token — public endpoint', async () => {
    db.query.mockResolvedValueOnce([[
      { id: 1, vehicle_name: 'Van 1', license_plate: 'ABC123', is_active: 1 },
    ], {}]);

    const res = await request(app).get('/api/vehicles');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('200 with admin token', async () => {
    db.query.mockResolvedValueOnce([[
      { id: 1, vehicle_name: 'Van 1', license_plate: 'ABC123', is_active: 1 },
    ], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/vehicles')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/vehicles — admin only
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/vehicles', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/vehicles')
      .send({ vehicle_name: 'Van X', license_plate: 'XYZ', vehicle_type: 'van' });
    expect(res.status).toBe(401);
  });

  test('403 for scheduler role', async () => {
    const token = makeToken('scheduler');
    const res = await request(app)
      .post('/api/vehicles')
      .set('Authorization', `Bearer ${token}`)
      .send({ vehicle_name: 'Van X', license_plate: 'XYZ', vehicle_type: 'van' });
    expect(res.status).toBe(403);
  });

  test('201 for admin with valid body', async () => {
    // Vehicle.createVehicle calls db.query for INSERT then SELECT
    db.query
      .mockResolvedValueOnce([{ insertId: 10, affectedRows: 1 }, {}])
      .mockResolvedValueOnce([[{
        id: 10, vehicle_name: 'Van X', license_plate: 'XYZ999',
        vehicle_type: 'van', is_active: 1,
      }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/vehicles')
      .set('Authorization', `Bearer ${token}`)
      .send({ vehicle_name: 'Van X', license_plate: 'XYZ999', vehicle_type: 'van' });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });

  test('400 for admin with missing required fields', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/vehicles')
      .set('Authorization', `Bearer ${token}`)
      .send({ vehicle_name: 'Van X' }); // Missing license_plate, vehicle_type

    // Validation schema requires license_plate and will catch empty or missing
    // The route may return 400 from the explicit check or the validator
    expect([400, 422]).toContain(res.status);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// DELETE /api/vehicles/:id — admin only
// ─────────────────────────────────────────────────────────────────────────────
describe('DELETE /api/vehicles/:id', () => {
  test('401 without token', async () => {
    const res = await request(app).delete('/api/vehicles/1');
    expect(res.status).toBe(401);
  });

  test('403 for technician', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .delete('/api/vehicles/1')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });
});
