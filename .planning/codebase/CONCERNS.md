# Codebase Concerns

**Analysis Date:** 2026-03-21

## Tech Debt

### 1. Excessive Console Logging in Production Code

**Issue:** Backend code contains 254 console.log/console.error statements throughout production code paths.

**Files:** `vehicle-scheduling-backend/src/**/*.js` (particularly `src/services/jobAssignmentService.js`, `src/models/Job.js`)

**Impact:** Console logs pollute production logs and impact performance. In high-concurrency scenarios, logging overhead becomes measurable. No log levels (info, warn, error) are used—all statements are at the same level, making it impossible to filter logs by severity.

**Fix approach:**
- Implement structured logging using a library like `winston` or `pino`
- Replace console.log calls with proper debug/info/warn/error levels
- Add log level configuration via environment variable (DEBUG, INFO, WARN, ERROR)
- Remove noisy debug logs (e.g., step-by-step logging in jobAssignmentService.js lines 54-286)
- Keep only essential error logs for production troubleshooting

---

### 2. Multiple Database Drivers Installed (Dead Code)

**Issue:** Both `mysql` (v2.18.1) and `mysql2` (v3.16.3) are installed in dependencies.

**Files:** `vehicle-scheduling-backend/package.json`

**Impact:** Only `mysql2` is actively used (`src/config/database.js` requires `mysql2/promise`). The legacy `mysql` package should not be included, adding unnecessary ~2MB to deployment bundle.

**Fix approach:**
- Remove `mysql` from package.json dependencies
- Run `npm install` to update package-lock.json
- Verify all database calls use `mysql2` (already confirmed)
- Update Dockerfile if base image layer is cached

---

### 3. MySQL 5.6 Compatibility Workarounds Baked In

**Issue:** Code contains fallback logic for MySQL 5.6 (GROUP_CONCAT instead of JSON_ARRAYAGG) despite schema being MySQL 8.0+.

**Files:** `vehicle-scheduling-backend/src/models/Job.js` lines 67-111 (technician parsing logic)

**Impact:** Adds unnecessary complexity to data parsing. The system supports MariaDB 10.4.32 per SQL dump, which supports JSON_ARRAYAGG, but code still handles GROUP_CONCAT format "1|Alice,2|Bob" with fallback parsing.

**Fix approach:**
- Migrate all queries to use `JSON_ARRAYAGG(JSON_OBJECT(...))` syntax
- Remove GROUP_CONCAT fallback parsing (`_parseTechnicians()` logic)
- Update Job model to return native JSON arrays from database
- Simplifies Flutter parsing since it will always receive standard arrays
- Target: Next major version bump

---

## Known Bugs

### 1. Race Condition in Dashboard Loading (Technician View)

**Symptoms:** When a technician opens the dashboard, loading spinners may show inconsistently. If dashboard refresh and job status update occur simultaneously, UI may flicker or show stale counts.

**Files:**
- `vehicle_scheduling_app/lib/screens/dashboard/dashboard_screen.dart` lines 28-30
- `vehicle_scheduling_app/lib/providers/job_provider.dart` lines 5-20

**Trigger:** Rapid navigation to dashboard immediately after job status change, or technician clicking refresh while a background job update is in flight.

**Workaround:** Refresh the screen manually; UI will eventually settle to correct state within 2-3 seconds.

**Root cause:** `_loadDashboard()` for technicians lacks try/catch error handling. If any provider fails to load (JobProvider.isLoading still true while VehicleProvider.isLoading is false), the loading state becomes inconsistent. Additionally, the dashboard checks `jobProvider.isLoading || vehProvider.isLoading`, which doesn't account for partial failure states.

---

### 2. Job Status Update False Failure Messages

**Symptoms:** After assigning a driver to a job from the detail screen, user sees error snackbar "Assignment failed" even though the driver WAS successfully assigned in the backend.

**Files:**
- `vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart` lines 6-16
- `vehicle_scheduling_app/lib/services/api_service.dart` lines 4-20

**Trigger:** Assign driver from job detail screen; check server logs to confirm assignment succeeded, but Flutter shows error toast.

**Workaround:** Dismiss the error and refresh the job detail—the driver assignment persists.

