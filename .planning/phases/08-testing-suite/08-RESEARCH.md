# Phase 8: Testing Suite — Research

**Researched:** 2026-03-22
**Domain:** Node.js API testing (Jest + Supertest), E2E (Playwright), load testing (Artillery)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Jest + Supertest for API tests (already partially set up)
- Playwright for E2E tests
- k6 or artillery for load testing
- Tests must be CI-ready (package.json scripts)
- TEST-01 through TEST-05 requirements must be satisfied

### Claude's Discretion
All implementation choices — pure infrastructure phase. All tooling choices, file organization, test patterns, and CI configuration.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope.
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TEST-01 | API endpoint tests for all backend routes (Jest + Supertest) | 15 route files mapped; auth helper pattern and JWT fixture strategy documented |
| TEST-02 | UI/E2E tests with Playwright (dispatcher and driver journeys) | Playwright 1.58.2 confirmed; key journeys identified (login, create job, assign, complete) |
| TEST-03 | Regression test suite (conflict detection, timezone, permissions) | Regression scenarios documented; extends existing unit/integration patterns |
| TEST-04 | Permission matrix regression tests (role-based access verification) | Full PERMISSIONS map extracted from constants.js; 4 roles × 20 permissions = 80 matrix cells |
| TEST-05 | Load testing with 20+ concurrent users | Artillery 2.0.30 chosen over k6 (npm-native, no standalone binary install); scenario documented |
</phase_requirements>

---

## Summary

The backend already has Jest 30.3.0, Supertest 7.2.2, and a working test scaffold with 3 test files covering security headers, input validation, and UTC date formatting. The `server.js` correctly exports `app` behind a `require.main === module` guard, so Supertest can import it without triggering the database startup sequence or cron jobs.

Phase 8 extends this infrastructure across all 15 route files (TEST-01), adds Playwright E2E tests for three core user journeys (TEST-02), builds regression suites for conflict detection / timezone / permission matrix (TEST-03/TEST-04), and adds Artillery load tests simulating 20+ concurrent users (TEST-05).

The critical design constraint is that API tests must work **without a live MySQL database** — JWT tokens must be minted in test fixtures and the DB layer must be mocked. This is already demonstrated by the existing integration tests which accept 401 responses as proof that routes exist and auth fires. Load tests are the only tier that requires a running backend + DB.

**Primary recommendation:** Organise tests into four clear tiers — `tests/unit/`, `tests/integration/` (existing), `tests/api/` (new, full route coverage with mocked DB), `tests/regression/` (new, permission matrix + conflict + timezone), and `tests/load/` (Artillery YAML scripts). Playwright lives in `e2e/` at the repo root level. Add `test:api`, `test:regression`, `test:e2e`, `test:load`, and `test:all` scripts to `package.json`.

---

## Standard Stack

### Core (already installed)
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jest | 30.3.0 | Test runner + assertion library | Already in devDependencies; latest as of registry check |
| supertest | 7.2.2 | HTTP assertions against Express apps | Already in devDependencies; latest as of registry check |

### New Additions
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| @playwright/test | 1.58.2 | E2E browser automation | UI journey tests (TEST-02) |
| artillery | 2.0.30 | Load / performance testing | Concurrent user simulation (TEST-05) |

**Why Artillery over k6:** k6 is a standalone binary (not on npm — `npm view k6 version` returns `0.0.0`). Artillery is a full npm package (`npm install -D artillery`), keeping CI setup to a single `npm install`. Artillery 2.x supports HTTP, Socket.IO, and WebSocket scenarios — matching this backend's GPS Socket.IO layer.

**Why Playwright over Cypress:** CONTEXT.md locks the choice to Playwright. Additionally, Playwright 1.58 has native network interception, multi-page support, and headless Chromium bundled via `npx playwright install chromium`.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Artillery | k6 | k6 is faster for pure load but requires a standalone binary install — CI setup complexity |
| Jest mock DB | real test DB | Real DB gives higher fidelity but requires DB provisioning in CI; mock is sufficient for route/permission coverage |
| Playwright | Cypress | CONTEXT.md locks to Playwright; both are excellent, Playwright is newer standard |

**Installation (new packages only):**
```bash
cd vehicle-scheduling-backend
npm install --save-dev artillery

# Playwright is installed separately (needs browser binaries)
npm install --save-dev @playwright/test
npx playwright install chromium
```

