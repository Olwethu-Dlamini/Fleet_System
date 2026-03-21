# Codebase Structure

**Analysis Date:** 2026-03-21

## Directory Layout

```
project-root/
├── vehicle-scheduling-backend/          # Express.js REST API server
│   ├── src/
│   │   ├── config/                      # Configuration & constants
│   │   ├── middleware/                  # Express middleware (auth guards)
│   │   ├── models/                      # Database models & query builders
│   │   ├── controllers/                 # HTTP request handlers
│   │   ├── services/                    # Business logic
│   │   ├── routes/                      # API route definitions
│   │   └── server.js                    # Express app entry point
│   ├── package.json                     # Node.js dependencies
│   └── node_modules/                    # Installed packages
│
├── vehicle_scheduling_app/              # Flutter mobile & web app
│   ├── lib/
│   │   ├── config/                      # App configuration & theme
│   │   ├── models/                      # Dart data models
│   │   ├── providers/                   # State management (ChangeNotifier)
│   │   ├── screens/                     # UI screens organized by feature
│   │   ├── services/                    # API clients & business logic
│   │   ├── utils/                       # Helper functions
│   │   ├── widgets/                     # Reusable UI components
│   │   └── main.dart                    # App entry point
│   ├── pubspec.yaml                     # Flutter dependencies
│   ├── android/                         # Android native code (auto-generated)
│   ├── ios/                             # iOS native code (auto-generated)
│   └── test/                            # Test files
│
├── .planning/
│   └── codebase/                        # Generated architecture docs
│
└── [Root SQL files]
    ├── vehicle_scheduling.sql           # Database schema & seed data
    └── vehicle_scheduling2.sql          # Alternative schema version
```

## Directory Purposes

**Backend:**

**`vehicle-scheduling-backend/src/config/`:**
- Purpose: Centralized configuration, constants, database setup
- Contains: Environment loading, database pool, constants for statuses/roles/permissions, Swagger spec
- Key files:
  - `database.js`: MySQL connection pool with 10 max connections
  - `constants.js`: JOB_STATUS, USER_ROLE, PERMISSIONS, validation rules, error messages
  - `swagger.js`: OpenAPI/Swagger definition for `/swagger` endpoint

**`vehicle-scheduling-backend/src/middleware/`:**
- Purpose: Express middleware for cross-cutting concerns
- Contains: Authentication and authorization guards
- Key files: `authMiddleware.js` with `verifyToken`, `requireRole`, `requirePermission` functions

**`vehicle-scheduling-backend/src/models/`:**
- Purpose: Database abstraction, query builders, data transformation
- Contains: Static methods for CRUD, complex queries, date/timezone handling
- Key files:
  - `Job.js`: Job CRUD, multi-technician queries, date formatting, MySQL 5.6 GROUP_CONCAT compatibility
  - `Vehicle.js`: Vehicle operations, availability checks

**`vehicle-scheduling-backend/src/controllers/`:**
- Purpose: HTTP request validation, response formatting, service orchestration
- Contains: One class per resource domain (auth, job assignments, job status, dashboard, reports)
- Key files:
  - `authController.js`: User authentication flows
  - `jobAssignmentController.js`: Vehicle-to-job assignment requests
  - `jobStatusController.js`: Status update requests
  - `dashboardController.js`: Dashboard metrics aggregation
  - `reportsController.js`: Report generation

**`vehicle-scheduling-backend/src/services/`:**
- Purpose: Business logic, validation, transaction management
- Contains: Service classes with static methods
- Key files:
  - `jobAssignmentService.js`: Assign vehicles to jobs, handle multi-technician, minimal transactions
  - `jobStatusService.js`: Update job status with audit logging
  - `vehicleAvailabilityService.js`: Check time slot conflicts, prevent double-booking
  - `dashboardService.js`: Aggregate job counts and metrics by status
  - `reportsService.js`: Generate reports on jobs, vehicles, technicians

