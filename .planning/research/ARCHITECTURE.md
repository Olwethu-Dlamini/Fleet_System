# Architecture Patterns: Vehicle Scheduling SaaS

**Domain:** Field service management / vehicle scheduling SaaS
**Researched:** 2026-03-21
**Codebase version analysed:** Node.js/Express + Flutter + MariaDB 10.4 (brownfield)
**Overall confidence:** HIGH (patterns grounded in direct codebase analysis + established industry practice)

---

## 1. Multi-Tenant SaaS Architecture

### 1.1 Tenancy Model Decision

For a sellable scheduling product there are three classic tenancy models. The recommendation for this codebase is **shared database, shared schema with `tenant_id` column isolation**.

| Model | Isolation | Cost | Migration effort from this codebase |
|-------|-----------|------|--------------------------------------|
| Database-per-tenant | Strongest | Highest (N DB connections, N Docker volumes) | Very high — new infra per customer |
| Schema-per-tenant | Medium | Medium (single DB, N schemas) | High — MySQL has weak schema-switching tooling |
| Shared schema + `tenant_id` | Weakest (but sufficient) | Lowest | **Lowest — add one column, add one middleware** |

**Why shared schema:** The existing tables (`jobs`, `vehicles`, `users`, `job_assignments`, `job_technicians`) are self-contained relational units. Adding `tenant_id INT UNSIGNED NOT NULL` to every table, enforcing it at the ORM/query layer, and indexing it is a two-sprint migration rather than an architectural rewrite. Database-per-tenant becomes attractive only when tenants require regulatory data segregation (e.g., GDPR with data residency clauses) or when individual tenant load is so high it needs its own DB instance — neither applies at the "sellable product" phase.

### 1.2 Tenant Isolation Implementation Pattern

```
users table:  add tenant_id
jobs table:   add tenant_id
vehicles:     add tenant_id
job_assignments:  tenant_id (denormalized for query speed)
job_technicians:  tenant_id
```

Every index that currently exists should become a **composite index** that leads with `tenant_id`:

```sql
-- Before (current)
INDEX idx_jobs_date (scheduled_date)

-- After (multi-tenant safe)
INDEX idx_jobs_tenant_date (tenant_id, scheduled_date)
INDEX idx_jobs_tenant_status (tenant_id, current_status)
```

The Node.js layer enforces tenant isolation through a middleware pattern that attaches `tenant_id` to every request after JWT verification, then all model queries receive `tenant_id` as a mandatory first filter.

```
Request → verifyToken → attachTenant → requirePermission → controller → model(tenantId)
```

The `attachTenant` middleware extracts `tenant_id` from the JWT payload (added at login) and stores it at `req.tenantId`. Every model method signature changes from:

```javascript
// Before
static async getAllJobs(filters = {})

// After
static async getAllJobs(tenantId, filters = {})
// All queries: WHERE tenant_id = ? AND ...
```

This is a mechanical change — tedious but not architecturally complex.

### 1.3 Tenant Registration and Onboarding

A `tenants` table becomes the root entity:

```sql
CREATE TABLE tenants (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  slug          VARCHAR(50) UNIQUE NOT NULL,  -- used in subdomain routing
  plan          ENUM('starter','pro','enterprise') DEFAULT 'starter',
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Admin users (super-admins at the platform level, not tenant admins) get a separate `platform_role` column. Within each tenant, the existing `admin | scheduler | technician` role hierarchy is preserved unchanged.

### 1.4 CORS Update for Multi-Tenant

The current CORS config only allows `localhost`. For multi-tenant SaaS with subdomains (e.g., `acme.yoursaas.com`):

```javascript
// Replace current regex with dynamic lookup
origin: function(origin, callback) {
  if (!origin) return callback(null, true); // server-to-server
  const allowed = /^https:\/\/([a-z0-9\-]+\.)?yoursaas\.com$/;
  if (allowed.test(origin) || /^http:\/\/localhost:\d+$/.test(origin)) {
    return callback(null, true);
  }
  callback(new Error(`CORS blocked: ${origin}`));
}
```

---

## 2. Real-Time Event Architecture

### 2.1 What Needs to Be Real-Time

Based on the codebase analysis, these events require real-time propagation:

| Event | Direction | Consumers | Urgency |
|-------|-----------|-----------|---------|
| Job status change (in_progress, completed) | Server → Admin/Scheduler | Dashboard, job list | High |
| Vehicle assignment / driver hot-swap | Server → Technician | My jobs screen | High |
| GPS location update | Technician device → Server → Admin | Map view | Medium (1-5s lag acceptable) |
| New job created and assigned | Server → Technician | Push notification | High |
| Job cancellation | Server → Technician | My jobs screen | High |

### 2.2 Recommended Transport: Socket.io over WebSocket

**Use Socket.io** (not raw WebSocket, not SSE) because:
- Flutter has `socket_io_client` (maintained, works on all platforms including web)
- Socket.io handles reconnection, room-based pub/sub, and namespace separation automatically
- The existing Express server can host Socket.io in the same process without a separate service

**Architecture pattern: Room-based pub/sub**

```
Server rooms:
  tenant:{tenantId}                   → all users in this tenant
  tenant:{tenantId}:job:{jobId}       → watchers of a specific job
  tenant:{tenantId}:driver:{userId}   → a specific driver's feed
