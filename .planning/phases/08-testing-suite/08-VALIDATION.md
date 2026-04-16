---
phase: 08
slug: testing-suite
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-22
---

# Phase 08 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Jest 30.3.0 (backend), Playwright (E2E), Artillery (load) |
| **Config file** | None — Jest auto-detects `tests/**/*.test.js` |
| **Quick run command** | `cd vehicle-scheduling-backend && npm run test:unit` |
| **Full suite command** | `cd vehicle-scheduling-backend && npm test` |
| **Estimated runtime** | ~15 seconds (Jest), manual (E2E + load) |

---

## Sampling Rate

- **After every task commit:** Run `npm run test:unit` (< 5 seconds)
- **After every plan wave:** Run `npm test` (all Jest tests)
- **Before `/gsd:verify-work`:** Full Jest suite green + Playwright passes
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | TEST-01 | integration | `jest --testPathPattern=tests/api` | ❌ W0 | ⬜ pending |
| 08-01-02 | 01 | 1 | TEST-01 | integration | `jest --testPathPattern=tests/api` | ❌ W0 | ⬜ pending |
| 08-02-01 | 02 | 2 | TEST-03,04 | regression | `jest tests/regression/` | ❌ W0 | ⬜ pending |
| 08-02-02 | 02 | 2 | TEST-05 | load | `npx artillery validate` | ❌ W0 | ⬜ pending |
| 08-03-01 | 03 | 2 | TEST-02 | e2e | `node --check playwright.config.js` | ❌ W0 | ⬜ pending |
| 08-03-02 | 03 | 2 | TEST-02 | e2e | `node --check *.spec.js` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/api/helpers/auth.js` — JWT fixture helper
- [ ] `tests/api/helpers/db.mock.js` — DB mock template
- [ ] `tests/api/auth.test.js` — first API test (template for 14 more)
- [ ] `tests/regression/permissionMatrix.test.js` — TEST-03/TEST-04
- [ ] `tests/regression/conflictDetection.test.js` — TEST-03
- [ ] `tests/load/concurrent-users.yml` — TEST-05
- [ ] `e2e/playwright.config.js` — Playwright project config
- [ ] `e2e/dispatcher.spec.js` — dispatcher journey
- [ ] `e2e/driver.spec.js` — driver journey

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| E2E journeys pass against live server | TEST-02 | Requires running backend + DB | Start server, run `npx playwright test` |
| Load test 20+ concurrent users | TEST-05 | Requires live server + DB | Start server, run `npm run test:load` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