**`vehicle-scheduling-backend/src/routes/`:**
- Purpose: HTTP route definitions, middleware application
- Contains: Express Router modules for each resource
- Key files:
  - `index.js`: Route aggregator, registers all sub-routes at `/api`
  - `jobs.js`: CRUD for jobs, role-scoped queries (technicians see only assigned)
  - `vehicles.js`: CRUD for vehicles (admin only)
  - `jobAssignmentRoutes.js`: POST /assign, PUT /hotswap, DELETE endpoints
  - `jobStatusRoutes.js`: PUT /:id endpoints for status transitions
  - `dashboard.js`: GET endpoints for dashboard metrics
  - `reports.js`: GET endpoints for report data
  - `users.js`: User management (admin only)
  - `availabilityRoutes.js`: Vehicle availability queries

**`vehicle-scheduling-backend/src/server.js`:**
- Purpose: Express app initialization, middleware setup, route mounting, error handling
- Entry point: `node src/server.js` or `nodemon src/server.js` (dev)
- Inline routes: `/api/auth/login`, `GET /api/auth/me`, `POST /api/auth/logout` (fast path, no caching issues)
- Swagger: `/swagger` serves UI, `/swagger.json` serves spec

**Frontend:**

**`vehicle_scheduling_app/lib/config/`:**
- Purpose: App-wide configuration and theming
- Key files:
  - `app_config.dart`: `baseUrl` for API endpoints (localhost:3000 for dev)
  - `theme.dart`: `AppTheme` with primaryColor, textStyles, lightTheme MaterialTheme

**`vehicle_scheduling_app/lib/models/`:**
- Purpose: Dart data classes for API responses
- Key files:
  - `job.dart`: `Job` class with fields (id, jobNumber, type, customer, status, technicians array), `JobTechnician` lightweight model, `fromJson` factory
  - `vehicle.dart`: `Vehicle` class with fields (id, name, license plate, type, status)
  - `user.dart`: `User` class with fields (id, username, role, email, full_name)

**`vehicle_scheduling_app/lib/providers/`:**
- Purpose: State management with ChangeNotifier pattern
- Contains: Application-level state holders, business logic coordination
- Key files:
  - `auth_provider.dart`: Login/logout, token management, role detection, permission checking
  - `job_provider.dart`: Job list management, filtering (status/type), CRUD operations, technician assignment
  - `vehicle_provider.dart`: Vehicle list management, availability queries

**`vehicle_scheduling_app/lib/screens/`:**
- Purpose: UI screens organized by feature domain
- Contains: Stateful/stateless widgets, form validation, navigation
- Directory structure by feature:
  - `dashboard/`: DashboardScreen (metrics, status overview)
  - `jobs/`: JobsListScreen, CreateJobScreen, EditJobScreen, JobDetailScreen, SchedulerScreen
  - `vehicles/`: VehiclesListScreen
  - `users/`: UsersScreen (admin only)
  - `reports/`: ReportsScreen (admin only)
  - `assignments/`: AssignmentScreens (driver assignment workflows)
  - `home/`: (if used)
  - Root level: `login_screen.dart`, `test_api_screen.dart`

**`vehicle_scheduling_app/lib/services/`:**
- Purpose: API client implementations and request handling
- Key files:
  - `api_service.dart`: Singleton HTTP client with Bearer token auth, error handling, response parsing resilience
  - `auth_service.dart`: Login/logout, token persistence to SharedPreferences
  - `job_service.dart`: Job CRUD, list endpoints, multi-technician assignment
  - `vehicle_service.dart`: Vehicle CRUD, availability checks
  - `user_service.dart`: User management operations
  - `report_service.dart`: Report fetching

**`vehicle_scheduling_app/lib/widgets/`:**
- Purpose: Reusable UI components
- Directory structure:
  - `common/`: Generic components (LocationPickerPopup, shared buttons/dialogs)
  - `job/`: Job-specific widgets (JobCard, StatusBadge)
  - `vehicle/`: Vehicle-specific widgets (VehicleCard)

**`vehicle_scheduling_app/lib/utils/`:**
- Purpose: Helper functions and utilities
- Contains: Date formatting, validation helpers, extensions

## Key File Locations

**Entry Points:**

Backend:
- `vehicle-scheduling-backend/src/server.js`: Node.js server initialization
  - Loads .env variables
  - Creates Express app with CORS, body parsers
  - Sets up Swagger at `/swagger`
  - Inline auth routes for login/logout/me
  - Mounts all API routes from `src/routes/index.js`
  - Starts listening on PORT (default 3000)

