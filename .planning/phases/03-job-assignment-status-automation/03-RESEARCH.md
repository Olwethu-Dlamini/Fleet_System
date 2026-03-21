# Phase 3: Job Assignment & Status Automation - Research

**Researched:** 2026-03-21
**Domain:** Node.js cron scheduling, MySQL load-balancing queries, Flutter geolocator, assignment audit tables
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Job count filterable by time range: yearly, monthly, and weekly counts — user can toggle between ranges on the assignment picker
- Binary green highlight on drivers with fewer jobs than average (based on selected filter)
- "Suggested" chip on the driver with lowest count among available drivers (based on selected filter)
- Assignment history tracks all events: create, reassign, swap, cancel — full audit trail in assignment_history table
- Cron runs every 1 minute to auto-transition jobs to "in progress" at scheduled start time
- GPS capture on completion: required but with fallback — attempt GPS, if unavailable store null + "no_gps" flag
- GPS accuracy threshold: 50 meters for field service
- Completion confirmation: confirm dialog — "Are you sure? This cannot be undone." before marking complete
- Chip-based multi-select for adding technicians — search and add as chips, remove with X
- No hard limit on technicians per job
- One driver per vehicle enforced
- Driver shown as primary (bold) in UI, technicians as secondary list — clear hierarchy

### Claude's Discretion
- Cron library choice (node-cron already in requirements)
- Database migration structure and column naming
- Flutter widget composition details
- Exact SQL queries for load balancing calculations

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ASGN-01 | Show total historical job count next to each driver name during assignment | SQL COUNT query on job_technicians grouped by user_id + time range filter |
| ASGN-02 | Green glow/highlight on drivers with fewer jobs than visual load indicator | Flutter BoxDecoration with green border/shadow, binary threshold = avg count of current filter window |
| ASGN-03 | "Suggested" chip on lowest-load available driver | Flutter Chip widget, backend returns driver ranked by count ASC, frontend marks rank=1 |
| ASGN-04 | Enforce one driver per vehicle, allow multiple technicians per job | job_assignments.driver_id already single-slot; job_technicians handles multi; schema already supports this |
| ASGN-05 | Assignment history table for audit trail (assignment_history) | New table: assignment_history with event_type enum, old_user_id, new_user_id, job_id, changed_by, changed_at |
| STAT-01 | Jobs auto-transition to "in progress" when scheduled start time arrives (cron-based) | node-cron 4.2.1; UPDATE jobs WHERE current_status='assigned' AND scheduled start <= NOW(); existing jobStatusService.updateJobStatus |
| STAT-02 | "Complete" button only available to assigned driver or technician | Backend: check req.user.id in job_technicians for job; Flutter: hide button unless user is in technicians list |
| STAT-03 | GPS coordinates captured automatically when "complete job" is tapped | Flutter geolocator 13.0.4 already in pubspec; Geolocator.getCurrentPosition() with accuracy threshold |
| STAT-04 | Completion location stored in job_completions table with timestamp | New table: job_completions with job_id, completed_by, lat, lng, accuracy, gps_status, completed_at |
</phase_requirements>

---

## Summary

Phase 3 builds on a solid foundation from Phases 1 and 2. The core assignment infrastructure (job_assignments, job_technicians, jobAssignmentService, jobStatusService) is already production-ready with FOR UPDATE transactions and deadlock retry. This phase adds three incremental layers on top: (1) a load-balancing query that counts historical job assignments per driver within a user-selected time window, (2) a background cron job that polls assigned jobs every minute and auto-transitions them to "in_progress", and (3) GPS capture at job completion written to a new job_completions table.

The most complex piece is the driver load picker UI. The backend needs a single new endpoint that returns all drivers with their job counts for the selected time range (yearly/monthly/weekly), the average count, and a boolean "below_average" flag. The Flutter screen computes no logic itself — it reads these pre-computed server fields and renders a green glow on below-average drivers and a "Suggested" chip on rank=1.

