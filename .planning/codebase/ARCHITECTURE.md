# Architecture

**Analysis Date:** 2026-03-21

## Pattern Overview

**Overall:** Three-tier client-server architecture with role-based access control (RBAC)

**Key Characteristics:**
- Separation of concerns: Controllers → Services → Models (backend)
- Provider-based state management (frontend)
- JWT-based authentication with role/permission matrix
- MySQL database with connection pooling
- REST API with granular permission guards
- Role scoping built into data queries (technicians see only assigned jobs)

## Layers

**Presentation Layer (Flutter):**
- Purpose: User interface and role-specific navigation
- Location: `vehicle_scheduling_app/lib/screens/`
- Contains: Screen widgets (login, dashboard, jobs, vehicles, users, reports)
- Depends on: Providers, Services, Models
- Used by: Users (admin/scheduler/technician)
- Pattern: Bottom-tab navigation with role-specific tab visibility

**State Management Layer (Flutter Provider):**
- Purpose: Manage application state, API communication orchestration
- Location: `vehicle_scheduling_app/lib/providers/`
- Contains: `AuthProvider`, `JobProvider`, `VehicleProvider` (ChangeNotifiers)
- Depends on: Services, Models
- Used by: Screen widgets for reactive UI updates
- Pattern: ChangeNotifier with notifyListeners() for UI rebuild triggers

**Service Layer (Flutter & Backend):**

*Flutter:*
- Location: `vehicle_scheduling_app/lib/services/`
- Files: `api_service.dart`, `auth_service.dart`, `job_service.dart`, `vehicle_service.dart`, `user_service.dart`, `report_service.dart`
- Purpose: API client implementations, request/response handling
- Pattern: Singleton ApiService with Bearer token auth; specific services wrap endpoints
- Error handling: Resilient JSON parsing, graceful fallbacks for non-Map responses

*Backend:*
- Location: `vehicle-scheduling-backend/src/services/`
- Files: `jobAssignmentService.js`, `jobStatusService.js`, `vehicleAvailabilityService.js`, `dashboardService.js`, `reportsService.js`
- Purpose: Business logic, validation, transaction management, role-aware data operations
- Depends on: Models, Database
- Used by: Controllers
- Pattern: Static methods, database queries separated from request handling

**Controller Layer (Backend):**
- Location: `vehicle-scheduling-backend/src/controllers/`
- Files: `authController.js`, `jobAssignmentController.js`, `jobStatusController.js`, `dashboardController.js`, `reportsController.js`
- Purpose: HTTP request validation, response formatting, route handler orchestration
- Depends on: Services
- Used by: Routes
- Pattern: Static methods, delegates to service layer

**Route Layer (Backend):**
- Location: `vehicle-scheduling-backend/src/routes/`
- Files: `index.js`, `authRoutes.js`, `jobs.js`, `vehicles.js`, `jobAssignmentRoutes.js`, `jobStatusRoutes.js`, `dashboard.js`, `reports.js`, `users.js`, `availabilityRoutes.js`
- Purpose: HTTP route definition, middleware application, request dispatch
- Depends on: Controllers, Middleware
- Used by: Express app
- Pattern: Router modules, guard middleware applied per-endpoint

**Middleware Layer (Backend):**
- Location: `vehicle-scheduling-backend/src/middleware/`
- File: `authMiddleware.js`
- Contains: `verifyToken`, `requireRole`, `requirePermission`
- Purpose: Authentication verification, role/permission enforcement
- Pattern: Chain-of-responsibility for auth guards

**Model Layer (Backend):**
- Location: `vehicle-scheduling-backend/src/models/`
- Files: `Job.js`, `Vehicle.js`
- Purpose: Database schema abstraction, query builders, data formatting
- Depends on: Database
- Used by: Services
- Pattern: Static methods for CRUD and complex queries
- Special: Includes date/timezone handling and MySQL 5.6 compatibility (GROUP_CONCAT for JSON aggregation)

**Data Layer (Backend):**
- Location: `vehicle-scheduling-backend/src/config/`
- File: `database.js`
- Purpose: MySQL connection pool management
- Pattern: mysql2/promise with 10-connection pool, keep-alive enabled

**Configuration Layer:**
- Location: `vehicle-scheduling-backend/src/config/` and `vehicle_scheduling_app/lib/config/`
- Backend files: `constants.js`, `swagger.js`
- Frontend files: `app_config.dart`, `theme.dart`
- Purpose: Centralized constants, API base URLs, validation rules, permission matrix
- Contains: Job statuses, roles, permissions, error messages, UI theme

## Data Flow

**Login Flow:**