Frontend:
- `vehicle_scheduling_app/lib/main.dart`: Flutter app root
  - Creates MultiProvider with three ChangeNotifiers
  - Wraps app in MaterialApp with theme
  - Defines AuthGate (checks auth → routes to LoginScreen or MainApp)
  - MainApp handles bottom-tab navigation with role-specific tabs
- `vehicle_scheduling_app/android/app/src/main/AndroidManifest.xml`: Android app manifest
- `vehicle_scheduling_app/ios/Runner/AppDelegate.swift`: iOS app delegate

**Configuration:**

Backend:
- `vehicle-scheduling-backend/package.json`: npm dependencies (express, mysql2, jsonwebtoken, cors, bcrypt, swagger-ui-express)
- `vehicle-scheduling-backend/src/config/database.js`: MySQL pool setup
- `vehicle-scheduling-backend/src/config/constants.js`: All enums and permission matrices

Frontend:
- `vehicle_scheduling_app/pubspec.yaml`: Flutter dependencies (provider, http, google_maps_flutter, geolocator, shared_preferences)
- `vehicle_scheduling_app/lib/config/app_config.dart`: baseUrl constant
- `vehicle_scheduling_app/lib/config/theme.dart`: Material Design theme

**Core Logic:**

Backend:
- `vehicle-scheduling-backend/src/models/Job.js`: All job queries, multi-technician handling, date fixes
- `vehicle-scheduling-backend/src/services/jobAssignmentService.js`: Transaction-minimal job-to-vehicle assignments
- `vehicle-scheduling-backend/src/services/vehicleAvailabilityService.js`: Conflict detection for scheduling
- `vehicle-scheduling-backend/src/middleware/authMiddleware.js`: JWT verification and permission checks

Frontend:
- `vehicle_scheduling_app/lib/providers/job_provider.dart`: Job state, filtering, CRUD orchestration
- `vehicle_scheduling_app/lib/providers/auth_provider.dart`: Login state, role/permission checks
- `vehicle_scheduling_app/lib/services/api_service.dart`: HTTP client, token management, response resilience
- `vehicle_scheduling_app/lib/screens/login_screen.dart`: Authentication UI

**Testing:**

Backend:
- No automated test files; manual testing via Swagger UI or API tools
- Test script placeholder in `package.json`

Frontend:
- `vehicle_scheduling_app/test/`: Test directory (auto-generated, may contain widget tests)
- No configured test suite documented

**Database:**

- `vehicle_scheduling.sql`: Database schema with tables (users, jobs, vehicles, job_technicians, etc.) and seed data
- `vehicle_scheduling2.sql`: Alternative schema version (for backup or comparison)

## Naming Conventions

**Files:**

Backend:
- Controllers: PascalCase + `Controller` suffix (e.g., `authController.js`, `jobAssignmentController.js`)
- Services: PascalCase + `Service` suffix (e.g., `jobAssignmentService.js`)
- Models: PascalCase (e.g., `Job.js`, `Vehicle.js`)
- Routes: camelCase or plural descriptive (e.g., `jobs.js`, `vehicles.js`, `jobAssignmentRoutes.js`)
- Middleware: camelCase + `Middleware` suffix (e.g., `authMiddleware.js`)
- Config: camelCase (e.g., `database.js`, `constants.js`)

Frontend:
- Screens: PascalCase + `Screen` suffix (e.g., `LoginScreen`, `JobsListScreen`)
- Providers: PascalCase + `Provider` suffix (e.g., `AuthProvider`, `JobProvider`)
- Services: camelCase + `Service` suffix (e.g., `apiService.dart`, `jobService.dart`)
- Models: PascalCase (e.g., `Job`, `User`, `Vehicle`)
- Widgets: PascalCase (e.g., `LocationPickerPopup`, `JobCard`)
- Files: snake_case (e.g., `login_screen.dart`, `job_provider.dart`)

**Directories:**

Backend:
- Feature-based grouping: `config/`, `middleware/`, `models/`, `controllers/`, `services/`, `routes/`
- camelCase directory names

