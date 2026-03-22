---
phase: 07-gps-maps-live-tracking
plan: 03
subsystem: flutter-gps-consent
tags: [gps, consent, popia, gdpr, flutter, provider, timer]
dependency_graph:
  requires: [07-01, 07-02]
  provides: [GPS-06, GPS-02]
  affects: [main.dart, dashboard_screen.dart]
tech_stack:
  added: []
  patterns: [Provider ChangeNotifier, SharedPreferences cache, Timer.periodic, Future.microtask in build]
key_files:
  created:
    - vehicle_scheduling_app/lib/providers/gps_provider.dart
    - vehicle_scheduling_app/lib/screens/gps/gps_consent_screen.dart
  modified:
    - vehicle_scheduling_app/lib/main.dart
    - vehicle_scheduling_app/lib/screens/dashboard/dashboard_screen.dart
decisions:
  - "maybePop() used in GpsConsentScreen navigation — AuthGate re-renders with consentGranted=true after pop"
  - "GPS consent gate only applies to isTechnician role — admin/scheduler bypass entirely"
  - "Timer.periodic starts only when _gpsEnabled=true and timer not already running — prevents duplicate timers"
  - "Working hours guard (hour >= 6 && hour < 20) suppresses off-hours location POSTs"
  - "Decline flow: grantConsent() then toggleGps(false) — creates POPIA audit record while disabling tracking"
metrics:
  duration_min: 21
  completed_date: "2026-03-22"
  tasks_completed: 2
  tasks_total: 2
  files_created: 2
  files_modified: 2
---

# Phase 7 Plan 3: GPS Consent Screen and Location Timer Summary

**One-liner:** POPIA/GDPR GPS consent gate with SharedPreferences cache, 30-second location timer during working hours (6AM-8PM), and driver dashboard GPS toggle.

## What Was Built

### GpsProvider (`lib/providers/gps_provider.dart`)
A ChangeNotifier managing the full GPS consent lifecycle:
- `checkConsent()` — reads SharedPreferences cache for fast startup, then verifies with backend API; sets `_consentChecked = true` after resolution.
- `grantConsent()` — POSTs to `/api/gps/consent`, caches `gps_consent_given=true` in SharedPreferences, starts location timer.
- `toggleGps(bool)` — PUTs to `/api/gps/consent` to enable/disable; starts or stops timer accordingly.
- `startLocationTimer()` — creates `Timer.periodic(30s)` that checks working hours, calls `Geolocator.getCurrentPosition()`, and POSTs via `GpsService.postLocation()`. Non-fatal; all errors are logged.
- `stopLocationTimer()` / `dispose()` — cleanly cancels the timer.
- `needsConsent` getter — `consentChecked && !consentGranted` — drives the consent gate in AuthGate.
- `isTimerRunning` getter — `_locationTimer != null` — prevents duplicate timer starts.

### GpsConsentScreen (`lib/screens/gps/gps_consent_screen.dart`)
A StatefulWidget with two modes:
- **First-time mode** (default): No back button (mandatory), shows "I Agree - Enable GPS Tracking" ElevatedButton and "Decline - Skip GPS Tracking" TextButton.
- **Manage mode** (`isManageMode: true`): Shows current GPS status as a SwitchListTile at top; same explanation card below; has a back button.
- Explanation card covers: What we collect, Why, When (working hours), and user rights.
- Decline creates a POPIA audit record in DB (`grantConsent()` then `toggleGps(false)`).
- Navigation after consent/decline uses `maybePop()` so AuthGate re-renders and routes to MainApp.

### main.dart — GPS consent gate
- `GpsProvider` added to `MultiProvider`.
- `_AuthGateState.build` checks `auth.isTechnician` before showing `MainApp`.
- If `!gps.consentChecked`, triggers `Future.microtask(() => gps.checkConsent())` and shows a loading spinner.
- If `gps.needsConsent`, returns `const GpsConsentScreen()` (blocks MainApp access).
- If `gps.gpsEnabled && !gps.isTimerRunning`, triggers `Future.microtask(() => gps.startLocationTimer())`.

### dashboard_screen.dart — GPS toggle icon
- Added imports for `GpsProvider` and `GpsConsentScreen`.
- AppBar actions include a GPS icon for technicians: `Icons.gps_fixed` (green) when enabled, `Icons.gps_off` (grey) when disabled.
- Tapping navigates to `GpsConsentScreen(isManageMode: true)`.

## Task Commits

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create GpsProvider and GPS consent screen | 93de8cb | gps_provider.dart, gps_consent_screen.dart |
| 2 | Wire consent gate in main.dart and GPS toggle in dashboard | 33076ff | main.dart, dashboard_screen.dart, gps_consent_screen.dart (nav fix) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed navigation after consent — used maybePop() instead of pushNamedAndRemoveUntil('/')**
- **Found during:** Task 2
- **Issue:** Plan specified `Navigator.pushNamedAndRemoveUntil('/', ...)` but `main.dart` uses `home: const AuthGate()` with no named routes — calling a named route would throw a routing error.
- **Fix:** Changed to `Navigator.of(context).maybePop()`. Since `GpsConsentScreen` is returned directly from `AuthGate.build` (not pushed onto a route stack), a pop causes `AuthGate` to rebuild. With `consentGranted = true`, `needsConsent` becomes false and `AuthGate` renders `MainApp`.
- **Files modified:** `lib/screens/gps/gps_consent_screen.dart`
- **Commit:** 33076ff

## Known Stubs

None. All GPS consent state is wired from real API calls (GpsService.getConsent, grantConsent, updateConsent) and timer invokes GpsService.postLocation with live Geolocator data.

## Self-Check: PASSED

- `vehicle_scheduling_app/lib/providers/gps_provider.dart` — FOUND
- `vehicle_scheduling_app/lib/screens/gps/gps_consent_screen.dart` — FOUND
- Commit 93de8cb — FOUND (feat(07-03): add GpsProvider and GPS consent screen)
- Commit 33076ff — FOUND (feat(07-03): wire GPS consent gate in main.dart and GPS toggle in dashboard)
