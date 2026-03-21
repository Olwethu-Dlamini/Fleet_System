---
phase: 01
plan: 02
subsystem: backend-concurrency
tags: [race-condition, transactions, database, locks, job-assignment]
dependency_graph:
  requires: [01-01]
  provides: [FOUND-02, FOUND-03]
  affects: [jobAssignmentService, Job-model]
tech_stack:
  added: []
  patterns:
    - SELECT ... FOR UPDATE inside beginTransaction() for pessimistic row locking
    - Deadlock retry loop with exponential back-off (50ms * attempt)
    - LAST_INSERT_ID(expr) atomic counter pattern for sequence generation
key_files:
  created: []
  modified:
    - vehicle-scheduling-backend/src/services/jobAssignmentService.js
    - vehicle-scheduling-backend/src/models/Job.js
decisions:
  - "Availability check moved inside transaction (not split read-then-lock) to close the race window"
  - "FOR UPDATE locks vehicle assignment rows for the full date, not just the overlapping slot — simpler, safe"
  - "forceOverride flag propagated into assignJobToVehicle so admin override works with locking still active"
  - "LAST_INSERT_ID(expr) UPDATE pattern chosen over sequence table + SELECT MAX — atomic in single statement"
metrics:
  duration_min: 9
  completed_date: "2026-03-21T10:30:57Z"
  tasks_completed: 2
  tasks_total: 2
  files_changed: 2
---

# Phase 01 Plan 02: Race Condition Fixes Summary

**One-liner:** Closed two confirmed race conditions — vehicle double-booking via SELECT...FOR UPDATE inside transaction, and duplicate job numbers via atomic LAST_INSERT_ID sequence table increment.

## What Was Built

### Task 1: Fix vehicle double-booking race (FOUND-02)

**Problem:** The availability check in `assignJobToVehicle()` ran outside `beginTransaction()`. Two concurrent requests could both pass the check within the ~10-100ms window, then both write — resulting in two jobs assigned to the same vehicle at the same time slot.

**Fix:** Moved the vehicle availability check inside `beginTransaction()` using `SELECT ... FOR UPDATE`. The FOR UPDATE lock prevents any concurrent transaction from reading or modifying the same job_assignments rows until the current transaction commits or rolls back.

Structure:
1. Non-locking validations outside transaction (job exists, vehicle exists/active — these don't affect the assignment race)
2. `beginTransaction()` — acquire exclusive connection
3. `SELECT ja.id, j.scheduled_time_start, j.scheduled_time_end FROM job_assignments ja JOIN jobs j ... FOR UPDATE` — lock all vehicle assignments for this date
4. Overlap check against locked rows — if conflict, `rollback()` and return error
5. Write operations (DELETE old, INSERT new assignment, replace job_technicians, UPDATE job status)
6. `commit()`

Wrapped in a 3-attempt deadlock retry loop with 50ms/100ms exponential back-off per InnoDB deadlock pattern.

The `forceOverride` flag (admin hotswap) still runs the FOR UPDATE lock — it skips the rollback-on-conflict step only, so two concurrent admin overrides cannot both win.

Removed decorative `console.log` calls throughout the file. `console.error` on catch blocks retained.

### Task 2: Fix duplicate job number race (FOUND-03)

**Problem:** `generateJobNumber()` used `SELECT job_number FROM jobs WHERE job_number LIKE ? ORDER BY job_number DESC LIMIT 1` — reading the current maximum then incrementing in application code. Two concurrent job creation requests could read the same MAX value, both add 1, and produce the same job number.

**Fix:** Replaced with the atomic `LAST_INSERT_ID(expr)` pattern against the `job_number_sequences` table (created in Plan 01 migration):

```sql
INSERT IGNORE INTO job_number_sequences (year, counter) VALUES (?, 0)
UPDATE job_number_sequences SET counter = LAST_INSERT_ID(counter + 1) WHERE year = ?
SELECT LAST_INSERT_ID() AS counter
```

The UPDATE with `LAST_INSERT_ID(expr)` is a single atomic database operation — no two connections can receive the same counter value. `INSERT IGNORE` handles the January 1st year-rollover edge case safely (no-op if row already exists).

Return format unchanged: `JOB-YYYY-NNNN` (zero-padded to 4 digits).

## Commits

| Task | Commit | Message |
|------|--------|---------|
| Task 1 | 93f0119 | fix(01-02): move vehicle availability check inside FOR UPDATE transaction |
| Task 2 | 7f2678e | fix(01-02): replace generateJobNumber with atomic sequence table pattern |

## Verification Results

- `grep "FOR UPDATE" jobAssignmentService.js` — line 115 (after beginTransaction on line 102)
- `grep "LAST_INSERT_ID" Job.js` — lines 825, 830
- `grep "INSERT IGNORE INTO job_number_sequences" Job.js` — line 817
- `grep "SELECT MAX" Job.js` — zero matches (old pattern removed)
- `node -e "require(...); require(...); console.log('ok')"` — prints `ok`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] forceOverride not extracted from assignmentData**

- **Found during:** Task 1
- **Issue:** The plan added `forceOverride` to the transaction flow but the original parameter extraction did not include it. The `forceOverride` param was needed to allow admin hotswap to bypass the conflict check while still holding the FOR UPDATE lock.
- **Fix:** Added `forceOverride = false` to the destructured `assignmentData` in `assignJobToVehicle()`.
- **Files modified:** vehicle-scheduling-backend/src/services/jobAssignmentService.js
- **Commit:** 93f0119 (included in Task 1 commit)

**2. [Rule 1 - Bug] Double connection.release() risk in retry loop**

- **Found during:** Task 1 implementation review
- **Issue:** The deadlock retry loop calls `connection.release()` explicitly before `continue`, then the `finally` block would call it again — causing a double-release error.
- **Fix:** Added `try { connection.release(); } catch (_) {}` in the finally block as a guard — safe to call on an already-released connection without crashing.
- **Files modified:** vehicle-scheduling-backend/src/services/jobAssignmentService.js
- **Commit:** 93f0119 (included in Task 1 commit)

## Known Stubs

None. Both methods are fully wired — no hardcoded empty values or placeholders.

## Self-Check: PASSED

- `vehicle-scheduling-backend/src/services/jobAssignmentService.js` — exists and loads
- `vehicle-scheduling-backend/src/models/Job.js` — exists and loads
- Commit 93f0119 — verified in git log
- Commit 7f2678e — verified in git log
- FOR UPDATE appears after beginTransaction in file order (line 115 vs line 102)
- No SELECT MAX pattern remains in Job.js