Frontend:
- Feature-based grouping: `config/`, `models/`, `providers/`, `screens/`, `services/`, `utils/`, `widgets/`
- snake_case directory names (Dart convention)
- Sub-feature grouping: `screens/jobs/`, `screens/vehicles/`, `screens/dashboard/`

## Where to Add New Code

**New Feature (e.g., "Task Management"):**

Backend:
1. Create `src/models/Task.js` with CRUD methods and query builders
2. Create `src/services/taskService.js` with business logic
3. Create `src/controllers/taskController.js` with HTTP handlers
4. Create `src/routes/taskRoutes.js` with route definitions
5. Import and mount routes in `src/routes/index.js` at `router.use('/tasks', taskRoutes);`
6. Add permission constants to `src/config/constants.js`
7. Add middleware guards to route definitions (e.g., `requirePermission('tasks:create')`)

Frontend:
1. Add `Task` and related models to `lib/models/` (e.g., `task.dart`)
2. Create `TaskService` in `lib/services/task_service.dart` wrapping API calls
3. Create `TaskProvider` in `lib/providers/task_provider.dart` for state management
4. Add `ChangeNotifierProvider(create: (_) => TaskProvider())` to providers list in `lib/main.dart`
5. Create feature directory `lib/screens/tasks/` with screen widgets
6. Add bottom navigation tab in `MainApp._buildTabsForRole()` and `_buildNavItemsForRole()`
7. Create `lib/widgets/task/` for task-specific components

**New Component/Module (e.g., "Driver Hotswap Modal"):**

Backend:
- If business logic: Add method to existing service (e.g., `jobAssignmentService.js`)
- If new endpoint: Create route handler in appropriate routes file (e.g., `jobAssignmentRoutes.js`)

Frontend:
- Create as widget in appropriate directory:
  - Standalone component: `lib/widgets/common/driver_hotswap_modal.dart`
  - Feature-specific: `lib/widgets/job/driver_hotswap_modal.dart`
- Export from `lib/widgets/` barrel file if needed
- Call via `showDialog()` or `Navigator.push()` from screen

**Utilities/Helpers:**

Backend:
- General helpers: Add to `src/services/` as utility functions or new utility module
- Validation logic: Centralize in `src/config/constants.js` (VALIDATION_RULES)
- Error messages: Add to `src/config/constants.js` (ERROR_MESSAGES)

Frontend:
- Dart extensions/helpers: Add to `lib/utils/` (e.g., `date_utils.dart`, `validators.dart`)
- Constants: Add to `lib/config/` or feature-level constants
- Reusable formatting: Add to `lib/services/` or utility classes

## Special Directories

**Backend:**

**`vehicle-scheduling-backend/scripts/`:**
- Purpose: Utility scripts
- Generated: Not currently used in active codebase
- Committed: Yes

**`vehicle-scheduling-backend/node_modules/`:**
- Purpose: npm-installed packages (Express, MySQL2, JWT, Swagger, etc.)
- Generated: Yes (via `npm install`)
- Committed: No (ignored by .gitignore)

Frontend:

**`vehicle_scheduling_app/assets/`:**
- Purpose: Static assets (images, icons)
- Structure: `assets/images/`, `assets/icon/` (app icon source)
- Generated: No
- Committed: Yes (image files)

**`vehicle_scheduling_app/build/`:**
- Purpose: Flutter build artifacts
- Generated: Yes (via `flutter build` commands)
- Committed: No (ignored by .gitignore)

**`vehicle_scheduling_app/.dart_tool/`:**
- Purpose: Dart analysis cache and build metadata
- Generated: Yes (via `flutter pub get`)
- Committed: No (ignored by .gitignore)

**`vehicle_scheduling_app/android/`, `ios/`, `windows/`, `macos/`, `linux/`, `web/`:**
- Purpose: Platform-specific native code and build configuration
- Generated: Partially (some files auto-generated by Flutter)
- Committed: Yes (source files), but generated plugin registrants may be regenerated
- Key files to preserve:
  - `android/app/src/main/AndroidManifest.xml`: Permissions, app name
  - `ios/Runner/Info.plist`: iOS configuration
  - Platform-specific gradle/podspec files

---

*Structure analysis: 2026-03-21*
