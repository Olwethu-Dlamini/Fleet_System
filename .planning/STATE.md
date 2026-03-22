---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_plan: 1
status: executing
stopped_at: Completed 09-01-PLAN.md
last_updated: "2026-03-22T11:13:32.833Z"
progress:
  total_phases: 9
  completed_phases: 8
  total_plans: 29
  completed_plans: 28
  percent: 100
---

# FleetScheduler Pro — Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-21)

**Core value:** Schedulers can efficiently assign, monitor, and adjust jobs in real-time so no job falls through the cracks
**Current focus:** Phase 09 — documentation-deployment

## Milestone: v1.0

**Status:** Executing Phase 09
**Phases:** 9 total
**Requirements:** 62 v1 requirements mapped across all phases

## Current Phase

**Phase:** 9
**Status:** Complete (02-01, 02-02, 02-03 all complete)
**Current Plan:** 1
**Requirements:** USR-01 to SCHED-04

## Phase Progress

| Phase | Name | Status | Plans |
|-------|------|--------|-------|
| 1 | Foundation & Security Hardening | ● Complete | 5/5 |
| 2 | User, Vehicle & Scheduler Enhancements | ● Complete | 3/3 |
| 3 | Job Assignment & Status Automation | ○ Not started | 0/0 |
| 4 | Dashboard & Views | ○ Not started | 0/0 |
| 5 | Notifications & Alerts | ○ Not started | 0/0 |
| 6 | Time Management | ○ Not started | 0/0 |
| 7 | GPS, Maps & Live Tracking | ○ Not started | 0/0 |
| 8 | Testing Suite | ○ Not started | 0/0 |
| 9 | Documentation & Deployment | ○ Not started | 0/0 |

Progress: [██████████] 100% (Phase 1)

## Key Documents

- `.planning/PROJECT.md` — Project context and requirements overview
- `.planning/REQUIREMENTS.md` — 62 checkable requirements with traceability
- `.planning/ROADMAP.md` — 9-phase roadmap with dependencies
- `.planning/research/` — 4 research documents (3,041 lines)
- `.planning/codebase/` — 7 codebase map documents (2,084 lines)

## Key Decisions Log

