---
phase: 03-job-assignment-status-automation
plan: 03
subsystem: ui
tags: [flutter, driver-load-balancing, gps, geolocator, provider, chips]

# Dependency graph
requires:
  - phase: 03-01
    provides: GET /api/job-assignments/driver-load endpoint with rank and below_average
  - phase: 03-02
    provides: POST /api/job-status/complete endpoint with GPS capture

provides:
  - DriverLoadCard widget with green glow on below-average drivers and Suggested chip on rank-1
  - getDriverLoad() and completeJobWithGps() methods on JobService
  - JobProvider: driverLoadStats state, fetchDriverLoad(), completeJobWithGps()
  - create_job_screen: load-balanced driver picker with weekly/monthly/yearly toggle
  - create_job_screen: chip-based technician multi-select with search and X-to-remove
  - edit_job_screen: same driver picker + technician chips, pre-populated from job data
  - job_detail_screen: Complete Job button with confirm dialog, GPS capture, and fallback

affects: [04-dashboard-views, 07-gps-maps-tracking]

# Tech tracking
tech-stack:
  added: [geolocator (GPS capture), SegmentedButton (time range toggle)]
  patterns:
    - DriverLoadCard stateless widget accepts driver map + isSelected + rangeLabel
    - GPS capture with 50m accuracy threshold: ok / low_accuracy / no_gps
    - Confirm dialog always precedes GPS capture (user decides before GPS permission prompt)

key-files:
  created:
    - vehicle_scheduling_app/lib/widgets/job/driver_load_chip.dart
  modified:
    - vehicle_scheduling_app/lib/services/job_service.dart
    - vehicle_scheduling_app/lib/providers/job_provider.dart
    - vehicle_scheduling_app/lib/screens/jobs/create_job_screen.dart
    - vehicle_scheduling_app/lib/screens/jobs/edit_job_screen.dart
    - vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart

key-decisions:
  - "DriverLoadCard uses green border + box-shadow on below_average to create the glow effect"
  - "Primary driver (single) selected via DriverLoadCard tap; technicians via chip multi-select with search"
  - "Confirm dialog fires FIRST, GPS capture second — user makes decision before GPS permission prompt"
  - "GPS accuracy threshold is 50m: above 50m stored as low_accuracy with null coords per prior decision"
  - "Complete Job button visible to assigned driver/technician AND admin/scheduler — STAT-02 enforcement"
  - "edit_job_screen pre-populates _selectedDriverId from job.driverId and _selectedTechnicianIds from job.technicians"

requirements-completed: [ASGN-01, ASGN-02, ASGN-03, ASGN-04, STAT-02, STAT-03, STAT-04]

# Metrics
duration: 30min
completed: 2026-03-21
---

# Phase 3 Plan 3: Flutter UI — Driver Load Picker, Technician Chips, and GPS Completion Summary

**Flutter assignment picker showing per-driver job counts with green glow load balancing, chip-based technician multi-select, and GPS-captured job completion flow with confirm dialog.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-03-21T15:00:00Z
- **Completed:** 2026-03-21T15:30:00Z
- **Tasks:** 2/2
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments

### Task 1: Service methods, provider state, and DriverLoadCard widget

- Added `getDriverLoad(range)` to `JobService` — calls `GET /api/job-assignments/driver-load?range=$range` via existing `ApiService` pattern
- Added `completeJobWithGps()` to `JobService` — calls `POST /api/job-status/complete` with GPS fields
- Added `_driverLoadStats`, `fetchDriverLoad()`, and `completeJobWithGps()` to `JobProvider`
- Created `DriverLoadCard` stateless widget: green border + box-shadow on `below_average==true`, `Suggested` chip on `rank==1`, check icon when `isSelected`

### Task 2: Enhanced screens and job detail completion flow

- `create_job_screen`: Replaced old multi-driver FilterChip grid with:
  - "Primary Driver" section: `SegmentedButton` toggle (Weekly/Monthly/Yearly) + `DriverLoadCard` list
  - "Technicians" section: `InputChip` list of selected techs with X-to-remove + search field + autocomplete dropdown
  - `_selectedDriverId` (single int?) for primary; `_selectedTechnicianIds` (Set<int>) for technicians
  - `_selectedDriverId` passed as `driverId` in `assignJob()` call

- `edit_job_screen`: Added identical driver picker (same toggle + DriverLoadCard + technician chips), pre-populated from `job.driverId` and `job.technicians` on `initState`

- `job_detail_screen`: Added `Complete Job` button (gated to `in_progress` status + assigned personnel):
  - Shows confirm dialog: "Are you sure? This cannot be undone."
  - After confirmation: captures GPS via `Geolocator.getCurrentPosition(LocationSettings)` with 10s timeout
  - Accuracy threshold 50m: `ok` / `low_accuracy` (null coords) / `no_gps` (error or permission denied)
  - Calls `provider.completeJobWithGps()` and pops screen on success

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Pattern] Used ApiService instead of direct http in job_service.dart**
- **Found during:** Task 1
- **Issue:** Plan showed methods using `http.get()` and `_authHeaders()` directly, but `JobService` uses `ApiService` which handles auth internally.
- **Fix:** Implemented methods using `apiService.get()` and `apiService.post()` to match existing patterns.
- **Files modified:** vehicle_scheduling_app/lib/services/job_service.dart

**2. [Rule 2 - Completeness] Added _DriverOption class to edit_job_screen.dart**
- **Found during:** Task 2
- **Issue:** `edit_job_screen.dart` didn't have the `_DriverOption` class needed for the technician list
- **Fix:** Added `_DriverOption` class before `EditJobScreen` widget definition.
- **Files modified:** vehicle_scheduling_app/lib/screens/jobs/edit_job_screen.dart

**3. [Rule 2 - UX] SegmentedButton uses WidgetStateProperty instead of MaterialStateProperty**
- **Found during:** Task 2
- **Issue:** Flutter 3.x uses `WidgetStateProperty` (renamed from `MaterialStateProperty`)
- **Fix:** Used `WidgetStateProperty.all()` in SegmentedButton style.
- **Files modified:** create_job_screen.dart, edit_job_screen.dart

## Known Stubs

None. All data flows through the real API endpoints from Plans 01 and 02.

## Commits

| Task | Commit | Message |
|------|--------|---------|
| 1 | 6cbad4b | feat(03-03): add driver load service, provider state, and DriverLoadCard widget |
| 2 | 6a82f5c | feat(03-03): enhance driver picker UI, technician chips, and Complete Job with GPS |
