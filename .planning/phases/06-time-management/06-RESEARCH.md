# Phase 6: Time Management - Research

**Researched:** 2026-03-21
**Domain:** Time extension workflow — impact analysis, rescheduling suggestion engine, multi-party notification
**Confidence:** HIGH (all findings based on direct codebase inspection of phases 1-5)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Preset duration options: 30min, 1hr, 2hr, custom — quick selection for common cases
- Free text reason field with 10-character minimum
- One active request at a time per job — previous must be resolved before new
- Both drivers and technicians assigned to the job can request extensions
- Impact scope: same driver AND same vehicle — both affected by delay
- System generates 2-3 rescheduling suggestions
- Suggestion types: Push (shift all later jobs), Swap (reassign driver), Custom (scheduler decides)
- Impact visualization: timeline list showing before/after times for affected jobs
- Dedicated approval screen with impact details and suggestion cards — accessed from push notification
- Scheduler can pick a suggestion OR enter custom times
- Optional reason on denial — quick deny for obvious cases
- Notifications after approval: driver + all technicians on job + any affected drivers from rescheduled jobs

### Claude's Discretion
- Database table schema for time_extension_requests and reschedule_options
- Impact calculation algorithm specifics
- API endpoint naming and response structure
- Flutter screen layout and widget composition

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| TIME-01 | "Add more time" button visible on in-progress jobs for driver/technician | Job detail screen already has status-gated button pattern; add alongside Complete button when status=in_progress |
| TIME-02 | Required reason field when requesting time extension | Mirrors cancel reason dialog pattern already in job_detail_screen.dart; reuse StatefulBuilder + TextFormField + 10-char minimum validator |
| TIME-03 | Impact analysis — system calculates which subsequent jobs/drivers are affected | Query jobs table: same driver (job_technicians) OR same vehicle (job_assignments) on same date, scheduled after extension end time |
| TIME-04 | System generates 2-3 rescheduling suggestions for affected jobs | Three fixed suggestion types computed server-side: Push, Swap, Custom; stored in reschedule_options table |
| TIME-05 | Scheduler receives notification of time extension request | Reuse sendTopicNotification() with type=time_extension_requested; insert notifications row; use scheduler_{id} topic |
| TIME-06 | Scheduler approves/denies extension with one of the suggested options or custom | New approval screen; PATCH endpoint applies selected suggestion to jobs table; denial path stores optional reason |
| TIME-07 | All affected parties notified of schedule changes after approval | Reuse sendTopicNotification() for driver, all technicians, affected vehicle's next-job drivers |
</phase_requirements>

---

## Summary

Phase 6 implements a self-contained time extension workflow that sits on top of the already-complete job, notification, and assignment infrastructure from Phases 1-5. No new npm packages are required on the backend. The core algorithmic work is the impact analysis query (finding jobs on the same driver and/or same vehicle that start after the extended end time) and the suggestion generator (three deterministic computation paths: push-all, swap-driver, manual).

The Flutter side needs two new screens (extension request form, scheduler approval screen) and a small addition to the existing job detail screen (the "Add More Time" button). Both screens follow patterns already established: Provider + ChangeNotifier for state, ApiService for HTTP, FCM deep-link navigation from notification tap.

The most important design decision for the planner is the transaction boundary: approving an extension must atomically update the source job's times AND update all affected jobs, inside a single MySQL transaction. A partial update (source updated, affected jobs not yet updated) would leave the schedule in an inconsistent state. The impact analysis query runs OUTSIDE the transaction; only the writes go inside it.

**Primary recommendation:** Build the backend service (TimeExtensionService) and route file first, then the Flutter provider + screens. Keep the suggestion engine deterministic — no randomness, reproducible results for the same input — so the scheduler always sees the same 3 options.

---

## Standard Stack

