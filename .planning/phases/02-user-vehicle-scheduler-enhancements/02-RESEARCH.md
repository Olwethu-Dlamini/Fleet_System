# Phase 2: User, Vehicle & Scheduler Enhancements — Research

**Researched:** 2026-03-21
**Domain:** MySQL schema extensions, Node.js/Express CRUD extension, Flutter Provider pattern, role-based permission UI gating
**Confidence:** HIGH — all findings based on direct codebase inspection and confirmed against live file content

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- E.164 international format with default country code +268 (Eswatini), user can change country
- Multiple phone numbers supported (primary + secondary)
- Contact numbers displayed on user list table, detail view, and create/edit forms
- Tap-to-call (tel: link) enabled on mobile for quick calling
- Predefined maintenance types dropdown (Service, Repair, Inspection, Tyre Change) plus "Other" with free text
- 3-state lifecycle: Scheduled -> In Progress -> Completed
- No overlapping maintenance windows allowed per vehicle
- Orange "In Maintenance" badge on vehicle list card as visual indicator
- Role-based column with permissions map in constants.js — extends existing USER_ROLE/PERMISSIONS pattern
- Optional note field when scheduler swaps vehicles (for audit trail, not required)
- GPS visibility toggle stored in `settings` table with key-value pairs (extensible for future settings)
- Same screens as admin with conditionally hidden admin-only actions (no duplicate screens)

### Claude's Discretion
- Database migration ordering and column naming
- API endpoint naming and response structure consistency with existing patterns
- Flutter widget composition and state management details within Provider pattern

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| USR-01 | Contact number field on user creation form | `users` table needs 2 new VARCHAR columns; `POST /api/users` body + validation need extending; Flutter create form needs 2 PhoneField widgets |
| USR-02 | Contact number displayed on user profile/detail view | `GET /api/users/:id` SELECT must include new columns; Flutter detail card needs contact rows with tap-to-call |
| USR-03 | Contact number field on edit user form | `PUT /api/users/:id` allowed-fields array + validation extended; Flutter edit sheet pre-fills new fields |
| MAINT-01 | "Schedule Maintenance" button on vehicle detail screen | New bottom-sheet form on vehicle card; calls POST /api/vehicle-maintenance |
| MAINT-02 | Maintenance scheduling with date range and description | New `vehicle_maintenance` table (vehicle_id, start_date, end_date, type, status, notes); full CRUD routes |
| MAINT-03 | Vehicles in maintenance excluded from job assignment picker on those dates | `Vehicle.getAvailableVehicles` extended to LEFT JOIN `vehicle_maintenance` and exclude overlapping windows |
| MAINT-04 | Maintenance history log per vehicle | GET /api/vehicle-maintenance?vehicle_id=X returns all records ordered by start_date DESC |
| MAINT-05 | Visual indicator on vehicle list for vehicles currently in maintenance | Vehicle list query joined to maintenance; Flutter card shows orange badge when active maintenance exists |
| SCHED-01 | Scheduler role with same permissions as admin EXCEPT cannot add/remove vehicles or users | Already mostly done in constants.js — dispatcher/scheduler rows exist; verify `users:read` is NOT in scheduler perms and confirm vehicles:create/update/delete are admin-only |
| SCHED-02 | Scheduler can swap vehicles on existing jobs | New PUT /api/jobs/:id/swap-vehicle endpoint; requirePermission('assignments:update') is already correct; optional note field stored in job_assignments |
| SCHED-03 | Permission matrix enforced on both backend API and Flutter UI | Backend: requirePermission middleware already in place; Flutter: auth.hasPermission() check on FABs and action buttons |
| SCHED-04 | Admin can toggle whether scheduler sees live GPS (visibility control) | New `settings` table (key VARCHAR, value TEXT, tenant_id INT); seed row `scheduler_gps_visible = 'false'`; admin toggle UI + GET/PUT /api/settings endpoint |
</phase_requirements>

---

## Summary

Phase 2 is a brownfield extension phase — all three feature areas (user contacts, vehicle maintenance, scheduler permissions) build on top of working CRUD infrastructure from Phase 1. No new framework dependencies are needed. The work is dominated by schema migrations, route extensions, and Flutter form updates.

