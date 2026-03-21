# Phase 1: Foundation & Security Hardening — Research

**Researched:** 2026-03-21
**Domain:** Node.js/Express security hardening, MySQL multi-tenancy, race-condition-safe transactions, structured logging
**Confidence:** HIGH — all findings grounded in direct codebase inspection and verified package versions from npm registry

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| FOUND-01 | Add `tenant_id` column to all tables for multi-tenant isolation | Migration pattern, middleware pattern, and composite index strategy documented in Architecture Patterns section |
| FOUND-02 | Fix race condition in job assignment — wrap availability check + insert in `SELECT ... FOR UPDATE` transaction | Confirmed bug location in `jobAssignmentService.js`; `SELECT ... FOR UPDATE` pattern documented with code example |
| FOUND-03 | Fix job number generation race condition — use atomic sequence table | Confirmed bug location in `Job.js`; atomic sequence table pattern documented with code example |
| FOUND-04 | Remove hardcoded JWT secret fallback — enforce env variable | Confirmed location in `server.js` line 19 and `authMiddleware.js` line 9; startup guard pattern documented |
| FOUND-05 | Add `helmet` and `express-rate-limit` middleware to server | Both packages verified (helmet 8.1.0, express-rate-limit 8.3.1); placement in server.js documented |
| FOUND-06 | Add input validation middleware (`express-validator`) on all routes | express-validator 7.3.1 verified; schema-per-route pattern documented; existing routes enumerated |
| FOUND-07 | Set `TZ=UTC` in Docker and add `tenant_timezone` field | Docker ENV syntax, MariaDB pool `timezone` option, and `tenant_timezone` column placement documented |
| FOUND-08 | Fix `GROUP_CONCAT` truncation — set `group_concat_max_len=65536` per connection | Confirmed bug in `Job.js` and `jobAssignmentService.js`; per-connection SET pattern documented |
| FOUND-09 | Add database indexes on `scheduled_date`, `current_status`, `tenant_id` | All index SQL statements documented; composite index with `tenant_id` as leading column documented |
| FOUND-10 | Replace `console.log` with structured logging (pino) | pino 10.3.1 verified; drop-in replacement pattern with child loggers and request context documented |
</phase_requirements>

---

## Summary

Phase 1 is a brownfield hardening phase. The existing codebase is functional but carries multiple confirmed production risks: two race conditions (job assignment and job number generation), a hardcoded JWT secret fallback, missing security middleware, no tenant isolation, and unstructured console logging. All ten requirements map to specific files and line numbers already identified in the codebase audit.

Every subsequent phase (2–9) builds on a `tenant_id` column that does not yet exist. FOUND-01 is the critical path item — it must be done first and every other FOUND task must be applied in the same migration sweep so no table is left without the column. The migration is mechanical (add column, backfill with `tenant_id = 1`, add composite indexes) but touches every table and every query in the backend.

The security and performance fixes (FOUND-02 through FOUND-10) are all self-contained with no dependencies between them except that FOUND-01 should complete before FOUND-09 so indexes are built with `tenant_id` as the leading column.

**Primary recommendation:** Execute FOUND-01 (tenant_id migration) first in an isolated plan, then group the remaining fixes into two plans — security middleware (FOUND-04, FOUND-05, FOUND-06) and database/logging fixes (FOUND-02, FOUND-03, FOUND-07, FOUND-08, FOUND-09, FOUND-10).

---

## Standard Stack

### Core — Already Installed

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| express | 5.2.1 | HTTP framework | Installed |
| mysql2 | 3.16.3 | DB driver (pool + promise) | Installed |
| jsonwebtoken | 9.0.3 | JWT sign/verify | Installed |
| dotenv | 17.2.4 | Env variable loading | Installed |

### Additions Required (Phase 1)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| helmet | 8.1.0 | HTTP security headers | OWASP-recommended; prevents XSS, clickjacking, MIME sniffing in one middleware |
| express-rate-limit | 8.3.1 | Rate limiting per IP | Standard Express protection against brute-force; 5-line integration |
| express-validator | 7.3.1 | Input validation middleware | Chain-based validators; returns field-level 400 errors; standard for Express |
| pino | 10.3.1 | Structured JSON logging | Fastest Node.js logger; JSON output integrates with log shipping (Loki, Datadog) |
| pino-http | latest | HTTP request logging middleware | Logs each request with status, duration, user context |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| pino | winston | Winston is more configurable but 3-5x slower. pino is the standard for high-throughput Express APIs. |
| express-validator | joi | Joi is excellent but adds a separate schema definition layer. express-validator chains directly on route definitions, lower migration cost. |
| express-rate-limit | rate-limiter-flexible | rate-limiter-flexible supports Redis-backed distributed limiting but requires Redis (not in stack yet). express-rate-limit with in-memory store is correct for single-instance Docker deployment. |

**Installation:**
```bash
cd vehicle-scheduling-backend
npm install helmet express-rate-limit express-validator pino pino-http
```

**Verified versions (npm registry, 2026-03-21):**
- helmet: 8.1.0
- express-rate-limit: 8.3.1
- express-validator: 7.3.1
- pino: 10.3.1

---

## Architecture Patterns