### Core (no new packages needed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| mysql2 | already installed | DB queries for impact analysis and writes | All phases use this |
| express | already installed | REST routes for extension endpoints | All phases use this |
| express-validator | already installed | Input validation on POST/PATCH bodies | FOUND-06 pattern |
| pino | already installed | Structured logging in TimeExtensionService | FOUND-10 pattern |
| firebase-admin | already installed | FCM push for scheduler notification (TIME-05) | Phase 5 pattern |
| flutter provider | already installed | State management for new provider | All Flutter screens |

### No New Packages

All backend and Flutter dependencies are already present in `package.json` / `pubspec.yaml`. Phase 6 is pure application logic on the existing stack.

---

## Architecture Patterns

### Recommended Project Structure (new files only)

```
vehicle-scheduling-backend/src/
├── services/
│   └── timeExtensionService.js      # Impact analysis + suggestion engine + approval logic
├── routes/
│   └── timeExtension.js             # POST /request, GET /:jobId, PATCH /:id/approve, PATCH /:id/deny

vehicle_scheduling_app/lib/
├── models/
│   └── time_extension.dart          # TimeExtensionRequest + RescheduleOption models
├── services/
│   └── time_extension_service.dart  # HTTP calls wrapping ApiService
├── providers/
│   └── time_extension_provider.dart # ChangeNotifier state for request + approval flow
├── screens/
│   └── time_management/
│       ├── time_extension_request_screen.dart  # Driver/tech: pick duration + enter reason
│       └── time_extension_approval_screen.dart # Scheduler: view impact + pick suggestion
```

### Pattern 1: TimeExtensionService — static methods, pino child logger

Follows the exact shape of jobAssignmentService.js and jobStatusService.js. Static methods, one child logger per service, db from `../config/database`.

```javascript
// Source: inspected src/services/jobAssignmentService.js
const logger = require('../config/logger').child({ service: 'timeExtensionService' });
const db = require('../config/database');

class TimeExtensionService {

  // ── Step 1: create request (validates one-active-at-a-time) ──
  static async createRequest({ jobId, requestedBy, durationMinutes, reason, tenantId }) {
    // 1a. Verify job is in_progress
    // 1b. Check no active request exists for this job
    //     SELECT id FROM time_extension_requests WHERE job_id=? AND status='pending' LIMIT 1
    // 1c. Verify requestedBy is assigned to this job (job_technicians or job_assignments.driver_id)
    // 1d. INSERT time_extension_requests row
    // 1e. Run impact analysis (outside transaction — read-only)
    // 1f. Insert reschedule_options rows
    // 1g. Notify schedulers (sendTopicNotification)
    // Returns: { requestId, affectedJobs, suggestions }
  }

  // ── Step 2: impact analysis ───────────────────────────────────
  static async analyzeImpact(jobId, extensionMinutes, tenantId) {
    // Returns list of affected job IDs with their current and projected times
    // Affected = same driver OR same vehicle, same date, starts after (original_end + extensionMinutes)
  }

  // ── Step 3: suggestion generator ─────────────────────────────
  static _buildSuggestions(sourceJob, extensionMinutes, affectedJobs) {
    // Push: shift all affected jobs by extensionMinutes
    // Swap: reassign source job's driver to any available driver (availabilityRoutes logic)
    // Custom: return null/empty times — scheduler fills in manually
    // Returns array of { type, label, changes: [{jobId, newStart, newEnd}] }
  }

  // ── Step 4: approve ───────────────────────────────────────────
  static async approveRequest(requestId, selectedSuggestionId, customChanges, approvedBy, tenantId) {
    // TRANSACTION:
    //   UPDATE time_extension_requests SET status='approved'
    //   UPDATE jobs SET scheduled_time_end=newEnd, estimated_duration_minutes=newDuration WHERE id=jobId
    //   For each affected job in suggestion: UPDATE jobs SET scheduled_time_start=..., scheduled_time_end=...
    // AFTER TRANSACTION:
    //   Notify driver + all technicians on job + affected drivers
  }

  // ── Step 5: deny ──────────────────────────────────────────────
  static async denyRequest(requestId, reason, deniedBy, tenantId) {
    // UPDATE time_extension_requests SET status='denied', denial_reason=?
    // Notify driver + technicians on job
  }
}
```

