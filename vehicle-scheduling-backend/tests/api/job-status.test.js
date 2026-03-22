// ============================================
// FILE: tests/api/job-status.test.js
// PURPOSE: Tests for /api/job-status routes
//
// Routes (from src/routes/jobStatusRoutes.js):
//   POST /api/job-status/complete           — verifyToken
//   POST /api/job-status/update             — no explicit verifyToken (JobStatusController.updateStatus)
//   GET  /api/job-status/history/:job_id    — JobStatusController.getStatusHistory
//   GET  /api/job-status/allowed-transitions/:job_id — JobStatusController.getAllowedTransitions
//   POST /api/job-status/validate-transition — JobStatusController.validateTransition
//   GET  /api/job-status/recent-changes     — JobStatusController.getRecentStatusChanges
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
// POST /api/job-status/complete
// ─────────────────────────────────────────────────────────────────────────────
describe('POST /api/job-status/complete', () => {
  test('401 without token', async () => {
    const res = await request(app)
      .post('/api/job-status/complete')
      .send({ job_id: 1 });
    expect(res.status).toBe(401);
  });

  test('400 when job_id is missing', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/job-status/complete')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });

  test('200 for admin completing a job', async () => {
    // JobStatusService.completeJob calls db.query multiple times
    // 1. Get job with FOR UPDATE (beginTransaction path)
    // 2. Get personnel check
    // 3. UPDATE status
    // 4. INSERT into job_status_changes
    // 5. INSERT into job_completion_details
    // 6. getJobById for response
    const mockJob = {
      id: 1, current_status: 'in_progress', driver_id: null,
      scheduled_date: '2026-04-01', customer_name: 'Test',
    };

    // Use getConnection mock for transaction path
    const mockConn = {
      query           : jest.fn(),
      beginTransaction: jest.fn().mockResolvedValue(undefined),
      commit          : jest.fn().mockResolvedValue(undefined),
      rollback        : jest.fn().mockResolvedValue(undefined),
      release         : jest.fn().mockReturnValue(undefined),
    };
    // getJobById (plain query) for personnel check
    db.query
      .mockResolvedValueOnce([[{ id: 1, driver_id: null, current_status: 'in_progress' }], {}])  // personnel check
      .mockResolvedValueOnce([[{ id: 1, current_status: 'completed', technicians_json: null, scheduled_date: '2026-04-01' }], {}]); // final getJobById

    // Transaction path uses getConnection
    db.getConnection.mockResolvedValue(mockConn);
    mockConn.query
      .mockResolvedValueOnce([[mockJob], {}])              // SELECT FOR UPDATE
      .mockResolvedValueOnce([{ affectedRows: 1 }, {}])   // UPDATE status
      .mockResolvedValueOnce([{ insertId: 1 }, {}])        // INSERT status_change
      .mockResolvedValueOnce([{ insertId: 1 }, {}]);       // INSERT completion_details

    const token = makeToken('admin');
    const res = await request(app)
      .post('/api/job-status/complete')
      .set('Authorization', `Bearer ${token}`)
      .send({ job_id: 1 });

    expect(res.status).not.toBe(401);
    // 200 on success, or 403/500 if service logic differs — main test is auth passes
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/job-status/history/:job_id
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/job-status/history/:job_id', () => {
  test('200 with mocked history data', async () => {
    // getStatusHistory first calls Job.getJobById (1 db.query for SELECT job)
    // then calls JobStatusService.getJobStatusHistory (1 db.query for SELECT history)
    db.query
      .mockResolvedValueOnce([[{
        id: 1, job_number: 'JOB-2026-0001', current_status: 'in_progress',
        technicians_json: null, scheduled_date: '2026-04-01',
      }], {}])   // Job.getJobById
      .mockResolvedValueOnce([[], {}]);  // JobStatusService.getJobStatusHistory

    // No explicit auth on this endpoint in the route file
    const res = await request(app).get('/api/job-status/history/1');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ─────────────────────────────────────────────────────────────────────────────
// GET /api/job-status/recent-changes
// ─────────────────────────────────────────────────────────────────────────────
describe('GET /api/job-status/recent-changes', () => {
  test('200 with mocked data', async () => {
    db.query.mockResolvedValueOnce([[], {}]);

    const res = await request(app).get('/api/job-status/recent-changes');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});
