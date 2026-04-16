# Requirements: FleetScheduler Pro

**Defined:** 2026-03-21
**Core Value:** Schedulers can efficiently assign, monitor, and adjust jobs in real-time so no job falls through the cracks.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Foundation & Security (FOUND)

- [x] **FOUND-01**: Add `tenant_id` column to all tables for multi-tenant isolation
- [x] **FOUND-02**: Fix race condition in job assignment — wrap availability check + insert in `SELECT ... FOR UPDATE` transaction
- [x] **FOUND-03**: Fix job number generation race condition — use atomic sequence table
- [x] **FOUND-04**: Remove hardcoded JWT secret fallback — enforce env variable
- [x] **FOUND-05**: Add `helmet` and `express-rate-limit` middleware to server
- [x] **FOUND-06**: Add input validation middleware (express-validator) on all routes
- [x] **FOUND-07**: Set `TZ=UTC` in Docker and add `tenant_timezone` field
- [x] **FOUND-08**: Fix `GROUP_CONCAT` truncation — set `group_concat_max_len=65536` per connection
- [x] **FOUND-09**: Add database indexes on `scheduled_date`, `current_status`, `tenant_id`
- [x] **FOUND-10**: Replace `console.log` with structured logging (pino)

### Notifications & Alerts (NOTIF)

- [x] **NOTIF-01**: Push notifications via Firebase Cloud Messaging (FCM v1 HTTP API with firebase-admin SDK)
- [x] **NOTIF-02**: Notification when job is about to start (configurable lead time)
- [x] **NOTIF-03**: Notification when job is overdue (past scheduled end, not completed)
- [x] **NOTIF-04**: Email notifications via nodemailer (togglable per user in settings)
- [x] **NOTIF-05**: In-app notification center with read/unread status and history
- [x] **NOTIF-06**: FCM topic-based subscriptions per user (`driver_{userId}`, `scheduler_{userId}`)
- [x] **NOTIF-07**: Background cron job (node-cron) for checking overdue jobs and upcoming starts

### Time Management (TIME)

- [x] **TIME-01**: "Add more time" button visible on in-progress jobs for driver/technician
- [x] **TIME-02**: Required reason field when requesting time extension
- [x] **TIME-03**: Impact analysis — system calculates which subsequent jobs/drivers are affected
- [x] **TIME-04**: System generates 2-3 rescheduling suggestions for affected jobs
- [x] **TIME-05**: Scheduler receives notification of time extension request
- [x] **TIME-06**: Scheduler approves/denies extension with one of the suggested options or custom
- [x] **TIME-07**: All affected parties notified of schedule changes after approval

### Job Assignment & Load Balancing (ASGN)

- [x] **ASGN-01**: Show total historical job count next to each driver name during assignment
- [x] **ASGN-02**: Green glow/highlight on drivers with fewer jobs (visual load indicator)
- [x] **ASGN-03**: "Suggested" chip on lowest-load available driver
- [x] **ASGN-04**: Enforce one driver per vehicle, allow multiple technicians per job
- [x] **ASGN-05**: Assignment history table for audit trail (`assignment_history`)

### Job Status Automation (STAT)

- [x] **STAT-01**: Jobs auto-transition to "in progress" when scheduled start time arrives (cron-based)
- [x] **STAT-02**: "Complete" button only available to assigned driver or technician
- [x] **STAT-03**: GPS coordinates captured automatically when "complete job" is tapped
- [x] **STAT-04**: Completion location stored in `job_completions` table with timestamp

### Vehicle Maintenance (MAINT)

- [x] **MAINT-01**: "Schedule Maintenance" button on vehicle detail screen
- [x] **MAINT-02**: Maintenance scheduling with date range and description
- [x] **MAINT-03**: Vehicles in maintenance excluded from job assignment picker on those dates
- [x] **MAINT-04**: Maintenance history log per vehicle
- [x] **MAINT-05**: Visual indicator on vehicle list for vehicles currently in maintenance

### Scheduler Role & Permissions (SCHED)

- [x] **SCHED-01**: Scheduler role with same permissions as admin EXCEPT cannot add/remove vehicles or users
- [x] **SCHED-02**: Scheduler can swap vehicles on existing jobs
- [x] **SCHED-03**: Permission matrix enforced on both backend API and Flutter UI
- [x] **SCHED-04**: Admin can toggle whether scheduler sees live GPS (visibility control)

### Dashboard & Views (DASH)