### Pattern 2: Impact Analysis Query

The impact query must cover BOTH the driver and vehicle constraints from CONTEXT.md.

```sql
-- Source: derived from jobAssignmentService.js inspection of job_assignments + job_technicians tables
-- Find jobs affected by delay to job :jobId for tenant :tenantId
-- "Affected" = scheduled on the same date, starting AT OR AFTER the new end time,
-- and sharing either the same driver OR the same vehicle.

SELECT DISTINCT
  j.id,
  j.job_number,
  j.scheduled_date,
  j.scheduled_time_start,
  j.scheduled_time_end,
  j.estimated_duration_minutes,
  j.current_status,
  ja.vehicle_id,
  ja.driver_id
FROM jobs j
LEFT JOIN job_assignments ja ON ja.job_id = j.id
WHERE j.tenant_id = :tenantId
  AND j.scheduled_date = :scheduledDate
  AND j.id != :jobId
  AND j.current_status NOT IN ('completed', 'cancelled')
  AND j.scheduled_time_start >= :newEndTime          -- starts at or after extended end
  AND (
    ja.vehicle_id = :vehicleId                        -- same vehicle
    OR EXISTS (
      SELECT 1 FROM job_technicians jt
      JOIN job_technicians jt2 ON jt2.user_id = jt.user_id AND jt2.job_id = j.id
      WHERE jt.job_id = :jobId
    )                                                  -- shared driver/technician
  )
ORDER BY j.scheduled_time_start ASC
```

### Pattern 3: Suggestion Builder Logic

Three suggestions are generated deterministically server-side. All three are inserted into `reschedule_options` and returned to the client; the scheduler picks one or overrides with custom.

```
Push suggestion (always present):
  For each affected job: newStart = currentStart + extensionMinutes, newEnd = currentEnd + extensionMinutes

Swap suggestion (present if alternative drivers available):
  Reassign the source job's driver to a different available driver for the extended time slot.
  The affected jobs remain unchanged (no domino effect).
  Query: same availability check logic as VehicleAvailabilityService.checkDriversAvailability()

Custom suggestion (always present as third option):
  Returns no pre-computed changes. The scheduler fills in times manually via the approval screen.
  Stored as type='custom' with changes=[]
```

### Pattern 4: Route Registration

```javascript
// Source: inspected src/routes/index.js
// Add to src/routes/index.js after notifications line:
const timeExtensionRoutes = require('./timeExtension');
router.use('/time-extensions', timeExtensionRoutes);
// New base: /api/time-extensions
```

Route surface:
```
POST   /api/time-extensions                — create request (driver/tech only)
GET    /api/time-extensions/:jobId         — get active request + suggestions for a job
PATCH  /api/time-extensions/:id/approve   — approve with suggestion or custom (scheduler/admin)
PATCH  /api/time-extensions/:id/deny      — deny with optional reason (scheduler/admin)
```

### Pattern 5: Flutter State Pattern

Follows the notification_provider.dart pattern (ChangeNotifier, loading/error state, async methods).

```dart
// Source: inspected lib/providers/notification_provider.dart + job_provider.dart
class TimeExtensionProvider extends ChangeNotifier {
  TimeExtensionRequest? _activeRequest;
  List<RescheduleOption> _suggestions = [];
  bool _loading = false;
  String? _error;

  Future<void> submitRequest(int jobId, int durationMinutes, String reason) async { ... }
  Future<void> loadActiveRequest(int jobId) async { ... }
  Future<void> approveRequest(int requestId, int? suggestionId, Map? customChanges) async { ... }
  Future<void> denyRequest(int requestId, String? reason) async { ... }
}
```

### Pattern 6: Flutter Deep-Link Navigation (TIME-05 → TIME-06)

Approval screen is reached either from navigation OR from tapping the FCM notification. Follow the established FCM data payload pattern from Phase 5 notification service.

```dart
// FCM data payload (backend sends):
// { jobId: '42', requestId: '7', type: 'time_extension_requested' }

// In FcmService / notification handler:
// if type == 'time_extension_requested': Navigator.push TimeExtensionApprovalScreen(requestId: id)
```

