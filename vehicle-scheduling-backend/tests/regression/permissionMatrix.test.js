// ============================================
// FILE: tests/regression/permissionMatrix.test.js
// PURPOSE: Regression test that validates RBAC enforcement across all
//          permission-gated endpoints for all 4 roles.
//
// TEST-04: Permission matrix — 4 roles × all protected endpoints
//
// IMPORTANT: JWT_SECRET must be set at line 1 BEFORE any require
// so that server.js startup guard does not call process.exit(1).
// ============================================

process.env.JWT_SECRET  = 'test-secret-value-minimum-32-chars-ok';
process.env.NODE_ENV    = 'test';

require('../api/helpers/db.mock');

const request = require('supertest');
const app     = require('../../src/server');
const { makeToken } = require('../api/helpers/auth');
const { resetDbMocks, db } = require('../api/helpers/db.mock');

// ============================================
// DB stub setup — every route needs at least one
// db.query call to not crash before the auth check.
// We reset and re-apply before each test.
// ============================================
beforeEach(() => {
  resetDbMocks();
  // Default: return empty result so routes don't throw before the
  // permission middleware returns 403.
  db.query.mockResolvedValue([[], {}]);

  // getConnection default (used by transaction routes)
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
// Helper: make a supertest request with a Bearer token
// ============================================
function authed(method, path, role, body = {}) {
  const token = makeToken(role);
  const req   = request(app)[method](path)
    .set('Authorization', `Bearer ${token}`);
  if (['post', 'put', 'patch'].includes(method)) {
    req.send(body);
  }
  return req;
}

// ============================================
// PERMISSION MATRIX
//
// Each row: [description, httpMethod, path, role, isAllowed]
// isAllowed = true  → expect NOT 403 (any of 200, 201, 400, 404, 409, 500 is acceptable)
// isAllowed = false → expect 403
//
// IMPORTANT facts derived from reading each route file:
//
//   GET  /api/jobs             — verifyToken only (no requirePermission)
//                                → all authenticated roles allowed
//   POST /api/jobs             — verifyToken + validation
//                                → all authenticated roles allowed (permission not enforced)
//   PUT  /api/jobs/:id         — verifyToken + validation
//                                → all authenticated roles allowed
//   DELETE /api/jobs/1/vehicle — verifyToken + inline admin check
//                                → only admin; others get 403
//   PUT  /api/jobs/1/swap-vehicle — verifyToken + requirePermission('assignments:update')
//                                → admin/scheduler/dispatcher allowed; technician blocked
//
//   GET  /api/vehicles         — NO AUTH at all (public route)
//                                → all roles allowed
//   POST /api/vehicles         — requireAdmin (adminOnly)
//                                → only admin; others get 403
//   PUT  /api/vehicles/1       — requireAdmin
//                                → only admin; others get 403
//   DELETE /api/vehicles/1     — requireAdmin
//                                → only admin; others get 403
//
//   GET  /api/users            — requireAdminOrScheduler (schedulerOrAbove = admin|scheduler)
//                                → admin and scheduler allowed; dispatcher and technician blocked
//   POST /api/users            — requireAdmin
//                                → only admin; others get 403
//   DELETE /api/users/2        — requireAdmin
//                                → only admin; others get 403
//
//   GET  /api/dashboard/summary — verifyToken only
//                                 → all roles allowed
//
//   GET  /api/reports/summary  — verifyToken + schedulerOrAbove (admin|scheduler)
//                                → admin and scheduler; dispatcher and technician blocked
//
//   GET  /api/settings         — verifyToken + requirePermission('settings:read')
//                                → admin only (per PERMISSIONS map)
//   PUT  /api/settings/gps_enabled — verifyToken + requirePermission('settings:update')
//                                → admin only
//
//   GET  /api/vehicle-maintenance?vehicle_id=1
//                              — verifyToken + requirePermission('maintenance:read')
//                                → admin/dispatcher/scheduler/technician all allowed
//   POST /api/vehicle-maintenance
//                              — verifyToken + requirePermission('maintenance:create')
//                                → admin only; others blocked
//   DELETE /api/vehicle-maintenance/1
//                              — verifyToken + requirePermission('maintenance:create')
//                                → admin only; others blocked
//
//   PUT  /api/jobs/1/swap-vehicle
//                              — verifyToken + requirePermission('assignments:update')
//                                → admin/dispatcher/scheduler; technician blocked
// ============================================

const MATRIX = [
  // ── GET /api/jobs ─────────────────────────────────────────────────────────
  ['jobs:read — admin can list jobs',       'get', '/api/jobs', 'admin',      true],
  ['jobs:read — scheduler can list jobs',   'get', '/api/jobs', 'scheduler',  true],
  ['jobs:read — dispatcher can list jobs',  'get', '/api/jobs', 'dispatcher', true],
  ['jobs:read — technician can list jobs',  'get', '/api/jobs', 'technician', true],

  // ── GET /api/jobs/:id ────────────────────────────────────────────────────
  ['jobs:read — admin can get job by id',       'get', '/api/jobs/999', 'admin',      true],
  ['jobs:read — scheduler can get job by id',   'get', '/api/jobs/999', 'scheduler',  true],
  ['jobs:read — dispatcher can get job by id',  'get', '/api/jobs/999', 'dispatcher', true],
  ['jobs:read — technician can get job by id',  'get', '/api/jobs/999', 'technician', true],

  // ── DELETE /api/jobs/:id/vehicle (inline admin check) ────────────────────
  ['jobs:admin — admin can unassign vehicle',        'delete', '/api/jobs/1/vehicle', 'admin',      true],
  ['jobs:admin — scheduler blocked from unassigning','delete', '/api/jobs/1/vehicle', 'scheduler',  false],
  ['jobs:admin — dispatcher blocked from unassigning','delete', '/api/jobs/1/vehicle', 'dispatcher', false],
  ['jobs:admin — technician blocked from unassigning','delete', '/api/jobs/1/vehicle', 'technician', false],

  // ── PUT /api/jobs/:id/swap-vehicle (assignments:update) ─────────────────
  ['assignments:update — admin can swap vehicle',        'put', '/api/jobs/1/swap-vehicle', 'admin',      true],
  ['assignments:update — scheduler can swap vehicle',    'put', '/api/jobs/1/swap-vehicle', 'scheduler',  true],
  ['assignments:update — dispatcher can swap vehicle',   'put', '/api/jobs/1/swap-vehicle', 'dispatcher', true],
  ['assignments:update — technician blocked swap vehicle','put', '/api/jobs/1/swap-vehicle', 'technician', false],

  // ── POST /api/vehicles (vehicles:create — adminOnly) ────────────────────
  ['vehicles:create — admin can create vehicle',         'post', '/api/vehicles', 'admin',      true],
  ['vehicles:create — scheduler blocked create vehicle', 'post', '/api/vehicles', 'scheduler',  false],
  ['vehicles:create — dispatcher blocked create vehicle','post', '/api/vehicles', 'dispatcher', false],
  ['vehicles:create — technician blocked create vehicle','post', '/api/vehicles', 'technician', false],

  // ── PUT /api/vehicles/:id (vehicles:update — adminOnly) ─────────────────
  ['vehicles:update — admin can update vehicle',         'put', '/api/vehicles/1', 'admin',      true],
  ['vehicles:update — scheduler blocked update vehicle', 'put', '/api/vehicles/1', 'scheduler',  false],
  ['vehicles:update — dispatcher blocked update vehicle','put', '/api/vehicles/1', 'dispatcher', false],
  ['vehicles:update — technician blocked update vehicle','put', '/api/vehicles/1', 'technician', false],

  // ── DELETE /api/vehicles/:id (vehicles:delete — adminOnly) ──────────────
  ['vehicles:delete — admin can delete vehicle',         'delete', '/api/vehicles/1', 'admin',      true],
  ['vehicles:delete — scheduler blocked delete vehicle', 'delete', '/api/vehicles/1', 'scheduler',  false],
  ['vehicles:delete — dispatcher blocked delete vehicle','delete', '/api/vehicles/1', 'dispatcher', false],
  ['vehicles:delete — technician blocked delete vehicle','delete', '/api/vehicles/1', 'technician', false],

  // ── GET /api/users (users:read — schedulerOrAbove = admin|scheduler) ────
  // NOTE: schedulerOrAbove uses requireRole('admin','scheduler') — not requirePermission
  //       dispatcher is NOT in the allowed list even though PERMISSIONS['users:read'] = [admin]
  ['users:read — admin can list users',         'get', '/api/users', 'admin',      true],
  ['users:read — scheduler can list users',     'get', '/api/users', 'scheduler',  true],
  ['users:read — dispatcher blocked list users','get', '/api/users', 'dispatcher', false],
  ['users:read — technician blocked list users','get', '/api/users', 'technician', false],

  // ── POST /api/users (users:create — adminOnly) ──────────────────────────
  ['users:create — admin can create user',         'post', '/api/users', 'admin',      true],
  ['users:create — scheduler blocked create user', 'post', '/api/users', 'scheduler',  false],
  ['users:create — dispatcher blocked create user','post', '/api/users', 'dispatcher', false],
  ['users:create — technician blocked create user','post', '/api/users', 'technician', false],

  // ── DELETE /api/users/2 (users:delete — adminOnly) ──────────────────────
  ['users:delete — admin can delete user',         'delete', '/api/users/2', 'admin',      true],
  ['users:delete — scheduler blocked delete user', 'delete', '/api/users/2', 'scheduler',  false],
  ['users:delete — dispatcher blocked delete user','delete', '/api/users/2', 'dispatcher', false],
  ['users:delete — technician blocked delete user','delete', '/api/users/2', 'technician', false],

  // ── GET /api/dashboard/summary (verifyToken only) ───────────────────────
  ['dashboard:read — admin can read dashboard',       'get', '/api/dashboard/summary', 'admin',      true],
  ['dashboard:read — scheduler can read dashboard',   'get', '/api/dashboard/summary', 'scheduler',  true],
  ['dashboard:read — dispatcher can read dashboard',  'get', '/api/dashboard/summary', 'dispatcher', true],
  ['dashboard:read — technician can read dashboard',  'get', '/api/dashboard/summary', 'technician', true],

  // ── GET /api/reports/summary (schedulerOrAbove = admin|scheduler) ────────
  ['reports:read — admin can read reports',         'get', '/api/reports/summary', 'admin',      true],
  ['reports:read — scheduler can read reports',     'get', '/api/reports/summary', 'scheduler',  true],
  ['reports:read — dispatcher blocked read reports','get', '/api/reports/summary', 'dispatcher', false],
  ['reports:read — technician blocked read reports','get', '/api/reports/summary', 'technician', false],

  // ── GET /api/settings (settings:read — admin only via requirePermission) ─
  ['settings:read — admin can read settings',         'get', '/api/settings', 'admin',      true],
  ['settings:read — scheduler blocked read settings', 'get', '/api/settings', 'scheduler',  false],
  ['settings:read — dispatcher blocked read settings','get', '/api/settings', 'dispatcher', false],
  ['settings:read — technician blocked read settings','get', '/api/settings', 'technician', false],

  // ── PUT /api/settings/:key (settings:update — admin only) ────────────────
  ['settings:update — admin can update settings',         'put', '/api/settings/gps_enabled', 'admin',      true],
  ['settings:update — scheduler blocked update settings', 'put', '/api/settings/gps_enabled', 'scheduler',  false],
  ['settings:update — dispatcher blocked update settings','put', '/api/settings/gps_enabled', 'dispatcher', false],
  ['settings:update — technician blocked update settings','put', '/api/settings/gps_enabled', 'technician', false],

  // ── GET /api/vehicle-maintenance (maintenance:read — all roles) ───────────
  ['maintenance:read — admin can read maintenance',       'get', '/api/vehicle-maintenance?vehicle_id=1', 'admin',      true],
  ['maintenance:read — scheduler can read maintenance',   'get', '/api/vehicle-maintenance?vehicle_id=1', 'scheduler',  true],
  ['maintenance:read — dispatcher can read maintenance',  'get', '/api/vehicle-maintenance?vehicle_id=1', 'dispatcher', true],
  ['maintenance:read — technician can read maintenance',  'get', '/api/vehicle-maintenance?vehicle_id=1', 'technician', true],

  // ── POST /api/vehicle-maintenance (maintenance:create — admin only) ───────
  ['maintenance:create — admin can create maintenance',         'post', '/api/vehicle-maintenance', 'admin',      true],
  ['maintenance:create — scheduler blocked create maintenance', 'post', '/api/vehicle-maintenance', 'scheduler',  false],
  ['maintenance:create — dispatcher blocked create maintenance','post', '/api/vehicle-maintenance', 'dispatcher', false],
  ['maintenance:create — technician blocked create maintenance','post', '/api/vehicle-maintenance', 'technician', false],

  // ── DELETE /api/vehicle-maintenance/:id (maintenance:create — admin only) ─
  ['maintenance:delete — admin can delete maintenance',         'delete', '/api/vehicle-maintenance/1', 'admin',      true],
  ['maintenance:delete — scheduler blocked delete maintenance', 'delete', '/api/vehicle-maintenance/1', 'scheduler',  false],
  ['maintenance:delete — dispatcher blocked delete maintenance','delete', '/api/vehicle-maintenance/1', 'dispatcher', false],
  ['maintenance:delete — technician blocked delete maintenance','delete', '/api/vehicle-maintenance/1', 'technician', false],
];

// ============================================
// Non-403 statuses — these indicate the route
// was reached (auth passed). DB errors (500)
// and validation errors (400, 404, 409) are
// acceptable because they prove the permission
// gate was cleared.
// ============================================
const ALLOWED_STATUSES = [200, 201, 400, 404, 409, 500];

describe('Permission Matrix — all roles × all protected endpoints', () => {
  MATRIX.forEach(([description, method, path, role, isAllowed]) => {
    it(description, async () => {
      // Some POST/PUT routes need a body to get past validation.
      // We send a minimal body. The important thing is whether we
      // get 403 vs something else — we don't care about 400/500.
      const body = {};
      if (path.includes('swap-vehicle')) {
        body.new_vehicle_id = 99;
      }
      if (path === '/api/vehicles' && method === 'post') {
        body.vehicle_name   = 'Test Van';
        body.license_plate  = 'TST-001';
        body.vehicle_type   = 'van';
      }
      if (path.includes('/api/vehicles/') && method === 'put') {
        body.vehicle_name = 'Updated Van';
      }
      if (path === '/api/users' && method === 'post') {
        body.username   = 'testuser';
        body.full_name  = 'Test User';
        body.email      = 'test@example.com';
        body.password   = 'password123';
        body.role       = 'technician';
      }
      if (path.includes('/api/settings/') && method === 'put') {
        body.value = 'true';
      }
      if (path === '/api/vehicle-maintenance' && method === 'post') {
        body.vehicle_id       = 1;
        body.maintenance_type = 'service';
        body.start_date       = '2026-06-01';
        body.end_date         = '2026-06-02';
      }

      const res = await authed(method, path, role, body);

      if (isAllowed) {
        expect(ALLOWED_STATUSES).toContain(res.status);
      } else {
        expect(res.status).toBe(403);
      }
    });
  });
});