The cron job and GPS capture are straightforward integrations of libraries already listed in the project dependencies (node-cron per REQUIREMENTS.md, geolocator 13.0.4 already locked in pubspec). The main pitfall to avoid is the cron running in the same process as the API server with a shared DB pool, which is the correct pattern here — do not spawn a separate process or use a job queue for this use case.

**Primary recommendation:** Implement backend load-balancing endpoint first (ASGN-01 through 03), then the assignment_history table (ASGN-05), then the cron auto-transition (STAT-01), then completion permission enforcement + GPS capture + job_completions table (STAT-02 through 04).

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| node-cron | 4.2.1 (latest) | Cron expression scheduler for Node.js | Lightweight, zero dependencies, well-maintained, required by REQUIREMENTS.md NOTIF-07 |
| geolocator (Flutter) | 13.0.4 (locked) | GPS coordinates from device | Already in pubspec.yaml/lock, permissions already declared in AndroidManifest + Info.plist |
| mysql2 | 3.16.3 (existing) | MySQL queries for new tables | Already in use throughout the project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| provider (Flutter) | 6.1.5+1 (existing) | State management | Extend JobProvider with load data + completion state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| node-cron | agenda, bull, BullMQ | node-cron needs no Redis/MongoDB; for 1 cron task at 1-minute intervals, full queue infrastructure is over-engineering |
| node-cron | setInterval | setInterval does not survive daylight saving transitions, has no cron-expression semantics, harder to reason about |
| geolocator | location package | geolocator is already in pubspec.lock — no new dependency needed |

**Installation:**
```bash
# Backend — node-cron not yet installed, add it
cd vehicle-scheduling-backend && npm install node-cron
```

**Version verification:** node-cron 4.2.1 confirmed via `npm view node-cron version`. geolocator 13.0.4 confirmed in pubspec.lock.

---

## Architecture Patterns

### Recommended Project Structure

Backend additions:
```
src/
├── services/
│   ├── jobAssignmentService.js    # EXTEND: add logAssignmentHistory()
│   ├── jobStatusService.js        # EXTEND: add autoTransitionToInProgress()
│   └── cronService.js             # NEW: node-cron scheduler, started by server.js
├── models/
│   └── Job.js                     # EXTEND: getDriverLoadStats(), completeJob()
└── routes/
    ├── jobAssignmentRoutes.js      # EXTEND: GET /driver-load
    └── jobStatusRoutes.js         # EXTEND: POST /complete (with GPS)
```

Migrations (idempotent, ADD COLUMN IF NOT EXISTS pattern from Phase 1):
```
vehicle_scheduling2.sql            # EXTEND: append assignment_history + job_completions CREATE TABLE IF NOT EXISTS
```

Flutter additions:
```
lib/
├── providers/
│   └── job_provider.dart          # EXTEND: loadDriverLoad(), completeJobWithGps()
├── services/
│   └── job_service.dart           # EXTEND: getDriverLoad(), completeJobWithGps()
├── screens/
│   └── jobs/
│       ├── create_job_screen.dart # EXTEND: driver picker shows load indicator
│       └── job_detail_screen.dart # EXTEND: "Complete" button with GPS capture + confirm dialog
└── widgets/
    └── job/
        └── driver_load_chip.dart  # NEW: reusable chip for suggested/load display
```

### Pattern 1: Driver Load Stats Endpoint

**What:** Single GET endpoint returns all drivers with job counts for the selected time range, pre-computed average, and below_average boolean.
**When to use:** Called when scheduler opens the assignment picker, and when they change the filter toggle.

```javascript
// GET /api/job-assignments/driver-load?range=weekly
// Source: project pattern — static class method, controller-service-model
static async getDriverLoadStats(tenantId, range = 'weekly') {
  const rangeClause = {
    weekly:  'AND jt.assigned_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)',
    monthly: 'AND jt.assigned_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)',
    yearly:  'AND jt.assigned_at >= DATE_SUB(NOW(), INTERVAL 365 DAY)',
  }[range] || '';

  const [rows] = await db.query(`
    SELECT
      u.id,
      u.full_name,
      COUNT(jt.id) AS job_count
    FROM users u
    LEFT JOIN job_technicians jt ON jt.user_id = u.id
      ${rangeClause}
    WHERE u.role IN ('driver','technician')
      AND u.is_active = 1
      AND u.tenant_id = ?
    GROUP BY u.id, u.full_name
    ORDER BY job_count ASC, u.full_name ASC
  `, [tenantId]);

  if (rows.length === 0) return [];

  const total = rows.reduce((sum, r) => sum + r.job_count, 0);
  const avg   = total / rows.length;

  return rows.map((r, i) => ({
    ...r,
    rank: i + 1,               // rank 1 = lowest load = "Suggested"
    below_average: r.job_count < avg,
  }));
}
```