### Pattern 7: Duration Preset UI

Four preset buttons + custom input field, consistent with the toggle-chip pattern seen in dashboard screens.

```dart
// Preset options: 30, 60, 120 minutes + custom
// When custom selected: show a TextFormField for int input (minutes)
// Validation: must be > 0 and <= 480 (8 hours max — reasonable cap)
```

### Anti-Patterns to Avoid

- **Running approval writes in two separate DB calls:** The source job update and the affected-job updates MUST be in a single transaction. A crash between the two calls leaves the schedule in an inconsistent state.
- **Running impact analysis inside the approval transaction:** Impact is read-only and pre-computed at request creation time. Re-running it at approval time inside a transaction causes unnecessary lock contention.
- **Querying driver availability separately from the impact query:** The impact query already joins job_technicians; do not issue a second separate query for drivers.
- **Allowing a second request before the first is resolved:** Enforce at INSERT time with a NOT EXISTS subquery guard — don't rely only on application-layer checks.
- **Generating suggestions on every GET:** Suggestions are computed once at request creation and stored in `reschedule_options`. The GET endpoint reads stored rows, not re-computes.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Push notifications for scheduler | Custom HTTP call to FCM | `sendTopicNotification()` from notificationService.js | Already handles Firebase lazy-load, graceful degradation, no-retry policy |
| Driver availability check for Swap suggestion | Custom SQL | `VehicleAvailabilityService.checkDriversAvailability()` | Handles time overlap logic correctly, already tested in Phase 3 |
| HTTP calls from Flutter | Raw http package | `ApiService` (already in lib/services/api_service.dart) | Handles auth token injection, error parsing, base URL routing |
| Job time update SQL | New UPDATE pattern | Reuse the pattern from jobStatusService.js (transaction + connection.release in finally) | Deadlock retry, guaranteed connection release |
| In-app notification record | New insert logic | Reuse the `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body)` pattern | Dedup logic pattern from notificationService.js |

---

## Database Schema (Claude's Discretion)

Two new tables. Schema must match MariaDB 10.4.32 (from SQL dump header) and use `ADD COLUMN IF NOT EXISTS` idiom for migrations.

### time_extension_requests

