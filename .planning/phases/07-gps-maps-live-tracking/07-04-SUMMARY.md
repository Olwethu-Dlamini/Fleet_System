---
phase: 07-gps-maps-live-tracking
plan: 04
subsystem: flutter-frontend
tags: [gps, live-tracking, google-maps, polling, navigation]
dependency_graph:
  requires: [07-01, 07-02, 07-03]
  provides: [live-tracking-map-screen, tracking-tab-nav]
  affects: [vehicle_scheduling_app/lib/main.dart]
tech_stack:
  added: [socket_io_client ^3.1.4]
  patterns: [Timer.periodic polling, GoogleMap with MarkerId map, BitmapDescriptor marker colors]
key_files:
  created:
    - vehicle_scheduling_app/lib/screens/gps/live_tracking_screen.dart
  modified:
    - vehicle_scheduling_app/pubspec.yaml
    - vehicle_scheduling_app/lib/main.dart
decisions:
  - "Markers older than 5 min are silently skipped rather than shown with an error hue — avoids clutter from offline drivers"
  - "Camera bounds fitted once on first load only — subsequent polls preserve user's manual camera position"
  - "const_eval_method_invocation auto-fixed: admin nav list changed from return const [...] to return [...] with per-item const"
metrics:
  duration_min: 4
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 3
---

# Phase 7 Plan 4: Live Tracking Map Screen Summary

**One-liner:** Flutter live tracking screen with 10-second polling of GpsService.getDriverLocations(), green/orange markers by freshness, added as Tracking tab in admin/scheduler bottom nav.

## What Was Built

A full-screen admin/scheduler map view (LiveTrackingScreen) showing live driver positions fetched via HTTP polling every 10 seconds. The screen integrates directly with the backend GET /api/gps/drivers endpoint implemented in Phase 07-01. The Tracking tab now appears after the Schedule tab for both admin and scheduler roles.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create live tracking map screen with polling | c9ba0b2 | lib/screens/gps/live_tracking_screen.dart, pubspec.yaml |
| 2 | Add Tracking tab to bottom navigation | 621174e | lib/main.dart |

## Acceptance Criteria Verification

- LiveTrackingScreen class with StatefulWidget: PASS
- GpsService.getDriverLocations() called in screen: PASS
- Timer.periodic(10s) polling: PASS
- GoogleMap widget rendered: PASS
- MarkerId-keyed marker map: PASS
- BitmapDescriptor hue for green/orange markers: PASS
- InfoWindow with driver name and time since update: PASS
- socket_io_client in pubspec.yaml: PASS
- File exceeds 100 lines (380 lines): PASS
- flutter pub get succeeds: PASS
- LiveTrackingScreen in main.dart (admin + scheduler tabs): PASS (2 tab instances + 1 import)
- Icons.map_outlined in nav items: PASS (2 occurrences)
- 'Tracking' label in nav items: PASS (2 occurrences)
- flutter analyze — no errors: PASS (info-only, all pre-existing)

## Marker Behavior

| Condition | Visual |
|-----------|--------|
| Updated <= 2 min ago | Green marker |
| Updated 3-5 min ago | Orange marker |
| Updated > 5 min ago | Not shown (silently filtered) |

## Navigation Tab Layout (Post 07-04)

| Role | Tabs |
|------|------|
| Admin | Dashboard, Jobs, Vehicles, Schedule, **Tracking**, Users, Reports, Settings |
| Scheduler | Dashboard, Jobs, Vehicles, Schedule, **Tracking** |
| Technician | Dashboard, My Jobs (unchanged) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed pre-existing `const_eval_method_invocation` error in admin nav list**
- **Found during:** Task 2 flutter analyze verification
- **Issue:** `_buildNavItemsForRole` for admin returned `const [...]` but contained an `if (auth.hasPermission(...))` conditional — methods cannot be called in constant expressions
- **Fix:** Changed `return const [...]` to `return [...]` with `const BottomNavigationBarItem(...)` on each individual item. The conditional `const` item remains as-is.
- **Files modified:** vehicle_scheduling_app/lib/main.dart
- **Commit:** 621174e (included in Task 2 commit)

## Known Stubs

None — LiveTrackingScreen directly calls GpsService.getDriverLocations() which hits the real backend endpoint. Data flows from backend to markers with no stubbing.

## Self-Check: PASSED
