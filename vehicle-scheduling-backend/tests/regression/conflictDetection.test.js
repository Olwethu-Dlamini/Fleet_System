// ============================================
// FILE: tests/regression/conflictDetection.test.js
// PURPOSE: Regression tests for double-booking and time overlap
//          detection in job assignments.
//
// TEST-03: Regression suite — conflict detection cases
//
// IMPORTANT: JWT_SECRET must be set at line 1 BEFORE any require.
// ============================================

process.env.JWT_SECRET  = 'test-secret-value-minimum-32-chars-ok';
process.env.NODE_ENV    = 'test';

require('../api/helpers/db.mock');

const request  = require('supertest');
const app      = require('../../src/server');
const { makeToken } = require('../api/helpers/auth');
const { resetDbMocks, db } = require('../api/helpers/db.mock');

beforeEach(() => {
  resetDbMocks();
  db.query.mockResolvedValue([[], {}]);

  const mockConn = {
    query           : jest.fn().mockResolvedValue([[], {}]),
    beginTransaction: jest.fn().mockResolvedValue(undefined),
    commit          : jest.fn().mockResolvedValue(undefined),
    rollback        : jest.fn().mockResolvedValue(undefined),
    release         : jest.fn().mockReturnValue(undefined),
  };
  db.getConnection.mockResolvedValue(mockConn);
});

// ============================================
// Test 1: Vehicle conflict detection via check-conflict endpoint
//
// POST /api/job-assignments/check-conflict
// Uses VehicleAvailabilityService.checkVehicleAvailability which:
//   Call 1: validateVehicle — SELECT from vehicles WHERE id = ?
//   Call 2: conflict query  — SELECT overlapping job_assignments
// ============================================
describe('Vehicle availability conflict detection', () => {
  it('should report conflict when vehicle is already booked for overlapping time', async () => {
    const token = makeToken('scheduler');

    // Call 1: validateVehicle returns the vehicle as active
    db.query
      .mockResolvedValueOnce([[{ id: 10, vehicle_name: 'Van A', is_active: 1 }], {}])
      // Call 2: conflict query returns an overlapping job
      .mockResolvedValueOnce([[{
        id                  : 5,
        job_number          : 'JOB-001',
        customer_name       : 'Test Customer',
        scheduled_date      : '2026-07-01',
        scheduled_time_start: '09:00:00',
        scheduled_time_end  : '12:00:00',
        current_status      : 'assigned',
        vehicle_name        : 'Van A',
        license_plate       : 'TST-001',
      }], {}]);

    const res = await request(app)
      .post('/api/job-assignments/check-conflict')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicle_id           : 10,
        scheduled_date       : '2026-07-01',
        scheduled_time_start : '10:00:00',
        scheduled_time_end   : '13:00:00',
      });

    // The route returns 200 with available:false when there is a conflict
    expect(res.status).toBe(200);
    expect(res.body.available).toBe(false);
    expect(res.body.conflicts).toHaveLength(1);
  });

  it('should allow assignment when vehicle has no overlapping jobs', async () => {
    const token = makeToken('scheduler');

    // Call 1: validateVehicle — vehicle exists and is active
    db.query
      .mockResolvedValueOnce([[{ id: 10, vehicle_name: 'Van A', is_active: 1 }], {}])
      // Call 2: conflict query — no conflicts
      .mockResolvedValueOnce([[], {}]);

    const res = await request(app)
      .post('/api/job-assignments/check-conflict')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicle_id           : 10,
        scheduled_date       : '2026-07-02',
        scheduled_time_start : '09:00:00',
        scheduled_time_end   : '11:00:00',
      });

    expect(res.status).toBe(200);
    expect(res.body.available).toBe(true);
    expect(res.body.conflicts).toHaveLength(0);
  });
});