**Root cause:** Two-layer issue:
1. Old code called `assignTechnicians()` then immediately called `loadJobById()` again. The provider's `assignTechnicians()` already internally calls `_reloadSingleJob()`, so the redundant load created race conditions.
2. `ApiService._handleResponse()` threw TypeError when backend returned valid JSON that wasn't a Map (e.g., plain array). Even though the assignment succeeded server-side, Flutter caught the TypeError and reported failure.

**Fix status:** Both issues have been patched in current codebase (see comments in job_detail_screen.dart and api_service.dart). Verify in testing.

---

### 3. Admin Override Feature Was Non-Functional (Now Fixed)

**Symptoms:** Admin selects "Force Override" when assigning a driver already booked on another overlapping job. Backend still rejects with 409 Conflict error instead of force-moving the driver.

**Files:**
- `vehicle-scheduling-backend/src/routes/jobs.js` lines 151-197
- `vehicle-scheduling-backend/src/services/jobAssignmentService.js` lines 301-350
- `vehicle_scheduling_app/lib/screens/jobs/job_detail_screen.dart` lines 18-28

**Trigger:** As admin, open job detail, click "Manage Drivers", select a technician who is assigned to a conflicting job during the same time window, check "Force Override" checkbox, confirm.

**Workaround:** Manually remove the driver from the conflicting job first, then assign them to the target job.

**Root cause:** The force_override flag was being sent by Flutter but never read by the backend route handler. Route handler always called conflict checking without checking the flag first.

**Fix status:** Fixed in current codebase. Route handler now reads `force_override` from request body (line 159 of jobs.js) and passes it to `JobAssignmentService.assignTechnicians()` (line 197). Service layer checks the flag before running conflict validation.

---

## Security Considerations

### 1. JWT Secret Hardcoded with Weak Default

**Risk:** If `.env` file is missing or incomplete, system falls back to hardcoded JWT secret `'vehicle_scheduling_secret_2024'`.

**Files:** `vehicle-scheduling-backend/src/controllers/authController.js` line 16

**Current mitigation:** `.env` file exists in deployment but is not committed. However, if `.env` is lost or new developer forgets to create it, tokens become predictable.

**Recommendations:**
- Make JWT_SECRET required at startup; throw error if missing
- Generate a random secret on first run if none provided (write to .env.local)
- Add validation check in server.js entry point:
  ```javascript
  if (!process.env.JWT_SECRET) {
    throw new Error('JWT_SECRET environment variable is required');
  }
  ```
- Document .env setup in README

---

### 2. Password Hashing Uses bcryptjs (Works but Deprecated)

**Risk:** bcryptjs is a pure JavaScript implementation of bcrypt, slower than native bcrypt. Though secure, bcryptjs version 3.0.3 is relatively new and less battle-tested. Additionally, package.json has BOTH bcrypt (6.0.0) and bcryptjs (3.0.3) installed but only bcryptjs is used.

**Files:**
- `vehicle-scheduling-backend/package.json` lines 15-16 (bcrypt and bcryptjs both installed)
- `vehicle-scheduling-backend/src/controllers/authController.js` line 12 (uses bcryptjs only)

**Current mitigation:** bcryptjs salt round is 10 (acceptable; industry standard is 10-12). Passwords hashed before storage.

**Recommendations:**
- Remove bcrypt from dependencies; keep only bcryptjs
- Add explicit note in code: `bcryptjs is pure JS impl. For high-volume auth, consider migrating to native bcrypt on Linux/Mac servers`

---

### 3. CORS Allows All Localhost Ports

**Risk:** While developer-friendly for local debugging, CORS policy is overly permissive in development.

**Files:** `vehicle-scheduling-backend/src/server.js` (CORS configuration not explicitly shown but mentioned in TECHNICAL_ARCHITECTURE.md line 23)

**Current mitigation:** Only applies to localhost/127.0.0.1. Production should have strict origin whitelist.

**Recommendations:**
- Verify CORS config changes for production deployment
- Document required CORS origins for staging vs production
- Use environment variable to control allowed origins (not hardcoded regex)

---

### 4. No Input Validation Middleware

**Risk:** While individual controllers perform some validation (e.g., `isNaN()` checks), there is no centralized validation schema or middleware.

**Files:** `vehicle-scheduling-backend/src/routes/` (all route files)

**Impact:** Request body validation scattered across controllers. Easy to miss edge cases (negative numbers, oversized strings, malformed JSON arrays). If a new endpoint is added, developer must remember to validate all fields.