```sql
CREATE TABLE IF NOT EXISTS `time_extension_requests` (
  `id`                    int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `tenant_id`             int(10) UNSIGNED NOT NULL,
  `job_id`                int(10) UNSIGNED NOT NULL,
  `requested_by`          int(10) UNSIGNED NOT NULL COMMENT 'User who submitted the request',
  `duration_minutes`      int(10) UNSIGNED NOT NULL COMMENT 'Requested extension in minutes',
  `reason`                text NOT NULL COMMENT 'Required explanation (min 10 chars enforced at API layer)',
  `status`                enum('pending','approved','denied') NOT NULL DEFAULT 'pending',
  `denial_reason`         text DEFAULT NULL,
  `approved_denied_by`    int(10) UNSIGNED DEFAULT NULL,
  `approved_denied_at`    timestamp NULL DEFAULT NULL,
  `selected_suggestion_id` int(10) UNSIGNED DEFAULT NULL COMMENT 'NULL if scheduler used custom times',
  `created_at`            timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at`            timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ter_job_status`   (`job_id`, `status`),
  KEY `idx_ter_tenant`       (`tenant_id`),
  KEY `idx_ter_requested_by` (`requested_by`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### reschedule_options

```sql
CREATE TABLE IF NOT EXISTS `reschedule_options` (
  `id`            int(10) UNSIGNED NOT NULL AUTO_INCREMENT,
  `request_id`    int(10) UNSIGNED NOT NULL,
  `tenant_id`     int(10) UNSIGNED NOT NULL,
  `type`          enum('push','swap','custom') NOT NULL,
  `label`         varchar(100) NOT NULL COMMENT 'Human-readable label shown on approval screen',
  `changes_json`  text NOT NULL COMMENT 'JSON array: [{jobId, newStart, newEnd}]',
  `created_at`    timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_ro_request` (`request_id`),
  KEY `idx_ro_tenant`  (`tenant_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

**Why `changes_json` as text:** MariaDB 10.4 has JSON support but `JSON` column type is an alias for `LONGTEXT`. Using `text` is consistent with existing schema practices and avoids validation surprises. The application layer parses the JSON string.

### Migration Strategy

Add to a new migration file (same `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` pattern from Phase 1). These are full new tables, so `CREATE TABLE IF NOT EXISTS` is sufficient.

---

## API Contract (Claude's Discretion)

### POST /api/time-extensions

**Auth:** verifyToken, role must be driver or technician assigned to job (enforced by service layer)

Request body:
```json
{
  "job_id": 42,
  "duration_minutes": 60,
  "reason": "Customer requested additional scope work"
}
```

Success response:
```json
{
  "success": true,
  "request": {
    "id": 7,
    "jobId": 42,
    "durationMinutes": 60,
    "reason": "Customer requested...",
    "status": "pending"
  },
  "affectedJobs": [
    { "id": 43, "jobNumber": "JOB-2026-0043", "currentStart": "14:00", "currentEnd": "15:30" }
  ],
  "suggestions": [
    { "id": 1, "type": "push",   "label": "Push all later jobs by 60 min", "changes": [...] },
    { "id": 2, "type": "swap",   "label": "Reassign job to Driver B",       "changes": [...] },
    { "id": 3, "type": "custom", "label": "Enter custom times",             "changes": [] }
  ]
}
```

Error — already active request:
```json
{ "success": false, "error": "A pending extension request already exists for this job" }
```

### GET /api/time-extensions/:jobId

Returns the active (pending) request for a job, with its suggestions. Returns `{ success: true, request: null }` if no active request.

### PATCH /api/time-extensions/:id/approve

**Auth:** verifyToken, requirePermission('jobs:update') (scheduler/admin)

Request body:
```json
{
  "suggestion_id": 1,
  "custom_changes": null
}
```
Or for custom:
```json
{
  "suggestion_id": null,
  "custom_changes": [
    { "jobId": 43, "newStart": "15:30", "newEnd": "17:00" }
  ]
}
```

### PATCH /api/time-extensions/:id/deny

Request body:
```json
{
  "reason": "Cannot reschedule — vehicle committed to other jobs"
}
```
Reason is optional (empty string allowed).

---

## Flutter Model (Claude's Discretion)

```dart
// lib/models/time_extension.dart

class TimeExtensionRequest {
  final int id;
  final int jobId;
  final int requestedBy;
  final int durationMinutes;
  final String reason;
  final String status; // 'pending' | 'approved' | 'denied'
  final String? denialReason;
  final DateTime createdAt;

  // ...fromJson, constructor
}

class RescheduleOption {
  final int id;
  final int requestId;
  final String type; // 'push' | 'swap' | 'custom'
  final String label;
  final List<JobTimeChange> changes;

  // ...fromJson, constructor
}

class JobTimeChange {
  final int jobId;
  final String jobNumber;
  final String? currentStart;  // original time (for impact visualization)
  final String? currentEnd;
  final String newStart;
  final String newEnd;

  // ...fromJson, constructor
}

class AffectedJob {
  final int id;
  final String jobNumber;
  final String currentStart;
  final String currentEnd;

  // ...fromJson, constructor
}
```

---

## Common Pitfalls

### Pitfall 1: One-Active-Request Enforcement Race Condition
**What goes wrong:** Two simultaneous POST /api/time-extensions calls from the same job both pass the "no active request" check and both insert rows.
**Why it happens:** The check (SELECT) and the insert are not atomic without a lock.
**How to avoid:** Add a UNIQUE index on `(job_id, status)` where status='pending' — but MySQL/MariaDB partial unique indexes on enum values aren't straightforward. Better: use an INSERT + NOT EXISTS subquery in a transaction, or use a unique index on `(job_id)` that is cleared on approval/denial. Simplest reliable option: enforce at application layer with a SELECT FOR UPDATE within a transaction before INSERT.
**Warning signs:** Duplicate pending requests for the same job_id in the table.

### Pitfall 2: Approval Transaction Scope Too Wide
**What goes wrong:** The impact analysis query (can be slow on many jobs) runs INSIDE the transaction that also updates job times.
**Why it happens:** Developer includes all logic in one function.
**How to avoid:** Impact analysis runs when the REQUEST is created (stored in reschedule_options). Approval transaction only reads the stored `changes_json` and applies UPDATEs. No slow queries inside the transaction.

### Pitfall 3: Scheduler Notification Sent Before DB Commit
**What goes wrong:** FCM notification fires during approval, but the DB transaction later rolls back. Scheduler taps notification, sees no updated state.
**Why it happens:** notification send is called inside the transaction before `commit()`.
**How to avoid:** Follow the Phase 5 / notificationService.js pattern: insert notification row first (inside transaction), send FCM AFTER `await connection.commit()`. FCM send failure is non-fatal per project decision.

### Pitfall 4: Duration Preset Buttons Not Updating Custom Field
**What goes wrong:** User taps "1hr" preset, then taps "Custom" and enters a value — the submission still uses 60.
**Why it happens:** Flutter `setState` not called when switching from preset to custom.
**How to avoid:** Use a single `int _selectedMinutes` state variable. Preset buttons call `setState(() => _selectedMinutes = N)`. Custom input's `onChanged` calls `setState(() => _selectedMinutes = int.tryParse(v) ?? 0)`. Submit reads only `_selectedMinutes`.

### Pitfall 5: Flutter Approval Screen Built Without Request ID
**What goes wrong:** Scheduler taps FCM notification but approval screen renders blank because the `requestId` was not passed through the FCM data payload.
**Why it happens:** FCM data payload only contains `jobId`, not `requestId`.
**How to avoid:** Include BOTH `jobId` AND `requestId` in FCM data payload. Approval screen fetches the full request (including suggestions) via GET /api/time-extensions/:jobId on mount.

### Pitfall 6: Affected Job List Includes Completed/Cancelled Jobs
**What goes wrong:** Impact analysis shows completed jobs as "affected", causing confusion.
**Why it happens:** The impact query didn't filter by status.
**How to avoid:** Always include `j.current_status NOT IN ('completed', 'cancelled')` in the impact WHERE clause.

### Pitfall 7: Time String Arithmetic in JavaScript vs MySQL
**What goes wrong:** Adding `extensionMinutes` to a TIME string '14:30:00' in JavaScript produces wrong results due to naive string parsing.
**Why it happens:** JavaScript has no native time-addition for HH:MM strings.
**How to avoid:** Do all time arithmetic in MySQL: `SEC_TO_TIME(TIME_TO_SEC('14:30:00') + 60*:extensionMinutes)`. Or convert to total minutes (split on ':'), add, then format back. Use a shared utility function in the service.

---

## Code Examples

### Notification call pattern for TIME-05 (from notificationService.js)

```javascript
// Source: inspected src/services/notificationService.js
// Send to all schedulers/admins in the tenant
const [schedulers] = await db.query(
  `SELECT id FROM users WHERE tenant_id = ? AND role IN ('admin', 'scheduler', 'dispatcher') AND is_active = 1`,
  [tenantId]
);

for (const scheduler of schedulers) {
  await db.query(
    `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body) VALUES (?, ?, ?, 'time_extension_requested', ?, ?)`,
    [tenantId, scheduler.id, jobId, 'Time Extension Request', `${jobNumber}: ${durationMinutes} min extension requested`]
  );
  await NotificationService.sendTopicNotification(
    `scheduler_${scheduler.id}`,
    'Time Extension Request',
    `${jobNumber}: driver requesting ${durationMinutes} min extension`,
    { jobId: String(jobId), requestId: String(requestId), type: 'time_extension_requested' }
  );
}
```

