# Domain Pitfalls: Vehicle Scheduling & Field Service Management

**Domain:** Vehicle scheduling SaaS for service companies (HVAC, plumbing, electrical, maintenance)
**Stack:** Node.js/Express + Flutter + MySQL
**Researched:** 2026-03-21
**Confidence:** HIGH — findings are grounded in the actual codebase, confirmed bugs, and deep domain knowledge of scheduling systems.

---

## Critical Pitfalls

Mistakes that cause rewrites, data corruption, or catastrophic user trust loss.

---

### Pitfall 1: Race Condition in Conflict Detection

**What goes wrong:** Two schedulers simultaneously assign different jobs to the same vehicle at the same time. Both run the availability check before either write completes. Both pass the check. Both commit. Vehicle ends up double-booked.

**Why it happens:** The current codebase runs conflict detection *outside* the transaction (intentionally, to reduce lock time), then performs the write inside a transaction. This is correct architecture but only safe if the check-then-write gap is protected. Without a database-level unique constraint or an advisory lock on the time slot, two concurrent requests can both pass the check window simultaneously.

**Confirmed in this codebase:** `jobAssignmentService.js` lines 105-165 — availability check is outside the transaction. The write transaction starts at line 175. There is a 10-100ms window where a second concurrent request can pass the same check.

**Consequences:** Dispatcher sees two jobs assigned to one vehicle for 09:00-12:00. Driver arrives at wrong job. Paying customer misses appointment. Trust destroyed on first significant concurrent-user day.

**Prevention:**
1. Add a unique constraint or partial index on `job_assignments` covering `(vehicle_id, scheduled_date, time_overlap)`. MySQL cannot enforce time-range overlaps natively, but an application-level row lock can.
2. Use `SELECT ... FOR UPDATE` on the target vehicle's assignment rows inside the transaction, not outside it. This acquires a pessimistic lock for the duration of the write.
3. Use an advisory lock keyed on `vehicle_id + date` (e.g., `GET_LOCK('vehicle_1_2026-03-21', 5)`) in MySQL, held only for the check-and-write pair.
4. Add an application-level Redis distributed lock (when Redis is introduced for notifications anyway) with a 2-second TTL per vehicle-date combination.

**Detection:** Symptom is double-booked vehicles in `job_assignments`. Add a monitoring query: `SELECT vehicle_id, scheduled_date FROM job_assignments ja JOIN jobs j ON ja.job_id = j.id WHERE j.current_status NOT IN ('completed','cancelled') GROUP BY vehicle_id, scheduled_date HAVING COUNT(*) > 1`. Run on a schedule; alert if any row returns.

---

### Pitfall 2: Job Number Generation Race Condition

**What goes wrong:** `generateJobNumber()` queries `MAX(job_number)` for the current year and increments it. Under concurrent job creation, two requests see the same MAX and both generate the same job number. The second INSERT fails with `ER_DUP_ENTRY`.

**Confirmed in this codebase:** `Job.js` lines 809-843. The SELECT and the INSERT are not atomic. The code catches `ER_DUP_ENTRY` and re-throws as a message but does not retry.

**Consequences:** User sees "Job number already exists" error on job creation. They retry. It may work the second time. But if two admins are actively creating jobs simultaneously — common on a busy morning — this will occur regularly.

**Prevention:**
1. Replace the MAX-then-increment pattern with a MySQL `AUTO_INCREMENT` sequence table or a dedicated `job_number_sequences` table with `UPDATE ... RETURNING` semantics using a transaction.
2. Better: generate the human-readable job number at INSERT time using a trigger or stored procedure that atomically increments a counter.
3. Simplest safe fix: use a UUID or timestamp-based job number, and format the human-readable display number as a separate derived field, populated asynchronously after creation.

---

### Pitfall 3: Timezone Shifts Breaking Scheduled Dates

**What goes wrong:** MySQL `DATE` columns are returned as JavaScript `Date` objects. When serialized to JSON via `.toISOString()`, they shift to UTC, which in a UTC+2 timezone moves `2026-03-23` to `2026-03-22T22:00:00.000Z`. Flutter parses the 22nd. Driver gets dispatched to a job one day early.

