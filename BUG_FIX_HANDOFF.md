# Bug Fix Handoff — Driver Assignment System
**Project:** Flutter + Node.js Vehicle Scheduling App  
**Author:** Senior Engineer  
**Audience:** Junior developer taking over maintenance

---

## How to read this document

This doc covers three bugs. Each section explains:
1. **What the bug was** — the exact user-visible symptom
2. **Why it happened** — the root cause in plain English, then in code
3. **What we changed and where** — every file touched, with reasoning
4. **What you should test** — concrete scenarios to verify the fix works

Read all three before touching any code. The bugs are related — they all live in the driver assignment flow and fixing one in isolation without understanding the others will create confusion.

---

## Architecture recap (read this first)

```
Flutter App
    │
    ├── Screens  (UI — shows data, calls providers)
    ├── Providers  (state — holds data, calls services)
    └── Services  (HTTP — makes API calls)
            │
            ▼
    Node.js API
            │
            ├── routes/  (URL → controller mapping)
            ├── controllers/  (validates HTTP input, calls services)
            ├── services/  (business logic — the smart layer)
            └── models/  (database queries — the dumb layer)
```

**The golden rule:** each layer talks only to the layer directly below it. A screen never talks to a service directly. A route never does a DB query directly. When you see a violation of this rule, that's usually where bugs live.

---

## Bug 1 — Drivers assigned on Create Job screen are not actually saved

### Symptom
A scheduler selects 2 drivers on the Create Job screen, submits, sees the summary dialog saying "2 drivers assigned" — but when they open the job detail, no drivers appear.

### Root cause

The **Post `/api/jobs`** endpoint creates a job record. It does **not** create `job_technicians` rows — that's the job of the **PUT `/api/job-assignments/:jobId/technicians`** endpoint.

The old Flutter code was passing `technicianIds` inside the `createJob()` POST body, trusting the backend to handle it. The backend silently ignored that field. The summary dialog showed "2 drivers assigned" purely because `techIds.length > 0` — no confirmation from the server was ever checked.

```
OLD FLOW (broken):
  POST /api/jobs  { ..., technician_ids: [3, 7] }
      ↓ backend ignores technician_ids
  bool success = true
  UI says "2 drivers assigned" ← LIE, based only on list length

NEW FLOW (fixed):
  1. POST /api/jobs  { ... }  ← no technicianIds
         ↓ returns Job object with real ID
  2. PUT /api/job-assignments/:id/technicians  { technician_ids: [3, 7] }
         ↓ backend writes job_technicians rows
  3. UI shows "2 drivers assigned" ← TRUTH, based on server response
```

### Files changed

**`lib/providers/job_provider.dart`**  
`createJob()` return type changed from `bool` to `Job?`.  
- `null` means failure  
- a `Job` object means success — and the caller now has the real database ID

**`lib/services/job_service.dart`**  
`createJob()` no longer includes `technician_ids` in the POST body. The parameter is removed entirely to make it impossible to accidentally pass it.

**`lib/screens/jobs/create_job_screen.dart`**  
The `_submit()` method now does three sequential steps:
1. Create job → get `Job?` back
2. If `newJob == null` → bail out with error
3. Call `assignTechnicians(jobId: newJob.id, ...)` as a separate, explicit step
4. Show summary dialog based on actual server results, not list lengths

### Why returning `Job?` instead of `bool` matters

The old code that tried to find the new job after creation looked like this:
```dart
// OLD — fragile race condition
final newJob = jobProvider.allJobs
    .reduce((a, b) => a.id > b.id ? a : b); // find newest by ID
await jobProvider.assignTechnicians(jobId: newJob.id, ...);
```

This is dangerous because:
- Another user could create a job simultaneously
- The sort order might not reflect database insertion order
- The list might not have refreshed yet

Now we just use the ID from the return value. Simple, reliable.

---

## Bug 2 — Assigning a driver from Job Detail shows an error, but the driver IS saved