### Recommended Migration Order

```
Step 1: FOUND-01 — Add tenant_id to all tables + tenants table + migration script
Step 2: FOUND-09 — Add composite indexes (must come after tenant_id column exists)
Step 3: FOUND-04 — Remove JWT secret fallback (no deps)
Step 4: FOUND-05 — helmet + rate-limit (no deps)
Step 5: FOUND-06 — express-validator on all routes (no deps)
Step 6: FOUND-02 — Race condition fix in job assignment (no deps)
Step 7: FOUND-03 — Job number sequence table (no deps)
Step 8: FOUND-07 — TZ=UTC Docker + tenant_timezone column (after tenant_id done)
Step 9: FOUND-08 — GROUP_CONCAT max_len fix (no deps)
Step 10: FOUND-10 — Replace console.log with pino (no deps)
```

### Recommended Project Structure Changes

```
vehicle-scheduling-backend/
├── src/
│   ├── config/
│   │   ├── database.js        # Add timezone: '+00:00' to pool config
│   │   └── logger.js          # NEW: pino instance, exported as singleton
│   ├── middleware/
│   │   ├── authMiddleware.js  # MODIFY: remove JWT_SECRET fallback
│   │   ├── rateLimiter.js     # NEW: express-rate-limit config
│   │   └── validate.js        # NEW: express-validator helper (validationResult handler)
│   ├── migrations/
│   │   └── 001_add_tenant_id.sql   # NEW: tenant_id migration script
│   ├── models/
│   │   └── Job.js             # MODIFY: add GROUP_CONCAT fix, add tenantId param
│   └── server.js              # MODIFY: helmet, rate-limit, JWT guard, pino-http
```

### Pattern 1: Tenant ID Migration (FOUND-01)

**What:** Add `tenant_id` to every table, create a `tenants` root table, backfill existing data to `tenant_id = 1`, then add composite indexes with `tenant_id` as the leading column.

**Tables to modify (confirmed from `vehicle_scheduling.sql`):**
- `jobs`
- `vehicles`
- `users`
- `job_assignments`
- `job_technicians`
- `job_status_changes`

**Migration SQL pattern:**
```sql
-- Source: direct schema analysis of vehicle_scheduling.sql

-- 1. Create tenants root table
CREATE TABLE IF NOT EXISTS `tenants` (
  `id`          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`        VARCHAR(100) NOT NULL,
  `slug`        VARCHAR(50) NOT NULL,
  `is_active`   TINYINT(1) NOT NULL DEFAULT 1,
  `tenant_timezone` VARCHAR(50) NOT NULL DEFAULT 'UTC',
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 2. Insert default tenant for existing data
INSERT INTO `tenants` (`id`, `name`, `slug`) VALUES (1, 'Default Tenant', 'default');

-- 3. Add tenant_id to each table (repeat for all tables)
ALTER TABLE `jobs`
  ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

ALTER TABLE `vehicles`
  ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

ALTER TABLE `users`
  ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

ALTER TABLE `job_assignments`
  ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

ALTER TABLE `job_technicians`
  ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

ALTER TABLE `job_status_changes`
  ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

-- 4. Remove DEFAULT 1 after backfill (enforce NOT NULL without default)
-- Run this after verifying all rows have tenant_id = 1
ALTER TABLE `jobs` ALTER COLUMN `tenant_id` DROP DEFAULT;
-- (Repeat for all tables)
```

**Middleware pattern — attach tenant to request:**
```javascript
// src/middleware/authMiddleware.js addition
const attachTenant = (req, res, next) => {
  if (!req.user || !req.user.tenant_id) {
    return res.status(401).json({ success: false, message: 'Tenant context missing from token' });
  }
  req.tenantId = req.user.tenant_id;
  next();
};
```

**JWT payload update — include tenant_id at login (server.js):**
```javascript
// In the login route, add tenant_id to the JWT payload
const token = jwt.sign(
  {
    id: user.id,
    role: normalisedRole,
    permissions: getPermissionsForRole(normalisedRole),
    tenant_id: user.tenant_id,   // ADD THIS
  },
  JWT_SECRET,
  { expiresIn: JWT_EXPIRES }
);
```

**Model query pattern — every query must include tenant_id:**
```javascript
// Before (current)
static async getAllJobs(filters = {}) {
  const [rows] = await db.query(`SELECT * FROM jobs WHERE ...`);
}