- [x] **DASH-01**: "Jobs Today" card on dashboard shows scheduler preview (reference existing graphs page)
- [x] **DASH-02**: Weekend jobs view — button to filter/show weekend-scheduled jobs
- [x] **DASH-03**: Weekday view toggle — switch between drivers-assigned view and clients view
- [x] **DASH-04**: Job count badges on dashboard cards

### GPS & Maps (GPS)

- [x] **GPS-01**: Directions + estimated travel time displayed when creating/viewing a job (Google Directions API)
- [x] **GPS-02**: Live driver tracking — drivers POST location every 15-30 seconds via HTTP
- [x] **GPS-03**: Real-time driver positions on map for admin/scheduler (Socket.IO broadcast)
- [x] **GPS-04**: Admin toggle to control scheduler GPS visibility
- [ ] **GPS-05**: Location snapshot on job completion (audit trail)
- [x] **GPS-06**: GPS consent screen on driver app (POPIA/GDPR compliance)
- [x] **GPS-07**: Time-bounded tracking — only during working hours / active jobs
- [x] **GPS-08**: Two-tier GPS storage — in-memory/Redis for live, periodic MySQL flush for history

### User Management (USR)

- [x] **USR-01**: Contact number field on user creation form
- [x] **USR-02**: Contact number displayed on user profile/detail view
- [x] **USR-03**: Contact number field on edit user form

### Testing & Quality (TEST)

- [x] **TEST-01**: API endpoint tests for all backend routes (Jest + Supertest)
- [x] **TEST-02**: UI/E2E tests with Playwright (dispatcher and driver journeys)
- [x] **TEST-03**: Regression test suite (conflict detection, timezone, permissions)
- [x] **TEST-04**: Permission matrix regression tests (role-based access verification)
- [x] **TEST-05**: Load testing with 20+ concurrent users

### Documentation (DOC)

- [x] **DOC-01**: User manual — admin guide
- [x] **DOC-02**: User manual — scheduler guide
- [x] **DOC-03**: User manual — driver/technician guide
- [x] **DOC-04**: API documentation (Swagger, already partially exists)
- [x] **DOC-05**: Deployment guide (Docker setup, environment variables)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Scheduling

- **SCHED-V2-01**: Geographic proximity scoring (Haversine distance) for smart assignment
- **SCHED-V2-02**: VRP optimization via Google OR-Tools for route planning
- **SCHED-V2-03**: Recurring job templates (weekly/monthly schedules)
- **SCHED-V2-04**: Gantt/timeline view for scheduler dashboard

### Multi-Tenant SaaS

- **TENANT-01**: Tenant onboarding flow (signup, setup wizard)
- **TENANT-02**: Custom branding per tenant (logo, colors)
- **TENANT-03**: Tenant-scoped billing and usage tracking
- **TENANT-04**: Data residency options (region-specific database)

### Advanced Features

- **ADV-01**: Offline mode for driver app (sync when back online)
- **ADV-02**: Photo capture on job completion
- **ADV-03**: Customer signature capture
- **ADV-04**: Inventory/parts tracking per job
- **ADV-05**: Customer-facing booking portal

## Out of Scope

| Feature | Reason |
|---------|--------|
| Real-time chat | High complexity, not core to scheduling value |
| Video posts/calls | Storage/bandwidth costs, separate concern |
| OAuth/social login | Email/password sufficient for v1 enterprise |
| Payment processing | Not needed for field service operations |
| App store deployment | Focus on functionality first |
| AI-powered scheduling | Constraint-based is sufficient for v1; AI is v3 |
| Database-per-tenant isolation | Shared-schema with tenant_id is correct for this stage |
| OpenStreetMap alternative | Google Maps already integrated, stay consistent |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| FOUND-01 to FOUND-10 | Phase 1 | Pending |
| USR-01 to USR-03 | Phase 2 | Pending |
| MAINT-01 to MAINT-05 | Phase 2 | Pending |
| SCHED-01 to SCHED-04 | Phase 2 | Pending |
| ASGN-01 to ASGN-05 | Phase 3 | Pending |
| STAT-01 to STAT-04 | Phase 3 | Pending |
| DASH-01 to DASH-04 | Phase 4 | Pending |
| NOTIF-01 to NOTIF-07 | Phase 5 | Pending |
| TIME-01 to TIME-07 | Phase 6 | Pending |
| GPS-01 to GPS-08 | Phase 7 | Pending |
| TEST-01 to TEST-05 | Phase 8 | Pending |
| DOC-01 to DOC-05 | Phase 9 | Pending |

**Coverage:**
- v1 requirements: 62 total
- Mapped to phases: 62
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-21*
*Last updated: 2026-03-21 after research synthesis*