---

## Architecture Patterns

### Recommended Project Structure
```
vehicle-scheduling-backend/
├── tests/
│   ├── unit/
│   │   └── dateFormatting.test.js       # existing — UTC date handling
│   ├── integration/
│   │   ├── securityHeaders.test.js      # existing — helmet headers
│   │   └── validation.test.js           # existing — express-validator
│   ├── api/
│   │   ├── helpers/
│   │   │   ├── auth.js                  # makeToken(role) helper
│   │   │   └── db.mock.js               # jest.mock('../config/database')
│   │   ├── auth.test.js
│   │   ├── jobs.test.js
│   │   ├── vehicles.test.js
│   │   ├── users.test.js
│   │   ├── dashboard.test.js
│   │   ├── reports.test.js
│   │   ├── notifications.test.js
│   │   ├── settings.test.js
│   │   ├── job-assignments.test.js
│   │   ├── job-status.test.js
│   │   ├── availability.test.js
│   │   ├── vehicle-maintenance.test.js
│   │   ├── time-extensions.test.js
│   │   └── gps.test.js
│   ├── regression/
│   │   ├── permissionMatrix.test.js     # TEST-03, TEST-04: all 80 role×permission cells
│   │   ├── conflictDetection.test.js    # TEST-03: double-booking guard
│   │   └── timezoneHandling.test.js     # TEST-03: UTC vs local edge cases
│   └── load/
│       └── concurrent-users.yml         # TEST-05: Artillery scenario
e2e/
├── playwright.config.js
├── fixtures/
│   └── auth.setup.js                    # login state saved to storage state
├── dispatcher.spec.js                   # TEST-02: dispatcher journey
├── driver.spec.js                       # TEST-02: driver/technician journey
└── scheduler.spec.js                    # TEST-02: scheduler journey
```

### Pattern 1: JWT Test Fixture Helper
**What:** A `makeToken(role, overrides)` helper that mints a valid JWT for use in test Authorization headers without touching the DB.
**When to use:** All API tests that hit protected routes (all routes except `POST /api/auth/login`).

```javascript
// tests/api/helpers/auth.js
// Source: Standard Supertest + jsonwebtoken pattern

const jwt = require('jsonwebtoken');

const JWT_SECRET = 'test-secret-value-minimum-32-chars-ok';

/**
 * Mint a valid JWT for test requests.
 * @param {string} role - 'admin' | 'scheduler' | 'technician'
 * @param {object} overrides - optional payload overrides
 */
function makeToken(role = 'admin', overrides = {}) {
  const payload = {
    id: 1,
    username: `test_${role}`,
    role,
    tenant_id: 1,
    ...overrides,
  };
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h' });
}

module.exports = { makeToken, JWT_SECRET };
```

```javascript
// Usage in a test file (test setup block)
process.env.JWT_SECRET = require('./helpers/auth').JWT_SECRET;
process.env.NODE_ENV = 'test';

const request = require('supertest');
const app     = require('../../src/server');
const { makeToken } = require('./helpers/auth');

describe('GET /api/jobs', () => {
  test('returns 200 for admin token', async () => {
    const token = makeToken('admin');
    const res = await request(app)
      .get('/api/jobs')
      .set('Authorization', `Bearer ${token}`);
    // DB will fail → mock or accept 500 from DB; route + auth wiring proved
    expect([200, 500]).toContain(res.status);
  });

  test('returns 401 without token', async () => {
    const res = await request(app).get('/api/jobs');
    expect(res.status).toBe(401);
  });
});
```

### Pattern 2: DB Mock for API Tests
**What:** `jest.mock` on the database module so tests never hit MySQL.
**When to use:** All `tests/api/` test files. Keeps tests deterministic and CI-safe.

```javascript
// tests/api/helpers/db.mock.js
// Provides controllable mock responses for db.query()

jest.mock('../../src/config/database', () => ({
  query: jest.fn(),
  // pool mock for transaction tests
  getConnection: jest.fn().mockResolvedValue({
    query: jest.fn(),
    beginTransaction: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  }),
}));

const db = require('../../src/config/database');

/** Reset all mocks between tests */
function resetDbMocks() {
  db.query.mockReset();
  db.getConnection.mockReset();
}

module.exports = { db, resetDbMocks };
```