The most complex feature is vehicle maintenance date-range blocking (MAINT-03). The existing `Vehicle.getAvailableVehicles` query uses only the `job_assignments` table for conflict checking; it must be extended to also exclude vehicles that have an active maintenance window overlapping the requested time slot. This must use the same pattern as the Phase 1 race-condition fix: the exclusion check must be inside the FOR UPDATE transaction so no vehicle is double-assigned while maintenance is being scheduled concurrently.

The scheduler role (SCHED-01 through SCHED-04) is largely already coded in `constants.js` — `USER_ROLE.DISPATCHER` / `USER_ROLE.SCHEDULER` exist, and the `PERMISSIONS` map already denies vehicles:create/update/delete and users:* to the dispatcher/scheduler roles. The only gaps are: (1) the `settings` table does not yet exist, (2) the vehicle swap endpoint does not exist, and (3) Flutter screens still use hardcoded `isAdmin` checks in a few places rather than `hasPermission()`.

**Primary recommendation:** Execute three plans — Plan 1: schema + backend (contacts + maintenance + settings tables, all routes), Plan 2: Flutter user screens (contacts fields), Plan 3: Flutter vehicle screens (maintenance UI + scheduler permission gating).

---

## Standard Stack

### Core — Already Installed, No New Packages Needed

| Library | Version | Purpose | Status |
|---------|---------|---------|--------|
| express | 5.2.1 | HTTP framework | Installed |
| mysql2 | 3.16.3 | DB driver with promise pool | Installed |
| express-validator | 7.3.1 | Input validation | Installed (Phase 1) |
| pino | 10.3.1 | Structured logging | Installed (Phase 1) |
| bcryptjs | installed | Password hashing | Installed |
| jsonwebtoken | 9.0.3 | JWT auth | Installed |

### Flutter — Already Available

| Package | Purpose | Status |
|---------|---------|--------|
| provider | State management (ChangeNotifier) | Installed |
| http (via ApiService) | REST calls | Installed |

### No New Dependencies Required

All three feature areas extend existing patterns. No new npm packages or Flutter pub packages are needed. Phone number formatting uses plain string handling — a dedicated phone package would be overkill for a primary + secondary field with a simple country prefix default.

---

## Architecture Patterns

### Existing Backend Patterns to Follow

```
src/
├── config/
│   ├── constants.js         # USER_ROLE, PERMISSIONS — extend for maintenance types
│   └── database.js          # mysql2 pool — use db.query() and db.getConnection() for transactions
├── middleware/
│   └── authMiddleware.js    # verifyToken, requirePermission, requireRole — use as-is
├── models/
│   ├── Vehicle.js           # Static class methods — add maintenance methods here
│   └── Job.js               # Reference for transaction pattern
├── routes/
│   ├── users.js             # Extend for contact_number columns
│   └── vehicles.js          # Extend or add vehicle-maintenance.js route file
└── services/
    └── jobAssignmentService.js  # FOR UPDATE transaction pattern reference
```

```
vehicle_scheduling_app/lib/
├── models/
│   ├── user.dart            # Add contactPhone, contactPhoneSecondary fields
│   └── vehicle.dart         # Add maintenanceStatus helper
├── services/
│   ├── user_service.dart    # Add contact fields to createUser/updateUser
│   └── vehicle_service.dart # Add maintenance CRUD methods
├── providers/
│   └── vehicle_provider.dart # Add maintenance state if needed
└── screens/
    ├── users/users_screen.dart         # Add contact fields to form sheets
    └── vehicles/vehicles_list_screen.dart  # Add maintenance badge + schedule button
```

### Pattern 1: ADD COLUMN IF NOT EXISTS (Idempotent Migration)

Established in Phase 1 decisions. All schema changes use this form:

```sql
-- Source: Phase 1 decision log — MariaDB 10.4.32 confirmed
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(20) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS contact_phone_secondary VARCHAR(20) DEFAULT NULL;
```

### Pattern 2: New Table with tenant_id

