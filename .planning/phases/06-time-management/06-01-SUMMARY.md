---
phase: 06-time-management
plan: "01"
subsystem: backend
tags: [time-extension, scheduling, notifications, mysql, express]
dependency_graph:
  requires:
    - 05-01 (NotificationService.sendTopicNotification)
    - 01-01 (authMiddleware verifyToken + requirePermission)
    - 03-01 (job_technicians table, job_assignments table)
  provides:
    - TimeExtensionService (createRequest, analyzeImpact, getActiveRequest, approveRequest, denyRequest)
    - REST API at /api/time-extensions (POST, GET, PATCH approve, PATCH deny)
    - DB tables: time_extension_requests, reschedule_options
  affects:
    - 06-02 (Flutter screens will call these endpoints)
tech_stack:
  added: []
  patterns:
    - FOR UPDATE in transaction for one-active-request guard (same as jobAssignmentService)
    - Notifications sent after transaction commit (same as other services)
    - pino child logger per service
    - express-validator for route validation
key_files:
  created:
    - vehicle-scheduling-backend/src/services/timeExtensionService.js
    - vehicle-scheduling-backend/src/routes/timeExtension.js
  modified:
    - vehicle_scheduling.sql (appended two CREATE TABLE IF NOT EXISTS blocks)
    - vehicle-scheduling-backend/src/routes/index.js (added require + router.use)
decisions:
  - "Notifications sent after transaction commit — same principle as existing services (audit trail must not block commit)"
  - "analyzeImpact uses UNION-style OR on vehicle_id and job_technicians overlap — covers both driver and vehicle conflicts"
  - "Swap suggestion queries users.first_name + users.last_name separately (schema has no full_name on users)"
  - "_buildSuggestions always returns push + custom; swap only if free driver found — 2 or 3 options"
  - "Suggestion changes_json stored as TEXT, parsed on read in getActiveRequest"
metrics:
  duration_min: 4
  completed_date: "2026-03-21"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 2
---

# Phase 06 Plan 01: Time Extension Backend Summary

**One-liner:** Full time extension backend — DB tables, impact analysis, suggestion engine (push/swap/custom), atomic approval transaction, and 4-endpoint REST API at /api/time-extensions.

## What Was Built

### Database (vehicle_scheduling.sql)
Two new tables appended with `CREATE TABLE IF NOT EXISTS`:

- **`time_extension_requests`** — Stores pending/approved/denied extension requests. Key columns: `job_id`, `requested_by`, `duration_minutes`, `reason`, `status` enum(pending/approved/denied), `denial_reason`, `approved_denied_by`, `selected_suggestion_id`. Indexes on `(job_id, status)`, `tenant_id`, `requested_by`.
- **`reschedule_options`** — Stores 2-3 generated rescheduling options per request. Key columns: `request_id`, `type` enum(push/swap/custom), `label`, `changes_json` (serialized array of job time changes).

### TimeExtensionService (timeExtensionService.js)

| Method | Purpose |
|--------|---------|
| `createRequest()` | Transaction: lock job (FOR UPDATE), one-active guard (FOR UPDATE), assignment check, INSERT. Post-commit: impact analysis, suggestions, scheduler notifications. |
| `analyzeImpact()` | Finds same-day jobs sharing driver/vehicle that start at or after the new end time. Excludes completed/cancelled. |
| `_buildSuggestions()` | Generates push (always), swap (if free driver available), custom (always). |
| `_notifySchedulers()` | Inserts notifications + FCM to all admin/scheduler/dispatcher users. |
| `getActiveRequest()` | Returns pending request with parsed suggestions, or `{ request: null }`. |
| `approveRequest()` | Transaction: UPDATE request status, extend source job time, UPDATE all affected job times. Post-commit: `_notifyAffectedParties`. |
| `denyRequest()` | UPDATE status to denied, notify job personnel via `_notifyJobPersonnel`. |
| `_notifyAffectedParties()` | Dedupes user IDs from source job driver/technicians + affected job drivers, sends notifications. |

### REST Routes (timeExtension.js + index.js)

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/time-extensions` | verifyToken | Create request; validates job_id (int), duration_minutes (1-480), reason (min 10 chars) |
| GET | `/api/time-extensions/:jobId` | verifyToken | Get active pending request with suggestions |
| PATCH | `/api/time-extensions/:id/approve` | verifyToken + jobs:update | Approve with suggestion_id or custom_changes |
| PATCH | `/api/time-extensions/:id/deny` | verifyToken + jobs:update | Deny with optional reason |

## Verification Results

- `node -e "require('./src/services/timeExtensionService')"` — loads without error (only SMTP warning, expected)
- `node -e "require('./src/routes/timeExtension')"` — loads without error
- `grep 'time-extensions' src/routes/index.js` — found: `router.use('/time-extensions', timeExtensionRoutes)`
- `grep -c 'time_extension_requests' vehicle_scheduling.sql` — 1 match (CREATE TABLE block)
- `grep -c 'reschedule_options' vehicle_scheduling.sql` — 1 match (CREATE TABLE block)
- `typeof svc.createRequest, analyzeImpact, getActiveRequest, approveRequest, denyRequest` — all `"function"`

## Deviations from Plan

None — plan executed exactly as written. The only adaptation was recognizing that `users.full_name` was not available in some queries so the swap suggestion uses `first_name + last_name` from the users table, which matches the actual schema (users table has these columns separately based on existing queries in the codebase).

## Known Stubs

None — all methods are fully implemented with real DB queries. No placeholder values or TODO items.

## Self-Check: PASSED

- `vehicle-scheduling-backend/src/services/timeExtensionService.js` — FOUND
- `vehicle-scheduling-backend/src/routes/timeExtension.js` — FOUND
- Commit `1fc7cfa` (Task 1) — FOUND
- Commit `47bea7a` (Task 2) — FOUND