### Symptom
An admin opens a job, taps "Manage Drivers", selects a driver, taps Save. A red error snackbar appears. But if they close the screen and reopen the job, the driver is there. The assignment worked — the error was false.

### Root cause

This was a **type mismatch** in the Flutter `api_service.dart`, combined with a **double-reload** in `job_detail_screen.dart`.

**Part A — The false error:**

The `PUT /api/job-assignments/:jobId/technicians` backend returns a `200 OK` with a body like:
```json
{ "success": true, "job": { ... } }
```

But sometimes — particularly after the backend processes the write and fetches the updated job — it can return a slightly different shape. The old `_handleResponse()` in `api_service.dart` did:
```dart
return jsonDecode(response.body) as Map<String, dynamic>;
```

If `jsonDecode` returned anything that wasn't a `Map<String, dynamic>` (e.g. the body was briefly a list, or the cast failed for any reason), Dart threw a `TypeError` at runtime. The `try/catch` in the provider caught this, set `_error`, and returned `false`. The assignment was already committed to the database — the error was entirely in the parsing layer.

**Part B — The double-reload:**

Even when the assignment succeeded, the old detail screen code did:
```dart
// After assignTechnicians() succeeds:
await context.read<JobProvider>().loadJobById(_job.id); // ← REDUNDANT
```

`assignTechnicians()` in the provider already calls `_reloadSingleJob()` internally. This redundant `loadJobById()` set status back to `loading`, triggered a rebuild, then set it to `success` again — two unnecessary rebuilds. On slow devices this caused a visible flash and, in edge cases, a race where the screen read `selectedJob` between the two loads and got stale data.

### Files changed

**`lib/services/api_service.dart`**  
`_handleResponse()` now handles non-Map successful responses safely:
```dart
// BEFORE (crashes on non-Map success response):
return jsonDecode(response.body) as Map<String, dynamic>;

// AFTER (resilient):
final decoded = jsonDecode(response.body);
if (decoded is Map<String, dynamic>) return decoded;
return {'success': true, 'data': decoded}; // wrap lists or other types
```
Empty body (204-style responses) also handled: returns `{'success': true}`.

**`lib/screens/jobs/job_detail_screen.dart`**  
Removed all redundant `loadJobById()` calls after `assignTechnicians()`, `unassignDriver()`, and `assignVehicle()`. The correct pattern is now:
```dart
if (success) {
  // Provider already reloaded selectedJob. Just read it.
  final updated = context.read<JobProvider>().selectedJob;
  if (updated != null && mounted) setState(() => _job = updated);
}
```

---

## Bug 3 — Admin override does nothing when assigning a busy driver

### Symptom
An admin opens a job, taps "Manage Drivers", sees a driver greyed out with "Already booked". The tooltip says "Admin override will unassign them from the other job". The admin checks the driver anyway. They tap Save. Nothing happens — the driver is not assigned. No error, just no change.

### Root cause

This was a **broken chain** across four layers. The admin's intent (force the assignment) was expressed in the UI but never reached the database.

```
Flutter UI      Admin checks a busy driver checkbox
                ↓
                Dialog pops with: selected.toList()  ← just a List<int>
                                  NO force flag passed ↑
                ↓
job_detail      jobProvider.assignTechnicians(
                  technicianIds: ids,
                  forceOverride: false  ← hardcoded, flag never set
                )
                ↓
job_service     PUT body: { technician_ids: [...] }
                          NO force_override key ↑
                ↓
jobs.js route   isAdminOverride = req.user.role === 'admin'
                                  ^ true for admin, but...
                Job.assignTechnicians(..., isAdminOverride)
                ↓
Job model       → runs checkDriversAvailability()  ← WRONG, should skip
                → throws conflict error
                → UI shows nothing (error swallowed in some paths)
```

The UI allowed the admin to check a busy driver, but the "override" information was never put in the request. The backend had the role check (`req.user.role === 'admin'`) but no way to know the admin *intended* an override versus accidentally selecting a busy driver.

