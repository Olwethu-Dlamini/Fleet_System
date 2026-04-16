---
phase: 07-gps-maps-live-tracking
verified: 2026-03-22T12:00:00Z
status: human_needed
score: 8/8 must-haves verified
re_verification:
  previous_status: gaps_found
  previous_score: 6/8
  gaps_closed:
    - "GPS-06: GPS consent screen (gps_consent_screen.dart) exists, GpsProvider wires grantConsent/updateConsent, consent gate in main.dart blocks technician until consent resolved"
    - "GPS-02: GpsService.postLocation() is now called from GpsProvider.startLocationTimer() on a 30-second Timer.periodic — no longer dead code"
    - "GPS-03: live_tracking_screen.dart exists (380 lines), polls GpsService.getDriverLocations() every 10 seconds, wired as Tracking tab in admin/scheduler bottom nav"
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "Verify Google Maps renders on job detail screen"
    expected: "A 250px map container appears with red destination marker. Loading spinner shown while fetching. Blue origin marker and route polyline once directions load. ETA and distance chips below the map."
    why_human: "Requires running Flutter app, Android emulator, and valid GOOGLE_MAPS_API_KEY in backend .env. Cannot verify rendering programmatically."
  - test: "Verify Socket.IO tenant-scoped broadcast reaches Flutter live tracking client"
    expected: "When driver POSTs to /api/gps/location, an admin Socket.IO client in the tracking:tenantId room immediately receives a driver_location event with the driver's coordinates."
    why_human: "Requires running backend + Socket.IO client connection. Cannot verify socket emission in a static check."
  - test: "Verify GPS consent gate blocks and then grants access on first driver login"
    expected: "First login as a technician: loading spinner briefly shown while checkConsent() resolves, then GpsConsentScreen appears. Tapping 'I Agree' saves consent and navigates to MainApp. On subsequent launch, consent screen is skipped and timer starts."
    why_human: "Requires running app on emulator with a fresh technician account. Cannot test post-login routing flow programmatically."
  - test: "Verify 30-second timer posts location during working hours"
    expected: "With GPS consent granted and the time between 6AM and 8PM, every 30 seconds a POST /api/gps/location call succeeds. Outside those hours no calls are made."
    why_human: "Requires running app, live Geolocator on device, and network access to backend. Time-bounded behavior needs real-time observation."
  - test: "Confirm GPS-05 checkbox in REQUIREMENTS.md"
    expected: "GPS-05 (location snapshot on job completion) checkbox at .planning/REQUIREMENTS.md line 86 should be updated from [ ] to [x] — Phase 3 implemented job_completions table with GPS fields in jobStatusService.js."
    why_human: "Requires human decision to tick a requirement satisfied across phases. Outside scope of automated verification."
  - test: "Working hours enforcement time boundary"
    expected: "POST /api/gps/location at 7:59 PM returns 200. POST at 8:00 PM returns 403 with message 'GPS tracking only active during working hours (6AM-8PM)'."
    why_human: "Requires live DB with settings row and time-sensitive manual test execution."
---

# Phase 7: GPS, Maps & Live Tracking — Re-Verification Report