**Recommendations:**
- Implement schema validation using `joi` or `zod`
- Create validation middleware for common patterns (job creation, assignment, etc.)
- Apply middleware at route definition level:
  ```javascript
  router.post('/', validateJobCreation, jobController.create);
  ```

---

## Performance Bottlenecks

### 1. Database Lock Contention on High-Concurrency Job Assignments

**Problem:** Multiple dispatchers assigning jobs to the same vehicle/technician simultaneously causes lock timeouts.

**Files:** `vehicle-scheduling-backend/src/services/jobAssignmentService.js` lines 168-271

**Cause:** Conflict checking is done OUTSIDE transaction (good, reduces lock time), but STEP 4 (minimal transaction) still performs multiple writes (DELETE, INSERT × 2, UPDATE) sequentially. Under load, these acquire row locks on jobs, job_assignments, job_technicians tables. If another dispatcher tries to assign at the same moment, they wait for the lock.

**Current bottleneck:** 50-100ms lock hold time. At >5 concurrent assignments, timeouts (default MySQL lock_wait_timeout = 50s) are rare but possible under sustained load.

**Improvement path:**
- Query optimization: batch delete + insert into single statement if possible
- Add connection pooling priority queue (mysql2 pool already configured with 10 connections; verify sufficiency under load)
- Reduce transaction scope further: move job status update outside critical section (accept eventual consistency for status field)
- Add retry logic with exponential backoff for `ER_LOCK_WAIT_TIMEOUT` errors

---

### 2. Dashboard Data Load Triggers Multiple Sequential API Calls

**Problem:** Dashboard loads job counts, vehicle counts, and pending assignments in separate API calls without parallelization or pagination.

**Files:**
- `vehicle_scheduling_app/lib/screens/dashboard/dashboard_screen.dart`
- `vehicle_scheduling_app/lib/providers/job_provider.dart`

**Cause:** Flutter screen calls `loadJobs()`, `loadVehicles()`, `loadDashboardStats()` sequentially. Each call waits for previous one to complete. On slow networks (3G), this can take 4-6 seconds to render dashboard.

**Improvement path:**
- Use `Future.wait()` to parallelize API calls:
  ```dart
  final results = await Future.wait([
    jobProvider.loadJobs(),
    vehicleProvider.loadVehicles(),
    ...
  ]);
  ```
- Implement pagination for large job lists (current query returns all jobs)
- Cache dashboard stats with 30-60 second TTL to reduce API load

---

### 3. Large SQL Joins Without Index Verification

**Problem:** Reports and dashboard queries perform multi-table JOINs (jobs → job_assignments → vehicles → users) without explicit index documentation.

**Files:**
- `vehicle-scheduling-backend/src/models/Job.js` (getJobsByTechnician, getAllJobs with JOINs)
- Database schema `vehicle_scheduling.sql`

**Cause:** SQL dumps provided don't show CREATE INDEX statements. Query planner may be doing full table scans on larger datasets.

**Current impact:** Low (test data set is small). At 10k+ jobs, queries could become slow (table scan vs index seek).

**Improvement path:**
- Audit queries with EXPLAIN PLAN to identify missing indexes
- Add indexes on foreign keys and filter columns:
  ```sql
  CREATE INDEX idx_job_assignments_vehicle ON job_assignments(vehicle_id);
  CREATE INDEX idx_job_technicians_user ON job_technicians(user_id);
  CREATE INDEX idx_jobs_created_by ON jobs(created_by);
  ```
- Document recommended indexes in schema file

---

## Fragile Areas

### 1. Date Serialization (Timezone Handling)

**Why fragile:** MySQL DATE columns are timezone-naive. Node.js JSON.stringify converts JavaScript Date objects to ISO 8601 UTC, which can shift dates by timezone offset. Flutter parses the shifted date.

**Files:** `vehicle-scheduling-backend/src/models/Job.js` lines 19-64

**Safe modification:** The codebase already has defensive date formatting (`_formatDateOnly()`) that uses local date methods (getFullYear, getMonth, getDate) instead of UTC methods. This is the correct approach. BUT developers adding new queries must remember to apply this formatter.

**Test coverage gap:** No tests verify that date serialization preserves the original date across timezones.