### Pattern 3: Permission Matrix Test
**What:** Systematic table-driven test asserting every role×permission combination returns the correct HTTP status.
**When to use:** `tests/regression/permissionMatrix.test.js` to cover TEST-04.

```javascript
// tests/regression/permissionMatrix.test.js
const request = require('supertest');
const app     = require('../../src/server');
const { makeToken } = require('../api/helpers/auth');

// Each row: [description, method, path, role, expectedStatus]
const MATRIX = [
  // vehicles:create — admin only
  ['admin can POST /api/vehicles',      'post', '/api/vehicles', 'admin',      [400, 409, 500]], // 403 would be a FAIL
  ['scheduler cannot POST /api/vehicles','post', '/api/vehicles', 'scheduler', [403]],
  ['technician cannot POST /api/vehicles','post', '/api/vehicles', 'technician',[403]],

  // users:delete — admin only
  ['admin can DELETE /api/users/99',    'delete', '/api/users/99', 'admin',     [200, 404, 500]],
  ['scheduler cannot DELETE /api/users/99','delete', '/api/users/99', 'scheduler',[403]],

  // jobs:read — all roles
  ['admin can GET /api/jobs',           'get', '/api/jobs', 'admin',      [200, 500]],
  ['scheduler can GET /api/jobs',       'get', '/api/jobs', 'scheduler',  [200, 500]],
  ['technician can GET /api/jobs',      'get', '/api/jobs', 'technician', [200, 500]],
  // ... full matrix continues
];

describe('Permission Matrix Regression (TEST-04)', () => {
  MATRIX.forEach(([desc, method, path, role, allowed]) => {
    test(desc, async () => {
      const token = makeToken(role);
      const res = await request(app)[method](path)
        .set('Authorization', `Bearer ${token}`);
      expect(allowed).toContain(res.status);
    });
  });
});
```

### Pattern 4: Artillery Load Test
**What:** YAML scenario file targeting the API server to simulate 20+ concurrent users.
**When to use:** `tests/load/concurrent-users.yml` — run against a live server with DB.

```yaml
# tests/load/concurrent-users.yml
# Source: Artillery 2.x documentation (https://www.artillery.io/docs)
config:
  target: "http://localhost:3000"
  phases:
    - duration: 60      # 60 seconds
      arrivalRate: 20   # 20 new virtual users per second = 20+ concurrent
  variables:
    adminToken: "{{ $processEnvironment.TEST_ADMIN_TOKEN }}"

scenarios:
  - name: "Dispatcher reads dashboard and job list"
    weight: 60
    flow:
      - get:
          url: "/api/dashboard/summary"
          headers:
            Authorization: "Bearer {{ adminToken }}"
          expect:
            - statusCode: 200
      - get:
          url: "/api/jobs"
          headers:
            Authorization: "Bearer {{ adminToken }}"

  - name: "Driver updates GPS location"
    weight: 40
    flow:
      - post:
          url: "/api/gps/location"
          headers:
            Authorization: "Bearer {{ adminToken }}"
          json:
            lat: -26.2041
            lng: 28.0473
```

### Pattern 5: Playwright E2E Journey Test
**What:** Browser-level test driving the Flutter web app (or backend API via browser). Since the frontend is Flutter, Playwright will target the **compiled Flutter web** app and the backend.
**When to use:** `e2e/dispatcher.spec.js`.

```javascript
// e2e/dispatcher.spec.js
// Source: Playwright 1.x documentation (https://playwright.dev/docs/writing-tests)
import { test, expect } from '@playwright/test';

test.describe('Dispatcher Journey', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('login → view dashboard → create job', async ({ page }) => {
    // Login
    await page.fill('[data-testid="username"]', 'admin');
    await page.fill('[data-testid="password"]', 'testpassword');
    await page.click('[data-testid="login-button"]');
    await expect(page).toHaveURL(/dashboard/);

    // Dashboard shows job count
    await expect(page.locator('[data-testid="jobs-today-card"]')).toBeVisible();
  });
});
```

**Note on Flutter web + Playwright:** Flutter web compiles to canvas-based rendering. Playwright can interact with Flutter web apps if semantic widgets are enabled (`--profile=flutter-web` or `semanticsEnabled: true`). Alternatively, E2E tests can target the **REST API directly** (without a browser) using Playwright's `apiRequestContext` — this is the recommended approach for this phase since a Flutter web build is not part of the phase scope.