// ============================================
// Test 2: Vehicle swap conflict detection
//
// PUT /api/jobs/:id/swap-vehicle
// When the new vehicle is already booked for the same time,
// the swap should be rejected with 409.
// ============================================
describe('Vehicle swap conflict regression', () => {
  it('should reject swap when new vehicle is already assigned to overlapping job', async () => {
    const token = makeToken('scheduler');

    // Mock 1: job exists
    db.query
      .mockResolvedValueOnce([[{
        id                  : 1,
        scheduled_date      : '2026-07-01',
        scheduled_time_start: '09:00:00',
        scheduled_time_end  : '12:00:00',
        current_status      : 'assigned',
      }], {}])
      // Mock 2: vehicle exists and is active
      .mockResolvedValueOnce([[{
        id          : 20,
        vehicle_name: 'Van B',
      }], {}])
      // Mock 3: Vehicle.getAvailableVehicles — vehicle 20 NOT in available list
      // (returns vehicles that DON'T include vehicle 20)
      .mockResolvedValueOnce([[{ id: 5 }, { id: 6 }], {}])
      // Mock 4: current assignment — job 1 has vehicle 10 (not 20)
      .mockResolvedValueOnce([[{ vehicle_id: 10 }], {}]);

    const res = await request(app)
      .put('/api/jobs/1/swap-vehicle')
      .set('Authorization', `Bearer ${token}`)
      .send({ new_vehicle_id: 20 });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
  });

  it('should allow swap when new vehicle is available', async () => {
    const token = makeToken('scheduler');

    // Mock 1: job exists
    db.query
      .mockResolvedValueOnce([[{
        id                  : 1,
        scheduled_date      : '2026-07-01',
        scheduled_time_start: '09:00:00',
        scheduled_time_end  : '12:00:00',
        current_status      : 'assigned',
      }], {}])
      // Mock 2: vehicle exists and is active
      .mockResolvedValueOnce([[{
        id          : 20,
        vehicle_name: 'Van B',
      }], {}])
      // Mock 3: Vehicle.getAvailableVehicles — vehicle 20 IS available
      .mockResolvedValueOnce([[{ id: 20 }, { id: 5 }], {}])
      // Mock 4: current assignment
      .mockResolvedValueOnce([[{ vehicle_id: 10 }], {}])
      // Mock 5: UPDATE job_assignments
      .mockResolvedValueOnce([{ affectedRows: 1 }, {}]);

    const res = await request(app)
      .put('/api/jobs/1/swap-vehicle')
      .set('Authorization', `Bearer ${token}`)
      .send({ new_vehicle_id: 20 });

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
  });
});

// ============================================
// Test 3: Maintenance window conflict detection
//
// POST /api/vehicle-maintenance
// When a vehicle already has an active maintenance window
// overlapping the requested dates, the endpoint must return 409.
// ============================================
describe('Maintenance window overlap regression', () => {
  it('should reject overlapping maintenance window creation', async () => {
    const token = makeToken('admin');

    // Mock overlap check returns a record (conflict exists)
    db.query.mockResolvedValueOnce([[{ id: 7 }], {}]);

    const res = await request(app)
      .post('/api/vehicle-maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicle_id       : 1,
        maintenance_type : 'service',
        start_date       : '2026-08-01',
        end_date         : '2026-08-05',
      });

    expect(res.status).toBe(409);
    expect(res.body.success).toBe(false);
  });

  it('should allow maintenance record when no overlap exists', async () => {
    const token = makeToken('admin');

    // Mock 1: overlap check — no existing records
    db.query
      .mockResolvedValueOnce([[], {}])
      // Mock 2: INSERT
      .mockResolvedValueOnce([{ insertId: 99 }, {}])
      // Mock 3: SELECT after insert
      .mockResolvedValueOnce([[{
        id             : 99,
        vehicle_id     : 1,
        maintenance_type: 'service',
        status         : 'scheduled',
        start_date     : '2026-09-01',
        end_date       : '2026-09-03',
        vehicle_name   : 'Van A',
      }], {}]);

    const res = await request(app)
      .post('/api/vehicle-maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicle_id       : 1,
        maintenance_type : 'service',
        start_date       : '2026-09-01',
        end_date         : '2026-09-03',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
  });

  it('should detect overlap when new window starts during existing window', async () => {
    const token = makeToken('admin');

    // Mock: an existing maintenance record overlapping the new request
    db.query.mockResolvedValueOnce([[{
      id        : 12,
      vehicle_id: 2,
      start_date: '2026-10-01',
      end_date  : '2026-10-10',
      status    : 'scheduled',
    }], {}]);

    const res = await request(app)
      .post('/api/vehicle-maintenance')
      .set('Authorization', `Bearer ${token}`)
      .send({
        vehicle_id       : 2,
        maintenance_type : 'repair',
        start_date       : '2026-10-05', // starts inside existing window
        end_date         : '2026-10-15',
      });

    // Must reject with conflict
    expect(res.status).toBe(409);
  });
});