1. User enters credentials on `LoginScreen` (`vehicle_scheduling_app/lib/screens/login_screen.dart`)
2. `AuthProvider.login()` calls `AuthService.login()` with credentials
3. `AuthService` calls `ApiService.post('/auth/login')` → Backend `POST /api/auth/login`
4. Backend `server.js` inline route verifies password hash, generates JWT with role/permissions
5. Response includes token + user object with normalized role + permissions array
6. `AuthProvider` stores token in `SharedPreferences`, sets `ApiService._authToken`, marks `status = authenticated`
7. `AuthGate` widget navigates to `MainApp` based on `auth.status`

**Job Fetch Flow (Role-Scoped):**

1. `JobProvider.loadJobs()` called on app startup
2. Checks `AuthProvider.isTechnician` to determine endpoint
3. Calls `JobService.getJobs()` or `JobService.getMyJobs()`
4. `JobService` calls `ApiService.get('/jobs')` or `ApiService.get('/jobs/my-jobs')`
5. Backend route handler in `src/routes/jobs.js`:
   - `verifyToken` middleware extracts user from JWT
   - Routes check `req.user.role === 'technician'` → calls `Job.getJobsByTechnician(userId)`
   - Other roles → `Job.getAllJobs()`
   - Both use Role-Aware SQL (job_technicians table filters results)
6. Response includes only jobs matching user's role scope
7. `JobProvider` parses response, updates `_jobs` list, calls `notifyListeners()`
8. `JobsListScreen` rebuilds with filtered/scoped jobs

**Job Assignment Flow (Multi-Technician):**

1. Admin/Scheduler on `SchedulerScreen` selects job + vehicle + technicians
2. Calls `JobProvider.assignJob()` or `JobProvider.assignTechnicians()`
3. Calls `JobService.assignJobToVehicle()` → `ApiService.put('/job-assignments/assign')`
4. Backend `jobAssignmentController.assignJob()`:
   - Validates job/vehicle existence (read-only, outside transaction)
   - Checks vehicle availability
   - Checks for driver conflicts (other jobs with same technician in time slot)
5. Minimal write transaction:
   - Updates `jobs.assigned_vehicle_id`
   - Updates `jobs.current_status = 'assigned'`
   - Writes each technician to `job_technicians(job_id, user_id)`
   - Single transaction < 50ms lock time
6. Response returns updated job object
7. `JobProvider._reloadSingleJob()` updates the job in state
8. UI refreshes to show assignment

**Status Update Flow:**

1. Technician on `JobDetailScreen` changes status (pending → in_progress → completed)
2. Calls `JobProvider.updateJobStatus(jobId, newStatus)`
3. Calls `JobService.updateJobStatus()` → `ApiService.put('/job-status/:id')`
4. Backend `jobStatusController.updateStatus()`:
   - Verifies user has `jobs:updateStatus` permission
   - Updates `jobs.current_status` and `jobs.updated_at`
   - Logs status change
5. Response includes updated job
6. `JobProvider` updates local state
7. UI reflects new status with color coding

**State Management:**

Backend State:
- Persistent: MySQL database (jobs, vehicles, users, assignments)
- Session: JWT token in Authorization header (stateless)
- Request: `req.user` object decoded from JWT by `verifyToken`

Frontend State:
- Persistent: Token stored in `SharedPreferences` (auto-restored at app launch)
- In-Memory: Providers hold `_jobs`, `_vehicles`, `_user`, filtered based on role
- Transient: Loading/error states for UI feedback

## Key Abstractions

**Job Assignment:**
- Purpose: Represents mapping of vehicle + technicians → job
- Implementation: Database tables `jobs` (vehicle_id), `job_technicians` (user_id array)
- Pattern: Multi-technician support with backwards-compat for legacy single driver_id
- Example paths: `vehicle-scheduling-backend/src/services/jobAssignmentService.js`, `vehicle-scheduling-backend/src/models/Job.js`

**User Role + Permissions:**
- Purpose: Granular access control beyond simple role names
- Example: Admin can delete jobs; scheduler can create but not delete
- Implementation: `PERMISSIONS` map in `vehicle-scheduling-backend/src/config/constants.js`
- Enforced by: `requirePermission(permissionKey)` middleware applied per-route
- Frontend: `AuthProvider.hasPermission(key)` checks if role has permission

**Vehicle Availability:**
- Purpose: Prevent double-booking and manage scheduling conflicts
- Implementation: `VehicleAvailabilityService.checkVehicleAvailability()` queries overlapping jobs
- Pattern: Checks time slot conflicts; supports driver reassignment with `forceOverride` flag
- File: `vehicle-scheduling-backend/src/services/vehicleAvailabilityService.js`

