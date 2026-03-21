---
phase: 05-notifications-alerts
plan: 01
subsystem: api
tags: [firebase-admin, fcm, nodemailer, smtp, notifications, cron, mysql]

# Dependency graph
requires:
  - phase: 03-job-assignment-status
    provides: "cronService.js with startCronJobs pattern"
  - phase: 01-foundation
    provides: "JWT auth, tenant_id in req.user, pino logger, db pool"

provides:
  - Firebase Admin SDK singleton with graceful degradation (no env var = no crash)
  - SMTP email service with HTML template and graceful degradation
  - Notification service with FCM topic sends, upcoming/overdue job checks with dedup, 30-day cleanup
  - notifications and notification_preferences DB tables (auto-migrated on startup)
  - REST API at /api/notifications (list, unread-count, mark-read, mark-all-read, preferences GET/PUT)
  - Cron schedules for upcoming job check (1min), overdue check (1min), daily cleanup (3AM)

affects:
  - 05-02-notifications-alerts (Flutter notification UI)
  - 06-time-management (may add notification triggers for time extension events)

# Tech tracking
tech-stack:
  added: [firebase-admin@13.7.0, nodemailer@8.0.3]
  patterns:
    - "Graceful degradation: Firebase/SMTP optional — server starts without them"
    - "FCM lazy-load in notificationService: require('../config/firebase') at call time"
    - "Dedup window: NOT EXISTS subquery checking 20-min window per job+user+type"
    - "Upsert pattern: UPDATE first, INSERT if affectedRows===0 (avoids REPLACE INTO ID reset)"
    - "No retry on FCM or email failure — log warn and move on (per CONTEXT decision)"
    - "Idempotent DB migration via CREATE TABLE IF NOT EXISTS in server.js startup guard"

key-files:
  created:
    - vehicle-scheduling-backend/src/config/firebase.js
    - vehicle-scheduling-backend/src/services/notificationService.js
    - vehicle-scheduling-backend/src/services/emailService.js
    - vehicle-scheduling-backend/src/controllers/notificationController.js
    - vehicle-scheduling-backend/src/routes/notifications.js
  modified:
    - vehicle-scheduling-backend/src/server.js
    - vehicle-scheduling-backend/src/services/cronService.js
    - vehicle-scheduling-backend/src/routes/index.js
    - vehicle-scheduling-backend/package.json

key-decisions:
  - "FCM_SERVICE_ACCOUNT_PATH not added to startup guard — Firebase is optional for dev (unlike JWT_SECRET)"
  - "No retry on FCM/email failures — log warn and move on per CONTEXT decision"
  - "Dedup uses 20-min window (NOT EXISTS subquery) to prevent notification storms"
  - "Lazy-load Firebase in notificationService — modules load without Firebase configured"
  - "SMTP transporter wrapped in try/catch — null if env vars missing, sendJobNotification returns early"
  - "route /read-all placed before /:id/read in router to avoid Express route shadowing"

patterns-established:
  - "Graceful degradation pattern: optional service null-check before use"
  - "In-app notification record inserted before FCM send — ensures audit trail even if FCM fails"
  - "Scheduler/admin notifications deduped independently from driver notifications"

requirements-completed: [NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-04, NOTIF-05, NOTIF-07]

# Metrics
duration: 6min
completed: 2026-03-21
---

# Phase 5 Plan 01: Notifications & Alerts — Backend Infrastructure Summary

**FCM push + SMTP email notification backend with deduped upcoming/overdue job cron checks, in-app notification REST API, and graceful degradation when Firebase or SMTP are not configured**

## Performance

- **Duration:** 6 min
- **Started:** 2026-03-21T17:28:24Z
- **Completed:** 2026-03-21T17:34:44Z
- **Tasks:** 2/2
- **Files modified:** 9

## Accomplishments

- Created full notification infrastructure: Firebase Admin, SMTP email service, and notification service with FCM topic sends and dedup logic
- Added idempotent DB migration for `notifications` and `notification_preferences` tables in server.js startup guard
- Extended cronService with 3 new schedules (upcoming job 15-min lead, overdue job 5-min past end, daily 30-day cleanup) and registered REST API at `/api/notifications`

## Task Commits

Each task was committed atomically:

1. **Task 1: DB migration + Firebase config + notification/email services** - `d351344` (feat)
2. **Task 2: Cron extensions + notification API routes + route registration** - `0a03f8a` (feat)

## Files Created/Modified

- `vehicle-scheduling-backend/src/config/firebase.js` - Firebase Admin SDK singleton with graceful degradation
- `vehicle-scheduling-backend/src/services/emailService.js` - SMTP nodemailer transport with FleetScheduler Pro HTML template
- `vehicle-scheduling-backend/src/services/notificationService.js` - sendTopicNotification, checkUpcomingJobs, checkOverdueJobs, cleanOldNotifications
- `vehicle-scheduling-backend/src/controllers/notificationController.js` - REST handlers for all notification endpoints
- `vehicle-scheduling-backend/src/routes/notifications.js` - Route definitions with verifyToken on all endpoints
- `vehicle-scheduling-backend/src/server.js` - Added notification table migration in startup guard
- `vehicle-scheduling-backend/src/services/cronService.js` - 3 new cron schedules added
- `vehicle-scheduling-backend/src/routes/index.js` - Registered /api/notifications
- `vehicle-scheduling-backend/package.json` - Added firebase-admin and nodemailer

## Decisions Made

- FCM_SERVICE_ACCOUNT_PATH NOT added to server.js startup guard (unlike JWT_SECRET) — Firebase is optional; server starts without it so developers don't need Firebase configured locally
- No retry on FCM or email failures — catch error, log warn, return (per CONTEXT decision)
- Dedup uses 20-minute window (NOT EXISTS subquery on notifications table) — prevents notification storms if cron runs while server was briefly down
- `/read-all` route placed before `/:id/read` in Express router to prevent route shadowing
- Lazy-require Firebase in notificationService at call time — allows module to load without Firebase configured

## Deviations from Plan

None - plan executed exactly as written.

## Known Stubs

None - all notification endpoints are fully implemented with real DB queries.

## User Setup Required

**External services require manual configuration** before push notifications and email work in production:

**Firebase Push Notifications:**
1. Go to Firebase Console (console.firebase.google.com) > Project Settings > Service Accounts
2. Click "Generate New Private Key" — download JSON file
3. Save to `vehicle-scheduling-backend/config/firebase-service-account.json`
4. Add to `.env`: `FCM_SERVICE_ACCOUNT_PATH=./config/firebase-service-account.json`

**SMTP Email Notifications:**
Add to `.env`:
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@email.com
SMTP_PASS=your-app-specific-password
```

**Without configuration:** Server starts normally. FCM sends and emails are skipped with logged warnings. In-app notifications still work.

## Next Phase Readiness

- Backend notification infrastructure is complete and ready for Flutter frontend integration (Phase 5 Plan 02)
- Flutter app needs to: subscribe to FCM topics (`driver_{userId}`, `scheduler_{userId}`), poll `GET /api/notifications/unread-count` for badge, render notification list from `GET /api/notifications`
- No blockers for Phase 5 Plan 02

---
*Phase: 05-notifications-alerts*
*Completed: 2026-03-21*
