# Roadmap: FleetScheduler Pro v1

**Created:** 2026-03-21
**Core Value:** Schedulers can efficiently assign, monitor, and adjust jobs in real-time so no job falls through the cracks.
**Milestone:** v1.0 — Production-ready sellable product

## Phase Overview

| Phase | Name | Requirements | Risk | Dependencies |
|-------|------|-------------|------|--------------|
| 1 | Foundation & Security Hardening | 5/5 | Complete    | 2026-03-21 |
| 2 | User, Vehicle & Scheduler Enhancements | 3/3 | Complete   | 2026-03-21 |
| 3 | Job Assignment & Status Automation | 3/3 | Complete   | 2026-03-21 |
| 4 | Dashboard & Views | DASH-01–04 | LOW | Phase 2 (scheduler role), Phase 3 (job counts) |
| 5 | Notifications & Alerts | NOTIF-01–07 | MEDIUM | Phase 1 (foundation), Phase 3 (status automation) |
| 6 | Time Management | TIME-01–07 | HIGH | Phase 5 (notifications), Phase 3 (assignment) |
| 7 | GPS, Maps & Live Tracking | GPS-01–08 | HIGH | Phase 1 (security), Phase 5 (notifications) |
| 8 | Testing Suite | TEST-01–05 | MEDIUM | All features complete (Phases 1–7) |
| 9 | Documentation & Deployment | DOC-01–05 | LOW | Phase 8 (tests passing) |

## Phase Details

---

### Phase 1: Foundation & Security Hardening

**Goal:** Make the existing codebase production-safe and multi-tenant ready. Every subsequent phase builds on this.

**Why first:** Research identified race conditions, missing security middleware, and no tenant isolation. Shipping features on a broken foundation compounds technical debt.

**Requirements:** FOUND-01 through FOUND-10

**Key deliverables:**
- `tenant_id` column added to all existing tables + migration script
- `SELECT ... FOR UPDATE` on job assignment to prevent double-booking
- Atomic job number generation (sequence table)
- JWT hardening — remove fallback secret, add token expiry validation
- `helmet`, `express-rate-limit`, `express-validator` middleware
- `TZ=UTC` in Dockerfile, `tenant_timezone` column
- `GROUP_CONCAT` max length fix
- Database indexes on key query columns
- Structured logging with pino

**Success criteria:**
- [ ] All tables have `tenant_id` column with NOT NULL constraint
- [ ] Concurrent job assignment test shows no double-booking
- [ ] Security middleware active on all routes
- [ ] All existing functionality still works (regression check)

**Plans:** 5/5 plans complete

Plans:
- [x] 01-01-PLAN.md — Database migration: tenant_id, sequence table, UTC timezone, GROUP_CONCAT fix, composite indexes
- [x] 01-02-PLAN.md — Race condition fixes: SELECT...FOR UPDATE in job assignment, atomic job number sequence
- [x] 01-03-PLAN.md — Security middleware: JWT startup guard, helmet, rate limiting, express-validator on all routes
- [x] 01-04-PLAN.md — Structured logging: pino logger replacing all console.log, Jest test scaffold
- [x] 01-05-PLAN.md — Gap closure: remove JWT fallback from authController.js, add tenant_id to JWT payload, sweep remaining console.* across src/

---

### Phase 2: User, Vehicle & Scheduler Enhancements

**Goal:** Add contact numbers to users, vehicle maintenance scheduling, and the scheduler role with correct permissions.

**Why this order:** These are low-risk, high-value features that extend existing CRUD. Scheduler role must exist before building scheduler-specific views (Phase 4).

**Requirements:** USR-01–03, MAINT-01–05, SCHED-01–04

**Key deliverables:**
- Contact number field on user CRUD (backend + Flutter)
- Vehicle maintenance table + scheduling UI
- Maintenance date-range blocking on vehicle assignment picker
- Scheduler role in permission matrix (backend middleware + Flutter UI)
- Admin toggle for scheduler GPS visibility (config stored in DB)

**Success criteria:**
- [ ] Contact number visible on user create/edit/view screens
- [ ] Vehicle in maintenance cannot be assigned to jobs on those dates
- [ ] Scheduler can do everything admin can EXCEPT add/remove vehicles and users
- [ ] Scheduler can swap vehicles on jobs

**Plans:** 3/3 plans complete

Plans:
- [x] 02-01-PLAN.md — Backend schema migration + all new/extended API routes (contacts, maintenance CRUD, settings, swap-vehicle)
- [x] 02-02-PLAN.md — Flutter user screens: contact phone fields, tap-to-call, permission-based UI gating
- [x] 02-03-PLAN.md — Flutter vehicle screens: maintenance UI, maintenance badge, admin settings toggle, permission gating

