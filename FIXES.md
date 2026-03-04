# Vehicle Scheduling App — Bug Fixes & Implementation Log

## Overview

This document covers every bug found and fixed during the development of the Vehicle Scheduling Flutter app and its Node.js backend. Each section explains what the bug was, why it happened, and exactly what was changed to fix it.

---

## 1. Route Not Found — `/api/users` returning 404

### Symptom
```
GET http://172.16.100.56:3000/api/users?role=technician
Response 404 — GET error: Route not found
```

### Root Cause
`users.js` was never registered in `src/routes/index.js`. The route file existed but Express didn't know about it.

### Fix — `src/routes/index.js`
```js
const userRoutes = require('./users');
router.use('/users', userRoutes); // ← added
```

---

## 2. "Admin Role Required" — 403 on vehicle and user write endpoints

### Symptom
```
POST error: Admin role required
VehicleService.createVehicle error: Admin role required
```
Logged in as admin, but all POST/PUT/DELETE requests to `/api/vehicles` and `/api/users` were rejected with 403.

### Root Cause
Both `vehicles.js` and `users.js` had **inline role guard functions** that checked `req.user.role !== 'admin'` using hardcoded strings. These guards also assumed `verifyToken` had already run (to populate `req.user`) — but `verifyToken` was **never called** on those routes. Since `req.user` was always `undefined`, the guard always failed with 403.

### Fix — `src/routes/vehicles.js` and `src/routes/users.js`

Replaced the inline guards with `[verifyToken, adminOnly]` middleware arrays imported from the shared `authMiddleware.js`:

```js
// BEFORE — broken
function requireAdmin(req, res, next) {
  if (!req.user || req.user.role !== 'admin') { // req.user is always undefined!
    return res.status(403).json({ message: 'Admin role required' });
  }
  next();
}

// AFTER — fixed
const { verifyToken, adminOnly, schedulerOrAbove } = require('../middleware/authMiddleware');
const requireAdmin            = [verifyToken, adminOnly];
const requireAdminOrScheduler = [verifyToken, schedulerOrAbove];
```

Express accepts arrays of middleware in route handlers. `verifyToken` runs first (parses the JWT and sets `req.user`), then `adminOnly` checks the role. Each route is now self-contained.

---

## 3. "Not Authenticated" — 401 on all `/api/users` requests

### Symptom
```
GET http://172.16.100.56:3000/api/users?active=all
Response 401 — GET error: Not authenticated
```
All requests to `/api/users` returned 401 even though the user was logged in.

### Root Cause (Flutter side)
`ApiService` was a **regular class**, not a singleton. Every `new ApiService()` created a fresh isolated instance with `_authToken = null`. When `auth.injectToken(someInstance)` was called in the dashboard, it set the token on *that specific instance* — but `UserService` created its *own separate* `ApiService()` that never received the token.

