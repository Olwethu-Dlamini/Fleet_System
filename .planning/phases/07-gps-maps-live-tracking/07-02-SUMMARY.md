---
phase: 07-gps-maps-live-tracking
plan: 02
subsystem: api, ui, maps
tags: [google-maps, flutter, polyline, directions, gps, routes-api]

# Dependency graph
requires:
  - phase: 07-gps-maps-live-tracking/07-01
    provides: gps.js routes file, routes/index.js GPS registration, gps consent + location endpoints

provides:
  - Google Routes API v2 backend proxy at GET /api/gps/directions
  - directionsService.js encoding polyline, duration, distance from Google Routes API v2
  - Flutter GpsService with all GPS API methods
  - JobMapWidget: embedded GoogleMap with polyline route, ETA chip, distance chip
  - Job detail screen shows route map for jobs with destination coordinates
  - app_config.dart GPS endpoint constants and WebSocket URL

affects:
  - 07-03 (live tracking map — reuses GpsService.getDriverLocations and wsUrl)
  - Any future screen needing GPS directions or live driver data

# Tech tracking
tech-stack:
  added:
    - flutter_polyline_points 3.1.0 (Flutter polyline decode)
  patterns:
    - Backend proxies Google API key — API key never sent to Flutter client
    - GpsService uses static methods matching existing service patterns
    - PolylinePoints.decodePolyline() called as static method (v3.x API)
    - JobMapWidget is StatefulWidget with initState async load pattern

key-files:
  created:
    - vehicle-scheduling-backend/src/services/directionsService.js
    - vehicle_scheduling_app/lib/services/gps_service.dart
    - vehicle_scheduling_app/lib/widgets/job_map_widget.dart
  modified:
    - vehicle-scheduling-backend/src/routes/gps.js
    - vehicle_scheduling_app/lib/config/app_config.dart
    - vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart
    - vehicle_scheduling_app/pubspec.yaml

key-decisions:
  - "Decode polyline with static PolylinePoints.decodePolyline() — v3.x requires apiKey for network methods but decodePolyline is static (no key needed)"
  - "GpsService returns null on error (non-fatal pattern) — map widget handles null with error state"
  - "JobMapWidget renders SizedBox.shrink() when no destination coords — zero UI impact on jobs without location"
  - "Route card placed after description and before action buttons — consistent with existing card layout"

patterns-established:
  - "GPS API proxied through backend: Flutter calls /api/gps/directions, backend calls Google — API key stays server-side"
  - "Static GpsService methods: matches notification_service.dart and existing Flutter service conventions"

requirements-completed: [GPS-01]

# Metrics
duration: 15min
completed: 2026-03-22
---

# Phase 7 Plan 02: Google Directions Integration Summary

**Google Routes API v2 backend proxy + Flutter map widget with polyline, ETA, and distance on job detail screen**

## Performance

- **Duration:** 15 min
- **Started:** 2026-03-22T07:50:00Z
- **Completed:** 2026-03-22T08:05:00Z
- **Tasks:** 2/2
- **Files modified:** 7

## Accomplishments

- Backend `directionsService.js` calls Google Routes API v2, parses encoded polyline, duration (seconds to "X hr Y min"), and distance (meters to km text)
- GET `/api/gps/directions` endpoint added to gps.js: tenant-scoped job lookup, optional origin params, API key never exposed
- Flutter `GpsService` provides all GPS API methods (directions, location POST, consent CRUD, driver locations)
- `JobMapWidget` shows embedded GoogleMap with blue polyline route, origin (blue) and destination (red) markers, ETA and distance chips
- Job detail screen shows Route card for jobs with destination coordinates

## Task Commits

1. **Task 1: Backend directions service + route endpoint** - `5ab5640` (feat)
2. **Task 2: Flutter job map widget + GPS service + job detail integration** - `b98b36e` (feat)

**Plan metadata:** (included in final docs commit)

## Files Created/Modified

- `vehicle-scheduling-backend/src/services/directionsService.js` - Google Routes API v2 client, polyline/ETA/distance parsing
- `vehicle-scheduling-backend/src/routes/gps.js` - Added GET /directions endpoint with verifyToken, tenant-scoped DB lookup
- `vehicle_scheduling_app/lib/services/gps_service.dart` - Static Flutter GPS service wrapping all /api/gps/* endpoints
- `vehicle_scheduling_app/lib/widgets/job_map_widget.dart` - StatefulWidget with GoogleMap, polyline, markers, info chips
- `vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart` - Import and render JobMapWidget in Route card
- `vehicle_scheduling_app/lib/config/app_config.dart` - GPS endpoint constants and wsUrl getter
- `vehicle_scheduling_app/pubspec.yaml` - Added flutter_polyline_points: ^3.1.0

## Decisions Made

- `PolylinePoints.decodePolyline()` called as a static method — flutter_polyline_points v3.x requires `apiKey` in the constructor for network methods, but `decodePolyline` is static and does not make API calls, so no key is needed here (we decode the polyline we already fetched from the backend proxy)
- `GpsService` uses static methods to match the project's existing service pattern (notification_service.dart, user_service.dart)
- `JobMapWidget` gracefully degrades: shows error state if directions fail, shows SizedBox.shrink() if no destination coordinates
- Route card added to job detail screen for structural consistency (matches Customer, Schedule, Assignment cards)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] PolylinePoints instantiation required apiKey**
- **Found during:** Task 2 (flutter analyze)
- **Issue:** Plan specified `PolylinePoints().decodePolyline()` but v3.1.0 constructor requires `apiKey` parameter and `decodePolyline` is static
- **Fix:** Changed to `PolylinePoints.decodePolyline(encodedPolyline)` — static call, no instantiation needed
- **Files modified:** `vehicle_scheduling_app/lib/widgets/job_map_widget.dart`
- **Verification:** flutter analyze reports no errors in job_map_widget.dart
- **Committed in:** b98b36e (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - library API mismatch)
**Impact on plan:** Minor fix — same functionality, correct API usage for v3.1.0. No scope creep.

## Issues Encountered

- The 07-01 parallel agent committed gps.js before our changes, so our Edit was applied to the working tree and is reflected in HEAD. The directions endpoint is present and verified. No functional issue.

## Known Stubs

None — directions fetch is fully wired to the backend proxy. JobMapWidget renders the real Google Map with real polyline when API key is configured. The widget degrades gracefully (error state) when the API key is not yet set — this is expected behavior documented in GOOGLE_MAPS_INTEGRATION.md.

## Next Phase Readiness

- GPS-01 complete: job detail screen shows route map, ETA, distance
- GpsService ready for 07-03 (live tracking): getDriverLocations() and wsUrl already implemented
- Backend GPS infrastructure (gps.js, gpsService.js, directionsService.js) complete for all remaining GPS plans

---
*Phase: 07-gps-maps-live-tracking*
*Completed: 2026-03-22*