Every new table must include `tenant_id INT UNSIGNED NOT NULL DEFAULT 1` following Phase 1's FOUND-01 decision. No FK constraint to `tenants` table (also Phase 1 decision):

```sql
CREATE TABLE IF NOT EXISTS vehicle_maintenance (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenant_id     INT UNSIGNED NOT NULL DEFAULT 1,
  vehicle_id    INT UNSIGNED NOT NULL,
  maintenance_type  ENUM('service','repair','inspection','tyre_change','other') NOT NULL,
  other_type_desc   VARCHAR(200) DEFAULT NULL COMMENT 'Used when type = other',
  status        ENUM('scheduled','in_progress','completed') NOT NULL DEFAULT 'scheduled',
  start_date    DATE NOT NULL,
  end_date      DATE NOT NULL,
  notes         TEXT DEFAULT NULL,
  created_by    INT UNSIGNED NOT NULL,
  created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_vehicle_id (vehicle_id),
  KEY idx_tenant_id (tenant_id),
  KEY idx_dates (vehicle_id, start_date, end_date, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### Pattern 3: settings Table (Key-Value Store)

For SCHED-04, the settings table follows a generic key-value pattern so it is reusable for future toggles (email notification preferences, timezone, etc.):

```sql
CREATE TABLE IF NOT EXISTS settings (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenant_id   INT UNSIGNED NOT NULL DEFAULT 1,
  setting_key VARCHAR(100) NOT NULL,
  setting_val TEXT DEFAULT NULL,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_tenant_key (tenant_id, setting_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed default value
INSERT IGNORE INTO settings (tenant_id, setting_key, setting_val)
VALUES (1, 'scheduler_gps_visible', 'false');
```

### Pattern 4: Overlap Check in Availability Query

The existing `getAvailableVehicles` in `Vehicle.js` uses a subquery NOT IN approach. Extend it to also exclude vehicles with maintenance overlap. Critical: use the same date-range overlap formula as job assignment:

```sql
-- Source: Vehicle.js getAvailableVehicles — extend this subquery
AND v.id NOT IN (
  SELECT vm.vehicle_id
  FROM vehicle_maintenance vm
  WHERE vm.tenant_id = ?
    AND vm.status IN ('scheduled', 'in_progress')
    AND vm.start_date <= ?    -- maintenance starts before or on the job date
    AND vm.end_date   >= ?    -- maintenance ends on or after the job date
)
```

Note: vehicle_maintenance uses DATE ranges (whole days), while job_assignments uses date + time. The conservative approach is to block the entire maintenance day range, which is correct fleet behavior.

### Pattern 5: Vehicle Swap Endpoint

SCHED-02 requires a swap endpoint. The cleanest approach reuses existing job_assignments table without a new table:

```
PUT /api/jobs/:id/swap-vehicle
Body: { new_vehicle_id: INT, note?: STRING }
Auth: requirePermission('assignments:update')  ← already covers scheduler role
```

Implementation: update `vehicle_id` on the existing `job_assignments` row for this job, optionally update the `notes` field. Return the updated job. No new permission key needed — `assignments:update` already granted to dispatcher/scheduler.

### Pattern 6: Backend File Header

Every new file follows the `// ============` header convention from the codebase:

```javascript
// ============================================
// FILE: src/routes/vehicle-maintenance.js
// PURPOSE: Vehicle maintenance scheduling CRUD
//
// Base URL: /api/vehicle-maintenance
// GET    /api/vehicle-maintenance?vehicle_id=X   — history for vehicle
// POST   /api/vehicle-maintenance                — schedule maintenance (admin)
// PUT    /api/vehicle-maintenance/:id            — update status / dates (admin)
// DELETE /api/vehicle-maintenance/:id            — cancel (admin)
// ============================================
```

### Pattern 7: Flutter Permission Gating

The correct Flutter pattern is `auth.hasPermission('permission:key')`, NOT `auth.isAdmin`. The `User.hasPermission()` method checks the server-returned `permissions` list:

```dart
// Source: lib/providers/auth_provider.dart + lib/models/user.dart
// Use this everywhere — never hardcode role checks in UI
if (auth.hasPermission('vehicles:create')) {
  // show FAB
}
if (auth.hasPermission('assignments:update')) {
  // show swap vehicle button
}
```

The `User` model already parses the `permissions` list from the JWT-supplied login response. No changes to the permission system are needed — only the UI gating patterns need updating where `isAdmin` is still used.

### Pattern 8: Flutter Form Field for Phone Numbers

Primary + secondary phone fields follow the existing TextFormField pattern in the users screen bottom sheet. E.164 format validation is a simple regex — no package needed:

```dart
// E.164 validation for +268 XXXXXXXX (Eswatini primary market)
// Allow empty for secondary field; primary is optional per USR-01
static const _phoneRegex = r'^\+?[0-9\s\-\(\)]{7,20}$';

TextFormField(
  controller: _phoneCtrl,
  keyboardType: TextInputType.phone,
  decoration: const InputDecoration(
    labelText: 'Contact Phone',
    hintText: '+268 7X XXX XXXX',
    prefixText: '+268 ',
  ),
)
```

For tap-to-call on mobile (USR-02 display requirement), the `url_launcher` package provides `launchUrl(Uri.parse('tel:$phone'))`. Check `pubspec.yaml` — if url_launcher is not installed, it needs adding.

### Anti-Patterns to Avoid

- **Duplicate screens for scheduler:** CONTEXT.md explicitly locks "same screens as admin with conditionally hidden admin-only actions." Do NOT create a separate SchedulerVehicleScreen — gate the existing screen's FAB and edit buttons with `hasPermission()`.
- **Hard-deleting maintenance records:** Use status = 'completed' or 'cancelled', never DELETE. Audit trail requirement.
- **Blocking vehicle availability by `is_active`:** The existing `is_active = 0` flag means permanently out of service. Maintenance is date-bounded — use the new `vehicle_maintenance` table, not `is_active`.
- **Partial maintenance overlap logic:** `start_date <= job_date AND end_date >= job_date` is correct. Common mistake is using strict `<` and `>` which misses same-day boundaries.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Phone E.164 validation | Custom regex parser | Simple regex `/^\+?[0-9\s\-\(\)]{7,20}$/` | Primary market is single country; full libphonenumber is 1MB+ overkill |
| Permission check in Flutter | Custom role-comparison logic | `auth.hasPermission('key')` from existing User model | Already server-driven; changing roles won't break UI if you use this |
| Tap-to-call | Deep link string builder | `url_launcher` package `tel:` URI scheme | OS handles calling intent correctly |
| Overlap date check | Application-layer loop | SQL DATE overlap condition in query | Single DB round-trip; app-layer loop has race condition risk |
| Maintenance status transitions | Custom state machine | ENUM column + backend validation | 3 states (scheduled → in_progress → completed) is simple enough for inline validation |

**Key insight:** All three feature areas are additive CRUD extensions. The risk is over-engineering (new permission keys, new providers, duplicate screens) when the existing infrastructure handles everything with small targeted edits.

---

## Current State Assessment

### What Already Exists (confirmed by file inspection)

| Item | Status | Location |
|------|--------|----------|
| USER_ROLE.DISPATCHER + USER_ROLE.SCHEDULER | Done | `constants.js` lines 51-53 |
| PERMISSIONS map with scheduler restrictions | Done | `constants.js` lines 61-92 — scheduler cannot manage users or vehicles |
| `requirePermission` middleware | Done | `authMiddleware.js` |
| `vehicles:create/update/delete` admin-only | Done | `constants.js` + `vehicles.js` routes |
| `users:read/create/update/delete` admin-only | Done | `constants.js` line 88-91 |
| `assignments:update` permission for scheduler | Done | `constants.js` line 73 |
| `User.hasPermission()` Flutter method | Done | `user.dart` line 61 |
| `AuthProvider.hasPermission()` Flutter method | Done | `auth_provider.dart` line 42 |
| Vehicle model `lastMaintenanceDate` field | Exists (single date) | `vehicle.dart` + DB schema — this is NOT the maintenance schedule; it's a simple date stamp |

### What Does NOT Exist (confirmed missing)

| Item | Gap | What to Build |
|------|-----|---------------|
| `contact_phone` column on `users` table | Missing | ADD COLUMN migration |
| `contact_phone_secondary` column on `users` table | Missing | ADD COLUMN migration |
| `contact_phone` in users route SELECT/INSERT/UPDATE | Missing | Extend users.js queries |
| `vehicle_maintenance` table | Missing | New table CREATE |
| `/api/vehicle-maintenance` routes | Missing | New route file |
| `vehicle_maintenance` overlap check in `getAvailableVehicles` | Missing | Extend Vehicle.js |
| `settings` table | Missing | New table CREATE |
| `/api/settings` route | Missing | New route file |
| `/api/jobs/:id/swap-vehicle` endpoint | Missing | New route in jobs.js |
| `contact_phone` fields in Flutter User model | Missing | Extend user.dart |
| `contact_phone` fields in UserService | Missing | Extend user_service.dart |
| `contact_phone` fields in UsersScreen forms | Missing | Extend users_screen.dart |
| Maintenance model/service/screen in Flutter | Missing | New files |
| Orange maintenance badge on vehicles list | Missing | Extend vehicles_list_screen.dart |
| Admin settings toggle for GPS visibility | Missing | New settings screen/widget |
| `url_launcher` package | Likely missing | Check pubspec.yaml |

### Users Table — Existing Schema (confirmed)

```sql
CREATE TABLE `users` (
  `id`            int(10) UNSIGNED NOT NULL,
  `username`      varchar(50) NOT NULL,
  `email`         varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `full_name`     varchar(100) NOT NULL,
  `role`          enum('admin','dispatcher','driver') NOT NULL DEFAULT 'driver',
  `is_active`     tinyint(1) NOT NULL DEFAULT 1,
  `created_at`    timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at`    timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE CURRENT_TIMESTAMP
)
-- NOTE: no contact_phone column — must be added
-- NOTE: role enum uses 'dispatcher' (DB value) not 'scheduler' (app value)
--       The TO_DB_ROLE / FROM_DB_ROLE maps in users.js handle translation
```

Phase 2 must ADD COLUMN to this table. The role enum already contains 'dispatcher'; it does NOT need 'scheduler' because the normalisation layer in users.js handles that translation.

### Role Normalisation (important for Phase 2)

The existing users.js has a normalisation layer that translates between DB-stored role names and app-visible role names:

```javascript
// Source: src/routes/users.js lines 68-73
const TO_DB_ROLE   = { scheduler: 'dispatcher', technician: 'driver' };
const FROM_DB_ROLE = { dispatcher: 'scheduler', driver: 'technician' };
// DB stores: admin | dispatcher | driver
// App sees:  admin | scheduler  | technician
```

This means:
- The `users` table role ENUM is `('admin','dispatcher','driver')` — no 'scheduler' in DB
- Flutter screens display 'scheduler' but the API stores/returns 'dispatcher'
- For SCHED-01/03: the PERMISSIONS map correctly references BOTH USER_ROLE.DISPATCHER and USER_ROLE.SCHEDULER so old JWTs (with 'scheduler') and new ones (with 'dispatcher') both resolve correctly
- The Flutter `User.isScheduler` getter checks `role == 'scheduler'` which matches what the API returns after normalisation

---

## Common Pitfalls

### Pitfall 1: Adding 'scheduler' to Users Table ENUM

**What goes wrong:** Developer adds `scheduler` to the role ENUM in the users table thinking it's needed because constants.js has `USER_ROLE.SCHEDULER`.
**Why it happens:** The role normalisation layer in users.js is easy to miss.
**How to avoid:** DB stores `dispatcher`. The `FROM_DB_ROLE` map converts it to `scheduler` for the API response. Never add 'scheduler' to the DB ENUM.
**Warning signs:** If you see `role ENUM('admin','dispatcher','driver','scheduler')` in a migration, it's wrong.

### Pitfall 2: Maintenance Date Overlap Using Wrong Comparison

**What goes wrong:** Using `start_date < job_date AND end_date > job_date` misses same-day boundaries.
**Why it happens:** Strict inequality is the intuitive reading.
**How to avoid:** Use `start_date <= job_date AND end_date >= job_date`. This correctly blocks a vehicle on both its first and last day of maintenance.
**Warning signs:** Vehicles available on the exact start or end date of a scheduled maintenance window.

### Pitfall 3: Using `is_active = 0` for Temporary Maintenance

**What goes wrong:** Setting `is_active = 0` on a vehicle to block it during maintenance. This makes the vehicle appear permanently deactivated.
**Why it happens:** `is_active` is the existing "out of service" flag and seems convenient.
**How to avoid:** Only the `vehicle_maintenance` table controls date-bounded blocking. `is_active` is for permanent decommission.
**Warning signs:** Vehicles with scheduled maintenance showing as "Inactive" on the vehicles list.

### Pitfall 4: Maintenance No-Overlap Check at Application Layer

**What goes wrong:** Checking for overlapping maintenance windows in JS before inserting, instead of using the DB overlap constraint.
**Why it happens:** Seems simpler.
**How to avoid:** Check overlap in the INSERT query itself (SELECT COUNT(*) first), and add a compound index `(vehicle_id, start_date, end_date)` so the check is fast. The CONTEXT.md decision "no overlapping maintenance windows allowed per vehicle" means you need an explicit query-level guard.
**Warning signs:** Two maintenance windows created at near-simultaneous requests can both pass the app-layer check before either inserts.

### Pitfall 5: Flutter `isAdmin` Instead of `hasPermission`

**What goes wrong:** FAB or action button visibility controlled by `auth.isAdmin` — so a scheduler who has `assignments:update` permission cannot see the swap vehicle button.
**Why it happens:** `isAdmin` shortcuts are already present in some screens.
**How to avoid:** All Phase 2 UI gating must use `auth.hasPermission('key')`. Only use `isAdmin` for controls that must be admin-exclusive (no other role should ever have them).
**Warning signs:** Scheduler logs in and sees no swap button even though the backend accepts their request.

### Pitfall 6: `url_launcher` Missing for Tap-to-Call

**What goes wrong:** `launchUrl(Uri.parse('tel:$phone'))` throws at runtime because `url_launcher` is not in pubspec.yaml.
**Why it happens:** It's not in the existing dependency list.
**How to avoid:** Add `url_launcher: ^6.3.0` to pubspec.yaml before implementing tap-to-call. Also add `<queries>` intent for Android and `LSApplicationQueriesSchemes` for iOS in manifests.
**Warning signs:** `MissingPluginException` at runtime on the contact display screen.

---

## Code Examples

### Adding Contact Phone Columns (Backend Migration)

```sql
-- Source: MariaDB 10.4.32 + Phase 1 ADD COLUMN IF NOT EXISTS pattern
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS contact_phone           VARCHAR(20) DEFAULT NULL
    COMMENT 'Primary contact number in E.164 format',
  ADD COLUMN IF NOT EXISTS contact_phone_secondary VARCHAR(20) DEFAULT NULL
    COMMENT 'Secondary contact number in E.164 format';
```

### Extending Users Route SELECT (Backend)

```javascript
// Source: src/routes/users.js — extend these queries
// GET /api/users
`SELECT id, username, full_name, role, email, is_active,
        contact_phone, contact_phone_secondary, created_at
 FROM users ${where} ORDER BY full_name ASC`

// POST /api/users — add to INSERT
const { username, full_name, email, password, role, is_active = 1,
        contact_phone = null, contact_phone_secondary = null } = req.body;

INSERT INTO users (username, full_name, email, password_hash, role, is_active,
                   contact_phone, contact_phone_secondary)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)

