// ============================================
// FILE: tests/api/settings.test.js
// PURPOSE: Tests for /api/settings routes
//
// Routes (from src/routes/settings.js):
//   GET /api/settings       — verifyToken + requirePermission('settings:read') — admin only
//   GET /api/settings/:key  — verifyToken + requirePermission('settings:read') — admin only
//   PUT /api/settings/:key  — verifyToken + requirePermission('settings:update') — admin only
//
// settings:read and settings:update are admin-only permissions per constants.js
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
// GET /api/settings
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/settings', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/settings');
    expect(res.status).toBe(401);
  });

  test('403 for technician — settings:read is admin-only', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .get('/api/settings')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('403 for scheduler — settings:read is admin-only', async () => {
    const token = makeToken('scheduler');
    const res = await request(app)
      .get('/api/settings')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('200 for admin — returns settings object', async () => {
    db.query.mockResolvedValueOnce([[
      { setting_key: 'scheduler_gps_visible', setting_val: 'true' },
    ], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/settings')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.settings).toBeDefined();
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// PUT /api/settings/:key
// ─────────────────────────────────────────────────────────────────────────────
describe('PUT /api/settings/:key', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .put('/api/settings/scheduler_gps_visible')
      .send({ value: 'true' });
    expect(res.status).toBe(401);
  });

  test('403 for scheduler', async () => {
    const token = makeToken('scheduler');
    const res = await request(app)
      .put('/api/settings/scheduler_gps_visible')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: 'true' });
    expect(res.status).toBe(403);
  });

  test('200 for admin — upserts setting', async () => {
    // UPDATE: affectedRows=1 (key exists)
    db.query.mockResolvedValueOnce([{ affectedRows: 1 }, {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .put('/api/settings/scheduler_gps_visible')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: 'false' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.key).toBe('scheduler_gps_visible');
  });

  test('200 for admin — inserts new setting if key does not exist', async () => {
    // UPDATE: affectedRows=0 (key not found) → INSERT
    db.query
      .mockResolvedValueOnce([{ affectedRows: 0 }, {}])   // UPDATE returns 0
      .mockResolvedValueOnce([{ insertId: 1 }, {}]);        // INSERT

    const token = makeToken('admin');
    const res = await request(app)
      .put('/api/settings/new_setting_key')
      .set('Authorization', `Bearer ${token}`)
      .send({ value: 'some_value' });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