**Confirmed in this codebase:** This bug already happened and was manually patched (`Job._formatDateOnly()`, `Job.js` lines 18-65). The fix uses local `getFullYear/getMonth/getDate` methods instead of UTC methods to avoid the shift. The comment on line 26 explicitly describes the original failure.

**Why the fix is fragile:** The workaround assumes the Node.js server and MySQL are in the same timezone. If the server is deployed to UTC (standard for cloud servers), and MySQL is in a different timezone, or if `TZ` env variable is unset, the getFullYear/getDate calls will return values in whatever the OS default is. This is unpredictable across deployments.

**Consequences:** Jobs silently shift by one day. Depending on the timezone offset and time of day the server is deployed, every job could appear one day early or one day late to the driver.

**Prevention:**
1. Set `TZ=UTC` explicitly in the Node.js Docker container environment and in `docker-compose.yml`.
2. Set `timezone = 'UTC'` in MySQL configuration (`my.cnf` or in the pool connection options: `timezone: '+00:00'`).
3. Remove the workaround and instead store all dates as `YYYY-MM-DD` strings, never as `DATE` objects. Alternatively, store as `DATETIME` in UTC and strip the time component on read.
4. Add a test: insert a job with `scheduled_date = '2026-03-23'`, read it back, assert the response equals `'2026-03-23'` exactly. Run this test in both UTC and UTC+2 environments.
5. Document the timezone assumption explicitly in `DEPLOYMENT.md` so future server operators do not configure a non-UTC timezone and silently break dates.

**Detection warning sign:** A job appears on the wrong date in the driver's app but is correct in the admin panel. This is the classic symptom of a timezone-dependent rendering difference between environments.

---

### Pitfall 4: JWT Secret Fallback in Production

**What goes wrong:** If the `JWT_SECRET` environment variable is not set, the server falls back to the hardcoded string `'vehicle_scheduling_secret_2024'`. Any actor who reads the source code (GitHub leak, disgruntled employee, dependency audit) can forge tokens for any user, including admin.

**Confirmed in this codebase:** `authMiddleware.js` line 9 and `server.js` line 19. Both have the same fallback string.

**Consequences:** Complete authentication bypass. An attacker can forge a JWT with `role: 'admin'` and gain full system access. All tenant data is exposed.

**Prevention:**
1. On server startup, check `if (!process.env.JWT_SECRET) { console.error('FATAL: JWT_SECRET not set'); process.exit(1); }`. This is a hard stop, not a warning.
2. Remove the fallback string entirely from both files.
3. Add `JWT_SECRET` to a `.env.example` file with a placeholder, and add `.env` to `.gitignore`.
4. In Docker deployment, pass secrets via Docker secrets or environment injection, never bake them into the image.

---

### Pitfall 5: Multi-Tenant Data Leakage

**What goes wrong:** The current schema has no `tenant_id` column on any table. Every query returns data for all users in the database. When the product is sold to a second customer, their data and the first customer's data are visible to each other if they share a database.

**Confirmed in this codebase:** `PROJECT.md` states "Multi-tenancy / white-labeling — architecture should support it, but tenant isolation is v2." The schema (`vehicle_scheduling.sql`) has no tenant isolation columns.

**Why this is critical now:** Adding `tenant_id` to every table and every query after the system is live requires a migration of every existing row and a rewrite of every query. Doing this in v2 is far more costly than doing it in v1. The architectural decision to defer it creates significant rework debt.

**Consequences:** If tenant isolation is retrofitted, every query must be audited. A single forgotten `WHERE tenant_id = ?` clause exposes all other tenants' data. This is the most common source of data breaches in SaaS products.

**Prevention:**
1. Add `tenant_id INT NOT NULL` to all core tables (`jobs`, `vehicles`, `users`, `job_assignments`, `job_technicians`) now, even if only one tenant exists.
2. Set `tenant_id = 1` for all existing rows in the migration.
3. Add `WHERE tenant_id = req.user.tenant_id` to every query. Extract this into a helper or ORM scope.
4. Use a database-level Row Level Security policy if migrating to PostgreSQL later.
5. Create a database user per tenant with access restricted to their rows — the strongest isolation but requires schema changes.

**Detection:** Create two test tenants. Log in as tenant B. Attempt to access a job ID that belongs to tenant A by guessing the numeric ID. If the API returns the job, isolation is broken.