---

### Phase 3: Job Assignment & Status Automation

**Goal:** Smart job assignment with load balancing visuals and automatic job status transitions.

**Why this order:** Load balancing and status automation are core scheduling features. Must be in place before building dashboard views (Phase 4) and notifications (Phase 5).

**Requirements:** ASGN-01–05, STAT-01–04

**Key deliverables:**
- Driver job count query (historical total + today's count)
- Visual load indicator on assignment picker (green glow on low-load drivers)
- "Suggested" chip on recommended driver
- One-driver-per-vehicle enforcement with multi-technician support
- Assignment history table for audit trail
- Cron job for auto-transitioning jobs to "in progress" at scheduled time
- "Complete" button restricted to assigned driver/technician
- GPS capture on job completion (coordinates + timestamp)
- `job_completions` table

**Success criteria:**
- [ ] Assignment picker shows job count and visual load indicators
- [ ] Jobs automatically become "in progress" at scheduled start time
- [ ] Only assigned personnel can mark jobs complete
- [ ] Completion records include GPS coordinates

**Plans:** 3/3 plans complete

Plans:
- [x] 03-01-PLAN.md — DB migration (assignment_history, job_completions, nullable changed_by) + driver load stats endpoint + assignment history logging
- [x] 03-02-PLAN.md — Cron auto-transition service + job completion endpoint with personnel auth and GPS storage
- [x] 03-03-PLAN.md — Flutter UI: driver load picker with green glow/suggested chip, technician chips, completion flow with GPS capture

---

### Phase 4: Dashboard & Views

**Goal:** Enhanced dashboard with scheduler preview, weekend view, and driver/client toggles.

**Requirements:** DASH-01–04

**Key deliverables:**
- "Jobs Today" dashboard card with scheduler graph preview
- Weekend jobs filter/view button
- Weekday toggle: drivers-assigned view vs clients view
- Job count badges on dashboard cards

**Success criteria:**
- [ ] Dashboard "Jobs Today" shows inline scheduler preview
- [ ] Weekend jobs view shows Saturday/Sunday jobs
- [ ] Toggle switches between driver and client views on weekday schedule
- [ ] Badge counts are accurate and update in real-time

**Plans:** 2 plans

Plans:
- [ ] 04-01-PLAN.md -- Backend chart-data endpoint, dashboard route security fixes (verifyToken + tenant_id), fl_chart dependency� Backend chart-data endpoint, dashboard route security fixes (verifyToken + tenant_id), fl_chart dependency
- [ ] 04-02-PLAN.md -- Flutter UI: bar chart card, badge overlays, drivers/clients toggle, weekend filter� Flutter UI: bar chart card, badge overlays, drivers/clients toggle, weekend filter

---

### Phase 5: Notifications & Alerts

**Goal:** Push + email notification system for job lifecycle events.

**Why this order:** Notifications depend on job status automation (Phase 3) for triggers. Must be in place before time management (Phase 6) which sends notifications.

**Requirements:** NOTIF-01–07

**Key deliverables:**
- Firebase Cloud Messaging integration (firebase-admin SDK, HTTP v1 API)
- FCM topic subscriptions per user on login
- `flutter_local_notifications` + `firebase_messaging` in Flutter app
- In-app notification center (bell icon, read/unread, history)
- Email notification system (nodemailer) with per-user toggle
- Background cron: check upcoming jobs (notify X minutes before) and overdue jobs
- `notifications` and `notification_preferences` tables

**Success criteria:**
- [ ] Push notification received when job starts in 15 minutes
- [ ] Push notification received when job is overdue
- [ ] Email toggle works — can enable/disable per user
- [ ] In-app notification center shows history with read/unread
- [ ] Notifications respect tenant isolation

**Estimated plans:** 3

---

### Phase 6: Time Management

**Goal:** Time extension workflow — technicians request more time, system shows impact, scheduler approves.

**Why this order:** This is the highest-complexity feature and a key differentiator. Requires notifications (Phase 5) for the request/approval flow.

**Requirements:** TIME-01–07

**Key deliverables:**
- "Add More Time" button on in-progress job screen (driver/technician view)
- Time extension request form with required reason field
- Impact analysis engine — calculates affected subsequent jobs
- Rescheduling suggestion algorithm (generates 2–3 options)
- Scheduler notification + approval screen
- Affected party notifications after approval
- `time_extension_requests` and `reschedule_options` tables

**Success criteria:**
- [ ] Technician can request time extension with reason
- [ ] System correctly identifies all affected jobs/drivers
- [ ] System generates valid rescheduling options
- [ ] Scheduler can approve/deny with one tap
- [ ] All affected parties notified of changes

**Estimated plans:** 3–4

---

### Phase 7: GPS, Maps & Live Tracking

**Goal:** Full maps integration with directions, live tracking, and compliance.

**Why this order:** GPS is infrastructure-heavy (Socket.IO, Redis, Google APIs). Features above it must be stable first.

**Requirements:** GPS-01–08

**Key deliverables:**
- Google Directions API integration — show route, distance, ETA on job view
- Driver location service — POST every 15–30 seconds via HTTP during active jobs
- Socket.IO server integration for real-time position broadcasting
- Redis (or in-memory Map) for live position cache
- Periodic MySQL flush for GPS history/audit trail
- Admin/scheduler map view showing live driver positions
- Admin toggle to hide GPS from scheduler
- GPS consent screen in Flutter app (POPIA/GDPR)
- Time-bounded tracking (active jobs / working hours only)
- `driver_positions` and `gps_history` tables

**Success criteria:**
- [ ] Job creation/view shows directions and estimated travel time
- [ ] Admin can see live driver positions on map
- [ ] GPS tracking only active during working hours / active jobs
- [ ] Consent screen shown before tracking begins
- [ ] Admin can toggle scheduler's GPS visibility

**Estimated plans:** 4–5

---

### Phase 8: Testing Suite

**Goal:** Comprehensive test coverage — API, E2E, regression, and load tests.

**Requirements:** TEST-01–05

**Key deliverables:**
- Jest + Supertest API tests for all backend routes
- Playwright E2E tests for key user journeys (dispatcher, driver, scheduler)
- Regression suite: conflict detection, timezone handling, permissions matrix
- Load test with 20+ concurrent users (k6 or artillery)
- CI-ready test scripts in package.json

**Success criteria:**
- [ ] All API endpoints have at least one happy-path and one error test
- [ ] E2E tests cover: login, create job, assign job, complete job, time extension
- [ ] Regression tests catch known edge cases
- [ ] System handles 20+ concurrent users without errors
- [ ] All tests pass in CI

**Estimated plans:** 3

---

### Phase 9: Documentation & Deployment

**Goal:** User manuals, API docs, and production deployment guide.

**Requirements:** DOC-01–05

**Key deliverables:**
- Admin user manual (HTML/PDF)
- Scheduler user manual
- Driver/technician user manual
- Swagger API documentation (update existing)
- Docker deployment guide with docker-compose
- Environment variable reference

**Success criteria:**
- [ ] Each role has a complete user guide
- [ ] API documentation covers all endpoints with examples
- [ ] New deployment can be stood up following the guide alone
- [ ] Documentation reviewed for accuracy

**Plans:** 2 plans

Plans:
- [ ] 04-01-PLAN.md -- Backend chart-data endpoint, dashboard route security fixes (verifyToken + tenant_id), fl_chart dependency� Backend chart-data endpoint, dashboard route security fixes (verifyToken + tenant_id), fl_chart dependency
- [ ] 04-02-PLAN.md -- Flutter UI: bar chart card, badge overlays, drivers/clients toggle, weekend filter� Flutter UI: bar chart card, badge overlays, drivers/clients toggle, weekend filter

---

## Dependency Graph

```
Phase 1 (Foundation)
  ├── Phase 2 (User/Vehicle/Scheduler) ──── Phase 4 (Dashboard)
  ├── Phase 3 (Assignment/Status) ─────┬── Phase 4 (Dashboard)
  │                                     └── Phase 5 (Notifications)
  │                                              └── Phase 6 (Time Mgmt)
  └── Phase 7 (GPS/Maps) ←── Phase 1 + Phase 5

Phase 8 (Testing) ←── Phases 1–7
Phase 9 (Docs) ←── Phase 8
```

## Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| Multi-tenant migration breaks existing data | HIGH | Run migration on test DB first, backup before prod |
| Google Maps API costs escalate with live tracking | HIGH | Implement rate limiting, cache directions, monitor billing |
| FCM push reliability on Android 13+ | MEDIUM | Fallback to in-app polling, test on real devices |
| Time extension rescheduling complexity | HIGH | Start with simple shift-forward algorithm, iterate |
| GPS battery drain on driver phones | MEDIUM | Adaptive polling frequency, only track during active jobs |
| POPIA/GDPR compliance for GPS data | HIGH | Legal review before GPS launch, consent flow mandatory |

---
*Roadmap created: 2026-03-21*
*Last updated: 2026-03-21 after research synthesis*
*Phase 1 plans created: 2026-03-21*
*Phase 1 gap closure plan added: 2026-03-21*
*Phase 2 plans created: 2026-03-21*
*Phase 3 plans created: 2026-03-21*
*Phase 4 plans created: 2026-03-21*
