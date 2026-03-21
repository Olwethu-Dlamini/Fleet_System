---
phase: 02-user-vehicle-scheduler-enhancements
plan: "02"
subsystem: flutter-user-screens
tags: [flutter, user-management, contact-phone, tap-to-call, permissions, url_launcher]
dependency_graph:
  requires: ["02-01"]
  provides: ["USR-01", "USR-02", "USR-03", "SCHED-03"]
  affects: ["vehicle_scheduling_app/lib/models/user.dart", "vehicle_scheduling_app/lib/services/user_service.dart", "vehicle_scheduling_app/lib/screens/users/users_screen.dart"]
tech_stack:
  added: []
  patterns: ["url_launcher tel: URI", "hasPermission() UI gating", "conditional form field pre-fill"]
key_files:
  created: []
  modified:
    - vehicle_scheduling_app/lib/models/user.dart
    - vehicle_scheduling_app/lib/services/user_service.dart
    - vehicle_scheduling_app/lib/screens/users/users_screen.dart
    - vehicle_scheduling_app/android/app/src/main/AndroidManifest.xml
    - vehicle_scheduling_app/ios/Runner/Info.plist
decisions:
  - "Pass canUpdate/canDelete booleans into _UserCard to avoid BuildContext dependency in StatelessWidget"
  - "Screen-level guard replaced isAdmin with hasPermission('users:read') for role-agnostic access control"
  - "contactPhoneSecondary copyWith uses nullable override — callers pass explicit null to clear the field"
metrics:
  duration_minutes: 7
  completed_date: "2026-03-21"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 5
---

# Phase 2 Plan 02: Flutter User Phone Fields and Permission Gating Summary

**One-liner:** Contact phone fields added to User model, service, and all user screens with tap-to-call (url_launcher tel: URI) and permission-based UI gating replacing hardcoded isAdmin checks.

## Tasks Completed

| Task | Description | Commit |
|------|-------------|--------|
| 1 | Extend User model and UserService with contact phone fields | a126312 |
| 2 | Phone fields on create/edit forms, tap-to-call on list, permission gating | 36c945b |

## What Was Built

### User Model (lib/models/user.dart)
- Added `final String? contactPhone` and `final String? contactPhoneSecondary` fields
- `User.fromJson` parses `contact_phone` and `contact_phone_secondary` from API JSON
- Constructor updated with optional named parameters
- `copyWith` updated with both phone fields

### UserService (lib/services/user_service.dart)
- `createUser` accepts `String? contactPhone` and `String? contactPhoneSecondary`
- Conditionally includes `contact_phone` / `contact_phone_secondary` keys in POST body (only when non-empty)
- `updateUser` already accepted `Map<String, dynamic>` — callers now pass phone keys directly

### Users Screen (lib/screens/users/users_screen.dart)
- Added `import 'package:url_launcher/url_launcher.dart'`
- Create form: primary and secondary phone `TextFormField` widgets with `+268 7X XXX XXXX` hint, phone regex validator (`^\+?[\d\s\-\(\)]{7,20}$`), after email field
- Edit form: phone controllers pre-filled from `user.contactPhone` / `user.contactPhoneSecondary`; update map includes phone keys only when values changed
- User list card: shows primary and secondary phone with blue `InkWell` tap-to-call using `launchUrl(Uri.parse('tel:...'))`
- FAB gated by `auth.hasPermission('users:create')`
- Edit and password reset buttons gated by `auth.hasPermission('users:update')`
- Deactivate/reactivate button gated by `auth.hasPermission('users:delete')`
- Screen-level access guard uses `hasPermission('users:read')` (was `isAdmin`)

### Platform Intent Config
- `AndroidManifest.xml`: added `<intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>` inside `<queries>` block — required for Android 11+ `canLaunchUrl` to return true
- `ios/Runner/Info.plist`: added `LSApplicationQueriesSchemes` array containing `tel` — required for iOS `canLaunchUrl` to return true

## Deviations from Plan

None — plan executed exactly as written.

## Decisions Made

1. **Pass canUpdate/canDelete as booleans to _UserCard** — `_UserCard` is a `StatelessWidget` with no context access. Rather than converting it to a `Builder` or passing `BuildContext`, permission booleans are evaluated once in the parent `build()` and passed as constructor params. Clean, testable, no unnecessary widget rebuilds.

2. **Screen guard uses `hasPermission('users:read')` not `isAdmin`** — The plan requires SCHED-03 permission-based gating. Changing the guard from `isAdmin` to `hasPermission('users:read')` makes the screen accessible to any role the backend grants that permission — future-proof when scheduler roles gain read access.

3. **`_field` helper extended with optional `hint` parameter** — Rather than duplicating the field decoration logic for phone fields, the existing helper was extended with an optional `hint` parameter. Backward compatible — all existing call sites omit it.

## Known Stubs

None — all phone fields are wired to the API via `User.fromJson` parsing `contact_phone` from the actual backend response. Data flows end-to-end.

## Self-Check: PASSED

- [x] `vehicle_scheduling_app/lib/models/user.dart` — exists and contains `contactPhone`
- [x] `vehicle_scheduling_app/lib/services/user_service.dart` — exists and contains `contact_phone`
- [x] `vehicle_scheduling_app/lib/screens/users/users_screen.dart` — exists and contains `tel:`, `contactPhone`, `hasPermission`
- [x] `vehicle_scheduling_app/android/app/src/main/AndroidManifest.xml` — contains `android:scheme="tel"`
- [x] `vehicle_scheduling_app/ios/Runner/Info.plist` — contains `LSApplicationQueriesSchemes`
- [x] Commit `a126312` exists (Task 1)
- [x] Commit `36c945b` exists (Task 2)