---

## Moderate Pitfalls

---

### Pitfall 6: CORS Locked to Localhost in Production

**What goes wrong:** `server.js` lines 47-60 configure CORS to allow only `localhost` and `127.0.0.1` origins. The Flutter mobile app does not send an `Origin` header (no origin check needed for native apps). But a web dashboard, Swagger UI, or any browser-based admin panel hosted on a real domain will be blocked.

**Confirmed in this codebase:** The callback explicitly calls `callback(new Error('CORS blocked: ' + origin))` for any non-localhost origin. If a web admin panel is deployed at `https://admin.fleetschedulerpro.com`, every request returns a CORS error.

**Prevention:**
1. Add a `ALLOWED_ORIGINS` environment variable (comma-separated list of approved origins).
2. Parse it on startup: `const allowedOrigins = (process.env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim())`.
3. In the CORS callback, check `allowedOrigins.includes(origin)`.
4. In development with `NODE_ENV=development`, fall back to the current localhost-only behavior.

---

### Pitfall 7: No Rate Limiting on Login Endpoint

**What goes wrong:** An attacker can attempt passwords against the login endpoint at machine speed. With a weak or reused password, credential stuffing or dictionary attacks succeed within minutes.

**Confirmed in this codebase:** `CONCERNS.md` Security section documents this gap. `server.js` has no rate limiting middleware on `POST /api/auth/login`.

**Prevention:**
1. Add `express-rate-limit` to the login route: 5 attempts per IP per 15-minute window, then 429 response.
2. Track failed attempts per `username` (not just IP) to catch distributed attacks.
3. Add exponential backoff: after 3 failures, add a 1-second delay. After 5, 5 seconds. After 10, lock for 15 minutes.
4. Log failed login attempts with IP and username to detect attack patterns.

---

### Pitfall 8: No Input Validation Middleware

**What goes wrong:** Route handlers perform ad-hoc checks (required fields, date format) but do not validate enum bounds, string lengths, or numeric ranges. Malformed data reaches the database.

**Confirmed in this codebase:** `CONCERNS.md` tech debt section. The `allowedFields` list in `Job.updateJob()` prevents unknown fields from being written, but does not validate the *values* of known fields. A `priority` of `'nuclear'` or an `estimated_duration_minutes` of `-9999` would be accepted.

**Specific edge cases to catch:**
- `estimated_duration_minutes: -1` — negative duration, makes time gap calculation wrong
- `scheduled_time_end <= scheduled_time_start` — inverted window, passes availability check but creates a zero- or negative-duration job
- `job_type` value not in the DB ENUM — MySQL rejects it, but the error message leaks schema details
- `customer_name` of 1 character — below the minimum defined in `VALIDATION_RULES`
- `destination_lat` outside -90 to 90 range or `destination_lng` outside -180 to 180 — Maps API will fail silently

**Prevention:**
1. Introduce `express-validator` or `joi` schema validation at the route layer.
2. Define schemas as constants and reuse them for create and update routes.
3. Return a consistent 400 response with field-level errors (not a 500 from a DB constraint violation).

---

### Pitfall 9: GROUP_CONCAT Silently Truncates Large Technician Lists

**What goes wrong:** MySQL's `GROUP_CONCAT` has a default `group_concat_max_len` of 1024 bytes. If a job has many technicians (or technicians with long names and emails), the concatenated string is silently truncated. The last technician entry is dropped without error.

**Confirmed in this codebase:** `CONCERNS.md` Scaling Limits section. The `_technicianSubquery` in `Job.js` line 104 uses `GROUP_CONCAT`. The `getAssignmentDetails()` method in `jobAssignmentService.js` line 594 also uses `GROUP_CONCAT` with a `~||` separator format that is even more byte-expensive.

**Consequences:** A technician assigned to a job is silently invisible in the response. The driver opens the app and cannot see their assignment. An admin reviewing the job sees fewer technicians than were assigned.

**Prevention:**
1. Run `SET SESSION group_concat_max_len = 65536;` before any query that uses `GROUP_CONCAT`. Add this to the database pool's `multipleStatements` or run it in a `connection.query` wrapper.
2. Or: replace `GROUP_CONCAT` queries with a separate `SELECT * FROM job_technicians WHERE job_id IN (?)` query and do the join in JavaScript. This is cleaner and scales to any number of technicians.
3. Add a test: assign 30 technicians to a job, fetch the job, assert all 30 appear in `technicians_json`.

