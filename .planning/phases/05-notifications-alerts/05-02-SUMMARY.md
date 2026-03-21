---
phase: 05-notifications-alerts
plan: "02"
subsystem: flutter-fcm-integration
tags: [fcm, push-notifications, firebase, flutter, android]
dependency_graph:
  requires: [05-01]
  provides: [fcm-device-registration, topic-subscription, foreground-notifications]
  affects: [vehicle-scheduling-backend/src/server.js, vehicle_scheduling_app/lib/services/fcm_service.dart]
tech_stack:
  added: [firebase_core ^3.13.0, firebase_messaging ^15.2.5, flutter_local_notifications ^18.0.1, com.google.gms.google-services:4.4.2]
  patterns: [FCM topic-based push, fire-and-forget subscription, graceful Firebase degradation, @pragma vm:entry-point background handler]
key_files:
  created:
    - vehicle_scheduling_app/lib/services/fcm_service.dart
  modified:
    - vehicle_scheduling_app/pubspec.yaml
    - vehicle_scheduling_app/lib/main.dart
    - vehicle_scheduling_app/lib/services/auth_service.dart
    - vehicle_scheduling_app/android/app/src/main/AndroidManifest.xml
    - vehicle_scheduling_app/android/app/build.gradle.kts
    - vehicle_scheduling_app/android/settings.gradle.kts
    - vehicle-scheduling-backend/src/server.js
decisions:
  - "Kotlin DSL (.kts) google-services registration via settings.gradle.kts plugins{} block instead of project-level buildscript — correct pattern for AGP 8.x"
  - "compileSdk hardcoded to 35 (not flutter.compileSdkVersion) — Firebase requires explicit SDK 35"
  - "Java 17 and coreLibraryDesugaring enabled — required by firebase_messaging for Java 8+ time APIs"
  - "Topic naming: driver_{userId} for technician/driver roles, scheduler_{userId} for admin/scheduler"
  - "FCM subscription is fire-and-forget and wrapped in lazy require() try/catch — server never fails at login due to missing Firebase config"
metrics:
  duration_minutes: 7
  completed_date: "2026-03-21"
  tasks_completed: 3
  files_changed: 8
---

# Phase 05 Plan 02: FCM Push Notification Integration Summary

**One-liner:** Firebase FCM integrated via topic subscriptions — Flutter sends device token at login, backend subscribes to driver/scheduler topics, foreground notifications displayed via flutter_local_notifications.

## What Was Built

Full FCM push notification pipeline connecting Flutter frontend to backend:

1. **FCM Service** (`fcm_service.dart`) — Initializes Firebase at app startup, registers the `@pragma('vm:entry-point')` background handler, creates the `high_importance_channel` Android notification channel, requests Android 13+ notification permission, and listens for foreground messages to display via `flutter_local_notifications`.

2. **Login token flow** — `auth_service.dart` calls `FcmService.getToken()` before the login API call and includes `fcm_token` in the POST body if available. Wrapped in try/catch so login succeeds without FCM.

3. **Backend topic subscription** — `server.js` login handler reads `req.body.fcm_token`, determines role-appropriate topic (`driver_{userId}` or `scheduler_{userId}`), and calls `firebaseAdmin.messaging().subscribeToTopic()` fire-and-forget (no await). Firebase module is lazily `require()`d inside try/catch so the server starts without `FCM_SERVICE_ACCOUNT_PATH`.

4. **Android config** — google-services plugin registered in `settings.gradle.kts` (Kotlin DSL pattern), applied in `app/build.gradle.kts`. compileSdk=35, minSdk=21, Java 17, coreLibraryDesugaring enabled. `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED` added to manifest.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Flutter FCM service + Android config + login token integration | 8fdbc18 | 7 files (pubspec.yaml, fcm_service.dart, auth_service.dart, main.dart, AndroidManifest.xml, app/build.gradle.kts, settings.gradle.kts) |
| 2 | Backend FCM topic subscription at login | a6a46f2 | 1 file (server.js) |
| 3 | Verify FCM push notification pipeline | auto-approved | checkpoint:human-verify auto-approved in autonomous mode |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Gradle files use Kotlin DSL, not Groovy**
- **Found during:** Task 1
- **Issue:** Plan instructions referenced Groovy syntax (`classpath '...'`, `apply plugin: '...'`). Project uses Kotlin DSL (`.kts` files) throughout.
- **Fix:** Used Kotlin DSL equivalent — registered `com.google.gms.google-services` plugin in `settings.gradle.kts` `plugins {}` block and applied via `id("com.google.gms.google-services")` in `app/build.gradle.kts`.
- **Files modified:** `android/settings.gradle.kts`, `android/app/build.gradle.kts`
- **Commit:** 8fdbc18

## Known Stubs

None — all wired functionality is real:
- FCM token retrieval is live (returns null if google-services.json absent, which is expected without Firebase project config)
- Backend subscription calls real firebase-admin API
- Foreground notifications use real `flutter_local_notifications` plugin

## User Setup Required

Before FCM will function end-to-end, the user must:
1. Download `google-services.json` from Firebase Console > Project Settings > Your Apps > Android app
2. Place it at `vehicle_scheduling_app/android/app/google-services.json`
3. Ensure backend `.env` has `FCM_SERVICE_ACCOUNT_PATH` pointing to the Firebase service account JSON

Without these files, the app and backend both degrade gracefully — login works, push notifications are simply not sent/received.

## Self-Check: PASSED

- [x] `vehicle_scheduling_app/lib/services/fcm_service.dart` — created and analyzed clean
- [x] `vehicle_scheduling_app/lib/services/auth_service.dart` — contains `fcm_token` and `FcmService.getToken`
- [x] `vehicle_scheduling_app/lib/main.dart` — contains `FcmService.initialize()`
- [x] `vehicle_scheduling_app/android/app/src/main/AndroidManifest.xml` — contains `POST_NOTIFICATIONS`
- [x] `vehicle-scheduling-backend/src/server.js` — contains `subscribeToTopic`, `driver_`, `scheduler_`, fire-and-forget pattern
- [x] Commit 8fdbc18 exists (Task 1)
- [x] Commit a6a46f2 exists (Task 2)
