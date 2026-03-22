// ============================================
// FILE: tests/api/jobs.test.js
// PURPOSE: Tests for /api/jobs routes
//
// Routes (from src/routes/jobs.js):
//   GET  /api/jobs            — verifyToken (role-scoped)
//   GET  /api/jobs/my-jobs    — verifyToken
//   GET  /api/jobs/:id        — verifyToken
//   POST /api/jobs            — verifyToken + createJobValidation
//   PUT  /api/jobs/:id        — verifyToken + updateJobValidation
//   PUT  /api/jobs/:id/technicians — verifyToken
//   PUT  /api/jobs/:id/swap-vehicle — verifyToken + requirePermission('assignments:update')
//   DELETE /api/jobs/:id/vehicle — verifyToken + adminOnly (inline check)
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
// GET /api/jobs
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/jobs', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/jobs');
    expect(res.status).toBe(401);
  });

  test('200 for admin — returns jobs list', async () => {
    // Job.getAllJobs calls db.query — mock it
    db.query.mockResolvedValueOnce([[
      { id: 1, customer_name: 'ACME Corp', current_status: 'pending', technicians_json: '[]' },
    ], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/jobs')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });

  test('200 for technician — returns only own jobs', async () => {
    // Job.getJobsByTechnician calls db.query
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('technician', { id: 5 });
    const res = await request(app)
      .get('/api/jobs')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /api/jobs
// Note: POST /api/jobs does NOT have a role permission check (any auth'd user
// can attempt — validation catches bad data). Technician role gets same 201
// if validation passes. We test with admin for simplicity.
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/jobs', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/jobs')
      .send({ customer_name: 'Test' });
    expect(res.status).toBe(401);
  });

  test('400 when validation fails — missing required fields', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/jobs')
      .set('Authorization', `Bearer ${token}`)
      .send({ customer_name: 'X' }); // Missing required fields

    expect(res.status).toBe(400);
  });

  test('201 with valid job body', async () => {
    // Job.createJob calls db.query 4+ times:
    //  1. INSERT IGNORE INTO job_number_sequences
    //  2. UPDATE job_number_sequences SET counter = LAST_INSERT_ID(...)
    //  3. SELECT LAST_INSERT_ID() AS counter
    //  4. INSERT INTO jobs
    //  5. getJobById -> SELECT job
    db.query
      .mockResolvedValueOnce([{ insertId: 0, affectedRows: 1 }, {}])    // INSERT IGNORE sequences
      .mockResolvedValueOnce([{ affectedRows: 1 }, {}])                  // UPDATE counter
      .mockResolvedValueOnce([[{ counter: 1 }], {}])                     // SELECT LAST_INSERT_ID
      .mockResolvedValueOnce([{ insertId: 42, affectedRows: 1 }, {}])    // INSERT job
      .mockResolvedValueOnce([[{                                          // getJobById SELECT
        id: 42, customer_name: 'Test Customer',
        current_status: 'pending', technicians_json: null,
        scheduled_date: '2026-04-01',
      }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/jobs')
      .set('Authorization', `Bearer ${token}`)
      .send({
        job_type                  : 'installation',
        customer_name             : 'Test Customer',
        customer_address          : '123 Main Street',
        scheduled_date            : '2026-04-01',
        scheduled_time_start      : '09:00',
        scheduled_time_end        : '11:00',
        estimated_duration_minutes: 120,
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/jobs/:id
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/jobs/:id', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/jobs/1');
    expect(res.status).toBe(401);
  });

  test('404 when job not found', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/jobs/9999')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  test('200 when job found for admin', async () => {
    db.query.mockResolvedValueOnce([[{
      id: 1, customer_name: 'ACME', current_status: 'pending', technicians_json: '[]',
    }], {}]);

    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/jobs/1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