---

### Pitfall 10: Conflict Detection Does Not Account for Travel Time

**What goes wrong:** The conflict check in `vehicleAvailabilityService.js` only checks if `startTime < existingEnd AND endTime > existingStart`. It does not add any travel time buffer. A vehicle assigned from 09:00-12:00 in one part of the city can be assigned to a 12:00-15:00 job across town. In reality, the driver cannot arrive at 12:00 exactly.

**Why it happens:** Travel time requires a routing API (Google Maps Directions). The current implementation has coordinates on jobs (`destination_lat`, `destination_lng`) but the backend does not call any routing service.

**Consequences:** Back-to-back jobs look valid in the scheduler but are operationally impossible. Drivers are always late to the second job. The scheduler learns to manually pad time, which defeats the purpose of the system.

**Prevention:**
1. In the short term: add a configurable minimum buffer between jobs per vehicle (e.g., 30 minutes). This is the `BUFFER_TIME_MINUTES: 30` constant already defined in `TIME_CONSTANTS` but never enforced in the conflict check.
2. Apply the buffer in `checkVehicleAvailability()`: instead of checking `startTime < j.scheduled_time_end`, check `startTime < j.scheduled_time_end + BUFFER_TIME_MINUTES`.
3. In the medium term: integrate the Google Maps Directions API to estimate actual travel time between consecutive job locations. Use this as the dynamic buffer.
4. Surface the travel time estimate to the scheduler in the UI before they confirm an assignment.

---

### Pitfall 11: Status Transitions Defined Only in Flutter

**What goes wrong:** Which status transitions are allowed (e.g., `assigned` → `in_progress` but not `pending` → `completed`) is enforced only in the Flutter UI (`job_detail_screen.dart` lines 75-97). The backend `updateJobStatus()` method only checks that the target status is a valid enum value — it does not enforce transition rules.

**Confirmed in this codebase:** `CONCERNS.md` Fragile Areas section. `Job.updateJobStatus()` in `Job.js` line 773 validates only that `newStatus` is in the valid list, not that the transition from the current status is legal.

**Consequences:** Any user who calls the API directly (not through the Flutter app) can move a job from `pending` directly to `completed`, bypassing the `assigned` and `in_progress` states. An audit log record of all intermediate states is lost. Reporting metrics are incorrect.

**Prevention:**
1. Add a `STATE_MACHINE` object to `constants.js` defining allowed transitions:
   ```js
   { pending: ['assigned', 'cancelled'], assigned: ['in_progress', 'cancelled', 'pending'], in_progress: ['completed', 'cancelled'], completed: [], cancelled: [] }
   ```
2. In `Job.updateJobStatus()`, check `STATE_MACHINE[currentStatus].includes(newStatus)` before writing.
3. Remove the transition logic from Flutter — let the backend's allowed-transitions endpoint drive the UI.

---

### Pitfall 12: Offline Handling — No Queue, No Feedback

**What goes wrong:** If a driver's device loses connectivity while marking a job `in_progress` or `completed`, the API call silently fails. The app may show a spinner indefinitely, or show an error without retrying. The job stays `assigned` in the backend. The driver assumes it worked and moves on. The scheduler sees an incomplete job.

**Confirmed in this codebase:** `CONCERNS.md` Missing Critical Features section. `api_service.dart` throws an `ApiException` on timeout but there is no retry queue. The `JobProvider.updateJobStatus()` does an optimistic local update but if the network call fails, the local state reflects `in_progress` while the backend still shows `assigned`.

**Consequences:** Driver and dispatcher see different statuses. The dispatcher manually calls the driver. The driver says "I marked it done on my phone." Dispatcher must manually correct. This happens in precisely the locations (remote job sites, basements, industrial areas) where the app is most used.

**Prevention:**
1. Implement a local command queue using Hive or SQLite in Flutter. When a status update fails due to network, store the intent locally.
2. On reconnection (monitor connectivity with `connectivity_plus`), replay the queue.
3. Show the driver a visual indicator: "Saved locally, syncing..." rather than an error.
4. Add a version/timestamp check on sync: if the server status is already further along (e.g., another device updated it), detect the conflict and show a reconciliation prompt.