**Mitigation:**
- Add JSDoc comment above date-returning queries: "Apply `_formatDateOnly()` to results"
- Add helper method `Job._fixDates()` to centralize the fix
- Unit test: parse date in UTC+2 timezone, verify response contains correct date string

---

### 2. Role Normalization and Permission Mapping

**Why fragile:** Backend role normalization maps `driver` → `technician` but only for legacy data. The system now has four roles: admin, scheduler, dispatcher, technician. Code includes comments about dispatcher potentially mapping to scheduler but this mapping is not currently active.

**Files:**
- `vehicle-scheduling-backend/src/controllers/authController.js` lines 86-87, 142-143
- `vehicle-scheduling-backend/src/config/constants.js` (PERMISSIONS map)

**Safe modification:** Role normalization should only happen in one place (authController._normaliseRole()). BUT permission checking is decentralized—some routes check role directly (`req.user.role === 'admin'`), others use permission strings from AuthProvider.

**Test coverage gap:** No test verifies that permission list changes are reflected in both backend and Flutter. If PERMISSIONS map is updated in constants.js, Flutter still uses cached permissions from JWT.

**Mitigation:**
- Add permission change endpoint that returns fresh permissions without requiring re-login
- Document permission matrix clearly in README (which permissions map to which roles)
- Add test: verify every route permission check against PERMISSIONS map

---

### 3. Multi-Technician Assignment Without Cascade Delete Handling

**Why fragile:** Job can have multiple technicians in `job_technicians` table, but when a job is deleted, the cascade relies on database FK constraint. If an application layer tries to delete a job without the database enforcing the cascade, orphaned technician records remain.

**Files:**
- `vehicle_scheduling.sql` lines 145-200 (job_technicians table definition with FK)
- `vehicle-scheduling-backend/src/models/Job.js` (deleteJob method—if it exists)

**Safe modification:** Always use database-level deletion or ensure application layer also deletes from job_technicians and job_assignments. Current code appears to rely on DB-level cascade, which is correct IF the schema is always enforced.

**Test coverage gap:** No test verifies orphaned records don't exist after job deletion.

**Mitigation:**
- Add explicit DELETE statements in application code before job delete for clarity
- Add data integrity check: `SELECT * FROM job_technicians WHERE job_id NOT IN (SELECT id FROM jobs)`

---

## Scaling Limits

### 1. Connection Pool Size (10 Connections)

**Current capacity:** 10 simultaneous database connections configured in `src/config/database.js` line 29.

**Limit:** At 5 concurrent user sessions each making 2 simultaneous API calls, pool can handle ~10 requests. Beyond that, subsequent requests queue and may timeout if initial requests are slow.

**Scaling path:**
- Monitor connection pool usage in production: log active connection count when queue depth > 0
- Increase to 20-30 if horizontal scaling is not an option
- Implement connection pooling caching at application layer for high-throughput scenarios
- Consider moving to connection proxy (PgBouncer alternative for MySQL)

---

### 2. Single Node.js Process (No Clustering)

**Current capacity:** One Node.js process handles all requests. No load balancing or worker clustering.

**Limit:** Node.js single-threaded event loop maxes out at ~200-300 req/sec on mid-range hardware depending on query complexity.

**Scaling path:**
- Implement Node.js clustering using `cluster` module (spawn one worker per CPU core)
- Or deploy multiple container instances behind load balancer (Kubernetes, Docker Compose)
- Add monitoring of CPU and event loop lag
- Current deployment likely handles this via Docker + AWS (see TECHNICAL_ARCHITECTURE.md line 124), but no explicit configuration shown

---

### 3. No Caching Layer

**Current capacity:** Every dashboard view, job list, vehicle list triggers fresh database queries with no caching.

**Limit:** At >1000 concurrent dashboards, database query load becomes bottleneck. Response times degrade from 200ms to 2000ms+.

**Scaling path:**
- Add Redis caching for frequently-read data: dashboard stats, vehicle list, pending jobs
- Implement cache invalidation on write: when job status changes, invalidate job list cache
- Use short TTL (30-60 sec) for time-series data to balance freshness vs load

---

## Dependencies at Risk

### 1. Old swagger-ui and swagger-jsdoc (Low Risk)

**Packages:** `swagger-ui-express` (5.0.1), `swagger-jsdoc` (6.2.8)

