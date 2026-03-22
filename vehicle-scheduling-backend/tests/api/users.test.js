// ============================================
// FILE: tests/api/users.test.js
// PURPOSE: Tests for /api/users routes
//
// Routes (from src/routes/users.js):
//   GET    /api/users            — requireAdminOrScheduler (verifyToken + schedulerOrAbove)
//   GET    /api/users/:id        — requireAdminOrScheduler
//   POST   /api/users            — requireAdmin (verifyToken + adminOnly)
//   PUT    /api/users/:id        — requireAdmin
//   DELETE /api/users/:id        — requireAdmin
//   POST   /api/users/:id/reset-password — requireAdmin
//
// Note: schedulerOrAbove = requireRole('admin', 'scheduler')
//       technician does NOT have users:read
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
// GET /api/users
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/users', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/users');
    expect(res.status).toBe(401);
  });

  test('403 for technician', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('200 for admin', async () => {
    db.query.mockResolvedValueOnce([[
      { id: 1, username: 'admin', full_name: 'Admin User', role: 'admin', email: 'a@t.com', is_active: 1 },
    ], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(Array.isArray(res.body.users)).toBe(true);
  });

  test('200 for scheduler', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('scheduler');
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/users
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/users', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/users')
      .send({ username: 'newuser', email: 'new@test.com', password: 'pass1234', role: 'technician', full_name: 'New User' });
    expect(res.status).toBe(401);
  });

  test('403 for scheduler', async () => {
    const token = makeToken('scheduler');
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', `Bearer ${token}`)
      .send({ username: 'newuser', email: 'new@test.com', password: 'pass1234', role: 'technician', full_name: 'New User' });
    expect(res.status).toBe(403);
  });

  test('201 for admin with valid body', async () => {
    // Mock INSERT result, then SELECT to return created user
    db.query
      .mockResolvedValueOnce([{ insertId: 5, affectedRows: 1 }, {}])
      .mockResolvedValueOnce([[{
        id: 5, username: 'newuser', full_name: 'New User',
        role: 'driver', email: 'new@test.com', is_active: 1,
        contact_phone: null, contact_phone_secondary: null, created_at: new Date(),
      }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', `Bearer ${token}`)
      .send({
        username : 'newuser',
        email    : 'new@test.com',
        password : 'pass1234',
        role     : 'technician',
        full_name: 'New User',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });
});