// After
static async getAllJobs(tenantId, filters = {}) {
  const [rows] = await db.query(`SELECT * FROM jobs WHERE tenant_id = ? AND ...`, [tenantId, ...]);
}
```

### Pattern 2: SELECT ... FOR UPDATE Race Condition Fix (FOUND-02)

**What:** The availability check in `jobAssignmentService.js` runs outside the write transaction, creating a 10-100ms window where concurrent requests both pass the check and both write. Fix by moving the availability check INSIDE the transaction and acquiring row locks with `SELECT ... FOR UPDATE`.

**Confirmed bug location:** `vehicle-scheduling-backend/src/services/jobAssignmentService.js` lines 105-175 — check is before `connection.beginTransaction()`.

```javascript
// Pattern: check-and-write inside a single transaction with row locks
const connection = await db.getConnection();
try {
  await connection.beginTransaction();

  // Lock the vehicle's assignment rows for the target date
  // This prevents any other transaction from reading these rows until commit
  const [existingAssignments] = await connection.query(
    `SELECT ja.id FROM job_assignments ja
     JOIN jobs j ON ja.job_id = j.id
     WHERE ja.vehicle_id = ?
       AND j.scheduled_date = ?
       AND j.current_status NOT IN ('completed', 'cancelled')
     FOR UPDATE`,
    [vehicleId, scheduledDate]
  );

  // Now run overlap check against locked rows
  const conflict = existingAssignments.some(/* overlap logic */);
  if (conflict) {
    await connection.rollback();
    return { success: false, message: 'Vehicle has a conflicting assignment' };
  }

  // Safe to write — row locks prevent concurrent inserts
  await connection.query(`UPDATE jobs SET assigned_vehicle_id = ? WHERE id = ?`, [vehicleId, jobId]);
  await connection.query(`INSERT INTO job_assignments (job_id, vehicle_id, ...) VALUES (?, ?, ...)`, [...]);

  await connection.commit();
} catch (err) {
  await connection.rollback();
  throw err;
} finally {
  connection.release();
}
```

**Important:** `FOR UPDATE` requires InnoDB tables (confirmed — schema uses `ENGINE=InnoDB`). It will NOT work with MyISAM.

### Pattern 3: Atomic Job Number Generation (FOUND-03)

**What:** Replace the `MAX(job_number)` + increment pattern with a dedicated sequence table. Atomic increment via `UPDATE ... SET counter = counter + 1` returns the new value in a single database round trip.

**Confirmed bug location:** `vehicle-scheduling-backend/src/models/Job.js` lines 809-843.

```sql
-- Create sequence table (add to migration script)
CREATE TABLE IF NOT EXISTS `job_number_sequences` (
  `year`     YEAR NOT NULL,
  `counter`  INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert current year seed (use current max to avoid collisions)
INSERT INTO `job_number_sequences` (`year`, `counter`)
VALUES (YEAR(CURDATE()), 14)   -- 14 = current max job count from test data
ON DUPLICATE KEY UPDATE `counter` = `counter`;
```

```javascript
// Atomic increment — no race condition possible
static async generateJobNumber() {
  const year = new Date().getFullYear();
  // Single atomic operation: increment and return new value
  const [result] = await db.query(
    `INSERT INTO job_number_sequences (year, counter) VALUES (?, 1)
     ON DUPLICATE KEY UPDATE counter = counter + 1`,
    [year]
  );
  // result.insertId is 0 on UPDATE path; use a SELECT to get the value
  const [[seq]] = await db.query(
    `SELECT counter FROM job_number_sequences WHERE year = ?`,
    [year]
  );
  return `JOB-${year}-${String(seq.counter).padStart(4, '0')}`;
}
```

**Note:** The INSERT + SELECT is still two queries. For true atomicity, use a stored procedure or `LAST_INSERT_ID(counter + 1)` trick:
```sql
UPDATE job_number_sequences SET counter = LAST_INSERT_ID(counter + 1) WHERE year = ?;
-- Then: SELECT LAST_INSERT_ID() returns the NEW counter value in the same connection
```

### Pattern 4: JWT Secret Startup Guard (FOUND-04)

**What:** Add a hard startup check that terminates the process if `JWT_SECRET` is not set. Remove the fallback string from both files.

**Files to modify:**
1. `vehicle-scheduling-backend/src/server.js` — line 19
2. `vehicle-scheduling-backend/src/middleware/authMiddleware.js` — line 9

```javascript
// src/server.js — add at the top, BEFORE app initialization
// Fail fast: if critical env vars are missing, crash immediately
const requiredEnvVars = ['JWT_SECRET'];
for (const varName of requiredEnvVars) {
  if (!process.env[varName]) {
    console.error(`FATAL: Required environment variable "${varName}" is not set. Aborting.`);
    process.exit(1);
  }
}

// Remove the fallback:
// BEFORE: const JWT_SECRET = process.env.JWT_SECRET || 'vehicle_scheduling_secret_2024';
// AFTER:
const JWT_SECRET = process.env.JWT_SECRET;
```

```javascript
// src/middleware/authMiddleware.js — line 9
// BEFORE: const JWT_SECRET = process.env.JWT_SECRET || 'vehicle_scheduling_secret_2024';
// AFTER:
const JWT_SECRET = process.env.JWT_SECRET;
// (startup guard in server.js ensures this is never undefined at runtime)
```

### Pattern 5: Helmet + Rate Limiter (FOUND-05)

**What:** Add `helmet` for HTTP security headers and `express-rate-limit` with a strict limit on the login route and a general API limit.

**Where in server.js:** Immediately after `app.use(cors(...))` and before routes.

```javascript
// src/server.js additions
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');

// Security headers — protects against XSS, clickjacking, MIME sniffing
app.use(helmet());

// General API rate limit — 200 requests per IP per 15 minutes
const apiLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 200,
  standardHeaders: true,      // Return rate limit info in headers
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' },
});
app.use('/api', apiLimiter);

