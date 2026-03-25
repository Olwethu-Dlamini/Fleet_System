---
phase: quick
plan: 260325-jwh
subsystem: time-management
tags: [bug-fix, time-extension, impact-analysis, day-schedule, flutter, backend]
dependency_graph:
  requires: []
  provides: [correct-overlap-detection, driver-conflict-detection, day-schedule-endpoint, day-schedule-ui]
  affects: [time_extension_service.js, timeExtension.js, time_extension.dart, time_extension_service.dart, time_extension_provider.dart, time_extension_approval_screen.dart, time_extension_request_screen.dart]
tech_stack:
  added: []
  patterns: [interval-overlap-detection, personnel-grouping-map, flutter-microtask-parallel-load]
key_files:
  created: []
  modified:
    - vehicle-scheduling-backend/src/services/timeExtensionService.js
    - vehicle-scheduling-backend/src/routes/timeExtension.js
    - vehicle_scheduling_app/lib/models/time_extension.dart
    - vehicle_scheduling_app/lib/services/time_extension_service.dart
    - vehicle_scheduling_app/lib/providers/time_extension_provider.dart
    - vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart
    - vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart
decisions:
  - "analyzeImpact updated to use interval overlap (start < newEnd AND end > sourceEnd) instead of start >= newEnd — the original condition missed jobs that overlap the extension window"
  - "driver_id OR branch added to analyzeImpact: catches driver conflicts in job_assignments not covered by job_technicians check"
  - "getDaySchedule groups by driver first, then technicians (deduplicates when driver_id matches a technician user_id in the same job)"
  - "loadDaySchedule called in a second Future.microtask in initState — parallel to loadActiveRequest, does not block the approval UI"
metrics:
  duration_minutes: 12
  completed_date: "2026-03-25"
  tasks_completed: 3
  files_modified: 7
---

# Quick Task 260325-jwh: Fix Time Extension Impact Analysis + Day Schedule Summary

**One-liner:** Fixed time extension overlap detection from `>=` to proper interval math, added driver_id conflict check, and wired a full day-schedule endpoint + approval screen section so schedulers see the complete picture.

## Tasks Completed

| Task | Name | Commit | Key Files |
|------|------|--------|-----------|
| 1 | Fix analyzeImpact + getDaySchedule + route | 4dc282f | timeExtensionService.js, timeExtension.js |
| 2 | Flutter models/service/provider | 3190b9b | time_extension.dart, time_extension_service.dart, time_extension_provider.dart |
| 3 | Approval screen day schedule + request screen preview | df7f146 | time_extension_approval_screen.dart, time_extension_request_screen.dart |

## Changes Made

### Task 1 — Backend (timeExtensionService.js + timeExtension.js)

**`analyzeImpact` fix:**

The original WHERE clause:
```sql
AND j.scheduled_time_start >= ?   -- only finds jobs STARTING after new end
```
Was replaced with proper interval overlap detection:
```sql
AND j.scheduled_time_start < ?    -- newEndTime
AND j.scheduled_time_end > ?      -- sourceJobCurrentEnd
```
This correctly finds any job whose time range overlaps `[sourceJobCurrentEnd, newEndTime]`.

The method signature now accepts `sourceJobCurrentEnd` as a 5th parameter, and `createRequest()` passes `job.scheduled_time_end` when calling `analyzeImpact`.

**Driver conflict check added:**

A third OR branch was added to the conflict detection:
```sql
OR ja.driver_id IN (SELECT driver_id FROM job_assignments WHERE job_id = ? AND driver_id IS NOT NULL)
```
This catches cases where a driver is assigned via `job_assignments` but not listed in `job_technicians`.

**`getDaySchedule` static method:**

- Fetches the source job's `scheduled_date`
- Queries all non-cancelled jobs for that date with driver name (JOIN users) and technician names/ids (GROUP_CONCAT subqueries)
- Groups results into a `Map` keyed by `driver_{id}` or `tech_{id}`, collecting jobs under each person
- Deduplicates: if a technician's user_id matches the driver_id for a job, they are not added as a separate technician entry
- Returns `{ date, personnel: [{ id, name, role, jobs: [...] }] }`

**New route:**

`GET /api/time-extensions/:jobId/day-schedule` — placed BEFORE `/:jobId` (line 306 vs 390) to avoid Express matching "day-schedule" as a jobId. Requires `verifyToken + requirePermission('jobs:update')`.

### Task 2 — Flutter models/service/provider

- `DayScheduleJob` model: parses `id, job_number, scheduled_time_start, scheduled_time_end, current_status, customer_name, driver_id, vehicle_id, driver_name, technician_names`
- `DaySchedulePersonnel` model: parses `id, name, role, jobs: List<DayScheduleJob>`
- `TimeExtensionService.getDaySchedule(int jobId)`: calls the new backend route, returns `Map<String, dynamic>` with `date` and `personnel`
- `TimeExtensionProvider` gains `_daySchedule`, `_dayScheduleDate` private state, `daySchedule`/`dayScheduleDate` getters, `loadDaySchedule` method
- `clearState()` now resets `_daySchedule = []` and `_dayScheduleDate = null`

### Task 3 — Flutter screens

**Approval screen (`time_extension_approval_screen.dart`):**
- `initState` now fires two `Future.microtask` calls — one for `loadActiveRequest`, one for `loadDaySchedule` (parallel, non-blocking)
- `_DayScheduleSection` widget added below `_AffectedJobsSection`, showing all day jobs grouped by driver/technician:
  - Header: person name (bold) + role badge chip (blue for driver, green for technician)
  - Job list with time range and status chip
  - Source job highlighted with yellow background + "this job" label

**Request screen (`time_extension_request_screen.dart`):**
- Orange impact preview info card added between reason field and submit button
- Text: "Impact Preview: This request will be checked against all jobs for the same day involving your driver, technician team, and vehicle. The scheduler will see any conflicts before approving."

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed exactly as specified.

### Notes

- The `withOpacity` deprecation info (not errors) seen in flutter analyze are pre-existing throughout the codebase and match the existing pattern. No errors were introduced.
- The `getDaySchedule` deduplication logic (skipping technician entry when `techId === row.driver_id`) was added proactively to prevent the same person appearing twice in the day schedule under both roles for the same job.

## Verification Results

1. Backend service loads: `node -e "require('./src/services/timeExtensionService')"` — OK
2. Backend routes load: `node -e "require('./src/routes/timeExtension')"` — OK
3. Flutter analyze (models/service/provider): 1 info issue (HTML in doc comment), no errors
4. Flutter analyze (screens): 16 info issues (withOpacity deprecation, pre-existing pattern), no errors
5. SQL overlap uses `<` and `>` operators confirmed at lines 208-209 of timeExtensionService.js
6. day-schedule route registered at line 306, before /:jobId catch-all at line 390

## Self-Check: PASSED

All modified files exist and all 3 commits verified:
- 4dc282f: fix(quick-260325-jwh): fix analyzeImpact overlap detection + add getDaySchedule + day-schedule route
- 3190b9b: feat(quick-260325-jwh): add DayScheduleJob/DaySchedulePersonnel models + getDaySchedule service + provider support
- df7f146: feat(quick-260325-jwh): add Day Schedule section to approval screen + impact preview to request screen