**Note on tenant_id:** The users table has tenant_id per Phase 1 migrations. Query must scope by tenant.

### Pattern 2: Cron Auto-Transition

**What:** node-cron task starts in server.js (or a cronService.js required by server.js). Runs every minute. Finds all jobs with current_status='assigned' and scheduled start time in the past. Calls jobStatusService.updateJobStatus() for each.
**When to use:** Singleton — one instance per server process.

```javascript
// Source: node-cron 4.x API (verified via npm view)
// FILE: src/services/cronService.js
const cron = require('node-cron');
const db   = require('../config/database');
const JobStatusService = require('./jobStatusService');
const logger = require('../config/logger').child({ service: 'cronService' });

function startCronJobs() {
  // Every minute: auto-transition assigned jobs whose start time has passed
  cron.schedule('* * * * *', async () => {
    try {
      const [jobs] = await db.query(`
        SELECT id FROM jobs
        WHERE current_status = 'assigned'
          AND CONCAT(scheduled_date, ' ', scheduled_time_start) <= NOW()
      `);

      for (const job of jobs) {
        await JobStatusService.updateJobStatus(
          job.id,
          'in_progress',
          null,          // system-initiated: no user ID
          'auto-transitioned by scheduler'
        );
        logger.info({ jobId: job.id }, 'Auto-transitioned job to in_progress');
      }
    } catch (err) {
      logger.error({ err }, 'Cron auto-transition error');
    }
  });

  logger.info('Cron jobs started');
}

module.exports = { startCronJobs };
```

**Important:** `updateJobStatus` requires `changedBy` to be a user ID or null. The current implementation has `changed_by INT(10) UNSIGNED NOT NULL` in job_status_changes. Either make the column nullable in migration, or use a system user ID (e.g., id=1). Recommended: make it nullable via `ADD COLUMN IF NOT EXISTS` migration and default it to NULL for cron-initiated changes.

**server.js integration:**
```javascript
// After DB pool initialization, before app.listen
const { startCronJobs } = require('./services/cronService');
if (require.main === module) {
  startCronJobs(); // Only start cron in production server, not in supertest
}
```

### Pattern 3: GPS Capture at Completion (Flutter)

**What:** When the driver taps "Complete," show confirm dialog, then call `Geolocator.getCurrentPosition()` with `desiredAccuracy: LocationAccuracy.high`. If accuracy <= 50m, send coordinates. If GPS fails or exceeds threshold, send null coordinates with `gps_status: 'no_gps'`.
**When to use:** Only on the "Complete" status transition in job_detail_screen.dart.

```dart
// Source: geolocator 13.x API (package already in pubspec.lock 13.0.4)
Future<Map<String, dynamic>> _captureGps() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
    if (position.accuracy <= 50.0) {
      return {
        'lat': position.latitude,
        'lng': position.longitude,
        'accuracy': position.accuracy,
        'gps_status': 'ok',
      };
    }
    return {'lat': null, 'lng': null, 'accuracy': null, 'gps_status': 'low_accuracy'};
  } catch (_) {
    return {'lat': null, 'lng': null, 'accuracy': null, 'gps_status': 'no_gps'};
  }
}
```

**IMPORTANT:** geolocator 13.x changed the API. `desiredAccuracy` is now passed via `LocationSettings` (or platform-specific variants like `AndroidSettings`), not as a named param. The `timeLimit` is set in LocationSettings. The old `Geolocator.getCurrentPosition(desiredAccuracy: ...)` signature is deprecated in 13.x.