**Risk:** These are not security-critical (documentation only) but are outdated. Latest versions available.

**Impact:** Minor; if Swagger UI is exposed to internet, XSS vulnerabilities in old UI code could be exploited.

**Migration plan:** Update to latest versions as part of next maintenance sprint. Low priority.

---

### 2. flutter google_maps_flutter (v2.10.0 - Requires Testing)

**Package:** `google_maps_flutter` (2.10.0) in pubspec.yaml

**Risk:** Google Maps integration newly added. Plugin requires API key configuration, Android key hashes, iOS bundle IDs, etc. Common source of integration bugs.

**Impact:** If API key is leaked or misconfigured, location data leaks or maps fail to load in production.

**Recommendations:**
- Verify API key is not committed in git
- Use separate API keys for dev/staging/production
- Test maps functionality on actual Android/iOS devices (not just emulator)
- Add documentation for maps setup in README

---

## Missing Critical Features

### 1. No Real-Time Job Updates (WebSockets)

**Problem:** When dispatcher assigns a job to a technician, technician must refresh their "My Jobs" screen to see the new assignment. No push notifications or live updates.

**Blocks:** Operational efficiency. Technicians may miss urgent job assignments for 30+ seconds if they're not actively refreshing.

**Current workaround:** Users manually refresh or wait for auto-refresh timer.

**Implementation path:**
- Add Socket.io or native WebSocket support to backend
- Emit job assignment events to assigned technician's connected client
- Update Flutter to open persistent WebSocket connection on login
- Publish updates to JobProvider to trigger UI rebuild

---

### 2. No Proof-of-Work (Photo Uploads)

**Problem:** Technicians cannot upload photos of completed work. Dispatchers have no way to verify job completion.

**Blocks:** Quality assurance and customer accountability. System is audit-light for completed jobs.

**Current workaround:** Manual email/SMS photo verification outside system.

**Implementation path:**
- Backend: add image upload endpoint (multipart/form-data support)
- Flutter: integrate image picker, compress before upload
- Database: add job_photos table with FK to jobs, URLs to S3 or similar
- See TECHNICAL_ARCHITECTURE.md line 173 for planned extensibility

---

## Test Coverage Gaps

### 1. No Automated Tests (Critical Risk)

**What's not tested:** Entire backend. No unit, integration, or E2E tests.

**Files:** `vehicle-scheduling-backend/package.json` line 8: `"test": "echo \"Error: no test specified\" && exit 1"`

**Risk:** Regressions are caught only in manual testing. Bug fixes (like the admin override fix) are not verified to not break existing functionality.

**Priority:** HIGH

**Recommendations:**
- Set up Jest for backend (add dev dependency)
- Create test suite for critical paths:
  - Job assignment (normal case, conflict case, override case)
  - Authentication (valid login, invalid password, role assignment)
  - Permission checks (technician sees only their jobs, admin sees all)
- Target: 70% coverage of critical paths
- Add pre-commit hook to run tests (prevent untested code from reaching main)
- Estimated effort: 2-3 days for basic suite

---

### 2. Flutter Widget Tests Incomplete

**What's not tested:** JobDetailScreen assignment dialogs, driver conflict UI, admin override checkbox behavior.

**Files:** `vehicle_scheduling_app/test/` (likely empty or minimal)

**Risk:** UI bugs (like the false failure toast) are caught only in manual QA.

**Priority:** MEDIUM

**Recommendations:**
- Add widget tests for:
  - Job detail screen displays technicians correctly
  - Admin override checkbox is only visible to admins
  - Assignment fails with correct error message on conflict
  - Loading spinners show/hide correctly
- Use testWidgets() from flutter_test package

---

### 3. Date Serialization Not Tested Across Timezones

**What's not tested:** Job dates remain unchanged when parsed in different server timezones.

**Files:** `vehicle-scheduling-backend/src/models/Job.js` lines 19-64

**Risk:** If code is deployed to server in different timezone (e.g., UTC vs UTC+2), date shifting bugs re-emerge.

**Priority:** MEDIUM

**Recommendations:**
- Add test: create job with date 2026-03-11, parse response JSON, verify date string is unchanged regardless of server timezone
- Run test with NODE_TZ=UTC and NODE_TZ=+0200 to verify both scenarios

---

*Concerns audit: 2026-03-21*
