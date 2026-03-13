# Vehicle Scheduling App — Full Bug Fix Handoff

**Project:** Flutter + Node.js Vehicle Scheduling App  
**Backend:** Express.js + MySQL  
**Frontend:** Flutter (Provider pattern)  
**Sessions:** Multi-session, bugs 1–7 (Bug 3 spanned 3 sessions)

---

## Architecture Cheat Sheet

```
Flutter Screen
  → Provider  (state + business logic)
    → Service  (HTTP calls)
      → Express Route  (URL mapping)
        → Controller   (request/response handling)
          → Service    (business logic)
            → Model    (SQL queries)
```

**Key rule:** Always enter the chain at the Service layer, never the Model layer directly. The Model only does raw SQL — conflict checks, override logic, and guards all live in the Service.

---

## Bug 1 — Drivers assigned on Create Job were not saved ✅

### Symptom
Creating a job with 2 drivers pre-assigned showed "2 drivers" in the UI, but the saved job had none.

### Root Cause
`POST /api/jobs` silently ignored `technician_ids` in the request body. The UI was counting the local list, not confirming what the server saved.

### Fix
Split create into two steps: create the job first (get the ID back), then call `assignTechnicians()` as a separate request.

**Files changed:**
- `job_service.dart` — removed `technician_ids` from the create payload
- `job_provider.dart` — `createJob()` now returns `Job?` instead of `bool`
- `create_job_screen.dart` — step 1: create → step 2: assign technicians using returned ID

---

## Bug 2 — False error after assigning a driver from the detail screen ✅

### Symptom
Assigning a driver succeeded on the server but showed an error in the UI.

### Root Cause
Double reload race condition. The provider already calls `_reloadSingleJob()` internally after `assignTechnicians()`. The screen was then calling `loadJobById()` again — the second call returned while the first was still resolving, putting the UI in a broken state.

### Fix
Remove all redundant `loadJobById()` calls after any successful provider action. Read the updated job directly from the provider instead:

```dart
if (success) {
  final updated = context.read<JobProvider>().selectedJob;
  if (updated != null && mounted) setState(() => _job = updated);
}
```

**Files changed:** `job_detail_screen.dart`

---

## Bug 3 — Admin force-override for busy drivers never worked ✅

### Symptom
Admin selects a driver already assigned to an overlapping job, ticks "override", confirms — still gets a conflict error.

### Root Cause (layered — took 3 sessions to find the final break)
The `force_override` flag was read in Flutter but never survived the full chain to the service layer. Each layer had its own break:

```
Flutter screen         sends force_override: true ✅
  → job_provider        passes forceOverride ✅
    → job_service        sends force_override in body ✅
      → jobAssignmentRoutes.js  routes to controller ✅
        → jobAssignmentController.js
            reads { technician_ids, assigned_by } only ❌  ← BUG (final fix)
            never reads force_override from body
            calls service with undefined as 4th arg
          → JobAssignmentService.assignTechnicians(…, undefined)
              defaults forceOverride = false ← override silently dropped
              runs conflict check → throws ❌
```

Additionally, an earlier attempt fixed `jobs.js` (the `/api/jobs/:id/technicians` route) when Flutter actually calls `/api/job-assignments/:id/technicians` — a completely separate route with its own controller.

### Fix
`jobAssignmentController.js` — `assignTechnicians()` method:

```javascript
// Before (broken):
const { technician_ids = [], assigned_by } = req.body;
// ...
await JobAssignmentService.assignTechnicians(jobId, techIds, parseInt(assigned_by));
//                                                                         ↑ undefined

// After (fixed):
const { technician_ids = [], assigned_by, force_override = false } = req.body;
// ...
const forceOverride = req.user.role === 'admin' && force_override === true;
await JobAssignmentService.assignTechnicians(jobId, techIds, parseInt(assigned_by), forceOverride);
```

**Security note:** `forceOverride` is only true when `req.user.role === 'admin'` AND `force_override === true` in the body. A non-admin sending `force_override: true` still gets `false`.

**What happens when forceOverride = true:**
`JobAssignmentService.assignTechnicians()` calls `Job.removeDriversFromConflictingJobs()` first — this deletes the driver from their old overlapping job — then inserts them on the new job. The driver *moves*, they are never double-booked.

**Files changed (full chain):**
| File | Change |
|------|--------|
| `job_detail_screen.dart` | Dialog pops typed `Map<String,dynamic>` with `ids` + `force` keys |
| `job_provider.dart` | `assignTechnicians()` accepts `bool forceOverride = false` |
| `job_service.dart` | Conditionally includes `force_override: true` in PUT body |
| `jobAssignmentController.js` | Reads `force_override`, computes `forceOverride`, passes to service ← **final fix** |
| `jobAssignmentService.js` | `assignTechnicians()` accepts `forceOverride`, branches on it |
| `Job.js` | `assignTechnicians()` accepts flag; new method `removeDriversFromConflictingJobs()` |

---

## Bug 4 — Drivers wiped when a vehicle was assigned later ✅

### Symptom
Job has 2 drivers assigned. Admin assigns a vehicle. Drivers disappear.

### Root Cause
`_assignVehicle()` and `_swapVehicle()` called `assignJob()` without passing `technicianIds`. The service sent `technician_ids: []` in the body — the backend interpreted an explicit empty array as "clear all drivers."

### Fix
Pass the current technician list when assigning a vehicle:

