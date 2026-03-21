---
phase: 02-user-vehicle-scheduler-enhancements
plan: "03"
subsystem: flutter-frontend
tags: [maintenance, vehicles, settings, permissions, flutter]
dependency_graph:
  requires: ["02-01"]
  provides: ["vehicle-maintenance-ui", "admin-settings-ui", "vehicle-swap-service"]
  affects: ["vehicle-list-screen", "vehicle-model", "navigation"]
tech_stack:
  added: []
  patterns: ["showDatePicker", "DropdownButtonFormField", "SwitchListTile", "permission-gated UI", "StatefulWidget with service calls"]
key_files:
  created:
    - vehicle_scheduling_app/lib/models/vehicle_maintenance.dart
    - vehicle_scheduling_app/lib/services/vehicle_maintenance_service.dart
    - vehicle_scheduling_app/lib/services/settings_service.dart
    - vehicle_scheduling_app/lib/screens/vehicles/vehicle_maintenance_screen.dart
    - vehicle_scheduling_app/lib/screens/settings/admin_settings_screen.dart
  modified:
    - vehicle_scheduling_app/lib/models/vehicle.dart
    - vehicle_scheduling_app/lib/services/vehicle_service.dart
    - vehicle_scheduling_app/lib/screens/vehicles/vehicles_list_screen.dart
    - vehicle_scheduling_app/lib/main.dart
decisions:
  - "Schedule Maintenance and View Maintenance buttons share VehicleMaintenanceScreen; canCreate controls form visibility within the screen"
  - "Admin Settings added as 7th tab in bottom nav, gated by hasPermission('settings:read')"
  - "Vehicle management buttons (edit/delete/toggle) individually gated by vehicles:update and vehicles:delete permissions rather than unified canManage"
metrics:
  duration_min: 10
  completed_date: "2026-03-21"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 9
requirements_covered: [MAINT-01, MAINT-02, MAINT-03, MAINT-04, MAINT-05, SCHED-02, SCHED-03, SCHED-04]
---

# Phase 02 Plan 03: Flutter Vehicle Maintenance UI & Settings Summary

**One-liner:** Full vehicle maintenance scheduling UI with date-range picker, type dropdown, history list, orange in-maintenance badge, admin GPS visibility toggle, and hasPermission()-gated vehicle actions.

## What Was Built

### Task 1: Models, Services, Vehicle Extension (commit: 7e275e2)

**Vehicle model extended:**
- Added `final bool isInMaintenance` field (defaults to `false`)
- `fromJson` parses `is_in_maintenance` field (handles int `1` and bool `true`)
- `toJson` and `copyWith` updated

**VehicleMaintenance model** (`lib/models/vehicle_maintenance.dart`):
- All fields from API: id, vehicleId, maintenanceType, otherTypeDesc, status, startDate, endDate, notes, createdBy, vehicleName, createdAt, updatedAt
- `typeDisplayName` getter: service, repair, inspection, tyre_change, other (with fallback to otherTypeDesc)
- `statusDisplayName` getter: scheduled, in_progress, completed
- `isActive` getter: returns `status != 'completed'`

**VehicleMaintenanceService** (`lib/services/vehicle_maintenance_service.dart`):
- `getMaintenanceForVehicle(vehicleId)` — GET /vehicle-maintenance?vehicle_id=X
- `getActiveMaintenance()` — GET /vehicle-maintenance/active
- `createMaintenance(...)` — POST /vehicle-maintenance
- `updateMaintenance(id, updates)` — PUT /vehicle-maintenance/:id
- `deleteMaintenance(id)` — DELETE /vehicle-maintenance/:id (soft-delete)

**SettingsService** (`lib/services/settings_service.dart`):
- `getAllSettings()` — GET /settings, returns `Map<String, String>`
- `getSetting(key)` — GET /settings/:key
- `updateSetting(key, value)` — PUT /settings/:key

**VehicleService extended:**
- `swapVehicle(jobId, newVehicleId, {note?})` — PUT /jobs/:id/swap-vehicle (SCHED-02)

### Task 2: UI Screens (commit: 2a23b05)

**vehicles_list_screen.dart updated:**
- Orange `'In Maintenance'` badge renders when `vehicle.isInMaintenance == true`
- "Schedule Maintenance" button shown when `hasPermission('maintenance:create')`
- "View Maintenance" button shown when `hasPermission('maintenance:read')` but not create
- Both navigate to `VehicleMaintenanceScreen`
- Deactivate/Reactivate gated by `hasPermission('vehicles:update')`
- Edit gated by `hasPermission('vehicles:update')`
- Delete gated by `hasPermission('vehicles:delete')`
- FAB remains gated by `hasPermission('vehicles:create')` (unchanged)

**VehicleMaintenanceScreen** (`lib/screens/vehicles/vehicle_maintenance_screen.dart`):
- Schedule form (shown if `maintenance:create` permission):
  - `DropdownButtonFormField` with 5 types: Service, Repair, Inspection, Tyre Change, Other
  - "Other description" TextFormField shown conditionally
  - Start date via `showDatePicker`
  - End date via `showDatePicker` (disabled until start date selected; firstDate = startDate)
  - Notes TextFormField (multiline, optional)
  - Submit calls `createMaintenance`, shows success SnackBar, reloads history
  - 409 conflict and other errors shown inline in error container
- Maintenance history list:
  - Each record as Card with type, status badge (green/orange/grey), date range, notes
  - "Start" button for `scheduled` → `in_progress`
  - "Complete" button for `in_progress` → `completed`
  - Uses `intl.DateFormat('MMM d, yyyy')` for date display

**AdminSettingsScreen** (`lib/screens/settings/admin_settings_screen.dart`):
- Loads all settings via `SettingsService().getAllSettings()` in `initState`
- `SwitchListTile` for "Scheduler GPS Visibility" (`scheduler_gps_visible`)
- Toggle calls `updateSetting`, updates local state, shows SnackBar
- Error and loading states handled

**main.dart updated:**
- AdminSettingsScreen imported
- Admin tabs include Settings tab (index 6) when `hasPermission('settings:read')`
- Nav items include Settings `BottomNavigationBarItem` with settings icon

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None. All screens load real data from API via service calls.

## Verification

1. Vehicle.fromJson parses `is_in_maintenance` — confirmed, line added
2. VehicleMaintenance model parses all fields from API JSON — confirmed, `fromJson` factory covers all fields
3. VehicleMaintenanceService has all CRUD methods — confirmed (5 methods)
4. SettingsService has getAllSettings, getSetting, updateSetting — confirmed
5. Vehicle list shows orange badge for vehicles in maintenance — confirmed, `vehicle.isInMaintenance` badge
6. Maintenance screen has schedule form with type dropdown, date pickers, notes — confirmed
7. Maintenance history loads and displays per vehicle — confirmed via `getMaintenanceForVehicle`
8. Admin settings screen has scheduler GPS visibility toggle — confirmed, `SwitchListTile`
9. All vehicle/maintenance actions use hasPermission() not isAdmin — confirmed

## Self-Check: PASSED