| Date | Decision | Context |
|------|----------|---------|
| 2026-03-21 | Push + email notifications (email togglable) | User preference, covers real-time + async |
| 2026-03-21 | Sellable from day 1 — tenant_id in Phase 1 | Adding later is a full rewrite |
| 2026-03-21 | Docker-first deployment, any Linux server | Cloud-agnostic requirement |
| 2026-03-21 | HTTP polling from drivers, Socket.IO to dispatchers | Research: proven pattern (Housecall Pro) |
| 2026-03-21 | Scheduler suggests options, scheduler approves | Time extension differentiator feature |
| 2026-03-21 | GPS consent required (POPIA/GDPR) | Legal compliance for sellable product |
| 2026-03-21 | Admin controls scheduler GPS visibility | Privacy/trust feature |
| 2026-03-21 | ADD COLUMN IF NOT EXISTS for idempotent migration | MariaDB 10.4.32 confirmed from SQL dump header |
| 2026-03-21 | No FK constraint tenant_id -> tenants.id in Phase 1 | Avoids cascading delete risk, deferred to later phase |
| 2026-03-21 | pool.on('connection') hook for GROUP_CONCAT fix | Per-connection SESSION var is the correct mysql2 pattern |
| 2026-03-21 | Availability check inside FOR UPDATE transaction (not split read-then-lock) | Closes vehicle double-booking race (FOUND-02) |
| 2026-03-21 | LAST_INSERT_ID(expr) atomic counter replaces SELECT MAX for job numbers | Single atomic DB operation, no race possible (FOUND-03) |
| 2026-03-21 | helmet() scoped to /api only — Swagger UI uses inline scripts blocked by CSP | FOUND-05 |
| 2026-03-21 | loginLimiter skipSuccessfulRequests: true — shared NAT/office IPs | FOUND-05 |
| 2026-03-21 | tenant_id in JWT payload from login — downstream phases need tenant-scoped queries | FOUND-04 |
| 2026-03-21 | pino-pretty only in non-production — production logs raw JSON for log shipping | FOUND-10 |
| 2026-03-21 | Child logger per service with service name in context for easy log filtering | FOUND-10 |
| 2026-03-21 | server.js require.main guard — enables supertest to import app without starting DB | Testing |
| 2026-03-21 | Integration tests accept 401 on protected routes — validates route exists and auth fires | FOUND-06 |
| 2026-03-21 | JWT fallback secret removed entirely — startup guard in server.js enforces JWT_SECRET at boot | FOUND-04 gap closure |
| 2026-03-21 | tenant_id added to authController jwt.sign() — both login paths now produce identical JWT payloads | FOUND-04 gap closure |
| 2026-03-21 | All console.* replaced with pino child loggers across all 16 src/ files — FOUND-10 fully satisfied | FOUND-10 gap closure |
| 2026-03-21 | Soft-delete maintenance records via status=completed — hard delete violates audit trail | 02-01 MAINT |
| 2026-03-21 | Schedule/View Maintenance share VehicleMaintenanceScreen; maintenance:create controls form visibility | 02-03 MAINT |
| 2026-03-21 | Admin Settings added as 7th bottom nav tab gated by hasPermission('settings:read') | 02-03 SCHED-04 |
| 2026-03-21 | Settings upsert: UPDATE first then INSERT if affectedRows===0 to avoid REPLACE INTO ID reset | 02-01 SCHED-04 |
| 2026-03-21 | requirePermission(assignments:update) on swap-vehicle for strict backend enforcement | 02-01 SCHED-02 |
| 2026-03-21 | Pass canUpdate/canDelete booleans into _UserCard — avoids BuildContext dependency in StatelessWidget | 02-02 USR |
| 2026-03-21 | Screen guard uses hasPermission('users:read') not isAdmin — role-agnostic access for future scheduler permissions | 02-02 SCHED-03 |
| 2026-03-21 | _logAssignmentHistory swallows errors — audit logging must never roll back a committed transaction | 03-01 ASGN |
| 2026-03-21 | reassignJob captures previousDriverId before delegating so both create and reassign events are logged with correct driver context | 03-01 ASGN |
| 2026-03-21 | driver-load route uses verifyToken inline — req.user.tenant_id required for tenant scoping | 03-01 ASGN |
| 2026-03-21 | Cron require() inside require.main guard async IIFE — Jest never loads cronService during tests | 03-02 STAT-01 |
| 2026-03-21 | completeJob personnel check uses plain db.query — read-only authorization needs no transaction | 03-02 STAT-02 |
| 2026-03-21 | GPS fallback: null coordinates + gps_status=no_gps stored when GPS unavailable | 03-02 STAT-03 |
| 2026-03-21 | DriverLoadCard uses green border + box-shadow on below_average to create glow effect | 03-03 ASGN-02 |
| 2026-03-21 | Confirm dialog fires FIRST, GPS capture second — user decides before GPS permission prompt | 03-03 STAT-03 |
| 2026-03-21 | Complete Job button visible to assigned driver/technician AND admin/scheduler per STAT-02 | 03-03 STAT-02 |
| 2026-03-21 | All dashboard routes require verifyToken — closes previously unauthenticated /summary and /stats | 04-01 DASH |
| 2026-03-21 | All dashboard queries scoped to req.user.tenant_id — fixes multi-tenant data leak in getDashboardSummary and getQuickStats | 04-01 DASH |
| 2026-03-21 | getChartData uses HOUR(scheduled_time_start) grouped by hour excluding cancelled for bar chart API | 04-01 DASH-01 |
| 2026-03-21 | Chart data fetch non-fatal in _loadDashboard() — chart stays empty if endpoint unavailable, never blocks dashboard load | 04-02 DASH-01 |
| 2026-03-21 | Weekend filter state in JobProvider so it persists across navigation and is accessible from any screen watching JobProvider | 04-02 DASH-02 |
| 2026-03-21 | FCM_SERVICE_ACCOUNT_PATH not in startup guard — Firebase optional for dev, server starts without it | 05-01 NOTIF |
| 2026-03-21 | No retry on FCM/email failures — log warn and move on, in-app record inserted first for audit trail | 05-01 NOTIF |
| 2026-03-21 | Notification dedup via 20-min NOT EXISTS subquery on notifications table — prevents storms | 05-01 NOTIF |
| 2026-03-21 | Kotlin DSL google-services registration in settings.gradle.kts plugins{} block — correct AGP 8.x pattern | 05-02 FCM |
| 2026-03-21 | FCM topic naming: driver_{userId} for technician/driver, scheduler_{userId} for admin/scheduler | 05-02 FCM |
| 2026-03-21 | compileSdk=35, Java 17, coreLibraryDesugaring required by firebase_messaging | 05-02 FCM |
| 2026-03-21 | Future.microtask pattern used in initState for async provider calls — standard Flutter pattern for post-frame async work | 05-03 NOTIF |
| 2026-03-21 | PATCH method added to ApiService — required for markRead/markAllRead API calls, missing method was a blocking gap | 05-03 NOTIF |
| 2026-03-21 | NotificationBell placed first in AppBar actions — most accessible position for primary notification UX | 05-03 NOTIF |
| 2026-03-21 | FOR UPDATE one-active-request guard in createRequest — prevents double-booking race on concurrent extension requests | 06-01 TIME |
| 2026-03-21 | analyzeImpact covers both driver (job_technicians) and vehicle (job_assignments) overlap — full conflict detection | 06-01 TIME |
| 2026-03-21 | Notifications sent after transaction commit in approveRequest — same pattern as all other services, audit never blocks commit | 06-01 TIME |
| 2026-03-21 | Add More Time button gated to isAssigned AND in_progress — not role-based, matches TIME-01 spec exactly | 06-02 TIME |
| 2026-03-21 | TimeExtensionProvider.clearState() public — future scheduler approval screen can reset between jobs | 06-02 TIME |
| 2026-03-21 | GlobalKey<NavigatorState> on FcmService.navigatorKey wired to MaterialApp — enables FCM to push routes without BuildContext (cold-start + background tap) | 06-03 TIME |
| 2026-03-21 | time_extension_approved/denied navigates popUntil(root) — JobDetailScreen requires a full Job object, navigating to jobs list is safer than partial navigation | 06-03 TIME |
| 2026-03-22 | Socket.IO JWT auth in handshake headers — consistent with REST auth pattern, no separate auth flow needed | 07-01 GPS |
| 2026-03-22 | In-memory Map for GPS cache keyed by driverId, evicts stale >5 min on read, preserves live positions after flush | 07-01 GPS |
| 2026-03-22 | gps_consent UNIQUE KEY on user_id — ON DUPLICATE KEY UPDATE for idempotent upsert | 07-01 GPS |
| 2026-03-22 | PolylinePoints.decodePolyline() called statically — v3.x requires apiKey for network methods but decode is static, no key needed | 07-02 GPS |
| 2026-03-22 | Backend proxies Google Routes API — GOOGLE_MAPS_API_KEY stays server-side, never sent to Flutter client | 07-02 GPS |
| 2026-03-22 | GpsService uses static methods — matches existing Flutter service pattern (notification_service, user_service) | 07-02 GPS |
| 2026-03-22 | maybePop() in GpsConsentScreen — AuthGate re-renders with consentGranted=true after pop, no named routes needed | 07-03 GPS |
| 2026-03-22 | GPS consent gate only applies to isTechnician role — admin/scheduler bypass entirely | 07-03 GPS |
| 2026-03-22 | Timer.periodic starts only when _gpsEnabled=true and timer not already running — prevents duplicate timers | 07-03 GPS |
| 2026-03-22 | Decline flow: grantConsent() then toggleGps(false) — POPIA audit record created while tracking disabled | 07-03 GPS |
| 2026-03-22 | Stale markers (>5 min) silently filtered in LiveTrackingScreen — avoids clutter from offline drivers | 07-04 GPS |
| 2026-03-22 | Camera bounds fitted once on first load only — subsequent polls preserve user's manual camera position | 07-04 GPS |
| 2026-03-22 | JWT_SECRET set at line 1 of every test file before any require — server.js process.exit(1) guard fires before module load | 08-01 TEST |
| 2026-03-22 | Jest 30.x renamed --testPathPattern to --testPathPatterns (plural) — breaking change from Jest 29.x | 08-01 TEST |
| 2026-03-22 | vehicles.js createVehicleValidation used body('name') but handler reads vehicle_name — bug fixed in route validator | 08-01 TEST |
| 2026-03-22 | apiRequestContext pattern used instead of browser UI — Flutter renders to canvas, DOM selectors won't work | 08-03 E2E |
| 2026-03-22 | Acceptable status codes include 400/404 for routes where test DB may lack seeded data — proves route and auth wiring | 08-03 E2E |