**Job Status Lifecycle:**
- Purpose: Track job progression from creation to completion
- States: pending → assigned → in_progress → completed / cancelled
- Implementation: `jobs.current_status` column updated by status service
- Example: `vehicle-scheduling-backend/src/services/jobStatusService.js`

**Role-Aware Queries:**
- Purpose: Prevent technicians from querying jobs assigned to other technicians
- Pattern: Joins `jobs` with `job_technicians` table filtered by `job_technicians.user_id = ?`
- Example: `Job.getJobsByTechnician()` in `vehicle-scheduling-backend/src/models/Job.js`

## Entry Points

**Backend:**
- Location: `vehicle-scheduling-backend/src/server.js`
- Triggers: Node.js process start (`npm start` or `npm run dev`)
- Responsibilities:
  - Load environment variables
  - Initialize Express app with CORS, JSON body parsing
  - Set up Swagger UI at `/swagger`
  - Inline auth routes (login, logout, /me)
  - Register all API routes from `src/routes/index.js`
  - Health check and 404 handlers
  - Global error handler
  - Database connection verification before listening on port

**Frontend:**
- Location: `vehicle_scheduling_app/lib/main.dart`
- Triggers: App launch via Flutter/Dart VM
- Responsibilities:
  - Creates MultiProvider wrapper with `AuthProvider`, `JobProvider`, `VehicleProvider`
  - Returns `VehicleSchedulingApp` (MaterialApp root)
  - Home: `AuthGate` (checks auth status, routes to login or MainApp)
  - Theme: `AppTheme.lightTheme` from `config/theme.dart`
  - Post-auth: `MainApp` (stateful bottom-tab navigation, role-specific tabs)

**API Root:**
- `GET /` → Returns API metadata (version, status, timestamp)
- `GET /health` → Server health check, uptime
- `POST /api/auth/login` → Public endpoint, no auth required
- `/swagger` → OpenAPI documentation

## Error Handling

**Strategy:** Layered error handling with graceful degradation

**Patterns:**

Backend:
- Database errors: Caught in service layer, wrapped in try-catch, logged to console, returned as JSON error response with 5xx status
- Validation errors: Checked in controller, returned as 400 Bad Request with error message
- Auth errors: Caught in `verifyToken`, returned as 401 Unauthorized
- Permission errors: Caught in `requirePermission`, returned as 403 Forbidden with required role list
- Global handler: Express error middleware catches uncaught exceptions, returns 500 with generic/detailed message based on NODE_ENV

Frontend:
- Network errors: `ApiService._handleResponse()` catches exceptions, wrapped in try-catch per service method
- Auth token errors: `verifyToken` on 401 response triggers logout + navigate to LoginScreen
- API response parsing: Resilient JSON parsing (handles non-Map responses, wraps in success envelope)
- UI feedback: Snackbars for errors, toast notifications for success
- Loading states: `JobStatus` enum (idle, loading, success, error) controls UI spinner visibility

## Cross-Cutting Concerns

**Logging:**
- Backend: `console.log/error` in key functions (login, assignment, error paths)
- Pattern: Decorative console output with emojis for status (✅ success, ❌ failure, 🚀 process start)
- Frontend: Debug `print()` statements in services (API calls, provider methods) for local debugging

**Validation:**
- Backend: Input validation in controller layer before calling service
  - Required fields checked
  - Type/format validation (e.g., phone regex in constants)
  - Custom business logic validation (job exists, vehicle available, time range valid)
- Frontend: Form validation in screen widgets (TextForm fields with validators)
- Example: `VALIDATION_RULES` in `vehicle-scheduling-backend/src/config/constants.js`

**Authentication:**
- JWT-based, stateless
- Token issued at login with role + user metadata
- Verified on every protected route via `verifyToken` middleware
- Token stored client-side in `SharedPreferences`
- Auto-attached to all API requests via `Authorization: Bearer <token>` header
- Expiry: Default 8 hours (configurable via JWT_EXPIRES env var)

**Role-Based Access Control (RBAC):**
- Three backend roles: `admin`, `scheduler`/`dispatcher`, `technician`
- Role normalization at login to handle legacy "dispatcher" → "scheduler" aliases
- Permission matrix in `PERMISSIONS` object maps 20+ granular permissions (jobs:read, jobs:create, vehicles:delete, etc.) to role arrays
- Frontend checks role and permission via `AuthProvider.isTechnician`, `AuthProvider.isAdmin`, `AuthProvider.hasPermission(key)`
- UI elements conditionally rendered or hidden based on role (e.g., Users tab only for admin)
- API routes guarded by `requireRole` or `requirePermission` middleware

---

*Architecture analysis: 2026-03-21*