// Strict login rate limit — 10 attempts per IP per 15 minutes
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many login attempts, please try again in 15 minutes.' },
  skipSuccessfulRequests: true,  // Don't count successful logins against the limit
});
// Apply BEFORE the login route definition
app.post('/api/auth/login', loginLimiter, async (req, res) => { ... });
```

### Pattern 6: express-validator (FOUND-06)

**What:** Add schema validation at the route layer. Return field-level 400 errors before any business logic runs.

**Routes to add validation to (confirmed from codebase):**
- `POST /api/jobs` — create job
- `PUT /api/jobs/:id` — update job
- `POST /api/job-assignments/assign` — assign vehicle
- `PUT /api/job-status/:id` — update status
- `POST /api/vehicles` — create vehicle
- `PUT /api/vehicles/:id` — update vehicle
- `POST /api/users` — create user (if exists)

```javascript
// src/middleware/validate.js — shared validation error handler
const { validationResult } = require('express-validator');

const validate = (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({
      success: false,
      message: 'Validation failed',
      errors: errors.array(),
    });
  }
  next();
};

module.exports = validate;
```

```javascript
// src/routes/jobs.js — example validation chain for POST /jobs
const { body } = require('express-validator');
const validate = require('../middleware/validate');

const createJobValidation = [
  body('job_type').isIn(['installation', 'delivery', 'miscellaneous'])
    .withMessage('job_type must be installation, delivery, or miscellaneous'),
  body('customer_name').isString().trim().isLength({ min: 2, max: 100 })
    .withMessage('customer_name must be 2-100 characters'),
  body('customer_address').isString().trim().notEmpty()
    .withMessage('customer_address is required'),
  body('scheduled_date').isDate({ format: 'YYYY-MM-DD' })
    .withMessage('scheduled_date must be YYYY-MM-DD format'),
  body('scheduled_time_start').matches(/^\d{2}:\d{2}(:\d{2})?$/)
    .withMessage('scheduled_time_start must be HH:MM or HH:MM:SS'),
  body('scheduled_time_end').matches(/^\d{2}:\d{2}(:\d{2})?$/)
    .withMessage('scheduled_time_end must be HH:MM or HH:MM:SS'),
  body('estimated_duration_minutes').isInt({ min: 1, max: 1440 })
    .withMessage('estimated_duration_minutes must be 1-1440'),
  body('priority').optional().isIn(['low', 'normal', 'high', 'urgent'])
    .withMessage('priority must be low, normal, high, or urgent'),
  body('destination_lat').optional().isFloat({ min: -90, max: 90 })
    .withMessage('destination_lat must be -90 to 90'),
  body('destination_lng').optional().isFloat({ min: -180, max: 180 })
    .withMessage('destination_lng must be -180 to 180'),
];

router.post('/', verifyToken, requirePermission('jobs:create'), createJobValidation, validate, jobController.create);
```

### Pattern 7: TZ=UTC in Docker (FOUND-07)

**What:** Ensure the Node.js process always runs in UTC by setting `TZ=UTC` in the Docker environment. Add `tenant_timezone` to the `tenants` table so display timezone is stored separately from storage timezone.

**Dockerfile addition:**
```dockerfile
# In Dockerfile (or docker-compose.yml environment section)
ENV TZ=UTC
```

**docker-compose.yml environment section:**
```yaml
services:
  api:
    environment:
      - TZ=UTC
      - NODE_ENV=production
      # ... other vars
```

**MariaDB pool config — enforce UTC at connection level:**
```javascript
// src/config/database.js — add timezone to pool config
const pool = mysql.createPool({
  host: process.env.DB_HOST || 'localhost',
  // ... other config
  timezone: '+00:00',       // Force UTC for all queries in this pool
  // ... rest of config
});
```

**tenant_timezone column** is added to the `tenants` table in FOUND-01 migration (already documented above). The column stores IANA timezone strings (e.g., `'Africa/Johannesburg'`) for display-layer conversion in the Flutter app.

### Pattern 8: GROUP_CONCAT Fix (FOUND-08)

**What:** Set `group_concat_max_len = 65536` per connection before any query that uses `GROUP_CONCAT`. This prevents silent truncation of technician lists.

**Confirmed bug locations:**
- `vehicle-scheduling-backend/src/models/Job.js` line ~104 (`_technicianSubquery`)
- `vehicle-scheduling-backend/src/services/jobAssignmentService.js` line ~594 (`getAssignmentDetails`)

**Option A — per-query wrapper (minimal disruption):**
```javascript
// Wrap GROUP_CONCAT queries
const connection = await db.getConnection();
try {
  await connection.query('SET SESSION group_concat_max_len = 65536');
  const [rows] = await connection.query(/* your GROUP_CONCAT query */);
  return rows;
} finally {
  connection.release();
}
```

**Option B — pool-level init query (preferred, set once for all connections):**
```javascript
// src/config/database.js
const pool = mysql.createPool({
  // ... existing config
  // MariaDB/MySQL: run this on every new connection
});