---

### Pitfall 13: Push Notification Delivery Is Not Guaranteed

**What goes wrong:** Firebase Cloud Messaging (FCM) is a best-effort delivery system. Notifications can be dropped if the device is offline, has a dead token, or the app is killed by the OS. On Android, DOZE mode delays background notifications. On iOS, APNs can silently drop notifications under poor conditions.

**Why it matters here:** The product requires `NOTIF-01` (notify driver when job starts) and `NOTIF-02` (notify when job is overdue). If FCM drops these, the driver misses a job or a time-sensitive alert. This is the core value proposition.

**Prevention:**
1. Never rely solely on push notifications for critical state. Notifications are a convenience layer on top of the source of truth (the database).
2. When the driver opens the app, always fetch current job state from the API regardless of what the notification said.
3. Implement a notification delivery confirmation: when the driver's device receives a notification, send a receipt to the backend. If no receipt arrives within N minutes, fall back to SMS (Twilio) or email.
4. Store all notifications in a `notifications` table with `delivered_at` and `read_at` timestamps. Build an in-app notification center (NOTIF-04) that always shows accurate state even when push failed.
5. Track FCM token freshness: tokens expire or rotate. On every app startup, re-register the FCM token and update it in the backend.

---

### Pitfall 14: Battery Drain from GPS Tracking

**What goes wrong:** Continuous GPS polling at high frequency (`geolocator` with `LocationAccuracy.high` and 1-second intervals) drains a device battery in 2-3 hours. A field technician's full workday is 8 hours. The device dies mid-shift. The driver cannot receive notifications or update job status.

**Why it matters here:** The product includes `GPS-02` (live driver tracking) and `GPS-04` (location snapshot on completion). These require GPS access.

**Prevention:**
1. Use adaptive GPS polling: high frequency (every 5 seconds) only when a job is `in_progress`. Drop to low frequency (every 2-5 minutes) when the driver is idle or travelling between jobs.
2. Use `LocationAccuracy.medium` or `LocationAccuracy.low` for background updates. Reserve `high` for the brief moment of job completion geo-capture.
3. Use geofencing (enter job site boundary triggers `arrived` status) instead of continuous polling where possible.
4. Implement a background isolate for GPS tracking to avoid draining the UI thread.
5. Test with actual devices over a full 8-hour shift, not just in the emulator. Emulators do not simulate battery accurately.
6. On Android, use `WorkManager` for background location updates to be compatible with DOZE mode and battery optimization.

---

### Pitfall 15: GPS Privacy and Employee Tracking Laws

**What goes wrong:** Tracking employee location without consent, or tracking outside working hours, is illegal in multiple jurisdictions. South Africa (POPIA), the EU (GDPR Article 9), the UK (UK GDPR), and US states (California CCPA) all regulate biometric and location data collection from employees. Even in jurisdictions with lighter regulation, courts have ruled that continuous GPS tracking of employees constitutes disproportionate monitoring.

**Why it matters for this product:** The product is designed to be sold to service companies. Those companies may operate in any jurisdiction. If the product enables a customer to illegally track their employees, the customer faces fines and the software vendor may face liability for enabling it.

**Specific risks in this codebase:**
- `GPS-02` (live driver tracking) with no time-bounding means location is recorded even after the driver clocks out.
- `GPS-03` (admin controls visibility toggle) addresses the scheduler-visible angle but not the data collection angle.
- `GPS-04` (location snapshot on completion) must obtain consent before capturing.

**Prevention:**
1. Track location only during scheduled job windows. If the job is `completed` or `cancelled`, stop all GPS updates for that device.
2. Add a consent screen on driver app first launch: "This app tracks your location during active job shifts. Do you consent?" Store the consent decision with a timestamp.
3. Add an opt-out mechanism: driver can pause tracking. The system records the pause (for audit) but respects the choice.
4. Do not store GPS coordinates beyond 30 days without explicit business justification.
5. Add a `data_retention_policy` configuration per tenant. Implement automatic purge of location history older than the policy period.
6. Include privacy policy and data processing agreement templates in the product's onboarding documentation.
7. For GDPR compliance (if selling to EU tenants): implement a "right to erasure" endpoint that deletes all location history for a given driver.