```

When a job status changes in `jobStatusService.js`, after the DB commit, emit:

```javascript
// Inside JobStatusService.updateJobStatus() — after commit
io.to(`tenant:${tenantId}`).emit('job:status_changed', {
  jobId,
  jobNumber: job.job_number,
  oldStatus: currentStatus,
  newStatus,
  changedBy: changedByName,
  changedAt: new Date().toISOString(),
});
io.to(`tenant:${tenantId}:driver:${assignedDriverId}`).emit('my_job:updated', { jobId, newStatus });
```

**Socket.io server setup** (add to `server.js`):

```javascript
const { createServer } = require('http');
const { Server }       = require('socket.io');

const httpServer = createServer(app);
const io         = new Server(httpServer, {
  cors: { origin: allowedOrigins, methods: ['GET', 'POST'] }
});

// Attach io to app so services can access it
app.set('io', io);

io.use((socket, next) => {
  // Verify JWT on socket handshake
  const token = socket.handshake.auth.token;
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    socket.data.user = decoded;
    next();
  } catch (e) {
    next(new Error('Authentication error'));
  }
});

io.on('connection', (socket) => {
  const { tenantId, id: userId } = socket.data.user;
  socket.join(`tenant:${tenantId}`);
  socket.join(`tenant:${tenantId}:driver:${userId}`);
});

httpServer.listen(PORT); // replace app.listen
```

### 2.3 GPS Location Update Pattern

GPS updates are high-frequency writes (every 5-30 seconds per vehicle). Do **not** write every GPS ping directly to MySQL. Use this two-tier pattern:

**Tier 1 — In-memory position store (fast writes)**

A simple in-process Map or Redis hash holds the current position of each vehicle. This is written on every GPS ping with no DB round-trip.

```javascript
// In-process for single-instance; Redis for multi-instance
const vehiclePositions = new Map(); // key: `${tenantId}:${vehicleId}`

io.on('connection', (socket) => {
  socket.on('gps:update', ({ vehicleId, lat, lng, accuracy, heading }) => {
    const key = `${socket.data.user.tenantId}:${vehicleId}`;
    vehiclePositions.set(key, { lat, lng, accuracy, heading, ts: Date.now() });

    // Broadcast to admin/scheduler room — not back to driver
    io.to(`tenant:${socket.data.user.tenantId}`).emit('vehicle:position', {
      vehicleId, lat, lng, heading, ts: Date.now()
    });
  });
});
```

**Tier 2 — Periodic MySQL write (audit trail)**

A background interval flushes significant positions (e.g., every 60 seconds or on job status change) to a `vehicle_location_history` table. This keeps the write rate at ~1/minute instead of ~12/minute per vehicle, which MySQL handles comfortably.

```sql
CREATE TABLE vehicle_location_history (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tenant_id  INT UNSIGNED NOT NULL,
  vehicle_id INT UNSIGNED NOT NULL,
  job_id     INT UNSIGNED,
  lat        DECIMAL(10,7) NOT NULL,
  lng        DECIMAL(10,7) NOT NULL,
  recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_vehicle_date (tenant_id, vehicle_id, recorded_at)
);
```

### 2.4 Push Notifications (FCM)

For driver notifications when offline (app not open), use Firebase Cloud Messaging:

```
Job assigned → jobAssignmentService.js → FCM push to driver's device token
```

Store FCM device tokens in a `user_device_tokens` table:

```sql
CREATE TABLE user_device_tokens (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  tenant_id  INT UNSIGNED NOT NULL,
  user_id    INT UNSIGNED NOT NULL,
  token      VARCHAR(255) NOT NULL,
  platform   ENUM('android','ios','web') NOT NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_platform (tenant_id, user_id, platform)
);
```

Use `firebase-admin` SDK on the Node.js backend. Push notifications complement (not replace) Socket.io — sockets handle foreground updates, FCM handles background.

---

## 3. Scheduling Conflict Resolution Patterns

### 3.1 Current State Assessment

The codebase already has a solid conflict-detection foundation in `VehicleAvailabilityService.checkVehicleAvailability()` and `checkDriversAvailability()`. The core overlap query is correct:

```sql
WHERE ? < j.scheduled_time_end AND ? > j.scheduled_time_start
-- This is the standard half-open interval overlap condition
```

### 3.2 Gaps That Need to Be Closed for SaaS

**Gap 1: Race condition on concurrent assignment**

If two dispatchers (at the same or different browser tabs) both request vehicle availability checks for the same slot within milliseconds, both get "available", and both submit assignments. The current code does not prevent this.

**Fix: Optimistic locking + SELECT FOR UPDATE**

Wrap the availability check and assignment creation in a single transaction using `SELECT ... FOR UPDATE` to lock the vehicle's schedule row:

```javascript
await conn.beginTransaction();