// Hook into connection creation
pool.on('connection', (connection) => {
  connection.query('SET SESSION group_concat_max_len = 65536');
});
```

**Note:** mysql2 pool does not expose a native `on('connection')` event as cleanly as the legacy `mysql` package. The safest approach is to wrap the query function:
```javascript
// src/config/database.js — exported wrapper
async function queryWithGroupConcat(sql, params) {
  const connection = await pool.getConnection();
  try {
    await connection.query('SET SESSION group_concat_max_len = 65536');
    const [rows] = await connection.query(sql, params);
    return rows;
  } finally {
    connection.release();
  }
}
```

### Pattern 9: Database Indexes (FOUND-09)

**What:** Add composite indexes with `tenant_id` as the leading column. Must be added AFTER FOUND-01 completes.

```sql
-- Phase 1 indexes (add to migration script or separate DDL file)

-- Jobs table: primary query patterns
ALTER TABLE `jobs`
  ADD KEY `idx_jobs_tenant_date`   (`tenant_id`, `scheduled_date`),
  ADD KEY `idx_jobs_tenant_status` (`tenant_id`, `current_status`),
  ADD KEY `idx_jobs_tenant_date_status` (`tenant_id`, `scheduled_date`, `current_status`);

-- Job assignments: vehicle availability lookups
ALTER TABLE `job_assignments`
  ADD KEY `idx_ja_tenant_vehicle` (`tenant_id`, `vehicle_id`);

-- Job technicians: technician's job lookups
ALTER TABLE `job_technicians`
  ADD KEY `idx_jt_tenant_user` (`tenant_id`, `user_id`);

-- Users: login lookups
ALTER TABLE `users`
  ADD KEY `idx_users_tenant` (`tenant_id`);

-- Vehicles: availability checks
ALTER TABLE `vehicles`
  ADD KEY `idx_vehicles_tenant` (`tenant_id`);
```

### Pattern 10: Pino Structured Logging (FOUND-10)

**What:** Replace all `console.log` / `console.error` calls with a pino logger instance. Use `pino-http` for automatic HTTP request logging.

```javascript
// src/config/logger.js — singleton logger
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
  transport: process.env.NODE_ENV !== 'production'
    ? { target: 'pino-pretty', options: { colorize: true } }  // Human-readable in dev
    : undefined,  // JSON in production (for log shipping)
});

module.exports = logger;
```

```javascript
// src/server.js — add HTTP request logging
const pinoHttp = require('pino-http');
const logger = require('./config/logger');

app.use(pinoHttp({ logger }));
```

```javascript
// In service files — replace console.log with child logger
const logger = require('../config/logger');

// Instead of: console.log('✅ Job assigned:', jobId)
// Use:
const jobLogger = logger.child({ service: 'jobAssignmentService' });
jobLogger.info({ jobId, vehicleId, assignedBy }, 'Job assigned successfully');

