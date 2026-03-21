---
phase: 06-time-management
plan: "03"
subsystem: frontend
tags: [time-extension, fcm, deep-link, flutter, provider, approval-screen]
dependency_graph:
  requires:
    - 06-01 (TimeExtensionService backend API at /api/time-extensions)
    - 06-02 (TimeExtensionProvider, TimeExtensionService Flutter, models)
  provides:
    - TimeExtensionApprovalScreen (scheduler approval/denial UI)
    - FCM deep-link routing for time_extension_requested → approval screen
    - TimeExtensionProvider registered app-wide in MultiProvider
  affects:
    - vehicle_scheduling_app/lib/services/fcm_service.dart (navigatorKey + routing)
    - vehicle_scheduling_app/lib/main.dart (provider registration)
tech_stack:
  added: []
  patterns:
    - Future.microtask in initState for async provider calls (standard Flutter pattern)
    - GlobalKey<NavigatorState> on FcmService for context-free FCM navigation
    - Consumer<T> + Provider.of pattern for reactive state
    - Radio<int> with InkWell for selectable suggestion cards
key_files:
  created:
    - vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart
  modified:
    - vehicle_scheduling_app/lib/services/fcm_service.dart
    - vehicle_scheduling_app/lib/main.dart
decisions:
  - "GlobalKey<NavigatorState> on FcmService.navigatorKey wired to MaterialApp — enables FCM to push routes without BuildContext (required for cold-start and background tap scenarios)"
  - "time_extension_approved/denied navigates popUntil(root) — JobDetailScreen requires a full Job object, navigating to jobs list is safer than partial navigation"
  - "Approval screen: affectedJobs uses Iterable<AffectedJob> from provider.affectedJobs (loaded by loadActiveRequest) not from createRequest response"
metrics:
  duration_min: 4
  completed_date: "2026-03-21"
  tasks_completed: 2
  tasks_total: 2
  files_created: 1
  files_modified: 2
---

# Phase 06 Plan 03: Scheduler Approval Screen & FCM Deep-Link Summary

**One-liner:** Scheduler-facing time extension approval screen with impact timeline, suggestion card selection (push/swap/custom), approve/deny actions, and FCM deep-link routing directly to approval screen on time_extension_requested notifications.

## What Was Built

### TimeExtensionApprovalScreen (new file)

Full scheduler review and action screen:

| Section | Content |
|---------|---------|
| Request Info Card | Extension duration, reason text, created timestamp, status chip (orange=pending, green=approved, red=denied) |
| Affected Jobs | Count badge header, ListTile per job with current start/end times and arrow icon |
| Suggestion Cards | InkWell/Radio cards per RescheduleOption: label, type chip (push=blue, swap=green, custom=orange), changes list for push/swap |
| Custom Time Inputs | Revealed when custom suggestion selected: per-job TextFormField pairs for new start/end HH:MM |
| Action Buttons | "Deny" (OutlinedButton, red) + "Approve" (ElevatedButton, disabled until suggestion selected) |

State handling: loading (CircularProgressIndicator), empty ("No pending extension request"), error (red text + retry).

### fcm_service.dart changes

- Added `static final GlobalKey<NavigatorState> navigatorKey` for context-free routing
- Added `_routeToNotification(Map<String, dynamic> data)` switch on FCM payload `type`:
  - `time_extension_requested` → pushes `TimeExtensionApprovalScreen(jobId:, requestId:)`
  - `time_extension_approved` / `time_extension_denied` → `popUntil(isFirst)` (back to jobs list)
- Wired `getInitialMessage()` (cold start) and `onMessageOpenedApp` (background tap) in `initialize()`

### main.dart changes

- Added `ChangeNotifierProvider(create: (_) => TimeExtensionProvider())` to MultiProvider list
- Added `navigatorKey: FcmService.navigatorKey` on MaterialApp

## Verification Results

- `grep -r "TimeExtensionApprovalScreen" vehicle_scheduling_app/lib/` — found in screen file + fcm_service.dart import
- `grep "time_extension_requested" vehicle_scheduling_app/lib/services/fcm_service.dart` — found in switch case
- `grep "TimeExtensionProvider" vehicle_scheduling_app/lib/main.dart` — found in MultiProvider list
- Approval screen has both Approve (ElevatedButton) and Deny (OutlinedButton) buttons

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Prerequisite files from 06-02 already existed**
- **Found during:** Pre-execution environment check
- **Issue:** Plan 06-02 had no SUMMARY.md indicating it was never executed, but the actual files (time_extension.dart, time_extension_service.dart, time_extension_provider.dart, app_config.dart endpoint) were all present on disk
- **Fix:** No action needed — files were present and correct. Plan proceeded normally.
- **Files modified:** None (files already correct)

**2. [Rule 2 - Missing critical functionality] Cold-start FCM routing not in plan**
- **Found during:** Task 2 implementation
- **Issue:** Plan specified `onMessageOpenedApp` handler but did not mention `getInitialMessage()` for cold-start scenarios (app killed when notification arrives)
- **Fix:** Added both `getInitialMessage()` (app terminated) and `onMessageOpenedApp` (app backgrounded) listeners — both required for complete FCM tap routing
- **Files modified:** vehicle_scheduling_app/lib/services/fcm_service.dart
- **Commit:** bb6d54d

**3. [Rule 2 - Missing critical functionality] navigatorKey not in plan**
- **Found during:** Task 2 implementation
- **Issue:** FCM routing requires pushing routes without BuildContext (background isolate → main thread). Plan specified Navigator.push but didn't address how to get a navigator reference outside widget tree
- **Fix:** Added `static final GlobalKey<NavigatorState> navigatorKey` to FcmService and wired it to MaterialApp's `navigatorKey` property
- **Files modified:** vehicle_scheduling_app/lib/services/fcm_service.dart, vehicle_scheduling_app/lib/main.dart
- **Commit:** bb6d54d

## Known Stubs

None — all actions call real backend endpoints through TimeExtensionProvider. No placeholder values or hardcoded mock data.

## Self-Check: PASSED

- `vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart` — FOUND
- `vehicle_scheduling_app/lib/services/fcm_service.dart` (modified) — FOUND
- `vehicle_scheduling_app/lib/main.dart` (modified) — FOUND
- Commit `0e49420` (Task 1) — verified below
- Commit `bb6d54d` (Task 2) — verified below