// Lock: prevents concurrent reads from seeing stale availability
const [lockRow] = await conn.query(
  'SELECT id FROM vehicles WHERE id = ? FOR UPDATE',
  [vehicleId]
);

// Now re-check conflicts inside the lock
const conflicts = await checkConflictsWithConnection(conn, vehicleId, date, start, end);
if (conflicts.length > 0) {
  await conn.rollback();
  throw new ConflictError('Vehicle just became booked — please refresh');
}

await conn.query('INSERT INTO job_assignments ...', [...]);
await conn.commit();
```

**Gap 2: No buffer time between jobs**

The system allows back-to-back jobs with zero travel time. For field service, a 15-30 minute buffer is typical.

**Fix: Apply a configurable buffer at the check layer**

```javascript
// In VehicleAvailabilityService
static async checkVehicleAvailability(vehicleId, date, startTime, endTime, options = {}) {
  const bufferMinutes = options.bufferMinutes ?? TENANT_SETTINGS.getBuffer(tenantId);
  const bufferedStart = subtractMinutes(startTime, bufferMinutes);
  const bufferedEnd   = addMinutes(endTime, bufferMinutes);
  // Use bufferedStart/End in the overlap query
}
```

**Gap 3: Admin override does not emit real-time event**

The current `removeDriversFromConflictingJobs()` pattern (admin hot-swap) correctly cleans the DB, but the displaced driver's mobile app will not know until they next poll. Add a real-time emit for each displaced driver.

**Gap 4: `generateJobNumber()` has a race condition**

The current pattern reads the max `job_number LIKE 'JOB-YYYY-%'` and increments it. Under concurrent load, two simultaneous job creations can both read the same max and generate duplicate numbers (though the `UNIQUE` constraint will catch it as an error rather than a silent corruption).

**Fix: Use MySQL's `AUTO_INCREMENT` as the sequence source, or an atomic sequence table:**

```sql
CREATE TABLE job_number_sequences (
  tenant_id INT UNSIGNED NOT NULL,
  year      YEAR NOT NULL,
  next_val  INT UNSIGNED NOT NULL DEFAULT 1,
  PRIMARY KEY (tenant_id, year)
);

-- Application calls this stored procedure atomically:
UPDATE job_number_sequences
SET next_val = LAST_INSERT_ID(next_val + 1)
WHERE tenant_id = ? AND year = YEAR(NOW());

SELECT LAST_INSERT_ID();
```

### 3.3 Priority-Based Conflict Resolution

For future auto-scheduling, implement a **priority score** approach. When the system needs to resolve who gets a vehicle when two jobs conflict:

```
Priority score = base_priority_weight + urgency_bonus + customer_tier_bonus + overdue_penalty
base:  low=1, normal=2, high=3, urgent=4
```

The higher score wins the vehicle; the other is flagged for rescheduling. This is a roadmap feature, not an immediate need.

---

## 4. Time Zone Handling for Multi-Region Deployment

### 4.1 Current Situation and Its Problem

The codebase stores `scheduled_date` as a MySQL `DATE` type and times as `TIME`. The existing `Job._formatDateOnly()` fix uses the **server's local clock** to prevent UTC drift. This works for a single-timezone deployment but breaks when:

- The Node.js server is in UTC (as AWS EC2 is by default)
- A tenant in South Africa (UTC+2) creates a job for "09:00 tomorrow"
- The server interprets "tomorrow" as the UTC day boundary, potentially off by 2 hours

### 4.2 Recommended Pattern: Store UTC, Display Local

**Rule: All timestamps stored in MySQL are UTC. The `scheduled_date` and `scheduled_time_start/end` are stored as naive date/time values that are meaningful only in the tenant's configured timezone.**

This requires:

1. A `timezone` column on the `tenants` table (e.g., `'Africa/Johannesburg'`)
2. All date/time comparisons on the backend use the tenant's timezone context
3. All API responses include the tenant timezone so the Flutter app can display correctly

```javascript
// In every date-sensitive query, apply timezone conversion
const tenantTz = req.tenantTimezone; // attached by middleware

// Convert "now" to tenant local time before comparing to scheduled_date
const nowInTz = DateTime.now().setZone(tenantTz);
const todayInTz = nowInTz.toISODate(); // 'YYYY-MM-DD'
```

Use `luxon` (actively maintained, modern successor to Moment.js) for timezone arithmetic on the Node.js side.

**Do NOT** rely on MySQL's `CONVERT_TZ()` function for this — it requires the MySQL timezone tables to be populated, which is not guaranteed in Docker or managed hosting environments.

### 4.3 Flutter Side

Flutter's `intl` package handles timezone display. The app should receive both:
- The naive date/time strings from the API (`'2026-03-21'`, `'09:00:00'`)
- The tenant's IANA timezone name (`'Africa/Johannesburg'`)

And construct display strings locally using the `timezone` package or the Flutter `intl` package.

### 4.4 What NOT to Do

- Do not use `getFullYear()` / `getMonth()` / `getDate()` (local server time) as the current code does in `_formatDateOnly()`. This is fragile when the server timezone changes or when running in UTC. Instead, always work explicitly with the tenant's configured timezone string.
- Do not store timestamps as varchar date strings — MySQL's `DATE` and `DATETIME` types are correct, but always attach a timezone context when interpreting them.

---

## 5. Database Scaling Patterns for Scheduling Data

### 5.1 The Write Pattern for This System

The scheduling database has an asymmetric read/write pattern:
- **Reads:** High volume (dashboard polling, driver app refreshes, reports)
- **Writes:** Medium volume (status updates, GPS flushes, new jobs)
- **Hot data:** Current day's jobs and the next 7 days
- **Cold data:** Completed/cancelled jobs older than 30 days (needed for reports, not operations)

### 5.2 Read Replica + Primary Separation

When the system reaches multiple tenants with concurrent users, separate read and write traffic:

```
Primary MySQL (writes):
  POST /api/jobs
  PUT  /api/jobs/:id/status
  POST /api/job-assignments