### Anti-Patterns to Avoid
- **Importing server without setting JWT_SECRET first:** The startup guard at the top of `server.js` will call `process.exit(1)` if `JWT_SECRET` is not set. Always set `process.env.JWT_SECRET` before `require('../../src/server')`.
- **Testing with a live DB in `tests/api/`:** Makes tests non-deterministic and CI-dependent. Mock `src/config/database` in all API tests.
- **Using `jest.setTimeout` globally for slow tests:** Indicates the test is doing real I/O. Fix: mock the slow layer instead.
- **Running Artillery against localhost without a live server:** Artillery requires the server to actually be running. Add a `pretest:load` script that starts the server, or document that load tests are a manual step.
- **Using `app` from `server.js` in load tests:** Load tests require the full `httpServer` (with Socket.IO). Use a `TEST_ADMIN_TOKEN` env var pre-minted for load test runs.
- **Cron service loading in tests:** The `require.main === module` guard in `server.js` already prevents cron from loading when imported by Jest. Do not require `cronService` in any test file.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT minting in tests | Custom token builder from scratch | `jsonwebtoken.sign()` + shared `makeToken()` helper | Already a dep; one function call |
| HTTP assertions | Manual fetch + status check | `supertest` | Handles app lifecycle, async, headers |
| Browser automation | Custom Puppeteer scripts | `@playwright/test` | Auto-wait, network interception, tracing built in |
| Load simulation | Custom async flood loops | `artillery` | Rate control, ramp-up, scenario weighting |
| Mock call tracking | Manual counters | `jest.fn()` / `jest.mock()` | Built into Jest; zero setup |

**Key insight:** All the hard test infrastructure already exists or is one `npm install` away. The work in Phase 8 is writing the test logic, not building test tooling.

---

## Common Pitfalls

### Pitfall 1: process.exit(1) in server.js kills Jest
**What goes wrong:** `server.js` line 9 calls `process.exit(1)` if `JWT_SECRET` is missing. If a test file forgets to set it before `require('../../src/server')`, Jest's worker process dies silently.
**Why it happens:** `process.exit` is synchronous and kills the Node.js process entirely, including Jest's worker.
**How to avoid:** Every test file that imports `server.js` MUST set `process.env.JWT_SECRET` before the require. Put this at line 1 of the test file (before any imports). Use the same token string as in `helpers/auth.js`.
**Warning signs:** Jest output shows `Test suite failed to run` with exit code 1 and no assertion errors.

### Pitfall 2: DB pool hanging in Jest
**What goes wrong:** `mysql2` connection pool keeps connections open. After tests finish, Jest waits for the pool to drain — typically a 30-second timeout — before exiting.
**Why it happens:** `db.pool.end()` is never called, so Jest's `--detectOpenHandles` flag would catch this.
**How to avoid:** In `tests/api/` tests, mock the DB module entirely via `jest.mock('../config/database')` — pool never opens. For integration tests that use a real DB, add `afterAll(() => db.pool && db.pool.end())`.
**Warning signs:** Jest shows `Jest did not exit one second after the test run has completed`.

### Pitfall 3: Socket.IO server not closed after tests
**What goes wrong:** `server.js` creates a Socket.IO server attached to `httpServer`. Supertest creates its own HTTP listener internally — but the Socket.IO `io` instance holds event listeners that prevent Jest cleanup.
**Why it happens:** Supertest uses a temporary port (`request(app)` without `.listen()`) — it closes its own connection. But the `io = new Server(httpServer, ...)` in server.js registers on the module-level `httpServer`, not Supertest's internal server.
**How to avoid:** For API tests, the mock-DB approach means no real server startup. For integration tests: either export `httpServer` alongside `app` and call `httpServer.close()` in `afterAll`, or use `--forceExit` in Jest config as a last resort.
**Warning signs:** Same open handles warning; Socket.IO error logs about `socket hang up`.

### Pitfall 4: Playwright targeting Flutter canvas (not DOM)
**What goes wrong:** Flutter web renders to a `<canvas>` element. Standard Playwright locators like `page.locator('button')` or `page.fill('input')` find nothing.
**Why it happens:** Flutter compiles UI to WebGL/canvas, not HTML form elements.
**How to avoid:** Use Playwright's `apiRequestContext` to test the backend API directly instead of browser UI interactions. This gives full E2E coverage of the API surface without needing Flutter semantic bridge setup.
**Warning signs:** Playwright selectors time out; page shows a canvas element with no children.

