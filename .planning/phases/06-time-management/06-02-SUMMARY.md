---
phase: 06-time-management
plan: 02
subsystem: ui
tags: [flutter, provider, dart, time-extensions, job-detail]

# Dependency graph
requires:
  - phase: 06-time-management plan 01
    provides: Backend time extension API (POST/GET/PATCH endpoints)
provides:
  - TimeExtensionRequest, RescheduleOption, JobTimeChange, AffectedJob Flutter models with fromJson factories
  - TimeExtensionService wrapping ApiService for all 4 time extension endpoints
  - TimeExtensionProvider ChangeNotifier with submitRequest/loadActiveRequest/approveRequest/denyRequest/clearState
  - TimeExtensionRequestScreen with 30min/1hr/2hr/Custom duration presets and 10-char reason validation
  - Add More Time OutlinedButton on job_detail_screen.dart gated to assigned driver/technician + in_progress status
affects: [07-gps-maps, 08-testing, scheduler-approval-plan]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "ChangeNotifier provider pattern for loading/error/data state (same as NotificationProvider)"
    - "Service layer wraps ApiService singleton — provider calls service, never calls ApiService directly"
    - "Builder widget inside Column for role/status-gated buttons (same pattern as Complete Job button)"
    - "Navigator.push returns bool for refresh signal on return"

key-files:
  created:
    - vehicle_scheduling_app/lib/models/time_extension.dart
    - vehicle_scheduling_app/lib/services/time_extension_service.dart
    - vehicle_scheduling_app/lib/providers/time_extension_provider.dart
    - vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart
  modified:
    - vehicle_scheduling_app/lib/config/app_config.dart
    - vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart

key-decisions:
  - "Add More Time button gated to isAssigned (driverId or technicians list) AND in_progress — matches TIME-01 spec exactly, not just role-based"
  - "TimeExtensionProvider clearState() exposed for screens that need to reset between jobs"
  - "Custom duration input uses FilteringTextInputFormatter.digitsOnly to prevent non-numeric input"
  - "Navigator.push returns bool true on success, parent refreshes job via JobProvider.loadJobById"

patterns-established:
  - "Time extension state: provider clears _activeRequest on approve/deny so callers can react to null"
  - "Role-gated buttons use Builder inside the actions Column to read auth context inline"

requirements-completed: [TIME-01, TIME-02, TIME-03, TIME-04]

# Metrics
duration: 4min
completed: 2026-03-21
---

# Phase 06 Plan 02: Time Extension Flutter UI Summary

**Flutter driver/technician time extension UI: 4 models, service + provider layer, request screen with duration presets, and Add More Time button gated to in_progress assigned jobs**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-21T18:24:04Z
- **Completed:** 2026-03-21T18:27:51Z
- **Tasks:** 2/2
- **Files modified:** 6

## Accomplishments

- 4 Dart model classes (TimeExtensionRequest, RescheduleOption, JobTimeChange, AffectedJob) with fromJson factories matching API response shape
- TimeExtensionService wrapping ApiService with createRequest, getActiveRequest, approveRequest, denyRequest methods
- TimeExtensionProvider ChangeNotifier managing loading/error state and post-submit affected jobs / suggestions
- TimeExtensionRequestScreen with ChoiceChip duration presets (30 min, 1 hr, 2 hrs, Custom) and 10-character reason validation
- Add More Time OutlinedButton on job_detail_screen.dart — visible only to assigned driver/technician when job is in_progress, navigates to request screen and refreshes on return

## Task Commits

1. **Task 1: Flutter models, service, provider, and AppConfig endpoint** - `592ade9` (feat)
2. **Task 2: Time extension request screen + Add More Time button on job detail** - `22e20cb` (feat)

## Files Created/Modified

- `vehicle_scheduling_app/lib/models/time_extension.dart` — 4 model classes with fromJson factories
- `vehicle_scheduling_app/lib/services/time_extension_service.dart` — HTTP client wrapping ApiService
- `vehicle_scheduling_app/lib/providers/time_extension_provider.dart` — ChangeNotifier state management
- `vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart` — Duration picker + reason form + submit
- `vehicle_scheduling_app/lib/config/app_config.dart` — Added timeExtensionsEndpoint constant
- `vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart` — Added Add More Time button + TimeExtensionRequestScreen import

## Decisions Made

- Add More Time button visibility uses `isAssigned` check (driver OR technician match by ID) AND `in_progress` status — not just role-based, matching TIME-01 spec ("user is assigned")
- Button follows same Builder-inside-Column pattern as the existing Complete Job button for consistency
- TimeExtensionProvider.clearState() is public so future scheduler approval screens can reset state between jobs
- Custom duration TextFormField uses FilteringTextInputFormatter.digitsOnly to prevent invalid input at the keyboard level

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Flutter driver/technician side of time extensions is complete
- Scheduler approval UI (viewing pending requests and approving/denying with reschedule options) is the next logical step but not in this plan
- TimeExtensionProvider.approveRequest and denyRequest methods are ready for any future scheduler UI plan
- Backend endpoints from Plan 06-01 are fully consumed

---
*Phase: 06-time-management*
*Completed: 2026-03-21*
