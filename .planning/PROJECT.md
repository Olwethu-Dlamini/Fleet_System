# FleetScheduler Pro — Vehicle Scheduling System

## What This Is

A multi-tenant vehicle scheduling and fleet management platform for service companies. Admins and schedulers assign jobs to drivers and technicians, track vehicles, manage maintenance schedules, and monitor field operations in real-time via GPS. Built as a sellable SaaS product with Docker-first deployment to any Linux server.

## Core Value

Schedulers can efficiently assign, monitor, and adjust jobs in real-time — with smart rescheduling, live GPS tracking, and automated notifications — so no job falls through the cracks.

## Requirements

### Validated

<!-- Shipped and confirmed valuable — inferred from existing codebase. -->

- [x] **AUTH-01**: JWT-based authentication with role-based access (admin, scheduler, driver, technician)
- [x] **JOB-01**: CRUD operations for jobs with assignment to drivers/technicians
- [x] **VEH-01**: CRUD operations for vehicles
- [x] **USR-01**: User management (create, edit, delete users)
- [x] **JOB-02**: Admin can hotswap drivers on jobs
- [x] **JOB-03**: Job status tracking (pending, in-progress, completed, cancelled)
- [x] **MAP-01**: Google Maps integration on job creation (location picker)
- [x] **DASH-01**: Basic dashboard with job statistics

### Active

<!-- Current scope. Building toward these. -->

**Notifications & Alerts**
- [ ] **NOTIF-01**: Push notifications when a job is about to start
- [ ] **NOTIF-02**: Push notifications when a job is overdue (should be complete but isn't)
- [ ] **NOTIF-03**: Email notifications (togglable per user preference)
- [ ] **NOTIF-04**: In-app notification center with history

**Time Management**
- [ ] **TIME-01**: "Add more time" button on in-progress jobs (technician-facing)
- [ ] **TIME-02**: Reason field required when requesting additional time
- [ ] **TIME-03**: System shows impact of time extension on other jobs/drivers
- [ ] **TIME-04**: System suggests 2-3 rescheduling options for affected jobs
- [ ] **TIME-05**: Scheduler has final approval on time extensions and rescheduling

**Job Assignment & Load Balancing**
- [ ] **ASGN-01**: Driver job count displayed next to name during assignment
- [ ] **ASGN-02**: Green glow/highlight on drivers with fewer jobs (visual load balancing)
- [ ] **ASGN-03**: One driver per vehicle, multiple technicians per job
- [ ] **ASGN-04**: Historical job count (total jobs ever done) visible during assignment

**Job Status Automation**
- [ ] **STAT-01**: Jobs auto-update to "in progress" when scheduled start time arrives
- [ ] **STAT-02**: "Complete" status requires manual confirmation by driver or technician only
- [ ] **STAT-03**: Geo-capture of location when "complete job" is tapped

**Vehicle Maintenance**
- [ ] **MAINT-01**: Vehicle maintenance scheduling button
- [ ] **MAINT-02**: Vehicles under maintenance are excluded from job assignment on those days
- [ ] **MAINT-03**: Maintenance history log per vehicle

**Scheduler Role & Dashboard**
- [ ] **SCHED-01**: Scheduler role has same permissions as admin EXCEPT cannot add/remove vehicles or drivers
- [ ] **SCHED-02**: Scheduler can swap vehicles on jobs
- [ ] **SCHED-03**: Dashboard "jobs today" shows scheduler preview (reference existing scheduler graphs page)
- [ ] **SCHED-04**: Weekend jobs view button on scheduler
- [ ] **SCHED-05**: Weekday view toggle: drivers-assigned vs clients view

**GPS & Maps**
- [ ] **GPS-01**: Directions and estimated travel time shown when creating/viewing a job
- [ ] **GPS-02**: Live driver tracking on map (real-time location during jobs)
- [ ] **GPS-03**: Admin controls visibility — can toggle whether scheduler sees live GPS
- [ ] **GPS-04**: Location snapshot recorded on job completion for audit trail

**User Management**
- [ ] **USR-02**: Contact number field on user creation and profile view

**Testing & Quality**
- [ ] **TEST-01**: API endpoint tests for all backend routes
- [ ] **TEST-02**: UI/integration tests with Playwright
- [ ] **TEST-03**: Regression test suite
- [ ] **TEST-04**: User manual / documentation

### Out of Scope

<!-- Explicit boundaries. Includes reasoning to prevent re-adding. -->

- Multi-tenancy / white-labeling — architecture should support it, but tenant isolation is v2
- Payment processing / billing — not needed for v1 operations
- Chat / messaging between users — out of scope, use existing communication tools
- Inventory management — separate concern from scheduling
- Customer-facing portal — v1 is internal operations only
- iOS/Android app store deployment — focus on functionality first, store submission later

## Context

**Existing codebase:** Brownfield project with working Node.js/Express backend (JWT auth, MySQL, Swagger docs) and Flutter mobile app (Provider state management, Google Maps partial integration). Core CRUD for jobs, vehicles, and users is functional. Admin can hotswap drivers. Database has test data.

**Codebase map:** See `.planning/codebase/` for detailed analysis (STACK.md, ARCHITECTURE.md, STRUCTURE.md, CONVENTIONS.md, TESTING.md, INTEGRATIONS.md, CONCERNS.md).

**Known issues from codebase analysis:** No test coverage, some security concerns (raw SQL in places), no input validation middleware, hardcoded config values, Express 5.x migration incomplete in some routes.

**Target market:** Service companies (HVAC, plumbing, electrical, maintenance) that dispatch technicians in vehicles to job sites.

## Constraints

- **Tech Stack**: Node.js/Express backend + Flutter frontend + MySQL — existing, non-negotiable
- **Deployment**: Docker-first, deployable to any Linux server
- **Timeline**: ASAP — prioritize shipping functional features
- **Maps**: Google Maps API (already integrated partially)
- **Push Notifications**: Firebase Cloud Messaging (Flutter ecosystem standard)
- **Architecture**: Keep sellable — clean separation, no hardcoded company-specific logic
- **Testing**: Comprehensive — API tests, UI tests (Playwright), regression suite, documentation

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Push + Email notifications | Cover both real-time alerts and async communication | — Pending |
| Firebase Cloud Messaging for push | Standard for Flutter, cross-platform | — Pending |
| Smart rescheduling (suggest options) | Scheduler keeps control but system does heavy lifting | — Pending |
| Admin controls GPS visibility | Privacy/trust — admin can limit scheduler's GPS access | — Pending |
| Docker-first deployment | Cloud-agnostic, consistent environments | — Pending |
| Sellable from day 1 | Architecture must support multi-tenant adaptation | — Pending |

---
*Last updated: 2026-03-21 after initial project definition*