## Performance Metrics

| Phase | Plan | Duration (min) | Tasks | Files |
|-------|------|----------------|-------|-------|
| 01 | 01 | 8 | 3/3 | 3 |
| 01 | 02 | 9 | 2/2 | 2 |
| 01 | 03 | 3 | 3/3 | 8 |
| 01 | 04 | 18 | 3/3 | 10 |
| 01 | 05 | 18 | 2/2 | 16 |
| 02 | 01 | 20 | 2/2 | 9 |
| 02 | 02 | 7 | 2/2 | 5 |
| 02 | 03 | 10 | 2/2 | 9 |
| Phase 02 P03 | 10 | 2 tasks | 9 files |
| Phase 03 P01 | 4 | 2 tasks | 4 files |
| Phase 03 P02 | 5 | 2 tasks | 5 files |
| Phase 03 P03 | 30 | 2 tasks | 6 files |
| Phase 04 P01 | 8 | 2 tasks | 4 files |
| Phase 04 P02 | 12 | 2 tasks | 3 files |
| Phase 04 P03 | 3 | 1 tasks | 2 files |
| Phase 05 P01 | 6 | 2 tasks | 9 files |
| Phase 05 P02 | 7 | 3 tasks | 8 files |
| Phase 05 P03 | 8 | 2 tasks | 9 files |
| Phase 06 P01 | 4 | 2 tasks | 4 files |
| Phase 06 P02 | 4 | 2 tasks | 6 files |
| Phase 06 P03 | 4 | 2 tasks | 3 files |
| Phase 07 P01 | 8 | 2 tasks | 6 files |
| Phase 07 P02 | 15 | 2 tasks | 7 files |
| Phase 07 P03 | 21 | 2 tasks | 4 files |
| Phase 07 P04 | 4 | 2 tasks | 3 files |
| Phase 08 P01 | 5 | 2 tasks | 18 files |
| Phase 08 P03 | 14 | 2 tasks | 7 files |
| Phase 08 P02 | 15 | 2 tasks | 6 files |
| Phase 09 P01 | 14 | 2 tasks | 3 files |

## Session

**Last session:** 2026-03-22T11:13:32.828Z
**Stopped at:** Completed 09-01-PLAN.md

---
*Last updated: 2026-03-21 after 01-01 execution*
