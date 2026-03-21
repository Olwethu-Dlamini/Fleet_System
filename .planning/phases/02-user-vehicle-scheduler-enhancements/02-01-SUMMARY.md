---
phase: 02-user-vehicle-scheduler-enhancements
plan: 01
subsystem: api
tags: [express, mysql, flutter, maintenance, settings, vehicle-scheduling]

requires:
  - phase: 01-foundation
    provides: JWT auth middleware, verifyToken, requirePermission, pino logger, constants.js patterns, validate middleware

provides:
  - Schema migration SQL for contact_phone columns, vehicle_maintenance table, settings table
  - MAINTENANCE_TYPE and MAINTENANCE_STATUS constants in constants.js
  - maintenance:* and settings:* permission keys in PERMISSIONS map
  - Vehicle maintenance CRUD routes (GET, POST, PUT, DELETE with overlap guard and soft-delete)
  - Settings key-value GET/PUT routes with upsert
  - PUT /api/jobs/:id/swap-vehicle endpoint with requirePermission(assignments:update)
  - Extended users.js CRUD accepting/returning contact_phone and contact_phone_secondary
  - Vehicle.getAvailableVehicles now blocks vehicles with overlapping maintenance windows
  - Vehicle.getAllVehicles now returns is_in_maintenance boolean flag
  - Flutter vehicleMaintenanceEndpoint and settingsEndpoint constants in app_config.dart

affects:
  - 02-02 (Flutter user contact phone UI — depends on users.js contact_phone fields)
  - 02-03 (Flutter vehicle maintenance UI — depends on vehicle-maintenance.js routes and Flutter endpoint constants)
  - Any phase that checks vehicle availability (maintenance blocking now active)

tech-stack:
  added: []
  patterns:
    - requireMaintRead/requireMaintAdmin bundles for maintenance route auth
    - Overlap guard with NOT IN subquery before INSERT (prevents double-booking)
    - Soft-delete via status = 'completed' (never hard-delete maintenance records)
    - Settings upsert pattern — UPDATE first, INSERT if affectedRows === 0
    - Maintenance blocking in getAvailableVehicles via second NOT IN subquery

key-files:
  created:
    - vehicle-scheduling-backend/src/migrations/02-user-vehicle-scheduler.sql
    - vehicle-scheduling-backend/src/routes/vehicle-maintenance.js
    - vehicle-scheduling-backend/src/routes/settings.js
  modified:
    - vehicle-scheduling-backend/src/config/constants.js
    - vehicle-scheduling-backend/src/routes/users.js
    - vehicle-scheduling-backend/src/routes/jobs.js
    - vehicle-scheduling-backend/src/routes/index.js
    - vehicle-scheduling-backend/src/models/Vehicle.js
    - vehicle_scheduling_app/lib/config/app_config.dart

key-decisions:
  - "Soft-delete maintenance records via status=completed — hard delete violates audit trail requirement"
  - "Settings upsert — UPDATE first, then INSERT if missing — avoids REPLACE INTO which resets auto-increment IDs"
  - "Maintenance blocking uses date-only comparison (not datetime) — maintenance windows are day-granular by design"
  - "requirePermission(assignments:update) on swap-vehicle — admin+dispatcher+scheduler can swap, technicians cannot"

patterns-established:
  - "requireMaintRead/requireMaintAdmin: bundle verifyToken+requirePermission for route-level auth clarity"
  - "Overlap guard before INSERT: SELECT id LIMIT 1 returning 409 Conflict on overlap"

requirements-completed:
  - USR-01
  - USR-02
  - USR-03
  - MAINT-01
  - MAINT-02
  - MAINT-03
  - MAINT-04
  - MAINT-05
  - SCHED-01
  - SCHED-02
  - SCHED-03
  - SCHED-04

duration: 20min
completed: 2026-03-21
---

# Phase 2 Plan 1: User, Vehicle & Scheduler Enhancements — Backend Summary

**Vehicle maintenance CRUD with date-range blocking, user contact phone fields, admin settings store, and scheduler vehicle-swap endpoint — all backed by a single migration SQL and wired into Flutter endpoint config**