### Job technician membership check (from job_assignments + job_technicians)

```javascript
// Source: inspected Job.js and jobAssignmentService.js
// Verify requesting user is assigned to job (driver OR technician)
const [membership] = await db.query(
  `SELECT 1 FROM job_technicians WHERE job_id = ? AND user_id = ?
   UNION
   SELECT 1 FROM job_assignments WHERE job_id = ? AND driver_id = ?
   LIMIT 1`,
  [jobId, userId, jobId, userId]
);
if (membership.length === 0) throw new Error('Not authorized to request extension for this job');
```

### Time addition utility (SQL-based, MariaDB 10.4)

```javascript
// Source: derived from SQL dump header (MariaDB 10.4.32)
// Add N minutes to a TIME string, returns 'HH:MM:SS'
// Usage inside a query:
//   SEC_TO_TIME(TIME_TO_SEC(scheduled_time_end) + ? * 60) AS new_end_time
// Or in Node:
function addMinutesToTime(timeStr, minutes) {
  const [h, m, s = 0] = timeStr.split(':').map(Number);
  const totalSec = h * 3600 + m * 60 + s + minutes * 60;
  const hh = String(Math.floor(totalSec / 3600) % 24).padStart(2, '0');
  const mm = String(Math.floor((totalSec % 3600) / 60)).padStart(2, '0');
  const ss = String(totalSec % 60).padStart(2, '0');
  return `${hh}:${mm}:${ss}`;
}
```