Read Replica (reads):
  GET /api/jobs
  GET /api/dashboard
  GET /api/reports
  GET /api/availability
```

In Node.js, use a connection pool per role:

```javascript
const writePool = mysql.createPool({ host: MYSQL_PRIMARY_HOST, ... });
const readPool  = mysql.createPool({ host: MYSQL_REPLICA_HOST, ... });
```

In `database.js`, export both and let the service layer choose:

```javascript
db.query(sql, params)       // reads
db.writeQuery(sql, params)  // writes
```

### 5.3 Table Partitioning for Jobs

Once `jobs` exceeds ~1M rows per tenant (or ~10M total), partition by date:

```sql
ALTER TABLE jobs
  PARTITION BY RANGE (YEAR(scheduled_date) * 100 + MONTH(scheduled_date)) (
    PARTITION p202601 VALUES LESS THAN (202602),
    PARTITION p202602 VALUES LESS THAN (202603),
    -- ...
    PARTITION pFuture VALUES LESS THAN MAXVALUE
  );
```

This makes monthly archival trivial (`ALTER TABLE jobs DROP PARTITION p202601`) and query pruning automatic for date-range reports.

**Do this proactively when designing the SaaS schema, before data grows.** Retrofitting partitioning onto a live table is painful.

### 5.4 Archival Strategy

`job_status_changes` grows ~5 rows per job lifecycle. At scale this table will be the largest in the system.

**Archival pattern:**
1. Keep 90 days of status history in the live table
2. A nightly background job (Node.js cron via `node-cron`) moves records older than 90 days to a `job_status_changes_archive` table (same schema, no indexes except primary key)
3. Reports that need historical data query both tables via a UNION view

```javascript
// server/jobs/archiveStatusHistory.js
const archiveOldStatusChanges = async () => {
  await db.query(`
    INSERT INTO job_status_changes_archive
    SELECT * FROM job_status_changes
    WHERE changed_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
  `);
  await db.query(`
    DELETE FROM job_status_changes
    WHERE changed_at < DATE_SUB(NOW(), INTERVAL 90 DAY)
  `);
};
```

### 5.5 Indexes to Add Now

The current schema is missing several indexes that will matter at SaaS scale:

```sql
-- Compound indexes after adding tenant_id
ALTER TABLE jobs
  ADD INDEX idx_tenant_date_status (tenant_id, scheduled_date, current_status),
  ADD INDEX idx_tenant_status      (tenant_id, current_status),
  ADD INDEX idx_tenant_created_at  (tenant_id, created_at);

ALTER TABLE job_assignments
  ADD INDEX idx_tenant_vehicle_date (tenant_id, vehicle_id, assigned_at);

ALTER TABLE job_technicians
  ADD INDEX idx_tenant_user (tenant_id, user_id);

ALTER TABLE job_status_changes
  ADD INDEX idx_tenant_changed_at (tenant_id, changed_at);
```

### 5.6 Connection Pooling Configuration

The current Docker deployment likely uses the default `mysql2` pool settings. For a multi-tenant SaaS workload:

```javascript
const pool = mysql.createPool({
  host               : process.env.DB_HOST,
  user               : process.env.DB_USER,
  password           : process.env.DB_PASSWORD,
  database           : process.env.DB_NAME,
  waitForConnections : true,
  connectionLimit    : 20,     // Start here; tune based on DB server RAM
  queueLimit         : 50,     // Reject requests beyond this queue depth
  enableKeepAlive    : true,
  keepAliveInitialDelay: 10000,
});
```

---

## 6. Security Best Practices for Field Service Apps

### 6.1 GPS Data Security

GPS coordinates are legally sensitive PII in most jurisdictions (they reveal where an employee is at all times).

**Access control rules:**
- Technicians should only be able to POST their own location (`user_id` must match JWT `id`)
- Admins/schedulers can read all vehicle positions for their tenant only
- GPS history older than the retention period must be purged (add to archival cron)

```javascript
// GPS write endpoint — enforce self-only rule
router.post('/gps/update', verifyToken, (req, res) => {
  const { vehicleId, lat, lng } = req.body;
  if (req.body.userId !== req.user.id) {
    return res.status(403).json({ error: 'Cannot update another driver\'s location' });
  }
  // ...
});
```

**Encryption at rest:** Enable MySQL encryption for the `vehicle_location_history` table using InnoDB tablespace encryption if the host supports it. As a minimum, encrypt the entire EBS volume on AWS.

**Transmission:** GPS data should only flow over TLS. The current `http://` transport used in the Flutter app config must become `https://` before launch. Never disable SSL verification in Flutter (do not use `HttpClient()` with `badCertificateCallback: (_, __, ___) => true`).

