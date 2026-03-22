// ============================================
// FILE: tests/api/time-extensions.test.js
// PURPOSE: Tests for /api/time-extensions routes
//
// Routes (from src/routes/timeExtension.js):
//   POST  /api/time-extensions          — verifyToken (any authenticated user — service validates assignment)
//   GET   /api/time-extensions/:jobId   — verifyToken
//   PATCH /api/time-extensions/:id/approve — verifyToken + requirePermission('jobs:update') — admin/scheduler
//   PATCH /api/time-extensions/:id/deny   — verifyToken + requirePermission('jobs:update') — admin/scheduler
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
// POST /api/time-extensions
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/time-extensions', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/time-extensions')
      .send({ job_id: 1, duration_minutes: 30, reason: 'Water damage found under flooring' });
    expect(res.status).toBe(401);
  });

  test('400 when validation fails — reason too short', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .post('/api/time-extensions')
      .set('Authorization', `Bearer ${token}`)
      .send({ job_id: 1, duration_minutes: 30, reason: 'Short' }); // reason < 10 chars

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('400 when job_id missing', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .post('/api/time-extensions')
      .set('Authorization', `Bearer ${token}`)
      .send({ duration_minutes: 30, reason: 'Water damage found under flooring' });

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('2xx or 4xx for technician creating valid request (service validates assignment)', async () => {
    // TimeExtensionService.createRequest calls db.query multiple times
    // We mock: getConnection for transaction, plus db.query calls
    const mockConn = {
      query           : jest.fn(),
      beginTransaction: jest.fn().mockResolvedValue(undefined),
      commit          : jest.fn().mockResolvedValue(undefined),
      rollback        : jest.fn().mockResolvedValue(undefined),
      release         : jest.fn().mockReturnValue(undefined),
    };
    db.getConnection.mockResolvedValue(mockConn);
    // Mock: job not in_progress → 400 from service
    mockConn.query.mockResolvedValueOnce([[{
      id: 1, current_status: 'pending', scheduled_time_end: '11:00:00',
    }], {}]);

    const token = makeToken('technician', { id: 5 });
    const res = await request(app)
      .post('/api/time-extensions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        job_id          : 1,
        duration_minutes: 30,
        reason          : 'Water damage found under flooring tiles',
      });

    // Service returns 400 (job not in_progress) — auth passed
    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/time-extensions/:jobId
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/time-extensions/:jobId', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/time-extensions/1');
    expect(res.status).toBe(401);
  });

  test('200 for admin with mocked data', async () => {
    // TimeExtensionService.getActiveRequest calls db.query
    db.query
      .mockResolvedValueOnce([[], {}])   // SELECT pending request
      .mockResolvedValueOnce([[], {}]);  // SELECT suggestions

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/time-extensions/1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// PATCH /api/time-extensions/:id/approve
// ─────────────────────────────────────────────────────────────────────────────
describe('PATCH /api/time-extensions/:id/approve', () => {
  test('401 without token', async () => {
    const res = await request(app).patch('/api/time-extensions/1/approve');
    expect(res.status).toBe(401);
  });

  test('403 for technician — jobs:update permission required', async () => {
    const token = makeToken('technician');
    const res = await request(app)
      .patch('/api/time-extensions/1/approve')
      .set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(403);
  });

  test('200 or 404 for admin (service validates request exists)', async () => {
    // TimeExtensionService.approveRequest calls db.query — mock: request not found
    const mockConn = {
      query           : jest.fn().mockResolvedValueOnce([[]], {}),
      beginTransaction: jest.fn().mockResolvedValue(undefined),
      commit          : jest.fn().mockResolvedValue(undefined),
      rollback        : jest.fn().mockResolvedValue(undefined),
      release         : jest.fn().mockReturnValue(undefined),
    };
    db.getConnection.mockResolvedValue(mockConn);

    const token = makeToken('admin');
    const res = await request(app)
      .patch('/api/time-extensions/1/approve')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).not.toBe(401);
    expect(res.status).not.toBe(403);
  });
});