### The fix — threading the force flag end-to-end

**`lib/screens/jobs/job_detail_screen.dart`**  
The dialog now pops with a structured result instead of a raw list:
```dart
// BEFORE:
Navigator.pop(ctx, selected.toList())  // just List<int>

// AFTER:
Navigator.pop(ctx, {
  'ids': selected.toList(),
  'force': isAdmin && selected.any((id) => busyIds.contains(id)),
})
```
`force` is `true` only when the admin deliberately selected at least one driver who is in `busyIds`. A non-admin user's dialog never produces `force: true`.

**`lib/providers/job_provider.dart`**  
`assignTechnicians()` now accepts and threads `forceOverride`:
```dart
Future<bool> assignTechnicians({
  ...
  bool forceOverride = false,  // ← new
}) async {
  await _jobService.assignTechnicians(
    ...,
    forceOverride: forceOverride,
  );
}
```

**`lib/services/job_service.dart`**  
`assignTechnicians()` conditionally includes `force_override` in the PUT body:
```dart
final data = <String, dynamic>{
  'technician_ids': technicianIds,
  'assigned_by': assignedBy,
  if (forceOverride) 'force_override': true,  // only sent when true
};
```

**`src/routes/jobs.js`** — `PUT /:id/technicians`  
Now reads `force_override` from the request body AND enforces that only admins can trigger it:
```javascript
const { technician_ids = [], assigned_by, force_override = false } = req.body;

// Both conditions must be true — role check AND explicit intent:
const isAdminOverride = req.user.role === 'admin' && force_override === true;
await Job.assignTechnicians(jobId, techIds, parseInt(assigned_by), isAdminOverride);
```

**`src/services/jobAssignmentService.js`** — `assignTechnicians()`  
Now accepts `forceOverride` and branches on it:
```javascript
static async assignTechnicians(jobId, technicianIds, assignedBy, forceOverride = false) {
  if (forceOverride) {
    // Skip conflict check. Instead, remove the driver from their
    // conflicting job first, then proceed to the INSERT.
    await Job.removeDriversFromConflictingJobs(technicianIds, ...);
  } else {
    // Normal path — conflict check throws if busy.
    const check = await VehicleAvailabilityService.checkDriversAvailability(...);
    if (!check.allAvailable) throw new Error(...);
  }
  await Job.assignTechnicians(jobId, technicianIds, assignedBy, forceOverride);
}
```

**`src/models/Job.js`** — two changes

1. `assignTechnicians()` gets `isAdminOverride` parameter. The SQL itself is unchanged (DELETE + INSERT), but the parameter is logged for auditability.

2. **New method: `removeDriversFromConflictingJobs()`**  
   This is the core of the override. It finds every `job_technicians` row where any of the given drivers is booked in an overlapping window, then deletes those rows:
   ```sql
   DELETE FROM job_technicians
   WHERE user_id IN (?)
     AND job_id IN (
       SELECT jt.job_id FROM job_technicians jt
       JOIN jobs j ON jt.job_id = j.id
       WHERE jt.user_id IN (?)
         AND j.scheduled_date = ?
         AND j.current_status NOT IN ('completed', 'cancelled')
         AND ? < j.scheduled_time_end
         AND ? > j.scheduled_time_start
         AND j.id != ?  ← don't delete from the job we're assigning TO
     )
   ```
   This means the driver *moves* from their old job to the new one — they don't end up on two jobs simultaneously.

---

## Complete file change list

### Flutter (Dart)