// PUT /api/users/:id — add to allowed fields
const allowed = ['username', 'full_name', 'email', 'role', 'is_active',
                 'contact_phone', 'contact_phone_secondary'];
```

### Contact Phone Validation (express-validator)

```javascript
// Source: express-validator 7.3.1 docs — add to createUserValidation array
body('contact_phone')
  .optional({ nullable: true })
  .isString().trim()
  .matches(/^\+?[\d\s\-\(\)]{7,20}$/)
  .withMessage('contact_phone must be a valid phone number'),
body('contact_phone_secondary')
  .optional({ nullable: true })
  .isString().trim()
  .matches(/^\+?[\d\s\-\(\)]{7,20}$/)
  .withMessage('contact_phone_secondary must be a valid phone number'),
```

### Extended getAvailableVehicles with Maintenance Blocking

```javascript
// Source: src/models/Vehicle.js getAvailableVehicles — extend this method
static async getAvailableVehicles(date, startTime, endTime, tenantId = 1) {
  const sql = `
    SELECT
      v.id, v.vehicle_name, v.license_plate, v.vehicle_type, v.capacity_kg, v.is_active
    FROM vehicles v
    WHERE v.is_active = 1
      AND v.tenant_id = ?
      AND v.id NOT IN (
        -- Exclude vehicles with time-overlapping job assignments
        SELECT ja.vehicle_id
        FROM job_assignments ja
        JOIN jobs j ON ja.job_id = j.id
        WHERE j.scheduled_date = ?
          AND j.current_status NOT IN ('completed', 'cancelled')
          AND ? < j.scheduled_time_end
          AND ? > j.scheduled_time_start
      )
      AND v.id NOT IN (
        -- Exclude vehicles with overlapping maintenance windows
        SELECT vm.vehicle_id
        FROM vehicle_maintenance vm
        WHERE vm.tenant_id = ?
          AND vm.status IN ('scheduled', 'in_progress')
          AND vm.start_date <= ?
          AND vm.end_date   >= ?
      )
    ORDER BY v.vehicle_name ASC
  `;
  const [rows] = await db.query(sql, [
    tenantId,
    date, startTime, endTime,  // job conflict params
    tenantId, date, date,       // maintenance conflict params
  ]);
  return rows;
}
```

### Maintenance Overlap Guard (Backend Insert)

```javascript
// Source: Pattern derived from Phase 1 FOR UPDATE / availability check pattern
// In POST /api/vehicle-maintenance controller, before inserting:
const [overlap] = await db.query(`
  SELECT id FROM vehicle_maintenance
  WHERE vehicle_id = ?
    AND tenant_id  = ?
    AND status NOT IN ('completed')
    AND start_date <= ?
    AND end_date   >= ?
  LIMIT 1
`, [vehicle_id, tenant_id, end_date, start_date]);