### 6.2 PII Handling

`customer_name`, `customer_phone`, `customer_address` are PII. For SaaS:

- Add a `data_retention_days` setting to the `tenants` table
- Nightly cron: anonymize completed/cancelled jobs older than the retention period (replace with `[REDACTED]`)
- Do not log customer data to application stdout (the current `console.error` calls in models log full error objects that may include query parameters containing customer data)

### 6.3 JWT Hardening

The current JWT setup has several improvements needed for production SaaS:

| Current | Required | Why |
|---------|----------|-----|
| `JWT_SECRET` fallback to hardcoded string | Must be env-only, no fallback | Fallback is published in git |
| 8h token lifetime, no refresh | Add refresh token pattern | Stolen tokens valid for 8h |
| No token blacklisting on logout | Add Redis-backed blacklist or short expiry | Current logout is client-side only |
| `HS256` algorithm | Acceptable for now | `RS256` better for multi-service future |

**Recommended token flow:**

```
Login → issue access_token (15min) + refresh_token (7 days, stored httpOnly cookie)
Expired access → client sends refresh_token → server issues new access_token
Logout → server-side: add access_token jti to Redis blacklist (TTL = remaining token lifetime)
```

### 6.4 Role-Based Access Control Hardening

The existing RBAC system is well-structured. For multi-tenant SaaS, add one more layer:

**Tenant data fencing:** Every database query must verify `tenant_id` matches. Never trust a client-supplied `tenant_id` — always derive it from the verified JWT.

**Privilege escalation prevention:** A user cannot change their own role. The `users:update` permission is admin-only, which is correct, but add an explicit server-side check that rejects any `role` field change made by a non-admin JWT, even if the route is hit through some bypass:

```javascript
// In users route — PUT /api/users/:id
if (updates.role && req.user.role !== 'admin') {
  return res.status(403).json({ error: 'Cannot change role without admin privileges' });
}
```

### 6.5 Input Validation

The codebase uses prepared statements for SQL injection prevention (correct). Add schema-level validation with `Joi` or `zod` at the route layer to reject malformed inputs before they reach the model:

```javascript
const createJobSchema = Joi.object({
  customer_name: Joi.string().min(2).max(100).required(),
  scheduled_date: Joi.string().pattern(/^\d{4}-\d{2}-\d{2}$/).required(),
  scheduled_time_start: Joi.string().pattern(/^\d{2}:\d{2}:\d{2}$/).required(),
  priority: Joi.string().valid('low', 'normal', 'high', 'urgent').required(),
  // ...
});
```

### 6.6 Rate Limiting

Add `express-rate-limit` to prevent brute-force attacks on the login endpoint and to protect the GPS write endpoint from flooding:

```javascript
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,  // 15 minutes
  max: 10,                     // 10 attempts per IP
  message: { error: 'Too many login attempts. Try again in 15 minutes.' }
});
app.post('/api/auth/login', loginLimiter, authHandler);

const gpsLimiter = rateLimit({
  windowMs: 60 * 1000,   // 1 minute
  max: 120,              // 2 updates/second per IP maximum
});
router.post('/gps/update', gpsLimiter, verifyToken, gpsHandler);
```

---

## 7. Common Pitfalls and Anti-Patterns

### 7.1 Critical Pitfalls (cause rewrites or data loss)

**Pitfall: Single-tenant assumption baked into every query**

What goes wrong: All existing queries lack `tenant_id` filtering. When multi-tenancy is added later, any missed filter leaks one tenant's data to another. In a scheduling app, this means Customer A can see Customer B's jobs.

Prevention: Make `tenantId` a mandatory parameter in every model method. A TypeScript migration, or at minimum JSDoc types with `@param {number} tenantId`, makes this harder to forget.

