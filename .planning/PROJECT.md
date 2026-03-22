# FleetScheduler Pro — Vehicle Scheduling System

## What This Is

A multi-tenant vehicle scheduling and fleet management SaaS for service companies. Admins and schedulers assign jobs to drivers and technicians, track vehicles, manage maintenance schedules, and monitor field operations in real-time via GPS. Features smart job assignment with load balancing, automated time extension workflows, FCM push + email notifications, live driver tracking via Socket.IO, and POPIA/GDPR-compliant GPS consent. Docker-first deployment to any Linux server.

## Core Value

Schedulers can efficiently assign, monitor, and adjust jobs in real-time — with smart rescheduling, live GPS tracking, and automated notifications — so no job falls through the cracks.

## Requirements

### Validated

- ✓ **AUTH-01**: JWT-based authentication with role-based access — v1.0
- ✓ **JOB-01**: CRUD operations for jobs with assignment — v1.0
- ✓ **VEH-01**: CRUD operations for vehicles — v1.0
- ✓ **USR-01**: User management — v1.0
- ✓ **JOB-02**: Admin can hotswap drivers — v1.0
- ✓ **JOB-03**: Job status tracking — v1.0
- ✓ **MAP-01**: Google Maps integration on job creation — v1.0
- ✓ **DASH-01**: Basic dashboard with job statistics — v1.0
- ✓ **FOUND-01–10**: Foundation & security hardening (multi-tenant, rate limiting, validation, logging) — v1.0
- ✓ **USR-02/03**: Contact number field on user forms — v1.0
- ✓ **MAINT-01–05**: Vehicle maintenance scheduling and history — v1.0
- ✓ **SCHED-01–04**: Scheduler role with restricted permissions — v1.0
- ✓ **ASGN-01–05**: Smart job assignment with load balancing — v1.0
- ✓ **STAT-01–04**: Job status automation with GPS completion capture — v1.0
- ✓ **DASH-01–04**: Enhanced dashboard with weekend view and toggles — v1.0
- ✓ **NOTIF-01–07**: Push + email + in-app notifications — v1.0
- ✓ **TIME-01–07**: Time extension workflow with impact analysis — v1.0
- ✓ **GPS-01–08**: Directions, live tracking, consent, working hours — v1.0
- ✓ **TEST-01–05**: API tests, E2E, regression, permission matrix, load testing — v1.0
- ✓ **DOC-01–05**: User manuals, Swagger API docs, deployment guide — v1.0

### Active

(None — all v1.0 requirements shipped. Define in next milestone.)

### Out of Scope

- Payment processing / billing — not needed for v1 operations
- Chat / messaging between users — use existing communication tools
- Inventory management — separate concern from scheduling
- Customer-facing portal — v1 is internal operations only
- iOS/Android app store deployment — focus on functionality first
- Offline mode — real-time is core value

## Context

**Shipped:** v1.0 MVP on 2026-03-22
**Codebase:** ~55,000 LOC across backend (16,500 JS), frontend (21,200 Dart), and tests (17,700 JS)
**Tech stack:** Node.js/Express 5.x + Flutter + MySQL + Socket.IO + Firebase Cloud Messaging
**Deployment:** Docker Compose (MySQL 8.0 + Node.js API), Swagger at /swagger
**Test coverage:** 194+ automated tests (112 API, 82 regression/permission, 20 E2E specs) + Artillery load config

**Known tech debt (from milestone audit):**
- `schedulerOrAbove` middleware excludes dispatcher JWT role — affects scheduler report access
- No immediate FCM push on job assignment (drivers notified via 15-min cron only)
- Artillery not installed due to disk space (npm install required)
- E2E scheduler spec has wrong HTTP method for time extension endpoints

## Constraints

- **Tech Stack**: Node.js/Express backend + Flutter frontend + MySQL — existing, non-negotiable
- **Deployment**: Docker-first, deployable to any Linux server
- **Maps**: Google Maps API (API key added by user manually)
- **Push Notifications**: Firebase Cloud Messaging
- **Architecture**: Keep sellable — clean separation, multi-tenant ready

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Push + Email notifications | Cover both real-time alerts and async communication | ✓ Good — FCM + nodemailer with graceful degradation |
| Firebase Cloud Messaging for push | Standard for Flutter, cross-platform | ✓ Good — topic-based subscriptions work well |
| Smart rescheduling (suggest options) | Scheduler keeps control but system does heavy lifting | ✓ Good — 2-3 suggestions generated per extension |
| Admin controls GPS visibility | Privacy/trust — admin can limit scheduler's GPS access | ✓ Good — settings toggle enforced on backend |
| Docker-first deployment | Cloud-agnostic, consistent environments | ✓ Good — docker-compose.yml ships with project |
| Sellable from day 1 | Architecture must support multi-tenant adaptation | ✓ Good — tenant_id on all tables, JWT-scoped |
| In-memory GPS cache over Redis | Simpler v1 — Redis planned for v2 scaling | ✓ Good — Map + 5-min cron flush works for single-server |
| Playwright API tests over browser | Flutter renders to canvas, DOM interaction impossible | ✓ Good — apiRequestContext covers all journeys |
| Socket.IO for live tracking | Real-time broadcast with JWT tenant rooms | ✓ Good — working, future upgrade to dedicated service |

---
*Last updated: 2026-03-22 after v1.0 milestone*