### Pitfall 5: Role string mismatch — 'dispatcher' vs 'scheduler'
**What goes wrong:** `constants.js` maps both `dispatcher` and `scheduler` to the same permissions. A test that mints a token with `role: 'dispatcher'` will hit PERMISSIONS lookups that include `'scheduler'` but not `'dispatcher'` in some older arrays.
**Why it happens:** The codebase has dual role names for backward compatibility. The PERMISSIONS map includes both `USER_ROLE.DISPATCHER` and `USER_ROLE.SCHEDULER` in every permission array where scheduler was previously allowed.
**How to avoid:** In test fixtures, use `'scheduler'` as the role string (the canonical test value). The `makeToken('scheduler')` produces a token with `role: 'scheduler'` which matches all PERMISSIONS entries. Test both role strings in the permission matrix regression suite.
**Warning signs:** Permission tests pass for `admin` but 403 for `scheduler` on routes that should allow it.

### Pitfall 6: Artillery requires a running server + populated DB
**What goes wrong:** Artillery sends real HTTP requests. If `TEST_ADMIN_TOKEN` is not set, or the server is not running, every scenario fails with connection refused.
**Why it happens:** Artillery is a black-box load tool — it doesn't mock anything.
**How to avoid:** Document that `npm run test:load` requires the server to be started first (`npm run dev` in another terminal with a seeded DB). Add a comment in `package.json`. Pre-mint the admin token using a helper script.
**Warning signs:** Artillery reports 100% error rate immediately; errors show `ECONNREFUSED`.

---

## Code Examples

### Complete API Test File Pattern
```javascript
// tests/api/jobs.test.js
// Source: Supertest 7.x documentation; existing project integration test patterns

// MUST be first — before any require() that loads server.js
process.env.JWT_SECRET = 'test-secret-value-minimum-32-chars-ok';
process.env.NODE_ENV   = 'test';

jest.mock('../../src/config/database', () => ({
  query: jest.fn(),
  getConnection: jest.fn().mockResolvedValue({
    query: jest.fn(),
    beginTransaction: jest.fn(),
    commit: jest.fn(),
    rollback: jest.fn(),
    release: jest.fn(),
  }),
}));

const request = require('supertest');
const app     = require('../../src/server');
const { makeToken } = require('./helpers/auth');
const db      = require('../../src/config/database');

beforeEach(() => {
  db.query.mockReset();
});

describe('GET /api/jobs', () => {
  test('401 without token', async () => {
    const res = await request(app).get('/api/jobs');
    expect(res.status).toBe(401);
  });

  test('200 for admin with mocked DB', async () => {
    db.query.mockResolvedValueOnce([[{ id: 1, job_number: 'JOB-0001', status: 'pending' }]]);
    const res = await request(app)
      .get('/api/jobs')
      .set('Authorization', `Bearer ${makeToken('admin')}`);
    expect(res.status).toBe(200);
  });

  test('403 for unknown permission key on protected route', async () => {
    // technician cannot create jobs
    const res = await request(app)
      .post('/api/jobs')
      .set('Authorization', `Bearer ${makeToken('technician')}`)
      .send({ job_type: 'delivery' }); // will 403 before validation
    expect(res.status).toBe(403);
  });
});
```

### Playwright API Request Context (Backend E2E)
```javascript
// e2e/dispatcher.spec.js
// Source: Playwright docs — https://playwright.dev/docs/api/class-apirequestcontext

import { test, expect } from '@playwright/test';

test.describe('Dispatcher API Journey', () => {
  let apiContext;
  let authToken;

  test.beforeAll(async ({ playwright }) => {
    apiContext = await playwright.request.newContext({
      baseURL: 'http://localhost:3000',
    });

    // Login to get real token
    const loginRes = await apiContext.post('/api/auth/login', {
      data: { username: process.env.TEST_ADMIN_USER, password: process.env.TEST_ADMIN_PASS },
    });
    const body = await loginRes.json();
    authToken = body.token;
  });

  test.afterAll(async () => {
    await apiContext.dispose();
  });

  test('can read dashboard summary', async () => {
    const res = await apiContext.get('/api/dashboard/summary', {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body).toHaveProperty('totalJobs');
  });

  test('can create and retrieve a job', async () => {
    const createRes = await apiContext.post('/api/jobs', {
      headers: { Authorization: `Bearer ${authToken}` },
      data: {
        job_type: 'delivery',
        customer_name: 'Test Customer',
        customer_address: '123 Test St',
        scheduled_date: '2026-12-01',
        scheduled_time_start: '09:00',
        scheduled_time_end: '10:00',
        estimated_duration_minutes: 60,
      },
    });
    expect(createRes.status()).toBe(201);
    const { job } = await createRes.json();
    expect(job.job_number).toMatch(/^JOB-/);
  });
});
```