**Phase Goal:** GPS, Maps & Live Tracking — Google Maps integration, route display with polyline/ETA, real-time driver location broadcasting via Socket.IO, GPS consent management, working hours enforcement, tiered storage.
**Verified:** 2026-03-22T12:00:00Z
**Status:** human_needed
**Re-verification:** Yes — after gap closure (07-03 and 07-04 executed)

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Job detail screen shows embedded Google Map with route polyline and ETA/distance (GPS-01) | VERIFIED | `job_map_widget.dart` (297 lines), `directionsService.js`, GET /directions endpoint, JobMapWidget rendered in job_detail_screen.dart line 1424 — unchanged from initial verification |
| 2 | Driver location POSTed every 30 seconds during working hours when consent granted (GPS-02) | VERIFIED | `GpsProvider.startLocationTimer()` creates `Timer.periodic(30s)` that calls `Geolocator.getCurrentPosition()` then `GpsService.postLocation()`. Guarded by `_isWithinWorkingHours()` (hour >= 6 && hour < 20). Called from gps_provider.dart line 173. |
| 3 | Admin/scheduler can see live driver positions on map (GPS-03) | VERIFIED | `live_tracking_screen.dart` (380 lines) renders GoogleMap with driver markers. Polls `GpsService.getDriverLocations()` every 10 seconds via `Timer.periodic`. Markers green (<= 2 min) or orange (3-5 min); stale (> 5 min) filtered out. Wired as Tracking tab in admin/scheduler bottom nav via main.dart lines 205 and 219. |
| 4 | Admin toggle controls scheduler GPS visibility (GPS-04) | VERIFIED | GET /drivers in gps.js enforces `scheduler_gps_visible` from settings table, returns 403 for schedulers when false. `admin_settings_screen.dart` provides the toggle UI — unchanged from initial verification. |
| 5 | GPS-05 location snapshot on job completion satisfied by Phase 3 | VERIFIED* | `jobStatusService.js` INSERTs into job_completions with lat, lng, accuracy_m, gps_status. (*REQUIREMENTS.md checkbox still [ ] — requires human decision.) |
| 6 | GPS consent screen shown on first launch for drivers with revocation in settings (GPS-06) | VERIFIED | `gps_consent_screen.dart` (303 lines) exists with Accept/Decline, POPIA explanation card, and manage-mode SwitchListTile. `GpsProvider.grantConsent()` and `updateConsent()` wired from screen. Consent gate in `main.dart` (lines 121-143) blocks technicians until `gps.needsConsent` resolves. `dashboard_screen.dart` shows GPS icon (gps_fixed/gps_off) navigating to manage mode. |
| 7 | Location POST rejected outside 6AM–8PM tenant timezone (GPS-07) | VERIFIED | `gpsService.isWithinWorkingHours()` queries tenant_timezone from settings, returns 403 outside hours. Flutter-side `GpsProvider._isWithinWorkingHours()` additionally suppresses client-side POSTs — unchanged from initial verification. |
| 8 | 5-minute cron flushes in-memory cache to driver_location_history table (GPS-08) | VERIFIED | `cronService.js` `*/5 * * * *` calls `GpsService.flushLocationHistory()` which batch-inserts all locationCache entries to driver_location_history — unchanged from initial verification. |

**Score: 8/8 truths verified**

---

## Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `vehicle-scheduling-backend/src/services/gpsService.js` | In-memory cache, broadcast, flush, working hours, consent | VERIFIED | 189 lines — unchanged |
| `vehicle-scheduling-backend/src/routes/gps.js` | GPS REST endpoints | VERIFIED | 252 lines — unchanged |
| `vehicle-scheduling-backend/src/services/directionsService.js` | Google Routes API v2 integration | VERIFIED | 136 lines — unchanged |
| `vehicle-scheduling-backend/src/server.js` | Socket.IO attached to HTTP server | VERIFIED | GpsService.init(io) call confirmed — unchanged |
| `vehicle-scheduling-backend/src/services/cronService.js` | 5-min GPS flush cron | VERIFIED | `*/5 * * * *` calling flushLocationHistory — unchanged |
| `vehicle_scheduling_app/lib/services/gps_service.dart` | Flutter GPS service | VERIFIED | 128 lines — unchanged |
| `vehicle_scheduling_app/lib/widgets/job_map_widget.dart` | Map widget with polyline, ETA, distance | VERIFIED | 297 lines — unchanged |
| `vehicle_scheduling_app/lib/config/app_config.dart` | GPS endpoint constants and wsUrl | VERIFIED | All GPS endpoints present — unchanged |
| `vehicle_scheduling_app/lib/providers/gps_provider.dart` | GPS consent state + 30-second timer | VERIFIED | 214 lines. `ChangeNotifier` with checkConsent, grantConsent, toggleGps, startLocationTimer, stopLocationTimer, dispose, needsConsent, isTimerRunning getters. Timer.periodic(30s) calls GpsService.postLocation(). SharedPreferences cache for consent. |
| `vehicle_scheduling_app/lib/screens/gps/gps_consent_screen.dart` | POPIA consent screen with Accept/Decline and manage mode | VERIFIED | 303 lines. First-time mode: mandatory (no back button), "I Agree - Enable GPS Tracking" ElevatedButton, "Decline - Skip GPS Tracking" TextButton. Manage mode: SwitchListTile, back button. Decline creates POPIA audit record via grantConsent() then toggleGps(false). |
| `vehicle_scheduling_app/lib/screens/gps/live_tracking_screen.dart` | GoogleMap with live driver markers via polling | VERIFIED | 380 lines. Timer.periodic(10s), GpsService.getDriverLocations(), MarkerId-keyed marker map, BitmapDescriptor hue (green/orange/filtered), InfoWindow with driver name and minutes-ago snippet, camera bounds fitted on first load. |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| server.js | gpsService.js | `GpsService.init(io)` | WIRED | server.js line 296: `GpsService.init(io)` — unchanged |
| gps.js routes | gpsService.js | `GpsService.*` method calls | WIRED | All route handlers call relevant GpsService methods — unchanged |
| cronService.js | gpsService.js | `GpsService.flushLocationHistory` | WIRED | cronService.js line 80 — unchanged |
| gps.js GET /directions | directionsService.js | `DirectionsService.getDirections()` | WIRED | gps.js line 71 — unchanged |
| job_map_widget.dart | /api/gps/directions | `GpsService.getDirections(jobId)` | WIRED | job_map_widget.dart line 85 — unchanged |
| job_detail_screen.dart | job_map_widget.dart | `JobMapWidget(jobId:, destinationLat:, destinationLng:)` | WIRED | job_detail_screen.dart line 1424 — unchanged |
| main.dart (AuthGate) | gps_consent_screen.dart | `GpsConsentScreen()` when `gps.needsConsent` | WIRED | main.dart line 134-135: `if (gps.needsConsent) return const GpsConsentScreen()` |
| main.dart | gps_provider.dart | `ChangeNotifierProvider(create: (_) => GpsProvider())` | WIRED | main.dart line 51: GpsProvider registered in MultiProvider |
| gps_provider.dart | gps_service.dart | `GpsService.postLocation()` in timer | WIRED | gps_provider.dart line 173: `await GpsService.postLocation(lat: ..., lng: ..., accuracyM: ...)` inside Timer.periodic |
| gps_provider.dart | gps_service.dart | `GpsService.getConsent/grantConsent/updateConsent` | WIRED | gps_provider.dart lines 56, 97, 131: all three consent methods called |
| gps_consent_screen.dart | gps_provider.dart | `context.read<GpsProvider>().grantConsent()` | WIRED | gps_consent_screen.dart line 34 (_acceptConsent) and line 64 (_declineConsent) |
| dashboard_screen.dart | gps_consent_screen.dart | `GpsConsentScreen(isManageMode: true)` | WIRED | dashboard_screen.dart line 342: NavigatorPush to GpsConsentScreen(isManageMode: true) |
| live_tracking_screen.dart | gps_service.dart | `GpsService.getDriverLocations()` | WIRED | live_tracking_screen.dart line 59: `final drivers = await GpsService.getDriverLocations()` inside Timer.periodic |
| main.dart | live_tracking_screen.dart | `LiveTrackingScreen()` in admin/scheduler tabs | WIRED | main.dart line 205 (admin tab 4) and line 219 (scheduler tab 4) |
| routes/index.js | gps.js | `router.use('/gps', gpsRoutes)` | WIRED | routes/index.js line 45 — unchanged |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| GPS-01 | 07-02-PLAN.md | Directions + ETA displayed on job view | SATISFIED | directionsService.js + GET /directions + JobMapWidget + job_detail integration. REQUIREMENTS.md: [x] |
| GPS-02 | 07-01-PLAN.md, 07-03-PLAN.md | Live driver tracking — drivers POST location every 15-30 seconds | SATISFIED | GpsProvider.startLocationTimer() creates Timer.periodic(30s) calling GpsService.postLocation(). REQUIREMENTS.md: [x] |
| GPS-03 | 07-01-PLAN.md, 07-04-PLAN.md | Real-time driver positions on map for admin/scheduler | SATISFIED | Backend Socket.IO broadcast + GET /drivers fully wired; live_tracking_screen.dart with 10-second polling + GoogleMap markers. REQUIREMENTS.md: [x] |
| GPS-04 | 07-01-PLAN.md | Admin toggle to control scheduler GPS visibility | SATISFIED | Backend enforces in GET /drivers; admin_settings_screen.dart toggles scheduler_gps_visible. REQUIREMENTS.md: [x] |
| GPS-05 | 07-01-PLAN.md | Location snapshot on job completion (audit trail) | PRE-SATISFIED (Phase 3) | jobStatusService.js inserts into job_completions with GPS fields. REQUIREMENTS.md checkbox still [ ] — needs human decision. |
| GPS-06 | 07-01-PLAN.md, 07-03-PLAN.md | GPS consent screen on driver app (POPIA/GDPR compliance) | SATISFIED | gps_consent_screen.dart (303 lines), GpsProvider, consent gate in main.dart. REQUIREMENTS.md: [x] |
| GPS-07 | 07-01-PLAN.md | Time-bounded tracking — only during working hours / active jobs | SATISFIED | Backend isWithinWorkingHours() + Flutter GpsProvider._isWithinWorkingHours() both enforce 6AM-8PM. REQUIREMENTS.md: [x] |
| GPS-08 | 07-01-PLAN.md | Two-tier GPS storage — in-memory for live, periodic MySQL flush for history | SATISFIED | locationCache Map + 5-min cron to driver_location_history. REQUIREMENTS.md: [x] |