### Root Cause (Backend side)
Even after the Flutter singleton fix, the backend `users.js` still had no `verifyToken` in the middleware chain (see Fix #2 above). Both problems existed simultaneously.

### Fix 1 — `lib/services/api_service.dart` — Singleton pattern
```dart
class ApiService {
  // Singleton: every service shares the same instance and the same token
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();
  // ...
}
```

### Fix 2 — `lib/providers/auth_provider.dart` — Auto-inject on login
Token is now set on the singleton automatically at every auth state change:

```dart
// After login:
_token = await _authService.getToken();
ApiService().setAuthToken(_token); // ← auto-injects for ALL services

// After app restart (checkAuthStatus):
_token = await _authService.getToken();
ApiService().setAuthToken(_token); // ← same

// After logout:
_token = null;
ApiService().setAuthToken(null); // ← clears from all services
```

`injectToken()` was updated to be backwards-compatible (optional argument) but now operates on the singleton:
```dart
void injectToken([ApiService? apiService]) {
  ApiService().setAuthToken(_token); // always sets on the singleton
}
```

---

## 4. Double URL — `/api` appearing twice in requests

### Symptom
```
GET http://172.16.100.56:3000/apihttp://172.16.100.56:3000/api/users
Response 404
```

### Root Cause
`user_service.dart` was building URLs using `AppConfig.baseUrl + '/users'`, which produced the full URL. Then `apiService.get()` prepended `baseUrl` again, doubling it.

All other services (vehicles, jobs, etc.) use short **relative paths** like `AppConfig.vehiclesEndpoint = '/vehicles'`. `ApiService.get()` prepends `baseUrl` to those, making the full URL correctly.

### Fix — `lib/config/app_config.dart`
Added a proper relative-path endpoint constant:
```dart
static const String usersEndpoint = '/users'; // ← added, matches pattern of all others
```

### Fix — `lib/services/user_service.dart`
```dart
// BEFORE — wrong
String get _endpoint => '${AppConfig.baseUrl}/users'; // full URL → doubles up

// AFTER — correct
String get _endpoint => AppConfig.usersEndpoint; // '/users' → ApiService prepends baseUrl
```

---

## 5. DB Role Enum Mismatch — scheduler/technician not found in queries

### Symptom
`GET /api/users?role=technician` returned empty results. `GET /api/users?role=scheduler` returned empty results.

### Root Cause
The database `users.role` enum is `('admin', 'dispatcher', 'driver')` — legacy values. The app and JWT use the normalised names `'scheduler'` and `'technician'`. Queries were hitting the DB with the wrong values.

### Fix — `src/routes/users.js`
Added bidirectional role mapping:

```js
// App/JWT value  →  DB enum value (for WHERE clauses)
const TO_DB_ROLE = { scheduler: 'dispatcher', technician: 'driver' };

// DB enum value  →  App/JWT value (for API responses)
const FROM_DB_ROLE = { dispatcher: 'scheduler', driver: 'technician' };

const toDbRole      = r => TO_DB_ROLE[r]   ?? r;
const fromDbRole    = r => FROM_DB_ROLE[r] ?? r;
const normaliseUser = u => ({ ...u, role: fromDbRole(u.role) });
```

All rows returned from the DB are passed through `normaliseUser()` so every API response uses `scheduler`/`technician` — consistent with the JWT and Flutter `User` model.

---

## 6. FilterChip Border Error — "A Border can only be drawn as a circle on borders with uniform colors"

### Symptom
```
Another exception was thrown: A Border can only be drawn as a circle on
borders with uniform colors.
```
Appeared multiple times when the Users screen loaded.

### Root Cause
`FilterChip`'s `side` property was set to a `BorderSide` whose color changed based on `selected` state. Flutter renders chips with a circular shape internally, and when a `Border` with a dynamically-changing color is applied at the top level, it triggers this constraint error.

### Fix — `lib/screens/users/users_screen.dart`
Moved the `BorderSide` inside a `shape: RoundedRectangleBorder(...)` instead:

```dart
// BEFORE — causes error
FilterChip(
  side: BorderSide(color: selected ? color : AppTheme.dividerColor),
  ...
)

// AFTER — correct
FilterChip(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
    side: BorderSide(color: selected ? color : AppTheme.dividerColor),
  ),
  ...
)
```

---

## 7. Duplicate Method Error — `_roleLabel` defined twice

### Symptom
Dart compile error on `users_screen.dart` pointing to `_roleLabel`.

### Root Cause
`_roleLabel` was defined twice in the file — once correctly inside `_UsersScreenState`, and once again just before the class closing `}`, which placed it outside the class as a stray top-level function.

### Fix
Removed the duplicate definition. The one at line 74 inside the class is the correct one.

---

## 8. User Model Missing `isActive` Field

### Symptom
`user.isActive` was not available on the `User` model, causing compile errors and wrong deactivation logic in the users screen.

### Root Cause
The original `user.dart` model only had `id`, `username`, `fullName`, `role`, `email`, and `permissions`. The `is_active` field exists in the DB and is returned by the API but was never parsed.

### Fix — `lib/models/user.dart`
```dart
class User {
  final bool isActive; // ← added

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      // ...
      isActive: json['is_active'] == 1 || json['is_active'] == true, // ← handles int and bool
    );
  }
}
```

---

## Architecture Summary

### Role mapping table

| Context | Admin | Scheduler | Technician |
|---------|-------|-----------|------------|
| DB enum | `admin` | `dispatcher` | `driver` |
| JWT / App | `admin` | `scheduler` | `technician` |
| `constants.js` `USER_ROLE` | `'admin'` | `'scheduler'` | `'technician'` |

The DB uses legacy names. `authController._normaliseRole()` converts DB → App at login time so the JWT always contains the modern names. `users.js` converts App → DB when querying and DB → App when responding.

### Token flow (after fixes)

```
Login / App Start
      ↓
AuthProvider sets _token
      ↓
ApiService().setAuthToken(_token)   ← singleton, one call sets for everyone
      ↓
UserService, VehicleService, JobService, etc.
all use ApiService() → same instance → same token
      ↓
Every HTTP request includes: Authorization: Bearer <token>
```

### Middleware chain for protected routes

```
Request → verifyToken → (populates req.user) → adminOnly/schedulerOrAbove → route handler
```

Both `verifyToken` and the role guard are bundled as an array on every route that needs them, making each route self-contained regardless of `server.js` global middleware configuration.

---

## Files Changed

| File | Change |
|------|--------|
| `src/routes/index.js` | Registered `/users` route |
| `src/routes/users.js` | Added `verifyToken` + role guards, role mapping, full CRUD |
| `src/routes/vehicles.js` | Added `verifyToken` + `adminOnly` to write routes |
| `lib/services/api_service.dart` | Made singleton |
| `lib/providers/auth_provider.dart` | Auto-injects token at login/startup/logout |
| `lib/services/user_service.dart` | Uses `AppConfig.usersEndpoint` (relative path) |
| `lib/config/app_config.dart` | Added `usersEndpoint = '/users'` |
| `lib/models/user.dart` | Added `isActive` field |
| `lib/screens/users/users_screen.dart` | Fixed FilterChip border, removed manual token injection, fixed duplicate `_roleLabel` |
| `lib/main.dart` | Added Users tab for admin role |
| `lib/screens/dashboard/dashboard_screen.dart` | Added Users AppBar button + quick-access card for admin |