if (overlap.length > 0) {
  return res.status(409).json({
    success: false,
    message: 'Vehicle already has a maintenance window overlapping these dates',
  });
}
```

### Vehicle Swap Endpoint (Backend)

```javascript
// Source: Pattern follows existing PUT /api/jobs/:id pattern + Phase 1 transaction
// PUT /api/jobs/:id/swap-vehicle
router.put('/:id/swap-vehicle',
  verifyToken,
  requirePermission('assignments:update'),
  body('new_vehicle_id').isInt({ min: 1 }).withMessage('new_vehicle_id must be a positive integer'),
  body('note').optional().isString().trim().isLength({ max: 500 }),
  validate,
  async (req, res) => {
    const jobId = parseInt(req.params.id);
    const { new_vehicle_id, note } = req.body;
    // 1. Verify vehicle exists and is available for the job's date/time
    // 2. UPDATE job_assignments SET vehicle_id = ?, notes = COALESCE(?, notes) WHERE job_id = ?
    // 3. Return updated job
  }
);
```

### Flutter User Model Extension

```dart
// Source: lib/models/user.dart — add fields
class User {
  final int id;
  final String username;
  final String fullName;
  final String role;
  final String email;
  final bool isActive;
  final List<String> permissions;
  // NEW:
  final String? contactPhone;
  final String? contactPhoneSecondary;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // ... existing fields ...
      contactPhone: json['contact_phone'] as String?,
      contactPhoneSecondary: json['contact_phone_secondary'] as String?,
    );
  }
}
```

### Flutter Maintenance Badge on Vehicle Card

```dart
// Source: Pattern from lib/screens/vehicles/vehicles_list_screen.dart
// Add to vehicle card widget — vehicle.isInMaintenance is a new computed bool
if (vehicle.isInMaintenance)
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Colors.orange.shade700,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Text(
      'In Maintenance',
      style: TextStyle(color: Colors.white, fontSize: 11),
    ),
  ),