// Instead of: console.error('❌ Assignment failed:', error)
// Use:
jobLogger.error({ err: error, jobId }, 'Job assignment failed');
```

**Files with console.log to replace (confirmed from CONCERNS.md):**
- `vehicle-scheduling-backend/src/services/jobAssignmentService.js` (50+ statements)
- `vehicle-scheduling-backend/src/services/jobStatusService.js`
- `vehicle-scheduling-backend/src/models/Job.js`
- `vehicle-scheduling-backend/src/server.js` (login route)

### Anti-Patterns to Avoid

- **Partial tenant_id migration:** If any table is left without `tenant_id`, Phase 2+ features will create data that cannot be isolated. All tables in one migration script.
- **FOR UPDATE outside transaction:** `SELECT ... FOR UPDATE` has no effect outside `BEGIN ... COMMIT`. Always verify `beginTransaction()` is called first.
- **helmet before CORS:** `helmet` must come AFTER `cors()` in the middleware stack, or the CORS pre-flight headers will conflict with helmet's header policies.
- **Setting GROUP_CONCAT at the pool level via `multipleStatements`:** Enabling `multipleStatements: true` on the pool is a SQL injection risk. Use per-connection `SET SESSION` instead.
- **pino-pretty in production:** The pretty-print transport is slow. Only use it in development (guard with `NODE_ENV !== 'production'`).

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP security headers | Custom header middleware | `helmet` | 15+ headers, CSP, HSTS, all maintained and updated against new CVEs |
| Rate limiting | In-memory counter + timer | `express-rate-limit` | Handles X-Forwarded-For, supports multiple strategies, memory-efficient sliding window |
| Input validation | Manual `if (!req.body.field)` | `express-validator` | Handles type coercion, nested objects, cross-field validation; automatic sanitization |
| Structured logging | `JSON.stringify(console.log)` | `pino` | Async logging, level filtering, child contexts, log rotation integration |
| Sequence generation | `SELECT MAX() + 1` | Sequence table with atomic UPDATE | The MAX+1 pattern is a classic race condition; sequence table is the standard SQL solution |

**Key insight:** All five of these are solved, well-maintained problems. Any custom implementation introduces security gaps or race conditions that the dedicated libraries already handle.

---

## Common Pitfalls

### Pitfall 1: Forgetting `job_status_changes` in the tenant_id migration
**What goes wrong:** All "main" tables get `tenant_id` but junction/audit tables are missed. Status change history becomes unscoped and leaks across tenants.
**Why it happens:** Developers focus on the primary entity tables and miss secondary tables.
**How to avoid:** List ALL tables from `vehicle_scheduling.sql` before writing the migration. Confirmed tables in schema: `jobs`, `job_assignments`, `job_technicians`, `job_status_changes`, `vehicles`, `users`.
**Warning signs:** A query that joins `job_status_changes` returns rows from other tenants.

### Pitfall 2: Helmet CSP blocking Swagger UI
**What goes wrong:** `helmet()` with default settings sets a Content-Security-Policy that blocks the inline scripts and styles used by Swagger UI. The `/swagger` endpoint becomes a blank page.
**Why it happens:** Helmet's default CSP does not whitelist `unsafe-inline` scripts needed by Swagger UI.
**How to avoid:** Disable CSP for the Swagger route, or configure helmet to exclude the `/swagger` path:
```javascript
app.use('/swagger', (req, res, next) => {
  res.setHeader('Content-Security-Policy', '');  // Allow Swagger inline scripts
  next();
}, swaggerUi.serve, swaggerUi.setup(swaggerSpec));
// Apply helmet ONLY to /api routes
app.use('/api', helmet());
```
**Warning signs:** `/swagger` loads but shows blank content with CSP errors in browser console.

### Pitfall 3: Rate limiter blocking the Flutter app on poor connections
**What goes wrong:** A single driver on a flaky mobile network retries the same request 6+ times. The rate limiter flags the IP and returns 429. The driver is locked out.
**Why it happens:** The Flutter http client has a 30-second timeout. On a slow connection, it may retry before the first request completes, causing duplicate requests from the same IP.
**How to avoid:** Use `skipSuccessfulRequests: true` on the login limiter. Set the API limiter threshold high enough (200/15min) that normal app usage never triggers it. Monitor 429 responses in logs.
**Warning signs:** Drivers report "too many requests" errors without having done anything unusual.

### Pitfall 4: FOR UPDATE deadlock on concurrent assignments
**What goes wrong:** Two concurrent transactions both try to lock the same `job_assignments` rows with `FOR UPDATE`. If they acquire locks in different orders (Transaction A locks vehicle 1, Transaction B locks vehicle 2, then each tries to lock what the other has), a deadlock occurs.
**Why it happens:** InnoDB detects the deadlock and rolls back one transaction automatically with `ER_LOCK_DEADLOCK` error code.
**How to avoid:** Always lock resources in a consistent order (e.g., always lock by `vehicle_id ASC` across all assignment operations). Wrap the assignment in a retry loop for `ER_LOCK_DEADLOCK`:
```javascript
const MAX_RETRIES = 3;
let attempt = 0;
while (attempt < MAX_RETRIES) {
  try {
    return await performAssignment(connection, ...);
  } catch (err) {
    if (err.code === 'ER_LOCK_DEADLOCK' && attempt < MAX_RETRIES - 1) {
      attempt++;
      await new Promise(r => setTimeout(r, 50 * attempt));  // backoff
      continue;
    }
    throw err;
  }
}
```
**Warning signs:** Intermittent 500 errors during high-concurrency assignment tests; `ER_LOCK_DEADLOCK` in logs.

### Pitfall 5: express-validator silent pass on missing optional fields
**What goes wrong:** A field marked `.optional()` with no further validation accepts `null`, empty string, or invalid values if not chained with `.notEmpty()` or type checks.
**Why it happens:** `.optional()` means "skip validation if field is absent" — it does NOT mean "accept any value if present."
**How to avoid:** Always chain `.optional()` with a type validator: `body('field').optional().isString().trim().notEmpty()`.
**Warning signs:** Empty string `""` gets saved to the database for fields that should be null when absent.

---

## Code Examples

### Full server.js middleware stack order (FOUND-04, FOUND-05, FOUND-10)

```javascript
// Source: Pattern synthesis from direct server.js analysis + helmet/rate-limit official docs

require('dotenv').config();

// Startup guard — must be before any usage of JWT_SECRET
if (!process.env.JWT_SECRET) {
  console.error('FATAL: JWT_SECRET environment variable is not set');
  process.exit(1);
}

const express     = require('express');
const cors        = require('cors');
const helmet      = require('helmet');
const rateLimit   = require('express-rate-limit');
const pinoHttp    = require('pino-http');
const logger      = require('./config/logger');

const app = express();

// 1. CORS — must come before helmet
app.use(cors({ /* existing config */ }));

// 2. Request logging
app.use(pinoHttp({ logger }));

// 3. Security headers — AFTER cors, BEFORE routes
app.use('/api', helmet());   // Only on API routes, not Swagger

// 4. Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// 5. General rate limit on all API routes
const apiLimiter = rateLimit({ windowMs: 15 * 60 * 1000, max: 200, /* ... */ });
app.use('/api', apiLimiter);

// 6. Swagger (no helmet, no rate limit)
app.use('/swagger', swaggerUi.serve, swaggerUi.setup(swaggerSpec));

// 7. Auth routes (login has its own stricter rate limit applied inline)
// 8. API routes
app.use('/api', routes);
```

### Migration script structure

```sql
-- File: vehicle-scheduling-backend/src/migrations/001_phase1_foundation.sql
-- Run order: 1 (FOUND-01 + FOUND-03 + FOUND-09)