---

### Pitfall 16: Notification Fatigue

**What goes wrong:** If every job status change, every assignment, every overdue alert, and every system event sends a push notification, drivers and schedulers will disable notifications within a week. Disabled notifications mean critical alerts are also missed.

**Prevention:**
1. **Batch similar notifications.** If three jobs are reassigned in 2 minutes, send one "3 jobs updated" notification, not three separate pushes.
2. **Prioritize critically.** Distinguish between informational notifications (job assigned, 2 hours away) and urgent ones (job overdue, customer waiting). Use different notification channels on Android with different importance levels.
3. **Let users control their preferences.** Each user should be able to select which event types trigger a notification, and whether it is push, in-app, or email.
4. **Silent push for low-priority state sync.** Use FCM data-only messages (silent push) to sync state in the background without showing a notification. Reserve visible notifications for things requiring human action.
5. **Quiet hours.** Allow users to configure a "do not disturb" window (e.g., 22:00-07:00). Queue notifications and deliver them at the start of the next working window.
6. **Notification deduplication.** If a driver has already seen a "job starting in 15 minutes" notification and opened the app, do not send the "job starting now" notification as well.

---

### Pitfall 17: Performance Collapse Under Real Data Volume

**What goes wrong:** The current `getAllJobs()` query includes a correlated `GROUP_CONCAT` subquery for every row (the `_technicianSubquery` getter). At 1,000 jobs, this is 1,000 additional sub-selects per call. At 10,000 jobs, the query becomes the bottleneck for all schedulers.

**Confirmed in this codebase:** `CONCERNS.md` Performance Bottlenecks — N+1 Query Pattern. `Job.js` lines 104-111.

**Secondary performance issues found in this codebase:**
- `scheduled_date` and `current_status` are used in WHERE clauses across every query but may not be indexed (SQL schema shows no explicit index declarations on these columns).
- The availability check runs multiple separate queries before each assignment (validate job, validate vehicle, check conflicts, check driver conflicts). Under concurrent load, this generates 4-8 queries per assignment request.
- Flutter loads all jobs into memory with no pagination. `JobProvider._jobs` grows unboundedly.

**Prevention:**
1. Add indexes immediately: `CREATE INDEX idx_jobs_date_status ON jobs(scheduled_date, current_status);`
2. Add index: `CREATE INDEX idx_job_assignments_vehicle ON job_assignments(vehicle_id);`
3. Add index: `CREATE INDEX idx_job_technicians_user ON job_technicians(user_id);`
4. Implement pagination on `GET /api/jobs`: add `page` and `limit` query parameters, default limit 100.
5. In Flutter, implement `ListView.builder` with lazy loading. Fetch the next page when the user scrolls near the bottom.
6. Replace the correlated subquery with a JOIN-based approach for the reporting endpoints where large result sets are expected.
7. Add a Redis cache for the availability check results with a 30-second TTL. Invalidate on any job write.

---

### Pitfall 18: Load Testing Never Done — Discovering Limits in Production

**What goes wrong:** The system is developed and tested against a handful of test records. The first real customer has 50 drivers, 200 daily jobs, and 5 schedulers working simultaneously. The system exhibits lock timeouts, slow responses, and connection pool exhaustion on the first morning of real use.

**Confirmed in this codebase:** `CONCERNS.md` Test Coverage Gaps — No Load/Performance Tests.

**Current connection pool limit:** `database.js` sets `connectionLimit: 10`. With 5 schedulers each making 3-4 concurrent requests, this is exceeded. The pool queues requests but with `queueLimit: 0` (unlimited), it will queue indefinitely under sustained load rather than failing gracefully.

**Prevention:**
1. Run a load test before the first customer deployment using k6 or Artillery. Simulate 20 concurrent schedulers making assignment requests. Identify the breaking point.
2. Set `queueLimit` to a reasonable maximum (e.g., 50). Return a 503 "server busy" response when the queue is full — this is better than making clients wait 30+ seconds.
3. Test the specific scenario: 10 concurrent job assignments against the same vehicle time slot. This is the race condition scenario and the transaction lock contention scenario.
4. Profile query performance with `EXPLAIN ANALYZE` before go-live. Ensure no full table scans on the jobs table.