### AppConfig endpoint constant (Flutter pattern)

```dart
// Source: inspected lib/config/app_config.dart
// Add to AppConfig class:
static const String timeExtensionsEndpoint = '/time-extensions';
```

### Flutter provider method shape

```dart
// Source: inspected lib/providers/job_provider.dart + notification_provider.dart
Future<bool> submitExtensionRequest({
  required int jobId,
  required int durationMinutes,
  required String reason,
}) async {
  _loading = true;
  _error = null;
  notifyListeners();
  try {
    final result = await _service.createRequest(
      jobId: jobId,
      durationMinutes: durationMinutes,
      reason: reason,
    );
    _activeRequest = result.request;
    _suggestions = result.suggestions;
    _affectedJobs = result.affectedJobs;
    return true;
  } catch (e) {
    _error = e.toString();
    return false;
  } finally {
    _loading = false;
    notifyListeners();
  }
}
```

---

## Validation Architecture

`workflow.nyquist_validation` is absent from `.planning/config.json` — treat as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | No test framework configured (CLAUDE.md: "npm test is a placeholder") |
| Config file | None — TEST-01 through TEST-05 are Phase 8 requirements |
| Quick run command | N/A until Phase 8 |
| Full suite command | N/A until Phase 8 |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TIME-01 | "Add More Time" button visible only when job.currentStatus == 'in_progress' AND user is driver/tech on job | manual smoke | Flutter hot reload + visual check | N/A |
| TIME-02 | Reason field rejects submission if < 10 chars | manual smoke | API POST with short reason returns 422 | N/A |
| TIME-03 | Impact analysis returns only same-day, same-driver-or-vehicle, non-completed jobs after new end time | manual smoke | API POST + check affectedJobs array | N/A |
| TIME-04 | Three suggestions returned: push, swap (or absent if no swap driver), custom | manual smoke | API POST + check suggestions array length and types | N/A |
| TIME-05 | Scheduler receives FCM notification containing requestId and jobId | manual smoke | Check notifications table row + Firebase console | N/A |
| TIME-06 | Approval atomically updates source job and all affected jobs in single transaction | manual smoke | PATCH approve + verify job times in DB | N/A |
| TIME-07 | All affected parties (driver, technicians, affected drivers) get notifications | manual smoke | PATCH approve + check notifications rows for each user | N/A |

### Wave 0 Gaps