```dart
// job_detail_screen.dart
final success = await context.read<JobProvider>().assignJob(
  jobId: _job.id,
  vehicleId: vehicleId,
  assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
  technicianIds: _job.technicians.map((t) => t.id).toList(), // ← added
);
```

And in the service, omit the field entirely when the list is empty (omission ≠ empty array):

```dart
// job_service.dart
if (technicianIds.isNotEmpty) 'technician_ids': technicianIds,
```

**Files changed:** `job_detail_screen.dart`, `job_service.dart`

---

## Bug 5 — Cancel Job assertion error cascade ✅

### Symptom
Cancelling a job triggered multiple errors: Hero tag clash, `TextEditingController` used after disposal, RenderFlex overflow, framework assertion, dirty widget in wrong build scope.

### Root Cause
`notifyListeners()` fired synchronously inside an `async` provider method while Flutter was mid-frame processing the dialog-close Hero animation. Updating state during a build/layout pass violates Flutter's single-pass rendering contract.

### Fix
Defer all post-action state updates to the next frame:

```dart
// job_provider.dart
import 'package:flutter/scheduler.dart';

SchedulerBinding.instance.addPostFrameCallback((_) {
  notifyListeners();
  const terminalStatuses = {'cancelled', 'completed'};
  if (!terminalStatuses.contains(newStatus)) _refreshJobSilently(jobId);
});
```

```dart
// job_detail_screen.dart — after status change
SchedulerBinding.instance.addPostFrameCallback((_) {
  if (!mounted) return;
  final updated = context.read<JobProvider>().selectedJob;
  setState(() => _job = updated ?? _job.copyWith(currentStatus: newStatus));
  _showSnack('Status updated to ${newStatus.replaceAll('_', ' ')}');
});

// Dispose controller safely
SchedulerBinding.instance.addPostFrameCallback((_) => controller.dispose());
```

**Hero tag clash fix:** Added `useRootNavigator: false` to all 8 `showDialog` calls in `job_detail_screen.dart`. Without this, dialogs mount at the root Navigator, and closing them triggers Hero transitions that conflict with the screen's own heroes.

**Files changed:** `job_provider.dart`, `job_detail_screen.dart`

---

## Bug 6 — Dashboard stat cards showed wrong counts for technician role ✅

### Three sub-bugs in `dashboard_screen.dart`:

**6a — Label/count mismatch**  
The counts used a single shared variable that was overwritten in a chain, so the "Assigned" card showed the count for "In Progress" etc.  
Fix: compute four independent `where()` counts, one per status.

**6b — Technician dashboard stuck on loading spinner**  
`isLoading` included `vehProvider.isLoading`, but technicians never call `loadVehicles()` — that future never completes.  
Fix:
```dart
final isLoading = auth.isTechnician
    ? _loading || jobProvider.isLoading
    : _loading || jobProvider.isLoading || vehProvider.isLoading;
```

**6c — No error handling around `loadMyJobs()`**  
An exception left `_loading = true` forever, freezing the screen.  
Fix: wrap in try/catch, always set `_loading = false` in finally.

**Files changed:** `dashboard_screen.dart`

---

## Key Rules (Lessons Learned)

| # | Rule |
|---|------|
| 1 | **Enter the chain at the Service layer, never the Model.** The Model only does SQL. Conflict checks, overrides, and guards live in the Service. |
| 2 | **Omitting a JSON field ≠ sending `[]`.** Use `if (list.isNotEmpty) 'key': list` to avoid accidentally clearing data. |
| 3 | **Use `SchedulerBinding.instance.addPostFrameCallback`, not `Future.microtask`.** Microtasks still run within the same frame. Post-frame callbacks run after Flutter finishes building/layout. |
| 4 | **`await showDialog<T>()` with a typed return, not `.then()`.** Typed dialogs make the result obvious and prevent casting bugs. |
| 5 | **`useRootNavigator: false` on all dialogs inside nested screens.** Prevents Hero animation conflicts when the dialog closes. |
| 6 | **Never call `loadJobById()` after `assignTechnicians()`/`assignJob()`.** The provider reloads internally — a second call causes a race condition. |
| 7 | **Stat card label and filter must match exactly.** If the badge says "Assigned", the `where()` filter must check `currentStatus == 'assigned'`. |
| 8 | **Only include a provider's `isLoading` if the screen actually calls that provider.** Including `vehProvider.isLoading` on a screen that never loads vehicles freezes it. |
| 9 | **Every `await` network call needs try/catch that always clears the loading flag.** Use `finally` so the flag clears even on error. |
| 10 | **Thread flags through every layer.** A flag missing at any single layer (screen → provider → service → route → controller → service → model) silently breaks the entire feature. Log the flag at the controller so you can verify it arrived. |
| 11 | **Know which route your client actually calls.** `/api/jobs/:id/technicians` and `/api/job-assignments/:id/technicians` are different routes with different controllers. Check the network tab/logs first. |

---

## Output Files

| File | Bug(s) Fixed |
|------|-------------|
| `jobAssignmentController.js` | Bug 3 (final fix — force_override threading) |
| `jobs.js` | Bug 3 (intermediate fix — wrong route, kept for completeness) |
| `job_detail_screen.dart` | Bugs 2, 3, 4, 5 |
| `job_provider.dart` | Bugs 1, 3, 5 |
| `job_service.dart` | Bugs 1, 3, 4 |
| `dashboard_screen.dart` | Bug 6a, 6b, 6c |

---

*All 7 bugs resolved across 3 sessions. No known open issues.*