## Performance

- **Duration:** 20 min
- **Started:** 2026-03-21T13:00:00Z
- **Completed:** 2026-03-21T13:20:00Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Schema migration SQL covering all three feature areas: ALTER TABLE users (contact_phone), CREATE TABLE vehicle_maintenance (with overlap-preventing indexes), CREATE TABLE settings (GPS visibility seed)
- Full vehicle maintenance CRUD with overlap guard (409 on conflicting windows), soft-delete, and maintenance-window blocking wired into getAvailableVehicles
- User CRUD extended to accept, store, and return contact_phone and contact_phone_secondary through all existing endpoints (GET list, GET by id, POST create, PUT update)
- Settings key-value store (GET all, GET by key, PUT upsert) scoped by tenant_id
- PUT /api/jobs/:id/swap-vehicle with availability check and requirePermission('assignments:update')
- Flutter app_config.dart receives vehicleMaintenanceEndpoint and settingsEndpoint for wave-2 Flutter plans

## Task Commits

Each task was committed atomically:

1. **Task 1: Schema migration + constants extension** - `9c0f927` (feat)
2. **Task 2: Routes, models, and Flutter config for Phase 2** - `dd034fe` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified

- `vehicle-scheduling-backend/src/migrations/02-user-vehicle-scheduler.sql` - Phase 2 migration: ALTER users, CREATE vehicle_maintenance, CREATE settings, seed GPS row
- `vehicle-scheduling-backend/src/config/constants.js` - Added MAINTENANCE_TYPE, MAINTENANCE_STATUS, maintenance:*/settings:* permissions
- `vehicle-scheduling-backend/src/routes/vehicle-maintenance.js` - New: CRUD routes for vehicle maintenance scheduling
- `vehicle-scheduling-backend/src/routes/settings.js` - New: admin settings key-value store routes
- `vehicle-scheduling-backend/src/routes/users.js` - Extended: contact_phone/contact_phone_secondary in all SELECT/INSERT/UPDATE paths
- `vehicle-scheduling-backend/src/routes/jobs.js` - Added: PUT /:id/swap-vehicle with requirePermission
- `vehicle-scheduling-backend/src/routes/index.js` - Registered /vehicle-maintenance and /settings routes
- `vehicle-scheduling-backend/src/models/Vehicle.js` - getAvailableVehicles blocks maintenance vehicles; getAllVehicles returns is_in_maintenance
- `vehicle_scheduling_app/lib/config/app_config.dart` - Added vehicleMaintenanceEndpoint and settingsEndpoint constants

## Decisions Made

- Soft-delete maintenance records via `status = 'completed'` — hard delete would break audit trail and historical reporting
- Settings upsert pattern (UPDATE first, INSERT on affectedRows === 0) — avoids REPLACE INTO which resets auto-increment IDs and breaks FK references
- Maintenance blocking uses date-only comparison (not datetime) — maintenance windows are scheduled at day granularity, not time granularity
- `requirePermission('assignments:update')` on swap-vehicle gives strict backend enforcement — admin, dispatcher, and scheduler can swap; technicians cannot

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

**Manual database migration required before Phase 2 features are live.**

Run the following against your MariaDB database:

```bash
mysql -u root -p vehicle_scheduling < vehicle-scheduling-backend/src/migrations/02-user-vehicle-scheduler.sql
```

This is safe to run multiple times (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS / INSERT IGNORE).

## Known Stubs

None — no stub data or placeholder text was introduced. All routes are fully wired to the database. The migration SQL must be applied manually before the new endpoints return data.

## Next Phase Readiness

- Wave-2 Flutter plans (02-02 user contact UI, 02-03 vehicle maintenance UI) can proceed — all backend APIs and Flutter endpoint constants are ready
- `vehicleMaintenanceEndpoint` and `settingsEndpoint` are available in app_config.dart for immediate use
- `is_in_maintenance` flag in getAllVehicles enables vehicle list screens to show maintenance status without a second API call

---
*Phase: 02-user-vehicle-scheduler-enhancements*
*Completed: 2026-03-21*
