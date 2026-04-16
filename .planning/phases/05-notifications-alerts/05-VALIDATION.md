---
phase: 05
slug: notifications-alerts
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 05 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | jest 29.x + supertest (backend), flutter analyze (Flutter) |
| **Config file** | vehicle-scheduling-backend/package.json (jest section) |
| **Quick run command** | `cd vehicle-scheduling-backend && npx jest --passWithNoTests -q` |
| **Full suite command** | `cd vehicle-scheduling-backend && npx jest --passWithNoTests` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run quick command
- **After every plan wave:** Run full suite command
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | Status |
|---------|------|------|-------------|-----------|-------------------|--------|
| 05-01-01 | 01 | 1 | NOTIF-01/02/03/04 | unit | `grep "sendTopicNotification" vehicle-scheduling-backend/src/services/notificationService.js` | ⬜ pending |
| 05-01-02 | 01 | 1 | NOTIF-05/07 | unit | `grep "checkUpcomingJobs" vehicle-scheduling-backend/src/services/cronService.js` | ⬜ pending |
| 05-02-01 | 02 | 2 | NOTIF-01/06 | manual | Flutter FCM integration — device test | ⬜ pending |
| 05-02-02 | 02 | 2 | NOTIF-06 | unit | `grep "subscribeToTopic" vehicle-scheduling-backend/src/server.js` | ⬜ pending |
| 05-03-01 | 03 | 2 | NOTIF-05 | manual | Flutter notification center — bell icon, list, mark read | ⬜ pending |

---

## Wave 0 Requirements

- Existing jest+supertest infrastructure from Phase 1 covers backend verification
- Flutter has no test runner configured — `flutter analyze` is the automated check
- TEST-01 to TEST-05 are deferred to Phase 8

*Existing infrastructure covers phase requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Push notification received on device | NOTIF-01 | Requires physical device + FCM | Login, trigger job, check notification |
| Job starting soon notification | NOTIF-02 | Cron + FCM + device | Schedule job 15min out, wait for notification |
| Overdue job notification | NOTIF-03 | Cron + FCM + device | Let scheduled job pass end time |
| Email toggle works | NOTIF-04 | SMTP + email delivery | Toggle preference, trigger notification, check email |
| Bell icon badge count | NOTIF-05 | UI visual | Create notifications, verify badge updates |
| FCM topic subscription | NOTIF-06 | Device + FCM console | Login, check FCM topic in Firebase console |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