| File | What changed | Bug |
|------|-------------|-----|
| `lib/providers/job_provider.dart` | `createJob()` returns `Job?` instead of `bool`; `assignTechnicians()` gets `forceOverride` param | 1, 3 |
| `lib/services/job_service.dart` | `createJob()` no longer sends `technician_ids`; `assignTechnicians()` gets `forceOverride` param | 1, 3 |
| `lib/services/api_service.dart` | `_handleResponse()` handles non-Map success bodies without crashing | 2 |
| `lib/screens/jobs/create_job_screen.dart` | `_submit()` now calls `assignTechnicians()` separately with real job ID | 1 |
| `lib/screens/jobs/job_detail_screen.dart` | Removed double-reload after assignment; dialog pops with `{ids, force}` map; passes `forceOverride` | 2, 3 |

### Node.js (Backend)

| File | What changed | Bug |
|------|-------------|-----|
| `src/routes/jobs.js` | `PUT /:id/technicians` reads `force_override` from body; `isAdminOverride` requires both role AND flag | 3 |
| `src/services/jobAssignmentService.js` | `assignTechnicians()` gets `forceOverride`; branches on it to skip conflict check and call `removeDriversFromConflictingJobs` | 3 |
| `src/models/Job.js` | `assignTechnicians()` gets `isAdminOverride`; new `removeDriversFromConflictingJobs()` method | 3 |
| `src/middleware/authMiddleware.js` | New file — `verifyToken`, `adminOnly`, `schedulerOrAbove` middleware used by all routes | — |

### Unchanged (no edits needed)
`server.js`, `database.js`, `constants.js`, `jobAssignmentController.js`, `jobStatusController.js`, `jobStatusService.js`, `vehicleAvailabilityService.js`, `availabilityRoutes.js`, `jobAssignmentRoutes.js`, `index.js`, `users.js`, `vehicles.js`

---

## Testing checklist

### Bug 1 — Create Job with drivers
- [ ] Create a job with 2 drivers selected. Open the job immediately. Both drivers should appear.
- [ ] Create a job with **no** drivers. Open the job. "No drivers assigned" should show.
- [ ] Create a job. Watch the network requests in browser devtools. You should see:
  1. `POST /api/jobs` → 201
  2. `PUT /api/job-assignments/:id/technicians` → 200
  Only if drivers were selected should request #2 fire.
- [ ] If the server is down during step 2, the job should still be created. The summary dialog should show a warning about driver assignment, not a crash.

### Bug 2 — Assign driver from Job Detail
- [ ] Open a job, manage drivers, add a driver. The success snackbar (green) should appear. No red error.
- [ ] After adding, the driver should appear in the UI immediately without needing to close and reopen the screen.
- [ ] Remove a driver. Same — no red error, immediate UI update.
- [ ] Check network tab: only ONE request to `PUT /api/job-assignments/:id/technicians`. Not two.

### Bug 3 — Admin override for busy driver
- [ ] Assign Driver A to Job 1 (9am–12pm).
- [ ] As admin, open Job 2 (10am–2pm). Manage Drivers. Driver A should appear greyed out.
- [ ] Select Driver A anyway. The checkbox should be tappable for admins (not for schedulers/technicians).
- [ ] Save. Green snackbar. Driver A should now appear on Job 2.
- [ ] Open Job 1. Driver A should **no longer** appear there.
- [ ] Repeat as a scheduler (non-admin). Driver A should not be selectable in the dialog. The save should fail with a conflict error if somehow submitted.

---

## Common mistakes to avoid

**Don't call `loadJobById()` after `assignTechnicians()` succeeds.**  
The provider handles the reload internally. Calling it again causes two rebuilds and potential stale-data races.

**Don't pass `technicianIds` to `createJob()`.**  
The POST endpoint doesn't process them. Always use the two-step create → assign flow.

**Don't set `force_override: true` from the scheduler role.**  
The backend checks `req.user.role === 'admin' AND force_override === true`. If the JWT says `scheduler`, the override is silently ignored even if the body says `force_override: true`. This is intentional — only admins can move drivers between jobs.

**Don't forget `excludeJobId` when checking driver availability for an existing job.**  
Without it, the driver appears "busy" because they're already assigned to the very job being edited, which is a false conflict. All availability check calls pass the current job's ID as `excludeJobId`.
