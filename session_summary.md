# Vehicle Scheduling App — Dev Session Summary

## Project Stack
- **Frontend:** Flutter/Dart, Provider state management
- **Backend:** Node.js/Express, MySQL 5.6
- **Auth:** JWT tokens, role-based permissions
- **Roles:** `admin`, `scheduler`, `technician`

## App Context
Internet company field service app — job types: `installation`, `delivery`, `miscellaneous`

---

## Permission Matrix
| Action | Admin | Scheduler | Technician |
|--------|-------|-----------|------------|
| See all jobs | ✅ | ✅ | ❌ (own only) |
| Create jobs | ✅ | ✅ | ❌ |
| Assign vehicle | ✅ | ✅ | ❌ |
| Swap vehicle | ✅ | ❌ | ❌ |
| Remove vehicle | ✅ | ❌ | ❌ |
| Manage drivers | ✅ | ❌ | ❌ |
| Override busy driver | ✅ | ❌ | ❌ |
| Update job status | ✅ | ✅ | ✅ (limited) |
| Manage users | ✅ | ❌ | ❌ |

---

## Database Tables (Key)
```sql
jobs                  -- main job table, escalation_status col exists but unused
job_assignments       -- single driver_id (legacy)
job_technicians       -- multi-driver assignments (current system)
job_status_history    -- audit log
users                 -- full_name, username, email, role, is_active
```

---

## Fixes Completed This Session

### 1. `create_job_screen.dart`
- **Bug:** Job type dropdown had `value: 'Miscellenous'` — capital M + misspelling caused MySQL ENUM rejection, job was never created
- **Fix:** Changed to `value: 'miscellaneous'` (lowercase, correct spelling)
- **Dropdown options:** Installation, Delivery, Miscellaneous (maintenance removed per client request)
- **SQL migration needed:**
```sql
ALTER TABLE jobs MODIFY COLUMN job_type ENUM('installation','delivery','miscellaneous') NOT NULL;
```

### 2. `job.dart` (model)
- **Bug:** `typeDisplayName` had no case for `'miscellaneous'` — rendered raw string
- **Fix:** Added `case 'miscellaneous': return 'Miscellaneous';`

### 3. `users_screen.dart`
- **Bug:** Password fields hidden behind `if (!_isEditing)` — no way to change password when editing a user
- **Fix:** Added "Change Password" toggle row in edit mode. Tapping expands New Password + Confirm fields. Fields are optional (validators gated on `_changePassword` bool). On save, calls `resetPassword()` alongside `updateUser()` if toggle is on.
- **New state vars:** `_changePassword`, `_showNewPass`

### 4. Technician Dashboard Fix (from previous session — in compaction summary)
- Technicians now call `loadMyJobs()` → `GET /api/jobs/my-jobs`
- Dashboard filter: `j.hasTechnician(userId) || j.driverId == userId`
- `GET /api/jobs` auto-scopes by role on backend

---

## Reassignment Feature (Admin Only)

### What was built
Admin can fully reassign an existing job — change drivers, remove individual drivers, swap/remove vehicle.

### `job_detail_screen.dart` changes
- `canManageDrivers` restricted to `auth.isAdmin` only (was admin + scheduler)
- Each driver row shows a `person_remove` icon button → `_unassignDriver()` confirms then removes single driver
- New `_unassignVehicle()` method + "Remove Vehicle" red button (admin + vehicle assigned)
- Manage Drivers dialog: admin can select busy drivers with amber warning (override). Non-admin still blocked from busy drivers
- `isAdmin` captured before `showDialog` so it's available inside `StatefulBuilder`

### `job_provider.dart` changes
- Added `unassignVehicle({required int jobId})` — calls service, reloads single job

### `jobs.js` (backend routes) changes
- `PUT /:id/technicians` — passes `isAdminOverride = req.user.role === 'admin'` to `Job.assignTechnicians()`
- New `DELETE /:id/vehicle` endpoint — admin only, deletes `job_assignments` row, reverts `assigned` → `pending`, logs to `job_status_history`

### `job_service.dart` changes
- Added `unassignVehicle({required int jobId})` — calls `DELETE /api/jobs/$jobId/vehicle`

### `api_service.dart` — no changes needed
- `delete()` method already existed ✅

---

## File Output Locations
```
/mnt/user-data/outputs/
  session_summary.md              ← this file
  users_screen.dart               ← password edit fix
  fixes/
    create_job_screen.dart        ← miscellaneous fix
    job.dart                      ← typeDisplayName fix
  reassignment/
    job_detail_screen.dart        ← full reassignment UI
    job_provider.dart             ← unassignVehicle added
    job_service.dart              ← unassignVehicle added
    jobs.js                       ← DELETE /vehicle + admin override
```

---

## Known Pending Items
- `Job.assignTechnicians()` in `Job.js` (backend model) needs to accept and use the `isAdminOverride` flag to skip conflict check when `true`
- SQL migration for `job_type` ENUM must be run on production DB

---

## Key Architecture Notes
- Two parallel assignment systems: `job_assignments.driver_id` (legacy) + `job_technicians` table (current). Both must be written to.
- `technicians_json` is a `GROUP_CONCAT` field returned by queries (MySQL 5.6 — no JSON_ARRAYAGG). Flutter parses pipe-delimited format.
- `_reloadSingleJob(jobId)` pattern used everywhere — avoids full list reload which breaks technician context
- `ApiService` is a singleton — `setAuthToken()` called once at login, all services share it
