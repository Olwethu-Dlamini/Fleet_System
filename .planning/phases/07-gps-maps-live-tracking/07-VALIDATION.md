---
phase: 07
slug: gps-maps-live-tracking
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 07 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Jest 30.3.0 (backend), flutter analyze (frontend) |
| **Config file** | none — see package.json scripts |
| **Quick run command** | `cd vehicle-scheduling-backend && npm test -- --testPathPattern=tests/unit/gps` |
| **Full suite command** | `cd vehicle-scheduling-backend && npm test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter analyze --no-pub` (frontend) or grep-based checks (backend)
- **After every plan wave:** Run full suite
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 1 | GPS-02,07,08 | unit | `npm test -- --testPathPattern=gps` | ❌ W0 | ✅ green (grep verified) |
| 07-01-02 | 01 | 1 | GPS-03 | unit | `node -e "require('./src/server')"` | ✅ | ✅ green |
| 07-02-01 | 02 | 1 | GPS-01 | unit | `node -e "require('./src/services/directionsService')"` | ✅ | ✅ green |
| 07-02-02 | 02 | 1 | GPS-01 | analyze | `flutter analyze --no-pub` | ✅ | ✅ green |
| 07-03-01 | 03 | 1 | GPS-06,02 | analyze | `flutter analyze --no-pub` + grep checks | ✅ | ⬜ pending |
| 07-03-02 | 03 | 1 | GPS-06 | analyze | `flutter analyze --no-pub` + grep checks | ✅ | ⬜ pending |
| 07-04-01 | 04 | 2 | GPS-03 | analyze | `flutter analyze --no-pub` + grep checks | ✅ | ⬜ pending |
| 07-04-02 | 04 | 2 | GPS-03 | analyze | `flutter analyze --no-pub` + grep checks | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/unit/gps.test.js` — covers GPS-01 through GPS-08 backend logic
- [ ] Mock for Google Routes API fetch call
- [ ] Socket.IO test setup: in-memory server for emit assertions

*Note: Wave 0 backend tests not created during 07-01/07-02 execution. Gap closure plans (07-03, 07-04) are Flutter-only — their verification uses flutter analyze and grep checks.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Google Map renders on job detail | GPS-01 | Requires running app + API key | Open job with coords, verify map/polyline/ETA |
| Socket.IO broadcast reaches client | GPS-03 | Requires live backend + socket client | Connect admin socket, POST driver location, verify event |
| Working hours boundary at 8PM | GPS-07 | Time-sensitive live test | POST location at 7:59PM and 8:00PM, verify 200/403 |
| Consent screen shown on first login | GPS-06 | Requires running Flutter app | Login as driver, verify consent screen appears |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