---

## Minor Pitfalls

---

### Pitfall 19: Hardcoded `defaultUserId = 1` in Flutter Config

**What goes wrong:** `app_config.dart` line 132 defines `static const int defaultUserId = 1`. If this value is referenced in production (e.g., as a fallback when `auth_provider` has not yet loaded the real user ID), it assigns actions to user 1 (likely the admin account from test data) instead of the actual logged-in user.

**Prevention:** Remove `defaultUserId` from AppConfig. Every action requiring a user ID must come from `AuthProvider.currentUser.id`. Add an assertion that the user is logged in before any action requiring an ID proceeds.

---

### Pitfall 20: Audit Trail Absent

**What goes wrong:** When a job is cancelled, there is no record of who cancelled it, when, or why. When a driver is swapped off a job, the `job_assignments` row is overwritten — the previous assignment is deleted. If a customer disputes a job outcome, there is no log to review.

**Confirmed in this codebase:** `CONCERNS.md` Missing Critical Features — Audit Trail. `unassignJob()` in `jobAssignmentService.js` runs `DELETE FROM job_assignments WHERE job_id = ?`. The previous assignment record is gone permanently.

**Prevention:**
1. Create a `job_audit_log` table: `(id, job_id, event_type, old_value, new_value, changed_by, changed_at)`.
2. Log every status change, every assignment change, every driver swap.
3. Never delete from `job_assignments`. Instead, add a `is_current BOOLEAN` column and set old assignments to `is_current = FALSE` when replaced.
4. Expose an audit log endpoint for admin users.

---

### Pitfall 21: Feature Bloat Killing UX — The Anti-Pattern for This Domain

**What goes wrong:** Field service apps routinely fail in the market by adding features that satisfy edge-case requests from one client and confuse the other 95%. The driver's view in particular must be extremely simple: my jobs today, in order, with one tap to update status. Anything more — complex filter screens, report generation, user management — on the driver's view is a usability failure.

**Prevention:**
1. Maintain a strict role-based UI: drivers see only their jobs and status update buttons. Schedulers see the calendar/map view. Admins see everything.
2. Resist adding fields to the job creation form "just in case." Each field a scheduler must fill extends job creation time.
3. Measure task completion time for the key flows: create a job (target: under 60 seconds), assign a driver (target: under 10 seconds), driver marks job complete (target: under 5 seconds, single tap).
4. Every feature request should be evaluated: "Does this make the scheduler's job faster, or does it just move complexity from email/phone into the app?"

---

### Pitfall 22: Console Logging in Production

**What goes wrong:** Every job assignment currently logs 20+ `console.log` lines (see `jobAssignmentService.js` from line 54 onward). In production, this floods stdout, fills disk on the server, and contains data (customer names, job numbers, user IDs) in unstructured plain text. Log rotation is not configured. On a cloud server with a few hundred assignments per day, disk fills within weeks.

**Confirmed in this codebase:** `CONCERNS.md` Tech Debt — Console.log Logging.

**Prevention:**
1. Replace `console.log` with a structured logger (Pino is preferred over Winston for Express — faster and JSON-native).
2. Log at appropriate levels: `info` for business events, `debug` for detailed tracing (disabled in production), `error` for failures.
3. Configure log rotation with `logrotate` on the server or use a log shipping solution (Loki, Datadog, CloudWatch).
4. Remove all `print()` statements from the Flutter codebase before release. In Flutter, use `kDebugMode` guards or a logging package.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Push notifications (FCM) | Notification fatigue; FCM token staleness causing missed alerts | Store tokens in DB, refresh on login, implement delivery confirmation, support quiet hours |
| GPS live tracking | Battery drain; privacy law compliance | Adaptive polling frequency; consent screen; track only during active job windows |
| Real-time updates (WebSocket/polling) | Connection pool exhaustion under concurrent users | Use long-polling or SSE before WebSocket; set pool queueLimit; implement heartbeat timeouts |
| Multi-tenant conversion | Data leakage between tenants due to missing WHERE clauses | Add tenant_id to all tables now; create integration test that cross-tenant access returns 404 |
| Offline mode | Race condition between offline queue replay and server-side state | Timestamp all offline actions; implement last-write-wins with conflict detection |
| Scheduling algorithm (auto-suggest rescheduling) | Overlapping suggestions ignoring travel time | Build travel time buffer into suggestion logic from the start; test with realistic city distances |
| Job completion with location capture | GPS permission not granted at completion time | Request permission on app startup; gracefully degrade if denied (record timestamp only, flag for follow-up) |
| Load testing before first real customer | Race conditions and lock timeouts discovered by users | Run k6 load test against staging environment with 20+ concurrent users before go-live |
| Status automation (jobs auto-start at scheduled time) | Server clock drift; cron job reliability | Use a reliable scheduler (node-cron with a lock table); test behavior when cron runs late |
| Reporting across date ranges | Slow queries on large date ranges with no index | Confirm `scheduled_date` index exists; add pagination to all reporting endpoints |

