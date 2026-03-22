// ============================================
// FILE: tests/api/notifications.test.js
// PURPOSE: Tests for /api/notifications routes
//
// Routes (from src/routes/notifications.js):
//   GET   /api/notifications               — verifyToken
//   GET   /api/notifications/unread-count  — verifyToken
//   GET   /api/notifications/preferences   — verifyToken
//   PATCH /api/notifications/read-all      — verifyToken
//   PATCH /api/notifications/:id/read      — verifyToken
//   PUT   /api/notifications/preferences   — verifyToken
//
// All routes require verifyToken. Any authenticated role can access.
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
// GET /api/notifications
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/notifications', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/notifications');
    expect(res.status).toBe(401);
  });

  test('200 for admin — returns notifications list', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/notifications')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('200 for technician — all roles can read notifications', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/notifications')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/notifications/unread-count
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/notifications/unread-count', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/notifications/unread-count');
    expect(res.status).toBe(401);
  });

  test('200 for admin', async () => {
    db.query.mockResolvedValueOnce([[{ count: 0 }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/notifications/unread-count')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/notifications/read-all
// ─────────────────────────────────────────────────────────────────────────────
describe('PATCH /api/notifications/read-all', () => {
  test('401 without token', async () => {
    const res = await request(app).patch('/api/notifications/read-all');
    expect(res.status).toBe(401);
  });

  test('200 for admin', async () => {
    db.query.mockResolvedValueOnce([{ affectedRows: 0 }, {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .patch('/api/notifications/read-all')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