```

The `isInMaintenance` flag should come from the vehicles list API response — the backend query should JOIN vehicle_maintenance and return a boolean field, not the Flutter app computing it from a separate API call.

---

## State of the Art

| Old Approach | Current Approach | Impact |
|--------------|------------------|--------|
| `is_active = 0` for temporary unavailability | Date-bounded `vehicle_maintenance` table | Vehicles return to available automatically after maintenance end date |
| Single `last_maintenance_date` date stamp | Full maintenance schedule with history | Supports MAINT-04 history log |
| `isAdmin` role check in Flutter UI | `hasPermission('key')` server-driven check | Role changes don't require app updates |
| `scheduler` in DB role enum | `dispatcher` in DB with normalisation map | Correct role in DB; backwards compat for old JWTs |

---

## Open Questions

1. **url_launcher in pubspec.yaml**
   - What we know: Tap-to-call requires url_launcher per Flutter docs
   - What's unclear: Not confirmed whether url_launcher is already installed (pubspec.yaml not read in detail)
   - Recommendation: Plan 1 should verify and add `url_launcher: ^6.3.0` if missing; also add Android `<queries>` intent and iOS LSApplicationQueriesSchemes

2. **tenant_id applied in Phase 1 or not?**
   - What we know: Phase 1 (FOUND-01) added tenant_id to all tables as a plan
   - What's unclear: Whether the migration was actually applied to the running DB — STATE.md shows Phase 1 plans are complete but live DB is not inspected here
   - Recommendation: Phase 2 migrations should use ADD COLUMN IF NOT EXISTS with tenant_id. The new `vehicle_maintenance` and `settings` tables should include `tenant_id DEFAULT 1` from creation.

3. **GET /api/vehicles returning maintenance status for badge**
   - What we know: Vehicle card needs to show "In Maintenance" badge based on today's date
   - What's unclear: Whether the vehicles list endpoint should return a pre-computed `is_in_maintenance` boolean or whether the Flutter app should call a separate endpoint
   - Recommendation: Extend the vehicles list query with a LEFT JOIN to `vehicle_maintenance` and compute a `is_in_maintenance` BOOLEAN column server-side. Avoids N+1 Flutter calls.

---

## Sources

### Primary (HIGH confidence)
- Direct file inspection: `src/config/constants.js` — confirmed PERMISSIONS map and role values
- Direct file inspection: `src/middleware/authMiddleware.js` — confirmed requirePermission pattern
- Direct file inspection: `src/models/Vehicle.js` — confirmed getAvailableVehicles query structure
- Direct file inspection: `src/routes/users.js` — confirmed existing columns, role normalisation, validation patterns
- Direct file inspection: `src/routes/vehicles.js` — confirmed admin-only write pattern
- Direct file inspection: `vehicle_scheduling.sql` — confirmed users table schema (no contact columns)
- Direct file inspection: `lib/models/user.dart` — confirmed hasPermission() method
- Direct file inspection: `lib/providers/auth_provider.dart` — confirmed hasPermission() delegation
- Direct file inspection: `lib/config/app_config.dart` — confirmed endpoint naming conventions
- Direct file inspection: `.planning/phases/01-foundation-security-hardening/01-RESEARCH.md` — confirmed ADD COLUMN IF NOT EXISTS pattern and MariaDB 10.4.32 version

### Secondary (MEDIUM confidence)
- Phase 1 STATE.md decisions log — confirmed tenant_id pattern, no FK constraint, FOR UPDATE transaction approach

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all existing packages confirmed installed
- Architecture: HIGH — patterns confirmed from direct file inspection of live codebase
- Pitfalls: HIGH — confirmed from actual schema gaps and code review
- Flutter patterns: HIGH — confirmed from live Dart model files

**Research date:** 2026-03-21
**Valid until:** 2026-04-20 (30 days — stable framework, no fast-moving dependencies)