Detection: Write integration tests that create data under tenant A, authenticate as tenant B, and assert that GET endpoints return empty (not tenant A's data).

---

**Pitfall: Storing times without timezone context then running on UTC servers**

What goes wrong: Jobs scheduled for "09:00" in South Africa (UTC+2) get displayed as "07:00" to dispatchers or missed by automated status checks that compare `NOW()` to `scheduled_time_start`.

Prevention: Add `tenant_timezone` to `tenants` table on day one. Use `luxon` everywhere times are compared. See Section 4.

Detection: Run the system with `TZ=UTC node server.js` and test that a job created in the local UI for "09:00 tomorrow" appears as "09:00" (not "07:00 UTC").

---

**Pitfall: Growing `job_status_changes` table without archival**

What goes wrong: At 100 jobs/day with 5 status changes each = 500 rows/day = 180,000 rows/year. At 50 tenants that is 9M rows/year. Queries that scan this table for dashboard activity feeds degrade severely.

Prevention: Add archival from day one (see Section 5.4). Add the `idx_tenant_changed_at` index immediately.

---

**Pitfall: Job number generation race condition**

What goes wrong: Two concurrent job creates both read `MAX(job_number) LIKE 'JOB-2026-%'` as `JOB-2026-0014`, both generate `JOB-2026-0015`, one fails with `ER_DUP_ENTRY`. The error surfaces to the user as a 500.

Prevention: Use the atomic sequence table pattern described in Section 3.2 Gap 4, or use a UUID-based job number where uniqueness is guaranteed without a read-modify-write cycle.

---

**Pitfall: Socket.io on a multi-instance deployment without Redis adapter**

What goes wrong: When the Node.js app is scaled to 2+ instances (horizontally), Socket.io rooms are instance-local. An admin on instance A subscribes to room `tenant:1`. A driver on instance B updates job status. Instance B emits to the room — but instance A never receives it, so the admin's dashboard doesn't update.

Prevention: Install `@socket.io/redis-adapter` from day one, even if running single-instance. It is trivial to add and prevents a production debugging nightmare later.

```javascript
const { createAdapter } = require('@socket.io/redis-adapter');
const { createClient } = require('redis');
const pubClient = createClient({ url: REDIS_URL });
const subClient = pubClient.duplicate();
await Promise.all([pubClient.connect(), subClient.connect()]);
io.adapter(createAdapter(pubClient, subClient));
```

---

**Pitfall: Using `network_mode: host` in Docker for production SaaS**

What goes wrong: The current AWS deployment uses host networking to let the container reach the host MySQL. This works for a single tenant on one server but prevents container-to-container isolation, breaks load balancers, and couples the app to the host network stack.

Prevention: Move MySQL to its own container (or managed RDS) and use a proper Docker bridge network. Set `DB_HOST=mysql` (the service name in docker-compose). For production SaaS, use AWS RDS (managed, backups, multi-AZ).

---

### 7.2 Moderate Pitfalls

**Pitfall: Polling instead of WebSocket for driver updates**

What goes wrong: If the Flutter app polls `GET /api/jobs/my-jobs` every 30 seconds for status updates, at 20 concurrent drivers that is 40 requests/minute just for polling. Under load this degrades API response times for all users.

Prevention: Replace polling with Socket.io subscription for status updates. Keep one poll on app resume (to catch any missed events during disconnection).

---

**Pitfall: Using the same DB connection for transactional and non-transactional code**

What goes wrong: The current services correctly use `db.getConnection()` for transactions and release in `finally`. If a connection is not released on an error path, the pool exhausts under load.

Prevention: Always use try/finally with `conn.release()`. Consider a wrapper utility:

```javascript
async function withTransaction(fn) {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const result = await fn(conn);
    await conn.commit();
    return result;
  } catch (e) {
    await conn.rollback();
    throw e;
  } finally {
    conn.release();
  }
}
```

---

**Pitfall: GROUP_CONCAT truncation on large technician lists**

What goes wrong: The current `_technicianSubquery` uses `GROUP_CONCAT`. MySQL's default `group_concat_max_len` is 1024 bytes. A job with many technicians (the test data shows 18 technicians on one job) where names are long can silently truncate the result, causing the Flutter app to show an incomplete technician list.

Prevention: Set `group_concat_max_len` in the MySQL connection configuration, or migrate to MySQL 8.0's `JSON_ARRAYAGG` (the codebase comment mentions MySQL 5.6 compat, but the actual SQL dump shows MariaDB 10.4, which supports `JSON_ARRAYAGG` with the `JSON_OBJECT` function).

```javascript
await conn.query("SET group_concat_max_len = 65536");
```

---

**Pitfall: Allowing past date scheduling in validation, or blocking it too aggressively**

What goes wrong: `VehicleAvailabilityService.validateInputs()` throws if the date is in the past (`checkDate < today`). This blocks legitimate use cases like: dispatcher creates a job for today at 09:00, it is now 10:00 — the job should still be creatable (it is a record of work done). Equally, blocking past dates on the UI but not on the API means a mobile user with a timezone offset can't create a job legitimately.

Prevention: Move "past date" from a hard error to a warning returned to the client. Let the business decide whether to block it.

---

### 7.3 Minor Pitfalls

**Pitfall: Console.log in production services**

What goes wrong: The services log detailed status transitions with emoji and multi-line console output. In production this creates log noise that buries real errors and exposes job data in log aggregators.

Prevention: Replace all `console.log` / `console.error` with a structured logger (`pino` is the recommended choice for Node.js — fast, JSON output, log levels). Configure log level via `LOG_LEVEL` env var.

---

**Pitfall: Returning full job objects from status update operations**

What goes wrong: `updateJobStatus()` returns the full job with all joins after every status change. For high-frequency operations (driver tapping "start job" → "complete job"), this is a double query (update + full join select) when the caller often only needs `{ success: true, newStatus }`.

Prevention: Offer two response modes: lightweight (`{ success, newStatus, jobId }`) for mobile, full for dashboard. Or use the WebSocket emission as the update signal and return only the lightweight response from REST.

---

**Pitfall: Forgetting to invalidate vehicle availability cache after admin overrides**

What goes wrong: If a caching layer (Redis) is added for `findAvailableVehicles()` results, the admin hot-swap feature that moves drivers between jobs will not invalidate the cache, causing stale availability data to be served.

Prevention: Design cache invalidation alongside caching. Use tag-based invalidation: any write to `job_assignments` or `job_technicians` for `tenant:X` on `date:Y` invalidates `availability:X:Y:*`.

---

## 8. Testing Architecture

### 8.1 Testing Strategy Overview

| Layer | Tool | What to Test | Priority |
|-------|------|--------------|----------|
| Unit | Jest | Service business logic (status transitions, conflict detection, time arithmetic) | High |
| Integration / API | Jest + Supertest | REST endpoints with real DB (test DB in Docker) | High |
| E2E | Playwright | Full dispatcher and driver workflows in browser | Medium |
| Contract | Postman/Newman | API shape regression between backend and Flutter | Medium |
| Load | k6 | Concurrent assignment, GPS flood, dashboard poll | Low (pre-launch) |

### 8.2 API Integration Test Setup

Use a dedicated test database that is seeded fresh for each test suite. The recommended pattern for this Node.js/MySQL stack:

```javascript
// jest.setup.js
const db = require('./src/config/database');

beforeAll(async () => {
  await db.query('SET FOREIGN_KEY_CHECKS = 0');
  await db.query('TRUNCATE TABLE jobs');
  await db.query('TRUNCATE TABLE job_assignments');
  await db.query('TRUNCATE TABLE job_technicians');
  await db.query('TRUNCATE TABLE job_status_changes');
  await db.query('TRUNCATE TABLE vehicles');
  await db.query('TRUNCATE TABLE users');
  await db.query('SET FOREIGN_KEY_CHECKS = 1');
  // Seed minimal fixtures
  await seedTestData();
});

afterAll(async () => {
  await db.end();
});
```

**Test the conflict detection logic directly — this is the most critical business logic:**

```javascript
describe('VehicleAvailabilityService', () => {
  test('detects overlapping time slots correctly', async () => {
    // Seed a job: vehicle 1, 2026-04-01, 09:00–12:00
    await seedJob({ vehicleId: 1, date: '2026-04-01', start: '09:00:00', end: '12:00:00' });

    // Check: 11:00–13:00 should conflict (overlaps 09:00–12:00)
    const result = await VehicleAvailabilityService.checkVehicleAvailability(
      1, '2026-04-01', '11:00:00', '13:00:00'
    );
    expect(result.isAvailable).toBe(false);
    expect(result.conflicts).toHaveLength(1);
  });

  test('does not flag non-overlapping slots', async () => {
    const result = await VehicleAvailabilityService.checkVehicleAvailability(
      1, '2026-04-01', '12:00:00', '14:00:00'
    );
    expect(result.isAvailable).toBe(true);
  });

  test('excludeJobId allows updating an existing assignment', async () => {
    const result = await VehicleAvailabilityService.checkVehicleAvailability(
      1, '2026-04-01', '09:00:00', '12:00:00', existingJobId
    );
    expect(result.isAvailable).toBe(true); // Excluded self, no other conflicts
  });
});
```

**Test status transitions — this is the second most critical:**

```javascript
describe('JobStatusService transitions', () => {
  test.each([
    ['pending', 'assigned', true],
    ['pending', 'in_progress', false],  // Must be assigned first
    ['completed', 'pending', false],    // Final state
    ['cancelled', 'pending', true],     // Reopen
  ])('from %s to %s: allowed=%s', (from, to, expected) => {
    expect(JobStatusService.canTransitionTo(from, to)).toBe(expected);
  });
});
```

### 8.3 Supertest API Tests

```javascript
// tests/api/jobs.test.js
const request = require('supertest');
const app = require('../../src/server');

describe('POST /api/jobs', () => {
  test('scheduler can create a job', async () => {
    const token = await loginAs('scheduler');
    const res = await request(app)
      .post('/api/jobs')
      .set('Authorization', `Bearer ${token}`)
      .send(validJobPayload);

    expect(res.status).toBe(201);
    expect(res.body.data.job_number).toMatch(/^JOB-\d{4}-\d{4}$/);
  });

  test('technician cannot create a job', async () => {
    const token = await loginAs('technician');
    const res = await request(app)
      .post('/api/jobs')
      .set('Authorization', `Bearer ${token}`)
      .send(validJobPayload);

    expect(res.status).toBe(403);
  });
});
```

### 8.4 Playwright E2E Test Architecture

Playwright tests should cover the two primary user journeys:

**Journey 1: Dispatcher creates and assigns a job**
```
1. Login as scheduler
2. Navigate to "New Job" form
3. Fill in customer details, select date/time
4. Submit → assert job appears in job list with status "pending"
5. Navigate to job → click "Assign Vehicle"
6. Select an available vehicle and driver
7. Submit → assert status changes to "assigned"
8. Assert conflict: try to assign same vehicle to overlapping time → expect error toast
```

**Journey 2: Driver updates job status**
```
1. Login as technician
2. Assert job list shows only assigned jobs for this technician
3. Click job → click "Start Job"
4. Assert status shows "in_progress"
5. Click "Complete Job"
6. Assert status shows "completed" and job disappears from active list
```

**Playwright configuration for this stack:**

```javascript
// playwright.config.js
module.exports = {
  testDir: './tests/e2e',
  use: {
    baseURL: process.env.E2E_BASE_URL || 'http://localhost:8080', // Flutter web build
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { browserName: 'chromium' } },
    { name: 'firefox',  use: { browserName: 'firefox' } },
  ],
  webServer: {
    command: 'flutter run -d web-server --web-port 8080',
    port: 8080,
    reuseExistingServer: !process.env.CI,
  },
};
```

**Regression strategy:**

The highest regression risk areas are:
1. The status transition matrix — test all edges (the `test.each` pattern above)
2. Conflict detection edge cases — midnight crossovers, same-minute boundaries
3. Admin override / hot-swap — verify displaced driver's jobs are cleaned correctly
4. Role-based route access — every route, every role combination (use a permission matrix test)

For the permission matrix test, generate tests programmatically from the `PERMISSIONS` constant so they stay in sync:

```javascript
// Generate role × endpoint coverage tests from PERMISSIONS map
Object.entries(PERMISSIONS).forEach(([permission, allowedRoles]) => {
  ALL_ROLES.forEach(role => {
    const shouldAllow = allowedRoles.includes(role);
    test(`${permission} for ${role}: ${shouldAllow ? 'allowed' : 'denied'}`, async () => {
      // ...
    });
  });
});
```

### 8.5 CI Pipeline Recommendation

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    services:
      mysql:
        image: mariadb:10.4
        env:
          MYSQL_ROOT_PASSWORD: test
          MYSQL_DATABASE: vehicle_scheduling_test
    steps:
      - name: Run schema migrations
        run: mysql -u root -ptest vehicle_scheduling_test < vehicle_scheduling.sql
      - name: Unit + Integration tests
        run: npm test
      - name: E2E tests
        run: npx playwright test
```

---

## 9. Recommended Component Boundaries for SaaS Upgrade

```
vehicle-scheduling-backend/
  src/
    config/
      database.js          (add: read pool + write pool)
      constants.js         (add: PLATFORM_ROLES for super-admin)
      tenants.js           (new: tenant settings cache)
    middleware/
      authMiddleware.js    (add: attachTenant, tenantFencing)
      rateLimiting.js      (new)
      validation.js        (new: Joi schemas)
    models/
      Job.js               (add: tenantId param to all methods)
      Vehicle.js           (add: tenantId param)
      Tenant.js            (new)
      UserDeviceToken.js   (new: for FCM)
    services/
      jobStatusService.js  (add: io.emit after commit)
      jobAssignmentService.js (add: io.emit, FCM push)
      gpsService.js        (new: in-memory position store + DB flush)
      notificationService.js (new: FCM abstraction)
      archivalService.js   (new: cron-based data lifecycle)
    realtime/
      socketHandler.js     (new: Socket.io room management)
    routes/
      (existing routes unchanged except adding tenantId threading)
      gps.js               (new)
      webhooks.js          (new: for future integrations)
    jobs/
      archiveStatusHistory.js (new: cron job)
      pruneGpsHistory.js      (new: cron job)
```

---

## 10. Confidence Assessment

| Area | Confidence | Basis |
|------|------------|-------|
| Multi-tenancy patterns | HIGH | Direct codebase analysis + established SaaS pattern |
| Conflict detection gaps | HIGH | Traced through actual code; race condition is provable |
| Socket.io real-time pattern | HIGH | Stable API, Flutter socket_io_client is maintained |
| GPS two-tier architecture | HIGH | Standard IoT pattern, fits this codebase exactly |
| Time zone handling | HIGH | Bug is demonstrable from existing `_formatDateOnly` code |
| DB scaling / partitioning | MEDIUM | Based on MySQL docs; exact thresholds depend on hardware |
| FCM integration | MEDIUM | API is stable; configuration steps require Firebase account setup |
| Playwright E2E with Flutter web | MEDIUM | Flutter web + Playwright is supported but has known rendering quirks |
| Redis adapter for Socket.io | HIGH | Official Socket.io documentation |

---

## Sources

- Direct analysis of `/c/Users/olwethu/Desktop/test/vehicle-scheduling-backend/src/` (March 2026)
- MySQL documentation: InnoDB partitioning, `LAST_INSERT_ID()` atomics, `GROUP_CONCAT` limits
- Socket.io documentation: Redis adapter, authentication middleware, room-based pub/sub
- OWASP Field Security Guide: JWT best practices, rate limiting, GPS PII handling
- Node.js `luxon` library documentation: timezone-aware date arithmetic
- Firebase Admin SDK Node.js documentation: FCM server-side push
- Playwright documentation: `webServer` config, Flutter web integration