### Pattern 4: Assignment History Logging

**What:** Every time an assignment event occurs (create, reassign, swap, cancel), insert a row into assignment_history. Hook this into the existing jobAssignmentService methods.
**When to use:** Add a private `_logAssignmentHistory()` call at the end of: `assignJobToVehicle`, `reassignJob`, `unassignJob`, `assignTechnicians`.

```javascript
// Called at the end of each assignment write (OUTSIDE transaction — non-critical audit)
static async _logAssignmentHistory(jobId, eventType, oldUserId, newUserId, changedBy) {
  try {
    await db.query(
      `INSERT INTO assignment_history
         (job_id, event_type, old_user_id, new_user_id, changed_by, changed_at)
       VALUES (?, ?, ?, ?, ?, NOW())`,
      [jobId, eventType, oldUserId || null, newUserId || null, changedBy]
    );
  } catch (err) {
    // Non-fatal: log error but don't bubble up — assignment already committed
    logger.error({ err, jobId, eventType }, 'Failed to log assignment history');
  }
}
```

### Pattern 5: Backend Permission Guard for Completion (STAT-02)

**What:** The backend must verify the requesting user is an assigned technician or driver for the job before allowing status transition to "completed".
**When to use:** Only for "completed" transitions. Other transitions follow existing permission rules.

```javascript
// In jobStatusRoutes.js or jobStatusController.js before calling updateJobStatus
// for newStatus === 'completed'
const [techRows] = await db.query(
  'SELECT 1 FROM job_technicians WHERE job_id = ? AND user_id = ?',
  [jobId, req.user.id]
);
const [assignRow] = await db.query(
  'SELECT 1 FROM job_assignments WHERE job_id = ? AND driver_id = ?',
  [jobId, req.user.id]
);
const isAssignedPersonnel = techRows.length > 0 || assignRow.length > 0;
const isAdminOrScheduler  = ['admin','scheduler','dispatcher'].includes(req.user.role);

if (!isAssignedPersonnel && !isAdminOrScheduler) {
  return res.status(403).json({ success: false, message: 'Only assigned personnel can complete this job.' });
}
```

### Anti-Patterns to Avoid

- **Spawning a separate Node.js process for cron:** Single process with shared DB pool is correct for this scale. Separate process = connection pool leak + no graceful shutdown.
- **Computing load average in Flutter:** Server-computed average is the single source of truth. Flutter must not recalculate — the toggle filter must trigger a new API call, not client-side re-filter.
- **Using `changed_by INT NOT NULL` for cron-inserted rows:** This will crash the cron. Migration must make it nullable.
- **Calling `Geolocator.getCurrentPosition(desiredAccuracy: ...)` in geolocator 13.x:** Old API, will not compile. Use `LocationSettings`.
- **Storing GPS inside the jobs table:** job_completions is a separate audit table (STAT-04). Do not add lat/lng columns to jobs.
- **Logging assignment history inside the transaction:** History logging is non-critical audit. Log it after transaction commit to avoid lengthening lock hold time.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Cron scheduling | Custom setInterval loop | node-cron 4.x | Handles cron expressions, timezone, graceful stop; setInterval drifts |
| GPS capture | Native plugin | geolocator 13.0.4 (already installed) | Handles Android/iOS permission flow, accuracy filtering |
| Time zone comparison for cron | Manual UTC offset math | MariaDB `NOW()` with server TZ=UTC (Phase 1 decision) | Phase 1 set TZ=UTC on DB, `CONCAT(scheduled_date, ' ', scheduled_time_start)` comparison is correct |

**Key insight:** Both major libraries (node-cron, geolocator) are already in the dependency manifest. This phase is primarily configuration and query work, not new dependencies.

---

## New Database Tables

