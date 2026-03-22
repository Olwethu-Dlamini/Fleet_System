---
phase: 08-testing-suite
plan: 01
subsystem: backend-testing
tags: [testing, jest, supertest, api, mocking]
dependency_graph:
  requires: []
  provides: [TEST-01, backend-api-coverage]
  affects: [all-backend-routes]
tech_stack:
  added: [jest, supertest, jest-mock-db]
  patterns: [db-mocking, jwt-fixture, supertest-integration]
key_files:
  created:
    - vehicle-scheduling-backend/tests/api/helpers/auth.js
    - vehicle-scheduling-backend/tests/api/helpers/db.mock.js
    - vehicle-scheduling-backend/tests/api/auth.test.js
    - vehicle-scheduling-backend/tests/api/jobs.test.js
    - vehicle-scheduling-backend/tests/api/vehicles.test.js
    - vehicle-scheduling-backend/tests/api/users.test.js
    - vehicle-scheduling-backend/tests/api/dashboard.test.js
    - vehicle-scheduling-backend/tests/api/reports.test.js
    - vehicle-scheduling-backend/tests/api/notifications.test.js
    - vehicle-scheduling-backend/tests/api/settings.test.js
    - vehicle-scheduling-backend/tests/api/job-assignments.test.js
    - vehicle-scheduling-backend/tests/api/job-status.test.js
    - vehicle-scheduling-backend/tests/api/availability.test.js
    - vehicle-scheduling-backend/tests/api/vehicle-maintenance.test.js
    - vehicle-scheduling-backend/tests/api/time-extensions.test.js
    - vehicle-scheduling-backend/tests/api/gps.test.js
  modified:
    - vehicle-scheduling-backend/package.json
    - vehicle-scheduling-backend/src/routes/vehicles.js
decisions:
  - "jest.mock() hoisted before server require — JWT_SECRET set at line 1 of each test file to prevent process.exit(1)"
  - "db.mock.js mocks pool directly (not query wrapper) — database.js exports pool, not { query }"
  - "mockResolvedValueOnce chained for Promise.all routes (dashboard summary uses 5 concurrent queries)"
  - "vehicle route validator bug fixed: body('name') aligned to body('vehicle_name') to match handler destructuring"
metrics:
  duration_minutes: 5
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 16
  files_modified: 2
requirements_satisfied: [TEST-01]
---

# Phase 8 Plan 1: Backend API Test Suite Summary

**One-liner:** 112 API tests across 14 test files covering all 15 backend route groups using Jest + Supertest with jest.mock DB — no live database required.

## What Was Built

Created a complete API test suite for the FleetScheduler backend. Every route group in `src/routes/index.js` now has at least one happy-path test (200/201) and one auth-failure test (401).

### Test Infrastructure

**`tests/api/helpers/auth.js`** — JWT fixture helper:
- `makeToken(role, overrides)` mints a valid signed JWT using `test-secret-value-minimum-32-chars-ok`
- Used by every test file to inject auth tokens into supertest requests

**`tests/api/helpers/db.mock.js`** — Database mock:
- `jest.mock('../../../src/config/database', ...)` replaces the MySQL pool with a Jest mock
- Provides `db.query` (mockFn), `db.getConnection` (returns mock connection with transaction methods)
- `resetDbMocks()` resets all mock state between tests — called in `beforeEach()`

### Test Files (14 files, 112 tests)

| File | Route Group | Tests |
|------|-------------|-------|
| auth.test.js | POST /api/auth/login, GET /api/auth/me, POST /api/auth/logout | 7 |
| jobs.test.js | GET/POST /api/jobs, GET /api/jobs/:id | 9 |
| vehicles.test.js | GET/POST/DELETE /api/vehicles | 7 |
| users.test.js | GET/POST /api/users | 7 |
| dashboard.test.js | GET /api/dashboard/{summary,stats,chart-data} | 6 |
| reports.test.js | GET /api/reports/{summary,jobs-by-vehicle} | 5 |
| notifications.test.js | GET/PATCH /api/notifications | 6 |
| settings.test.js | GET/PUT /api/settings | 7 |
| job-assignments.test.js | GET /api/job-assignments/driver-load, POST check-conflict, PUT technicians | 5 |
| job-status.test.js | POST /api/job-status/complete, GET history, GET recent-changes | 5 |
| availability.test.js | GET /api/availability/drivers, /vehicles, POST check-drivers | 9 |
| vehicle-maintenance.test.js | GET/POST /api/vehicle-maintenance | 8 |
| time-extensions.test.js | POST/GET/PATCH /api/time-extensions | 7 |
| gps.test.js | GET/POST /api/gps/consent, /directions, /drivers, /location | 10 |

### package.json Scripts Added

```json
"test:api": "jest --testPathPatterns=tests/api --forceExit",
"test:regression": "jest --testPathPatterns=tests/regression --forceExit",
"test:all": "jest --forceExit"
```

Note: Jest 30.x requires `--testPathPatterns` (plural) — the old `--testPathPattern` flag was removed in this major version.

## Verification

```
Test Suites: 14 passed, 14 total
Tests:       112 passed, 112 total
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed vehicle route validator field name mismatch**
- **Found during:** Task 1 (vehicles test 201 failing)
- **Issue:** `createVehicleValidation` used `body('name')` but the route handler destructures `vehicle_name` from `req.body`. When a client sends `vehicle_name`, the validator checked `name` (absent) and returned 422 validation error before the handler ran.
- **Fix:** Updated `body('name')` to `body('vehicle_name')` in both `createVehicleValidation` and `updateVehicleValidation`
- **Files modified:** `src/routes/vehicles.js`
- **Commit:** 9389ab8

**2. [Rule 1 - Bug] Fixed `--testPathPattern` → `--testPathPatterns` for Jest 30.x**
- **Found during:** Task 1 (first test run crashed immediately)
- **Issue:** Jest 30.x removed the singular `--testPathPattern` flag, replacing it with `--testPathPatterns`
- **Fix:** Updated all test scripts in package.json
- **Files modified:** `package.json`
- **Commit:** 9389ab8

## Known Stubs

None — all test files exercise real route logic against mocked database responses. No hardcoded empty values reach the test assertions.

## Self-Check: PASSED

All 17 files verified present. Both task commits confirmed in git log:
- `9389ab8` — Task 1: helpers + 7 route test files
- `2784db7` — Task 2: remaining 7 route test files

Final test run: 112 tests passed, 0 failures, 14 test suites.
