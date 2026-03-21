---
phase: 03-job-assignment-status-automation
plan: 01
subsystem: backend
tags: [database, migration, assignment, audit, load-balancing]
dependency_graph:
  requires: []
  provides: [assignment_history-table, job_completions-table, driver-load-endpoint, assignment-audit-trail]
  affects: [jobAssignmentService, jobAssignmentRoutes, Job-model]
tech_stack:
  added: []
  patterns: [audit-log-after-commit, non-critical-fire-and-forget-logging, rank-and-below-average-flag]
key_files:
  created: []
  modified:
    - vehicle_scheduling2.sql
    - vehicle-scheduling-backend/src/models/Job.js
    - vehicle-scheduling-backend/src/services/jobAssignmentService.js
    - vehicle-scheduling-backend/src/routes/jobAssignmentRoutes.js
key_decisions:
  - "_logAssignmentHistory swallows its own errors — audit logging is non-critical and must never roll back a committed transaction or surface to the caller"
  - "reassignJob captures previousDriverId before delegating to assignJobToVehicle so both 'create' (from delegated call) and 'reassign' (with old driver context) are logged separately"
  - "driver-load route reuses the existing verifyToken inline pattern from the file rather than relying on global server.js auth — req.user.tenant_id is required"
  - "getDriverLoadStats LEFT JOIN with range clause means drivers with zero jobs in the window still appear (job_count=0, rank=1 if no one else has jobs)"
metrics:
  duration_min: 4
  completed_date: "2026-03-21"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
requirements_covered: [ASGN-01, ASGN-02, ASGN-03, ASGN-04, ASGN-05]
---

# Phase 3 Plan 1: DB Migration + Driver Load Stats + Assignment Audit Trail Summary

**One-liner:** Phase 3 DB migration adds assignment_history and job_completions tables, driver-load endpoint pre-computes rank and below_average flags per tenant/time-range, and all 4 assignment mutations now write audit rows after commit.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1 | DB migration — assignment_history, job_completions, nullable changed_by | 39af1d5 | vehicle_scheduling2.sql |
| 2 | Driver load stats endpoint + assignment history logging | ddf98fc | Job.js, jobAssignmentService.js, jobAssignmentRoutes.js |

## What Was Built

### Task 1: Database Migration

Three additions appended to `vehicle_scheduling2.sql`:

1. **`assignment_history` table** — Audit log for all assignment events (create, reassign, swap, cancel, technician_add, technician_remove). Has `tenant_id`, `changed_by`, `old_user_id`, `new_user_id`. Indexed on `job_id`, `tenant_id`, and `changed_at`.

2. **`job_completions` table** — Records when a job is marked complete, including GPS capture fields (`lat`, `lng`, `accuracy_m`, `gps_status` ENUM). Has `tenant_id`. Unique constraint on `job_id`. Supports STAT-03.

3. **`ALTER TABLE job_status_changes MODIFY COLUMN changed_by`** — Makes `changed_by` nullable so cron-initiated status transitions (e.g., auto-progress to `in_progress` at scheduled start time) can write a row without requiring a user ID.

### Task 2: Driver Load Stats + Audit Trail

**`Job.getDriverLoadStats(tenantId, range)`** — New static method on Job model. Queries active drivers/technicians via LEFT JOIN to `job_technicians` with a date-range clause. Post-processes results to add `rank` (1 = fewest jobs = "Suggested") and `below_average` boolean. Returns empty array when no active drivers exist.

**`JobAssignmentService._logAssignmentHistory(...)`** — Private static helper that inserts into `assignment_history`. Wrapped in try/catch — errors are logged with pino and swallowed so audit failures never affect the committed assignment.

**Call sites added:**
- `assignJobToVehicle` → logs `event_type='create'` after the transaction commit, using `driverId` from technician_ids[0] or driver_id
- `reassignJob` → captures `previousDriverId` from `job.driver_id` before delegating, then logs `event_type='reassign'` with old/new driver context after the delegate returns
- `unassignJob` → logs `event_type='cancel'` with the previous driver from the pre-transaction assignment query
- `assignTechnicians` → loops over `technicianIds` and logs `event_type='technician_add'` for each

**`GET /api/job-assignments/driver-load`** — New route registered BEFORE existing routes to avoid path conflicts. Requires `verifyToken`. Validates `range` query param (400 on invalid). Calls `Job.getDriverLoadStats(req.user.tenant_id, range)`. Returns `{ success: true, data: [...] }`.

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. The `job_completions` table is created for future use by STAT-03 (geo-capture on job complete) — it has no backend write logic yet, but it is not a stub in this plan since this plan's goal was the migration only. The write logic is in a future plan.

## Self-Check: PASSED

All 4 modified files exist on disk. Both task commits verified:
- `39af1d5` — feat(03-01): add Phase 3 DB migration
- `ddf98fc` — feat(03-01): driver load stats endpoint + assignment history audit trail