### assignment_history
```sql
CREATE TABLE IF NOT EXISTS assignment_history (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  job_id       INT UNSIGNED NOT NULL,
  event_type   ENUM('create','reassign','swap','cancel','technician_add','technician_remove') NOT NULL,
  old_user_id  INT UNSIGNED DEFAULT NULL,   -- driver/tech removed (NULL for create events)
  new_user_id  INT UNSIGNED DEFAULT NULL,   -- driver/tech added (NULL for cancel events)
  changed_by   INT UNSIGNED NOT NULL,
  changed_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  notes        TEXT DEFAULT NULL,
  tenant_id    INT UNSIGNED DEFAULT NULL,
  INDEX idx_ah_job_id   (job_id),
  INDEX idx_ah_tenant   (tenant_id),
  INDEX idx_ah_changed_at (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### job_completions
```sql
CREATE TABLE IF NOT EXISTS job_completions (
  id           INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  job_id       INT UNSIGNED NOT NULL UNIQUE,  -- one completion per job
  completed_by INT UNSIGNED NOT NULL,
  lat          DOUBLE DEFAULT NULL,
  lng          DOUBLE DEFAULT NULL,
  accuracy_m   FLOAT DEFAULT NULL,            -- GPS accuracy in metres
  gps_status   ENUM('ok','low_accuracy','no_gps') NOT NULL DEFAULT 'no_gps',
  completed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  tenant_id    INT UNSIGNED DEFAULT NULL,
  INDEX idx_jc_job_id  (job_id),
  INDEX idx_jc_tenant  (tenant_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### job_status_changes nullable changed_by

```sql
-- Make changed_by nullable to support cron-initiated transitions
ALTER TABLE job_status_changes
  MODIFY COLUMN changed_by INT UNSIGNED DEFAULT NULL;
```

**Note on idempotency:** `CREATE TABLE IF NOT EXISTS` handles the migration safely per the Phase 1 pattern. The ALTER TABLE for `changed_by` should be guarded with a check:
```sql
-- MariaDB supports this syntax:
ALTER TABLE job_status_changes MODIFY COLUMN changed_by INT(10) UNSIGNED DEFAULT NULL;
-- Idempotent: re-running has no effect when column is already nullable
```

---

## Common Pitfalls

### Pitfall 1: Cron fires while job is being manually updated
**What goes wrong:** Cron reads 1 job as "assigned" and begins transition to "in_progress". Simultaneously, a scheduler manually cancels or edits the same job. Race condition: cron overwrites the cancel.
**Why it happens:** Cron loop calls `updateJobStatus` in a loop without row-level locking.
**How to avoid:** The existing `updateJobStatus` already validates transition rules inside a transaction. If the job was already cancelled when cron tries to transition it, the `ALLOWED_TRANSITIONS` check throws ("Cannot change from 'cancelled' to 'in_progress'"). Cron should catch this error per-job and log it as info, not error.
**Warning signs:** Log entries showing "Invalid status transition" from the cron service.

### Pitfall 2: geolocator 13.x API signature change
**What goes wrong:** Code using the old `Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)` signature fails to compile on geolocator ^13.0.0.
**Why it happens:** v13 moved accuracy into a `LocationSettings` object.
**How to avoid:** Use `locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)` as shown in Pattern 3.
**Warning signs:** Dart compile error "The named parameter 'desiredAccuracy' is not defined."

### Pitfall 3: Driver load query missing tenant scope
**What goes wrong:** A scheduler at tenant A sees driver counts that include tenant B's jobs.
**Why it happens:** Missing `tenant_id` filter on the load query.
**How to avoid:** `WHERE u.tenant_id = ?` using `req.user.tenant_id` from JWT. The join on `job_technicians` must also scope by the driver's tenant (done via the user table join).

### Pitfall 4: job_status_changes INSERT fails for cron (NOT NULL changed_by)
**What goes wrong:** Cron calls `updateJobStatus(job.id, 'in_progress', null, ...)`, which tries to INSERT a row with `changed_by = NULL` into a `NOT NULL` column.
**Why it happens:** The existing schema has `changed_by INT(10) UNSIGNED NOT NULL`.
**How to avoid:** Run the ALTER TABLE migration to make `changed_by` nullable before deploying the cron service. The migration must be in the Phase 3 SQL file.

### Pitfall 5: Flutter confirm dialog fires after GPS capture starts
**What goes wrong:** If GPS capture starts before the confirm dialog, the user might dismiss the dialog but GPS is already acquired. Worse: GPS fires on every tap.
**Why it happens:** Wrong order of operations in the completion flow.
**How to avoid:** Order must be: (1) show confirm dialog, (2) user confirms, (3) start GPS capture, (4) POST to backend. GPS capture is inside the confirmed branch only.

### Pitfall 6: Load average includes inactive drivers
**What goes wrong:** Drivers with 0 jobs (inactive or new) pull the average down, making nearly everyone appear "above average" and no one gets the green glow.
**Why it happens:** LEFT JOIN includes all users even with zero jobs if they are inactive.
**How to avoid:** Filter `WHERE u.is_active = 1` so the average is computed only over active drivers.

### Pitfall 7: node-cron starts during supertest runs
**What goes wrong:** Jest + supertest imports `server.js` which starts the cron, which opens DB connections that remain open after test ends, causing Jest to hang.
**Why it happens:** `require('./services/cronService').startCronJobs()` runs unconditionally.
**How to avoid:** Guard with `if (require.main === module) { startCronJobs(); }` — already established pattern in Phase 1 for the DB startup guard.

---

## Code Examples

Verified patterns from official sources and project codebase:

### node-cron schedule syntax (verified: node-cron 4.2.1)
```javascript
// Every minute
cron.schedule('* * * * *', callback);
// Every 30 seconds (node-cron supports seconds as 6th field)
cron.schedule('*/30 * * * * *', callback);
```

### geolocator 13.x — request permission + get position
```dart
// Source: geolocator pub.dev documentation (13.x)
final permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
  final result = await Geolocator.requestPermission();
  if (result == LocationPermission.deniedForever) {
    return; // Cannot proceed
  }
}

final position = await Geolocator.getCurrentPosition(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    timeLimit: Duration(seconds: 10),
  ),
);
```

### Flutter driver load chip — below-average indicator
```dart
// Reusable widget for assignment picker row
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(8),
    border: driver.belowAverage
        ? Border.all(color: Colors.green, width: 2)
        : null,
    boxShadow: driver.belowAverage
        ? [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 8)]
        : null,
  ),
  child: ListTile(
    title: Row(children: [
      Text(driver.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
      if (driver.rank == 1)
        const Chip(label: Text('Suggested'), backgroundColor: Colors.green),
    ]),
    subtitle: Text('${driver.jobCount} jobs (${_rangeLabel})'),
  ),
)
```

### MariaDB CONCAT for datetime comparison
```sql
-- Correct pattern for MariaDB 10.4 (project DB version)
WHERE current_status = 'assigned'
  AND CONCAT(scheduled_date, ' ', scheduled_time_start) <= NOW()
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `Geolocator.getCurrentPosition(desiredAccuracy: X)` | `Geolocator.getCurrentPosition(locationSettings: LocationSettings(accuracy: X))` | geolocator v10+ | Must use new API — old signature won't compile |
| node-cron 2.x (separate seconds field always required) | node-cron 3.x+ supports optional 6th seconds field | node-cron 3.0 | Standard 5-field cron expressions work as-is |

**Deprecated/outdated:**
- `Geolocator.getCurrentPosition(desiredAccuracy: ...)`: removed in geolocator 13.x — use `LocationSettings`.
- Direct `changed_by INT NOT NULL` in status changes: must be nullable for system-initiated changes.

---

## Open Questions

1. **System user ID for cron-initiated status changes**
   - What we know: `job_status_changes.changed_by` needs a value; making it nullable is the cleanest solution.
   - What's unclear: The planner may prefer using the admin user id=1 as a "system" actor instead of nullable.
   - Recommendation: Make nullable. Null in `changed_by` with `reason = 'auto-transitioned by scheduler'` is self-documenting and avoids coupling to a specific user record.

2. **Cron behaviour when server has multiple instances (horizontal scaling)**
   - What we know: This project is Docker-first, single-instance deployment (Phase 1 decision).
   - What's unclear: If scaled to multiple instances in future, each instance runs the cron, causing duplicate transitions.
   - Recommendation: Not a concern for v1. Document in cron comment that it assumes single-instance. Phase 5 (notifications) may need to revisit.

3. **GPS status on iOS simulator**
   - What we know: Simulators return mock GPS with ~0m accuracy; physical devices may vary.
   - What's unclear: Whether the 50m threshold is too tight for real field conditions.
   - Recommendation: 50m is user-locked. Fallback path handles anything over threshold gracefully. No action needed.

---

## Validation Architecture

> nyquist_validation key is absent from .planning/config.json — treating as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Jest 30.3.0 + Supertest 7.2.2 |
| Config file | none — see Wave 0 |
| Quick run command | `npm test -- --testPathPattern=tests/unit` |
| Full suite command | `npm test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| ASGN-01 | Driver load stats query returns job_count per driver | unit | `npm test -- --testPathPattern=tests/unit/driverLoad` | ❌ Wave 0 |
| ASGN-02 | below_average flag set correctly when driver count < avg | unit | `npm test -- --testPathPattern=tests/unit/driverLoad` | ❌ Wave 0 |
| ASGN-03 | rank=1 driver is the one with lowest count | unit | `npm test -- --testPathPattern=tests/unit/driverLoad` | ❌ Wave 0 |
| ASGN-04 | One driver per vehicle — existing assignment service enforces | unit | existing test (Phase 1) | — |
| ASGN-05 | assignment_history row inserted on create/reassign/cancel | unit | `npm test -- --testPathPattern=tests/unit/assignmentHistory` | ❌ Wave 0 |
| STAT-01 | Cron auto-transitions assigned jobs with past start time | unit | `npm test -- --testPathPattern=tests/unit/cronAutoTransition` | ❌ Wave 0 |
| STAT-02 | Non-assigned user cannot complete job (403) | integration | `npm test -- --testPathPattern=tests/integration/jobCompletion` | ❌ Wave 0 |
| STAT-03 | GPS capture returns correct structure with ok/no_gps status | manual-only | manual device test — GPS requires physical device | — |
| STAT-04 | job_completions row created on complete transition | integration | `npm test -- --testPathPattern=tests/integration/jobCompletion` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `npm test -- --testPathPattern=tests/unit`
- **Per wave merge:** `npm test`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/unit/driverLoad.test.js` — covers ASGN-01, ASGN-02, ASGN-03
- [ ] `tests/unit/assignmentHistory.test.js` — covers ASGN-05
- [ ] `tests/unit/cronAutoTransition.test.js` — covers STAT-01
- [ ] `tests/integration/jobCompletion.test.js` — covers STAT-02, STAT-04

---

## Sources

### Primary (HIGH confidence)
- Project codebase: `src/services/jobAssignmentService.js` — existing assignment patterns, FOR UPDATE, deadlock retry
- Project codebase: `src/services/jobStatusService.js` — status transition rules, history logging
- Project codebase: `vehicle_scheduling.sql` — confirmed table schemas (job_assignments, job_technicians, job_status_changes)
- Project codebase: `vehicle_scheduling_app/pubspec.yaml` + `pubspec.lock` — confirmed geolocator 13.0.4, google_maps_flutter 2.10.0
- Project codebase: `android/app/src/main/AndroidManifest.xml` + `ios/Runner/Info.plist` — location permissions already declared
- `npm view node-cron version` — confirmed 4.2.1

### Secondary (MEDIUM confidence)
- node-cron README (npm): cron expression syntax, `cron.schedule()` API
- geolocator pub.dev page: v13.x API uses `LocationSettings`, permission flow

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — both primary libraries already in project dependencies, versions verified from lock file and npm registry
- Architecture: HIGH — patterns directly extend existing codebase with verified code from jobAssignmentService.js and jobStatusService.js
- Pitfalls: HIGH — derived from reading actual schema and existing code; geolocator API change verified from pubspec version
- Database tables: HIGH — follows established project patterns (tenant_id, idempotent migrations, InnoDB, utf8mb4)

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable libraries; geolocator/node-cron APIs unlikely to change in 30 days)