---

## Testing Blind Spots

These are the gaps where bugs will hide if tests are not explicitly written for them:

**Scheduling Logic:**
- Two concurrent requests assigning the same vehicle to overlapping times (race condition test)
- Job assigned 23:30-00:30 that spans midnight — does conflict detection work across days?
- Job on the last day of a month or leap year day — does `generateJobNumber()` work correctly?
- Driver assigned to Job A (09:00-12:00), then Job B (09:00-12:00) with force_override=true — does Job A lose the driver correctly?
- Vehicle deactivated while a future job is already assigned — does the assignment remain visible?

**Timezone:**
- Create a job with `scheduled_date = '2026-12-31'` from a UTC+14 timezone client — does the date save correctly?
- Server running UTC, MySQL running UTC+2 — does date display in Flutter match what was entered?

**Data Integrity:**
- Delete a vehicle that has future assigned jobs — does the API prevent it or cascade correctly?
- A user is deactivated mid-day while they have an in-progress job — what happens to their assignment?
- Two schedulers simultaneously assign different vehicles to the same job — last writer wins, but does the first assignment get properly cleaned up?

**Mobile / Offline:**
- App offline, driver marks job complete, reconnects — does the status sync correctly?
- App offline for 8+ hours (token expires while offline), driver reconnects — does the app refresh the token gracefully or show a login screen with the queued action lost?
- FCM token rotated by OS mid-session — does the backend update the token before the next notification?

**Security:**
- Technician calls `GET /api/jobs/:id` for a job they are not assigned to — does the backend return 403?
- Scheduler calls `DELETE /api/users/:id` — does the backend return 403?
- Unauthenticated request to any protected endpoint — does it return 401 with no data leak?
- JWT with expired signature — does the app redirect to login cleanly or crash?

**Performance:**
- `getAllJobs()` with 10,000 rows — is the response under 500ms?
- 20 concurrent schedulers each making an assignment request — no deadlocks, all succeed or fail cleanly?
- Flutter job list with 5,000 jobs loaded — does scrolling remain at 60fps?

---

## Sources

**Primary source:** Direct analysis of this codebase (2026-03-21).
- `vehicle-scheduling-backend/src/models/Job.js`
- `vehicle-scheduling-backend/src/services/jobAssignmentService.js`
- `vehicle-scheduling-backend/src/services/vehicleAvailabilityService.js`
- `vehicle-scheduling-backend/src/middleware/authMiddleware.js`
- `vehicle-scheduling-backend/src/server.js`
- `vehicle-scheduling-backend/src/config/constants.js`
- `vehicle_scheduling_app/lib/services/api_service.dart`
- `vehicle_scheduling_app/lib/services/job_service.dart`
- `vehicle_scheduling_app/lib/providers/job_provider.dart`
- `vehicle_scheduling_app/lib/config/app_config.dart`
- `vehicle_scheduling_app/pubspec.yaml`
- `.planning/codebase/CONCERNS.md` (prior codebase audit, same date)
- `.planning/PROJECT.md`

**Domain knowledge sources:**
- GDPR Article 9 (special category data), Article 17 (right to erasure) — relevant to GPS tracking
- POPIA (South Africa Protection of Personal Information Act) — relevant to local deployment context
- FCM documentation — best-effort delivery guarantees and token lifecycle
- MySQL documentation — GROUP_CONCAT max length, InnoDB lock behavior, DATE column timezone handling
- Field service management product post-mortems (ServiceTitan, Jobber, FieldEdge public case studies)
