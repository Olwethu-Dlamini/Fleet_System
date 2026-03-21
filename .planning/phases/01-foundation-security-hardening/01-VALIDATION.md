# Phase 1 Validation Architecture

**Phase:** 01-foundation-security-hardening
**Source:** Derived from RESEARCH.md "Validation Architecture" section

---

## Test Framework

| Property | Value |
|----------|-------|
| Framework | Jest |
| Config file | `vehicle-scheduling-backend/jest.config.js` |
| Quick run (unit only) | `cd vehicle-scheduling-backend && TZ=UTC npx jest --testPathPattern="unit" --no-coverage` |
| Full suite | `cd vehicle-scheduling-backend && TZ=UTC npx jest --coverage` |

**Setup required before tests run:** Plan 04 installs Jest (`npm install -D jest supertest`) and creates `jest.config.js`.

---

## Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | Created By |
|--------|----------|-----------|-------------------|------------|
| FOUND-01 | All tables have `tenant_id` column after migration | smoke | `mysql -u root -e "DESCRIBE jobs" \| grep tenant_id` | Plan 01 (manual verify) |
| FOUND-01 | Query for non-existent tenant_id returns 0 rows | integration | `TZ=UTC npx jest tests/integration/tenantIsolation.test.js` | Phase 8 |
| FOUND-02 | Concurrent assignments to same vehicle do not double-book | integration | `TZ=UTC npx jest tests/integration/raceCondition.test.js` | Phase 8 |
| FOUND-03 | Concurrent job creation generates unique job numbers | integration | `TZ=UTC npx jest tests/integration/jobNumber.test.js` | Phase 8 |
| FOUND-04 | Server exits with non-zero code if JWT_SECRET unset | static | `JWT_SECRET="" node vehicle-scheduling-backend/src/server.js 2>&1 \| grep FATAL` | Plan 03 (manual verify) |
| FOUND-05 | Response includes X-Frame-Options header | integration | `TZ=UTC npx jest tests/integration/securityHeaders.test.js` | Plan 04 |
| FOUND-05 | Login returns 429 after 11 attempts | integration | Included in securityHeaders.test.js | Plan 04 (scaffold only) |
| FOUND-06 | POST /api/jobs with invalid job_type returns 400 | integration | `TZ=UTC npx jest tests/integration/validation.test.js` | Plan 04 |
| FOUND-06 | POST /api/jobs with negative duration returns 400 | integration | Included in validation.test.js | Plan 04 (scaffold only) |
| FOUND-07 | Job date does not shift when server TZ=UTC | unit | `TZ=UTC npx jest tests/unit/dateFormatting.test.js` | Plan 04 |
| FOUND-08 | Job with 30 technicians returns all 30 in response | integration | `TZ=UTC npx jest tests/integration/groupConcat.test.js` | Phase 8 |
| FOUND-09 | EXPLAIN on date+status query uses index (no full scan) | manual | `mysql -u root -e "EXPLAIN SELECT * FROM jobs WHERE tenant_id=1 AND scheduled_date='2026-03-21'"` | Plan 01 (manual) |
| FOUND-10 | No console.log calls remain in src/ | static | `grep -r "console\.log" vehicle-scheduling-backend/src/ \| wc -l` (expect 0) | Plan 04 |

---

## Sampling Protocol

**After each Plan 04 task commit:**
```bash
cd vehicle-scheduling-backend && TZ=UTC npx jest --testPathPattern="unit" --no-coverage
```

**After all Plan 04 tasks complete (wave merge):**
```bash
cd vehicle-scheduling-backend && TZ=UTC npx jest --coverage
```

**Phase gate (before marking Phase 1 complete):**
- All 4 unit tests in `dateFormatting.test.js` pass with `TZ=UTC`
- Static checks pass: `grep -r "console\.log" vehicle-scheduling-backend/src/ | wc -l` returns `0`
- Static check: `grep "vehicle_scheduling_secret_2024" vehicle-scheduling-backend/src/server.js` returns zero matches
- Integration test runner executes without crashing (individual tests may fail due to DB unavailability in CI)

---

## Test Files Created in Phase 1

| File | Req | Status |
|------|-----|--------|
| `tests/unit/dateFormatting.test.js` | FOUND-07 | Created by Plan 04, 4 tests, all must pass with TZ=UTC |
| `tests/integration/securityHeaders.test.js` | FOUND-05 | Created by Plan 04, 3 tests, scaffold |
| `tests/integration/validation.test.js` | FOUND-06 | Created by Plan 04, 4 tests, scaffold |

## Test Files Deferred to Phase 8

| File | Req | Reason |
|------|-----|--------|
| `tests/integration/tenantIsolation.test.js` | FOUND-01 | Requires tenant-scoped query layer (Phase 2+) |
| `tests/integration/raceCondition.test.js` | FOUND-02 | Requires concurrent DB connections and test fixtures |
| `tests/integration/jobNumber.test.js` | FOUND-03 | Requires concurrent DB connections and test fixtures |
| `tests/integration/groupConcat.test.js` | FOUND-08 | Requires test data with 30+ technicians |

---

## Wave 0 Gaps (resolved by Plan 04)

- [x] `vehicle-scheduling-backend/package.json` — add Jest: `npm install -D jest supertest`
- [x] `vehicle-scheduling-backend/jest.config.js` — Jest config with testEnvironment: node
- [x] `vehicle-scheduling-backend/tests/unit/` — directory + dateFormatting test
- [x] `vehicle-scheduling-backend/tests/integration/` — directory + securityHeaders + validation tests
- [ ] `vehicle-scheduling-backend/tests/integration/tenantIsolation.test.js` — deferred to Phase 8
- [ ] `vehicle-scheduling-backend/tests/integration/raceCondition.test.js` — deferred to Phase 8
- [ ] `vehicle-scheduling-backend/tests/integration/jobNumber.test.js` — deferred to Phase 8
- [ ] `vehicle-scheduling-backend/tests/integration/groupConcat.test.js` — deferred to Phase 8
