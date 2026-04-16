---
phase: 03
slug: job-assignment-status-automation
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-21
---

# Phase 03 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | jest 29.x + supertest |
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

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 03-01-01 | 01 | 1 | ASGN-01/02/03 | unit | `grep "getDriverLoadStats" vehicle-scheduling-backend/src/models/Job.js` | ❌ W0 | ⬜ pending |
| 03-01-02 | 01 | 1 | ASGN-05 | unit | `grep "_logAssignmentHistory" vehicle-scheduling-backend/src/services/jobAssignmentService.js` | ❌ W0 | ⬜ pending |
| 03-02-01 | 02 | 2 | STAT-01 | unit | `grep "cron.schedule" vehicle-scheduling-backend/src/services/cronService.js` | ❌ W0 | ⬜ pending |
| 03-02-02 | 02 | 2 | STAT-02/03/04 | integration | `grep "completeJob" vehicle-scheduling-backend/src/services/jobStatusService.js` | ❌ W0 | ⬜ pending |
| 03-03-01 | 03 | 3 | ASGN-01/02/03/04 | manual | Flutter UI — driver picker with load indicators | N/A | ⬜ pending |
| 03-03-02 | 03 | 3 | STAT-02/03/04 | manual | Flutter UI — completion flow with GPS | N/A | ⬜ pending |

---

## Wave 0 Requirements

- [ ] `vehicle-scheduling-backend/tests/unit/driverLoad.test.js` — stubs for ASGN-01/02/03 load stats
- [ ] `vehicle-scheduling-backend/tests/unit/assignmentHistory.test.js` — stubs for ASGN-05 audit trail
- [ ] `vehicle-scheduling-backend/tests/unit/cronAutoTransition.test.js` — stubs for STAT-01
- [ ] `vehicle-scheduling-backend/tests/integration/jobCompletion.test.js` — stubs for STAT-02/03/04

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Green highlight on below-average drivers | ASGN-02 | Visual styling | Open assignment picker, verify green glow on low-load drivers |
| "Suggested" chip on lowest-load driver | ASGN-03 | Visual element | Open assignment picker, verify chip on recommended driver |
| Chip-based multi-select for technicians | ASGN-04 | Interactive UI | Create job, search and add technicians as chips |
| GPS capture on completion | STAT-03 | Device hardware | Complete a job on device, verify coordinates stored |
| Confirm dialog on completion | STAT-02 | Interactive UI | Tap complete, verify "Are you sure?" dialog appears |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 10s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
