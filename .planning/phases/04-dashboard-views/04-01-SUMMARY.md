---
phase: 04-dashboard-views
plan: "01"
subsystem: backend-dashboard, flutter-config
tags: [dashboard, security, tenant-scoping, fl_chart, auth]
dependency_graph:
  requires: []
  provides: [chart-data-endpoint, dashboard-auth-security, fl_chart-dependency]
  affects: [dashboard-views, flutter-chart-widget]
tech_stack:
  added: [fl_chart 1.2.0]
  patterns: [tenant-scoped queries, verifyToken on all dashboard routes]
key_files:
  created: []
  modified:
    - vehicle-scheduling-backend/src/controllers/dashboardController.js
    - vehicle-scheduling-backend/src/routes/dashboard.js
    - vehicle_scheduling_app/pubspec.yaml
    - vehicle_scheduling_app/lib/config/app_config.dart
decisions:
  - "All dashboard routes now require verifyToken — closes previously unauthenticated endpoints"
  - "getDashboardSummary and getQuickStats queries all scoped to req.user.tenant_id — fixes multi-tenant data leak"
  - "getChartData queries HOUR(scheduled_time_start) grouped by hour for bar chart data, excluding cancelled jobs"
  - "dashboardChartEndpoint added as getter (not const) since it derives from dashboardEndpoint string"
metrics:
  duration_min: 8
  completed_date: "2026-03-21"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 4
---

# Phase 4 Plan 01: Dashboard Security + Chart Data Endpoint Summary

**One-liner:** Tenant-scoped hourly job count API for bar charts, with verifyToken security fix across all dashboard routes.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add chart-data endpoint and fix dashboard route security | af40039 | dashboardController.js, dashboard.js |
| 2 | Add fl_chart dependency and AppConfig endpoint | 2ad2372 | pubspec.yaml, app_config.dart |

## What Was Built

**Backend — `dashboardController.js`:**
- Added `getChartData(req, res)` static method:
  - Extracts `tenantId` from `req.user.tenant_id`
  - Queries `HOUR(scheduled_time_start)` grouped by hour for today, excluding cancelled jobs, scoped to tenant
  - Returns `{ success: true, date, hourly: [{ hour, count }] }`
  - Wrapped in try/catch with pino error logging
- Fixed `getDashboardSummary`: all 5 parallel queries now include `AND tenant_id = ?` (jobs, job_status_changes, vehicles, job_assignments)
- Fixed `getQuickStats`: both all-time and today's-count queries include `AND tenant_id = ?`

**Backend — `dashboard.js` routes:**
- Added `const { verifyToken } = require('../middleware/authMiddleware');`
- All three routes now protected: `/summary`, `/stats`, `/chart-data` all use `verifyToken` middleware

**Flutter — `pubspec.yaml`:**
- Added `fl_chart: ^1.2.0` — bar/line chart library for the "Jobs Today" dashboard widget
- `flutter pub get` ran successfully, `fl_chart 1.2.0` resolved

**Flutter — `app_config.dart`:**
- Added `static String get dashboardChartEndpoint => '$dashboardEndpoint/chart-data';`
- Returns `/dashboard/chart-data` — used by future chart service calls

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

All checks passed:

- `getChartData` loads without error
- `grep -c "verifyToken" routes/dashboard.js` → 5 (import + 3 route uses + require comment)
- `grep -c "tenant_id" dashboardController.js` → 11 (well above 5+ required)
- `fl_chart` present in pubspec.yaml
- `dashboardChartEndpoint` present in app_config.dart
- `flutter analyze lib/config/app_config.dart` → No issues found

## Known Stubs

None — all functionality is fully implemented and wired.

## Self-Check: PASSED