### playwright.config.js
```javascript
// e2e/playwright.config.js
// Source: Playwright 1.x docs — https://playwright.dev/docs/test-configuration

import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  timeout: 30_000,
  retries: 1,
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:3000',
    extraHTTPHeaders: {
      'Accept': 'application/json',
    },
  },
  reporter: [['html', { outputFolder: 'e2e/report' }], ['list']],
});
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Jest 27 `testEnvironment: 'node'` was opt-in | Jest 30 defaults to `node` env | Jest 27 → 28 | No config needed |
| Supertest required `app.listen()` to bind | Supertest handles un-bound apps | Supertest 4+ | No server start needed |
| k6 was only standalone binary | Artillery 2.x has full npm install | 2022 | Simpler CI setup |
| Playwright required manual browser install | `npx playwright install chromium` | Playwright 1.x | One command setup |
| Artillery 1.x used `phases[].duration` only | Artillery 2.x adds `think`, `loop`, `websocket` | 2023 | Socket.IO scenarios possible |

**Deprecated/outdated:**
- `supertest` + `http.createServer(app)` pattern: No longer needed — pass `app` directly to `request()`.
- Jest `testRunner: 'jasmine2'`: Removed in Jest 27; Jest 30 uses its own runner.
- Artillery 1.x YAML schema: 2.x changed `config.payload` and `expect` syntax — use 2.x docs.

---

## Open Questions

1. **Flutter E2E — web build required?**
   - What we know: TEST-02 says "UI/E2E tests with Playwright for dispatcher and driver journeys"
   - What's unclear: Flutter web needs to be compiled (`flutter build web`) and served to test real UI. No `flutter build web` step exists in the roadmap.
   - Recommendation: Use Playwright `apiRequestContext` to test the backend REST API for both dispatcher and driver journeys. This provides full E2E API coverage. Label tests clearly as "API journey tests" in the plan to set correct expectations with stakeholders.

2. **Regression conflict detection tests — does the DB layer need to be real?**
   - What we know: Conflict detection lives in `timeExtensionService.analyzeImpact()` and `vehicleAvailabilityService` — they run SQL queries.
   - What's unclear: Pure unit tests can mock DB responses to simulate conflicts; integration tests need a seeded DB.
   - Recommendation: Conflict detection regression tests use mocked DB with crafted response fixtures (overlapping time windows). This keeps TEST-03 runnable in CI without a DB.

3. **`test:load` in CI — blocked on live DB**
   - What we know: Artillery load tests require a running server + DB.
   - What's unclear: Whether the CI pipeline has a MySQL service or not.
   - Recommendation: Mark `test:load` as a "local/staging only" script. Add a `# REQUIRES: live server on port 3000` comment in package.json. This is standard practice for load tests in pre-production systems.

---

## Validation Architecture