No test framework infrastructure is needed for Phase 6. Testing Phase (Phase 8) will build the test suite. Phase 6 verification is manual smoke testing per the above test map.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Console.log | pino child logger per service | Phase 1 (FOUND-10) | All Phase 6 service code MUST use pino, never console.* |
| Global queries without tenant_id | All queries scoped to req.user.tenant_id | Phase 1 (FOUND-01) | TIME extension queries MUST include tenant_id in all WHERE clauses |
| Unauthenticated routes | verifyToken on all routes | Phase 1 | Every /api/time-extensions endpoint needs verifyToken |
| JWT without tenant_id | tenant_id in JWT payload | Phase 1 (FOUND-04) | req.user.tenant_id is available in all route handlers |
| Single FCM send | sendTopicNotification() with graceful degradation | Phase 5 | Do not call Firebase directly — use the wrapper |

---

## Open Questions

1. **Swap suggestion when no alternative driver is available**
   - What we know: Swap suggestion should reassign source job's driver to a different available driver
   - What's unclear: If no available driver exists (all busy), should the Swap option be omitted, or shown as disabled with a message?
   - Recommendation: Omit the Swap suggestion from the array entirely when no swap driver is available. Fewer options (2 instead of 3) is better than showing a disabled option that confuses the scheduler. Return `suggestions.length` of 2 in that case.

2. **Approval with custom_changes for jobs not in original affectedJobs**
   - What we know: Scheduler can enter custom times for the source job or any affected job
   - What's unclear: Should the backend validate that custom_changes only references jobs from the original impact analysis, or allow the scheduler to modify any job?
   - Recommendation: Validate that all jobIds in custom_changes belong to the same tenant (tenant_id check). Do NOT restrict to only the impact-analysis set — schedulers may have better domain knowledge.

3. **Expired/stale pending requests**
   - What we know: One active request per job. No expiry mechanism defined.
   - What's unclear: What happens if a pending request is never approved/denied (scheduler misses the notification)?
   - Recommendation: Out of scope for Phase 6. The overdue job notification from Phase 5 (NOTIF-03) already alerts schedulers to jobs running long. No auto-expiry cron needed in v1.

---

## Sources

### Primary (HIGH confidence)
- Direct codebase inspection of `src/services/notificationService.js` — FCM send pattern, notification dedup, notification row insert pattern
- Direct codebase inspection of `src/services/jobAssignmentService.js` — transaction pattern, FOR UPDATE, deadlock retry, audit trail pattern
- Direct codebase inspection of `src/services/jobStatusService.js` — status transition enforcement pattern
- Direct codebase inspection of `src/services/cronService.js` — cron extension pattern, require.main guard
- Direct codebase inspection of `lib/providers/job_provider.dart` + `notification_provider.dart` — Flutter ChangeNotifier pattern
- Direct codebase inspection of `lib/screens/jobs/job_detail_screen.dart` — button gating, dialog patterns, SchedulerBinding.addPostFrameCallback usage
- Direct codebase inspection of `lib/config/app_config.dart` — endpoint constant pattern
- Direct codebase inspection of `src/routes/index.js` — route registration pattern
- Direct codebase inspection of `vehicle_scheduling.sql` — confirmed MariaDB 10.4.32, table structure, existing column names
- Direct codebase inspection of `.planning/phases/06-time-management/06-CONTEXT.md` — all locked decisions

### Secondary (MEDIUM confidence)
- MariaDB 10.4 TIME_TO_SEC / SEC_TO_TIME functions: standard MariaDB/MySQL SQL functions, present since MySQL 5.x, confirmed present in MariaDB 10.4 by documentation

### Tertiary (LOW confidence)
None.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages already installed, confirmed by package.json/pubspec.yaml inspection
- Database schema: HIGH — follows confirmed MariaDB 10.4.32 syntax from vehicle_scheduling.sql dump
- Architecture patterns: HIGH — all patterns extracted from existing Phase 1-5 code, not hypothesized
- Impact analysis query: HIGH — directly derived from existing job_assignments + job_technicians table structure
- Flutter patterns: HIGH — all patterns extracted from existing Phase 1-5 Flutter code

**Research date:** 2026-03-21
**Valid until:** 2026-04-20 (stable stack, 30-day window)
