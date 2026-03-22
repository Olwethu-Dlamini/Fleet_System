// ============================================
// FILE: tests/api/auth.test.js
// PURPOSE: Tests for POST /api/auth/login, GET /api/auth/me, POST /api/auth/logout
//
// PITFALL: JWT_SECRET MUST be set at line 1 — before any require — or
//          server.js will call process.exit(1) and kill Jest.
// ============================================
process.env.JWT_SECRET = 'test-secret-value-minimum-32-chars-ok';
process.env.NODE_ENV   = 'test';

// Activate DB mock before requiring server
const { db, resetDbMocks } = require('./helpers/db.mock');
const { makeToken }        = require('./helpers/auth');

const request = require('supertest');
const app     = require('../../src/server');

beforeEach(() => {
  resetDbMocks();
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/login
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/auth/login', () => {
  test('400 when username is missing', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ password: 'somepassword' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('400 when password is missing', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('401 when user not found in database', async () => {
    // Mock: no rows returned (user not found)
    db.query.mockResolvedValueOnce([[], {}]);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'nobody', password: 'wrongpass' });

    expect(res.status).toBe(401);
    expect(res.body.success).toBe(false);
  });

  test('200 with valid credentials — returns token and user object', async () => {
    const bcrypt = require('bcryptjs');
    const hash   = await bcrypt.hash('correctpass', 10);

    // Mock: user found in DB
    db.query.mockResolvedValueOnce([[{
      id           : 1,
      username     : 'admin',
      password_hash: hash,
      role         : 'admin',
      email        : 'admin@test.com',
      full_name    : 'Test Admin',
      tenant_id    : 1,
    }], {}]);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ username: 'admin', password: 'correctpass' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.token).toBeDefined();
    expect(res.body.user.role).toBe('admin');
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/auth/me
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/auth/me', () => {
  test('401 when no Authorization header', async () => {
    const res = await request(app).get('/api/auth/me');
    expect(res.status).toBe(401);
  });

  test('200 with valid token — returns current user', async () => {
    // Mock: user found
    db.query.mockResolvedValueOnce([[{
      id       : 1,
      username : 'admin',
      full_name: 'Test Admin',
      role     : 'admin',
      email    : 'admin@test.com',
    }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.user).toBeDefined();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/auth/logout
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/auth/logout', () => {
  test('200 always (stateless logout)', async () => {
    const res = await request(app).post('/api/auth/logout');
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