**Orphaned requirements check:** REQUIREMENTS.md maps GPS-01 through GPS-08 to Phase 7. All 8 accounted for in plan frontmatter. No orphaned requirements.

---

## Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `.planning/REQUIREMENTS.md` | 86 | GPS-05 shows `[ ]` unchecked | Info | GPS-05 was satisfied in Phase 3. Checkbox not updated — requires human decision, not a code defect. |

No blockers or warnings in the new files. The three previously-flagged dead-code methods (`postLocation`, `grantConsent`, `updateConsent`) are all now called from real code paths.

---

## Human Verification Required

### 1. Google Map rendering on job detail

**Test:** Run the Flutter app on an Android emulator. Open a job with `destination_lat`/`destination_lng` set. Navigate to the job detail screen and scroll to the "Route" card.
**Expected:** A 250px map container appears showing a red destination marker. A `CircularProgressIndicator` shown while loading. Once directions load, a blue origin marker, blue route polyline, and ETA/distance chips appear below the map.
**Why human:** Requires a running Flutter app, Android emulator, and valid `GOOGLE_MAPS_API_KEY` in the backend `.env`. Cannot verify rendering programmatically.

### 2. Socket.IO tenant-scoped broadcast

**Test:** Start the backend. Connect two Socket.IO clients authenticated with JWTs from the same tenant — one as driver, one as admin. Admin client joins `tracking:tenantId` room. Driver client POSTs to `/api/gps/location` with valid coordinates.
**Expected:** Admin client receives a `driver_location` event immediately with the driver's coordinates and driver_id.
**Why human:** Requires a running Node.js server with live DB connection. Socket emission cannot be verified in a static check.

### 3. GPS consent gate flow on first driver login