-- Step 1: Tenants table
CREATE TABLE IF NOT EXISTS `tenants` ( ... );
INSERT INTO `tenants` (`id`, `name`, `slug`) VALUES (1, 'Default', 'default');

-- Step 2: Add tenant_id to all tables
ALTER TABLE `jobs` ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `vehicles` ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `users` ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `job_assignments` ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `job_technicians` ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;
ALTER TABLE `job_status_changes` ADD COLUMN `tenant_id` INT UNSIGNED NOT NULL DEFAULT 1 AFTER `id`;

-- Step 3: Sequence table for job numbers
CREATE TABLE IF NOT EXISTS `job_number_sequences` (
  `year`    YEAR NOT NULL,
  `counter` INT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`year`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO `job_number_sequences` (`year`, `counter`)
SELECT YEAR(CURDATE()), COALESCE(MAX(CAST(SUBSTRING_INDEX(job_number, '-', -1) AS UNSIGNED)), 0)
FROM `jobs`
WHERE job_number LIKE CONCAT('JOB-', YEAR(CURDATE()), '-%');

-- Step 4: Composite indexes (AFTER tenant_id columns exist)
ALTER TABLE `jobs`
  ADD KEY `idx_jobs_tenant_date` (`tenant_id`, `scheduled_date`),
  ADD KEY `idx_jobs_tenant_status` (`tenant_id`, `current_status`),
  ADD KEY `idx_jobs_tenant_date_status` (`tenant_id`, `scheduled_date`, `current_status`);

ALTER TABLE `job_assignments`
  ADD KEY `idx_ja_tenant_vehicle` (`tenant_id`, `vehicle_id`);

ALTER TABLE `job_technicians`
  ADD KEY `idx_jt_tenant_user` (`tenant_id`, `user_id`);
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `console.log` for logging | `pino` structured JSON logging | Standard since Node.js 12+ era | Enables log aggregation, filtering, alerting |
| Manual header setting | `helmet` package | Standard since Express 4+ | 1 line replaces 15 manual header calls |
| Manual rate limiting | `express-rate-limit` | Standard since 2015 | In-memory store sufficient for single instance |
| `SELECT MAX() + 1` for sequences | Sequence tables or DB sequences | MySQL 8.0+ has real sequences; workaround needed on MariaDB 10.4 | Eliminates duplicate key errors under concurrency |
| Full table scans | Composite indexes with leading tenant_id | Multi-tenant SaaS standard | 10-100x query performance improvement at scale |

**Deprecated/outdated in this codebase:**
- `bcryptjs`: The codebase imports both `bcryptjs` (line 7 of server.js) and `bcrypt` (in package.json). The native `bcrypt` is faster and preferred. `bcryptjs` is a pure-JS fallback — not needed if native bindings compile. This is out of scope for Phase 1 but should be cleaned up (remove `bcryptjs`, use only `bcrypt`).
- `mysql` (legacy): `package.json` lists both `mysql` and `mysql2`. Only `mysql2` is used in the codebase. The `mysql` package can be removed with `npm uninstall mysql`. Out of scope for Phase 1 but noted.

---

## Open Questions

1. **Does the `users` table have a `tenant_id` column for login scoping?**
   - What we know: The login route in `server.js` queries `users` by email without a tenant filter. This is correct for a single-tenant system.
   - What's unclear: After adding `tenant_id`, should login require a tenant slug/identifier in the request? Or do email addresses remain globally unique across tenants?
   - Recommendation: For Phase 1, keep email globally unique (simpler). The login route adds `tenant_id` to the JWT based on the user's row. This defers multi-tenant login UX to a later phase.

2. **Are there any other SQL files beyond `vehicle_scheduling.sql` and `vehicle_scheduling2.sql`?**
   - What we know: `vehicle_scheduling2.sql` exists in the repo (seen in git status). If it has different table definitions, the migration must account for both.
   - What's unclear: Is `vehicle_scheduling2.sql` a newer schema version or an alternate deployment?
   - Recommendation: Read `vehicle_scheduling2.sql` before writing the final migration to ensure all table variants are covered.

3. **Does the existing Dockerfile exist and where is it?**
   - What we know: The stack doc mentions Docker deployment to AWS EC2 with `node:20-alpine`. A Dockerfile is referenced but its path was not confirmed.
   - What's unclear: Whether `TZ=UTC` needs to be added to an existing Dockerfile or a new one must be created.
   - Recommendation: Glob for `Dockerfile` before implementing FOUND-07.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Jest (not yet installed — see Wave 0 gaps) |
| Config file | none — Wave 0 must create `jest.config.js` |
| Quick run command | `cd vehicle-scheduling-backend && npx jest --testPathPattern="unit" --no-coverage` |
| Full suite command | `cd vehicle-scheduling-backend && npx jest --coverage` |

**Note:** `package.json` currently has `"test": "echo \"Error: no test specified\" && exit 1"`. Wave 0 must install Jest and configure it.

### Phase Requirements to Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| FOUND-01 | All tables have `tenant_id` column after migration | smoke | `mysql -u root -e "DESCRIBE jobs" \| grep tenant_id` | No — Wave 0 |
| FOUND-01 | Query for non-existent tenant_id returns 0 rows | integration | `jest tests/integration/tenantIsolation.test.js` | No — Wave 0 |
| FOUND-02 | Concurrent assignments to same vehicle do not double-book | integration | `jest tests/integration/raceCondition.test.js` | No — Wave 0 |
| FOUND-03 | Concurrent job creation generates unique job numbers | integration | `jest tests/integration/jobNumber.test.js` | No — Wave 0 |
| FOUND-04 | Server exits with non-zero code if JWT_SECRET unset | unit | `jest tests/unit/startupGuard.test.js` | No — Wave 0 |
| FOUND-05 | Response includes X-Frame-Options header | integration | `jest tests/integration/securityHeaders.test.js` | No — Wave 0 |
| FOUND-05 | Login returns 429 after 11 attempts | integration | included in securityHeaders.test.js | No — Wave 0 |
| FOUND-06 | POST /api/jobs with invalid job_type returns 400 | integration | `jest tests/integration/validation.test.js` | No — Wave 0 |
| FOUND-06 | POST /api/jobs with negative duration returns 400 | integration | included in validation.test.js | No — Wave 0 |
| FOUND-07 | Job date does not shift when server TZ=UTC | unit | `jest tests/unit/dateFormatting.test.js` | No — Wave 0 |
| FOUND-08 | Job with 30 technicians returns all 30 in response | integration | `jest tests/integration/groupConcat.test.js` | No — Wave 0 |
| FOUND-09 | EXPLAIN on date+status query uses index (no full scan) | manual | n/a | n/a |
| FOUND-10 | No console.log calls remain in src/ | static | `grep -r "console\.log" vehicle-scheduling-backend/src/ \| wc -l` (expect 0) | n/a |

### Sampling Rate

- **Per task commit:** `cd vehicle-scheduling-backend && npx jest --testPathPattern="unit" --no-coverage`
- **Per wave merge:** `cd vehicle-scheduling-backend && npx jest --coverage`
- **Phase gate:** Full suite green before marking phase complete

### Wave 0 Gaps

- [ ] `vehicle-scheduling-backend/package.json` — add Jest: `npm install -D jest supertest`
- [ ] `vehicle-scheduling-backend/jest.config.js` — Jest config with testEnvironment: node
- [ ] `vehicle-scheduling-backend/tests/unit/` — directory + placeholder
- [ ] `vehicle-scheduling-backend/tests/integration/` — directory + placeholder
- [ ] `vehicle-scheduling-backend/tests/unit/dateFormatting.test.js` — covers FOUND-07
- [ ] `vehicle-scheduling-backend/tests/integration/tenantIsolation.test.js` — covers FOUND-01
- [ ] `vehicle-scheduling-backend/tests/integration/raceCondition.test.js` — covers FOUND-02
- [ ] `vehicle-scheduling-backend/tests/integration/jobNumber.test.js` — covers FOUND-03
- [ ] `vehicle-scheduling-backend/tests/integration/securityHeaders.test.js` — covers FOUND-05
- [ ] `vehicle-scheduling-backend/tests/integration/validation.test.js` — covers FOUND-06
- [ ] `vehicle-scheduling-backend/tests/integration/groupConcat.test.js` — covers FOUND-08

---

## Sources

### Primary (HIGH confidence)
- Direct inspection of `vehicle-scheduling-backend/src/server.js` — JWT fallback confirmed line 19
- Direct inspection of `vehicle-scheduling-backend/src/middleware/authMiddleware.js` — JWT fallback confirmed line 9
- Direct inspection of `vehicle_scheduling.sql` — all table structures, no tenant_id, no indexes on date/status
- Direct inspection of `vehicle-scheduling-backend/package.json` — confirmed packages installed/missing
- `.planning/codebase/CONCERNS.md` — confirmed race condition, GROUP_CONCAT, console.log locations
- `.planning/codebase/STACK.md` — confirmed Node.js, Express, MariaDB stack
- `.planning/research/PITFALLS.md` — race condition specifics (lines 105-175 in jobAssignmentService.js)
- npm registry — helm 8.1.0, express-rate-limit 8.3.1, express-validator 7.3.1, pino 10.3.1 (verified 2026-03-21)

### Secondary (MEDIUM confidence)
- `.planning/research/ARCHITECTURE.md` — tenant_id migration patterns, middleware chain recommendation
- `.planning/research/STACK.md` — competitor stack analysis, SQL schema patterns

---

## Metadata

**Confidence breakdown:**
- Standard stack (packages to install): HIGH — versions confirmed from npm registry
- Architecture (migration patterns): HIGH — based on direct schema inspection and InnoDB documentation
- Race condition fix (FOR UPDATE pattern): HIGH — InnoDB locking behavior is well-documented and stable
- Sequence table pattern: HIGH — standard MariaDB/MySQL pattern for atomic counters
- Pitfalls (helmet/Swagger conflict, rate limiter on mobile): MEDIUM — based on known library behaviors, should be validated during implementation

**Research date:** 2026-03-21
**Valid until:** 2026-06-21 (stable libraries; helmet/express-rate-limit APIs are very stable)