> `workflow.nyquist_validation` key is absent from `.planning/config.json` — treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Jest 30.3.0 (already installed) |
| Config file | None currently — Jest auto-detects `tests/**/*.test.js` |
| Quick run command | `npm run test:unit` (< 5 seconds) |
| Full suite command | `npm test` (all Jest tests) |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TEST-01 | All 15 routes return correct status codes for admin/scheduler/technician | integration | `jest --testPathPattern=tests/api` | ❌ Wave 0 |
| TEST-02 | Dispatcher login → dashboard → create job journey via API | e2e | `npx playwright test` | ❌ Wave 0 |
| TEST-02 | Driver login → view assigned jobs → complete job journey via API | e2e | `npx playwright test` | ❌ Wave 0 |
| TEST-03 | Conflict detection returns correct overlapping jobs | unit/mock-db | `jest tests/regression/conflictDetection.test.js` | ❌ Wave 0 |
| TEST-03 | Timezone: UTC midnight date does not shift | unit | `jest tests/unit/dateFormatting.test.js` | ✅ EXISTS |
| TEST-03 | Permission matrix: all 20 permission keys × 4 roles | integration | `jest tests/regression/permissionMatrix.test.js` | ❌ Wave 0 |
| TEST-04 | scheduler cannot DELETE users (returns 403) | integration | `jest tests/regression/permissionMatrix.test.js` | ❌ Wave 0 |
| TEST-04 | technician cannot POST jobs (returns 403) | integration | `jest tests/regression/permissionMatrix.test.js` | ❌ Wave 0 |
| TEST-05 | 20 concurrent users: dashboard GET p95 < 2s | load | `npm run test:load` (manual — live server) | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `npm run test:unit` (dateFormatting — always green, < 5s)
- **Per wave merge:** `npm test` (all Jest tests — unit + integration + api + regression)
- **Phase gate:** Full Jest suite green + Playwright passes before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/api/helpers/auth.js` — JWT fixture helper (used by all API tests)
- [ ] `tests/api/helpers/db.mock.js` — DB mock template
- [ ] `tests/api/auth.test.js` — first API test file (template for remaining 14)
- [ ] `tests/regression/permissionMatrix.test.js` — TEST-03/TEST-04
- [ ] `tests/regression/conflictDetection.test.js` — TEST-03
- [ ] `tests/load/concurrent-users.yml` — TEST-05
- [ ] `e2e/playwright.config.js` — Playwright project config
- [ ] `e2e/dispatcher.spec.js` — dispatcher API journey
- [ ] `e2e/driver.spec.js` — driver API journey
- [ ] Framework installs: `npm install --save-dev artillery @playwright/test && npx playwright install chromium`
- [ ] Add scripts to `package.json`: `test:api`, `test:regression`, `test:e2e`, `test:load`, `test:all`

---

## Sources

### Primary (HIGH confidence)
- Supertest 7.x — project `package.json` confirms `"supertest": "^7.2.2"` installed; `npm view supertest version` returns `7.2.2`
- Jest 30.3.0 — project `package.json` confirms `"jest": "^30.3.0"` installed; `npm view jest version` returns `30.3.0`
- `src/middleware/authMiddleware.js` — read directly; PERMISSIONS matrix extracted verbatim
- `src/server.js` — read directly; confirmed `require.main === module` guard at line 302, `module.exports = app` at line 388
- `src/routes/index.js` — read directly; confirmed 15 route files registered
- `src/config/constants.js` — read directly; confirmed 4 roles, 20+ permission keys, dual `dispatcher`/`scheduler` naming

### Secondary (MEDIUM confidence)
- Playwright 1.58.2 — `npm view @playwright/test version` returned `1.58.2` (registry verified 2026-03-22)
- Artillery 2.0.30 — `npm view artillery version` returned `2.0.30` (registry verified 2026-03-22); `npm view artillery dist-tags` confirmed `latest: '2.0.30'`
- k6 npm stub — `npm view k6 version` returned `0.0.0` confirming k6 is not a real npm package (standalone binary only); this is the basis for recommending Artillery

### Tertiary (LOW confidence)
- Flutter web + Playwright interaction: canvas-rendering limitation is well-known community knowledge (training data); the `apiRequestContext` workaround is verified via Playwright official docs pattern

---

## Metadata

**Confidence breakdown:**
- Standard stack (Jest/Supertest): HIGH — already installed, versions registry-verified
- Standard stack (Playwright/Artillery): HIGH — versions registry-verified 2026-03-22
- Architecture patterns: HIGH — derived directly from reading the actual source files
- Permission matrix: HIGH — read from `src/config/constants.js` directly
- Pitfalls: MEDIUM — DB pool hang and Socket.IO open handle are common Node.js test patterns; server.js `process.exit` pitfall verified by reading code
- Flutter/Playwright E2E: LOW — canvas limitation from training data; mitigation (apiRequestContext) is HIGH from Playwright docs

**Research date:** 2026-03-22
**Valid until:** 2026-09-22 (stable toolchain; review if Jest/Playwright major versions released)