**Test:** Run the Flutter app with a fresh technician account (no consent record in DB and `gps_consent_given` not in SharedPreferences). Log in as technician.
**Expected:** A loading spinner briefly appears while `checkConsent()` resolves against the API. Then `GpsConsentScreen` appears with the POPIA explanation. Tapping "I Agree - Enable GPS Tracking" saves consent and navigates to `MainApp`. On subsequent launch the consent screen is skipped and the timer starts automatically.
**Why human:** Requires running app on emulator with a fresh technician account and network access to the backend. Cannot test post-login routing flow programmatically.

### 4. 30-second location timer and working hours enforcement

**Test:** With GPS consent granted and the device clock showing a time between 6AM and 8PM, monitor outgoing network requests from the Flutter app.
**Expected:** Every 30 seconds a POST to `/api/gps/location` succeeds. Change the device clock to 8PM or later — no more POSTs are sent.
**Why human:** Requires running app with live Geolocator, network access to backend, and time manipulation. Cannot verify timer-based network behavior programmatically.

### 5. GPS-05 checkbox in REQUIREMENTS.md

**Test:** Review `.planning/REQUIREMENTS.md` line 86.
**Expected:** `- [ ] **GPS-05**` should be updated to `- [x] **GPS-05**`. Phase 3 implemented `job_completions` INSERT with lat, lng, accuracy_m, gps_status in `jobStatusService.js`. Confirm this satisfies the audit trail requirement and update the checkbox.
**Why human:** Requires human decision to mark a requirement satisfied across phases.

### 6. Working hours enforcement time boundary (backend)

**Test:** With a `settings` row in the DB for `tenant_timezone` set to the local timezone, POST to `/api/gps/location` just before and just after 8:00 PM.
**Expected:** POST at 7:59 PM returns 200. POST at 8:00 PM returns 403 with message "GPS tracking only active during working hours (6AM-8PM)".
**Why human:** Requires live DB with settings row and time-sensitive test execution.

---

## Re-Verification Summary

All three gaps from the initial verification are now closed:

**Gap 1 (GPS-06) — CLOSED:** `gps_consent_screen.dart` (303 lines) is a complete POPIA-compliant consent screen. `GpsProvider` manages consent state, wraps all three `GpsService` consent methods, and is registered in `MultiProvider`. The consent gate in `main.dart` blocks technicians at the `AuthGate` level until `gps.needsConsent` resolves. `dashboard_screen.dart` exposes a GPS status icon navigating to manage mode. The two previously-dead methods `grantConsent()` and `updateConsent()` are now called from `gps_consent_screen.dart` and `gps_provider.dart` respectively.

**Gap 2 (GPS-02) — CLOSED:** `GpsProvider.startLocationTimer()` creates a real `Timer.periodic(Duration(seconds: 30))` that calls `Geolocator.getCurrentPosition()` and then `GpsService.postLocation()`. The working hours guard (`hour >= 6 && hour < 20`) suppresses off-hours POSTs on the client side, complementing the backend 403. `postLocation()` is no longer dead code.

**Gap 3 (GPS-03) — CLOSED:** `live_tracking_screen.dart` (380 lines) renders a `GoogleMap` widget with per-driver `Marker` objects keyed by `MarkerId`. A `Timer.periodic(Duration(seconds: 10))` calls `GpsService.getDriverLocations()` and rebuilds markers. Green markers for updates within 2 minutes, orange for 3-5 minutes, silently filtered beyond 5 minutes. Wired as a "Tracking" tab at index 4 in both the admin and scheduler `_buildTabsForRole` lists, with `Icons.map_outlined` nav items.

No regressions were found in previously-passing truths. All 8 GPS requirements are satisfied in code. Six items require human verification before the phase can be fully signed off — these are runtime behaviors (rendering, socket events, timer behaviour) that cannot be confirmed through static analysis.

---

_Verified: 2026-03-22T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
