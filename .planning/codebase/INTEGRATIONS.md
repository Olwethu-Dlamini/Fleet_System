# External Integrations

**Analysis Date:** 2026-03-21

## APIs & External Services

**Google Maps:**
- Google Maps API - Interactive map for job location selection and display
  - SDK/Client: `google_maps_flutter` 2.10.0
  - Usage: `vehicle_scheduling_app/lib/widgets/common/location_picker_popup.dart`
  - Features: Map widget, tap-to-select location, latitude/longitude capture
  - Configuration: API key in `android/app/src/main/AndroidManifest.xml` (line 14-15)
    - Key: AIzaSyAzF9BaCiVjkSZytnLS_85WDkxebS3MZhE
  - iOS: Requires key in `ios/Runner/Info.plist` (currently not configured)

**Device Geolocation:**
- Geolocator - Device GPS and location permission handling
  - SDK/Client: `geolocator` 13.0.2
  - Usage: `vehicle_scheduling_app/lib/widgets/common/location_picker_popup.dart`
  - Features: Request location permissions, get device position, check location service status
  - Permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` (declared in `AndroidManifest.xml`)
  - iOS permissions: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysUsageDescription` (in `Info.plist`)

**URL Handling:**
- url_launcher 6.3.1 - Opens external URLs and apps
  - Usage: Launch Google Maps navigation, open browser links
  - Features: URL scheme support (https://, geo://, tel://)

## Data Storage

**Primary Database:**
- MySQL 5.6+ / MariaDB 10.4.32+
  - Host: localhost (dev), EC2 instance (production)
  - Client: `mysql2/promise` 3.16.3 (Node.js driver)
  - Connection Pool: `src/config/database.js`
    - Max connections: 10
    - Wait for available connections: enabled
    - Connection timeout and keep-alive: enabled
  - Database name: `vehicle_scheduling` (default)
  - Connection credentials via env vars:
    - `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_PORT`, `DB_NAME`

**Database Schema Tables:**
- `jobs` - Work orders with customer info, scheduling, status
  - Fields: job_number, job_type (installation/delivery/miscellaneous), customer_name, customer_phone, customer_address, destination_lat, destination_lng, scheduled_date, scheduled_time_start, scheduled_time_end, estimated_duration_minutes, current_status (pending/assigned/in_progress/completed/cancelled), priority, created_by, created_at, updated_at
- `job_assignments` - Job-to-vehicle-to-driver mapping
  - Fields: job_id, vehicle_id, driver_id, assigned_at, assigned_by, notes
- `job_technicians` - Many-to-many: jobs to multiple technicians/drivers
  - Fields: job_id, user_id (technician), assigned_at, assigned_by
- `job_status_changes` - Audit trail of job status transitions
  - Fields: job_id, old_status, new_status, reason, changed_by, changed_at, notes
- `vehicles` - Fleet vehicle inventory
  - Fields: vehicle_name, license_plate, vehicle_type (car/van/truck), capacity_kg, is_active, last_maintenance_date, notes
- `users` - System users with roles
  - Fields: username, password_hash, full_name, email, role (admin/scheduler/technician), is_active, created_at, updated_at
- `driver_availability` - Driver shift schedules and availability windows

**Initialization Scripts:**
- `vehicle_scheduling.sql` - Current schema with test data
- `vehicle_scheduling2.sql` - Alternate/backup schema version

**Device Local Storage (Flutter):**
- SharedPreferences - Persistent key-value storage
  - Package: `shared_preferences` 2.5.4
  - Storage location: Device platform-specific (SQLite on Android, NSUserDefaults on iOS)
  - Keys stored (from `auth_service.dart`):
    - `auth_token` - JWT token for authenticated requests
    - `user_id` - Current user ID (integer)
    - `username` - Login username
    - `full_name` - User display name
    - `user_role` - Role: admin, scheduler, or technician
    - `user_email` - User email address
    - `user_permissions` - Array of permission strings (e.g., "jobs:read", "jobs:create")
  - Persistence: Survives app restart, cleared only on logout or manual cache clear

**File Storage:**
- Local filesystem only
  - App icons: `vehicle_scheduling_app/assets/icon/app_icon.png`
  - Images: `vehicle_scheduling_app/assets/images/` directory
- No cloud storage (S3, Firebase, etc.) integrated

**Caching:**
- None explicitly configured
- In-memory Provider state holds current user, jobs, vehicles during session
- No HTTP caching headers implemented

## Authentication & Identity

**Auth Provider:**
- Custom JWT-based system (no third-party auth)
  - Endpoint: `POST /api/auth/login`
  - Token generation: `jsonwebtoken` 9.0.3
  - Token storage: JWT_SECRET env var
  - Duration: 8 hours (JWT_EXPIRES env var)
  - Bearer token sent in: `Authorization: Bearer {token}` header

**Implementation Files:**
- Backend: `src/server.js` lines 78-162 (login, logout, me endpoints)
- Frontend: `lib/services/auth_service.dart` (login/logout, token management)
- API Service: `lib/services/api_service.dart` (includes Authorization header)

**Password Security:**
- Hash algorithm: bcryptjs 3.0.3 or bcrypt 6.0.0
- Verification: `bcrypt.compare(password, user.password_hash)`
- Database column: `password_hash` in `users` table
- Never transmit or store plaintext passwords

**User Roles & Permissions:**
- Roles: admin, scheduler (formerly dispatcher), technician (formerly driver)
- Role normalization: `src/server.js` normaliseRole() function handles legacy DB values
- Permissions: Defined in `src/config/constants.js`
  - Returned on login and stored locally as `user_permissions` array
  - Examples: `jobs:read`, `jobs:create`, `jobs:delete`, `vehicles:read`, etc.
  - Currently permissions inform frontend UI (not enforced server-side validation)

**Session Management:**
- Stateless JWT - no backend session storage
- Token persistence: SharedPreferences on device
- Token validation: Sent in every request header
- Logout endpoint: `POST /api/auth/logout` (optional - JWT is self-validating)
- No session timeout enforcement (handled by JWT expiry)

## Monitoring & Observability

**Error Tracking:**
- Not configured - no external error tracking service
- Console logging only (backend stdout, Flutter print statements)

**Logging:**
- Backend: `console.error()`, `console.log()` statements
  - Startup: Database connection status, server listening
  - Routes: HTTP method and path logged
  - Errors: `Global error handler` middleware logs all exceptions
  - Output: Docker container stdout (accessible via `docker logs`)
- Flutter: `print()` statements in service classes
  - API requests logged: `GET $baseUrl$endpoint`, response status
  - Errors printed with `print('ServiceName.methodName error: $e')`
  - Output: Accessible via `flutter logs` command or device Logcat

**Health Checks:**
- Backend endpoint: `GET /health`
  - Returns: `{ status: 'healthy', uptime: <seconds>, timestamp: <ISO8601> }`
  - Response time: Indicates server responsiveness
- Database connectivity test on startup: `SELECT 1 as test` query
  - Validates MySQL connection before server starts
  - Failure prevents server startup (exit code 1)

**Metrics:**
- Not configured - no performance metrics collected
- Future consideration: Response time tracking, request/error rates

## CI/CD & Deployment

**Hosting:**
- Backend: AWS EC2 instance
  - Public IP: 3.231.191.15
  - Docker: node:20-alpine image
  - Port mapping: 8080 (public) → 3000 (container)
  - Documented in: `fleet_backend_docker_guide.md`
- Database: MySQL/MariaDB on EC2 host
  - Bound to 0.0.0.0 (accessible from containers and external)
- Mobile Apps: Distributed as APK/IPA to phones (not via app store)

**CI Pipeline:**
- Not configured - manual deployment only
- No automated tests, builds, or deployments

**Deployment Process (Manual):**
1. Build Docker image: `docker build -t vehicle-backend .`
2. Push image (optional): Docker registry (not configured)
3. Run container: `docker run -d -p 8080:3000 --name vehicle_backend_dev --env-file .env vehicle-backend`
4. Validate: `docker logs vehicle_backend_dev`
5. Database: Ensure MySQL running and schema initialized

**Docker Setup:**
- Base image: `node:20-alpine`
- Dockerfile: `vehicle-scheduling-backend/Dockerfile`
- Entrypoint: `npm run dev` (nodemon for auto-reload)
- Port exposed: 3000 (internal container port)
- Environment: `.env` file mounted at runtime

**Environment Configuration (EC2 Deployment):**
- `.env` file contents (sample):
  ```
  DB_HOST=localhost                          # or host.docker.internal for container
  DB_USER=fleet_user                         # Limited permission user
  DB_PASSWORD=<secure_password>              # Production password
  DB_NAME=vehicle_scheduling
  DB_PORT=3306
  PORT=3000
  NODE_ENV=production
  JWT_SECRET=<long_random_string>            # Rotate periodically
  JWT_EXPIRES=8h
  ```
- Database user `fleet_user` has limited permissions (not root)

## Webhooks & Callbacks

**Incoming Webhooks:**
- None implemented
- No external systems can push events to this API

**Outgoing Webhooks:**
- None implemented
- No notifications sent to external systems
- Future consideration: Job status updates to TMS, driver notifications, customer SMS/email

## Environment Configuration

**Backend Environment Variables:**

Required for development and production:
```bash
# Database
DB_HOST=localhost                    # MySQL server address
DB_USER=root                         # MySQL username
DB_PASSWORD=your_password            # MySQL password
DB_NAME=vehicle_scheduling           # Database name
DB_PORT=3306                         # MySQL port

# Server
PORT=3000                            # Node.js listening port
NODE_ENV=development                 # development or production

# Authentication
JWT_SECRET=vehicle_scheduling_secret_2024  # Token signing secret (change in prod)
JWT_EXPIRES=8h                       # Token expiration duration

# Optional
APP_NAME=Vehicle Scheduling API      # Used in responses
```

**Flutter Environment Configuration:**
- All configured in code at `lib/config/app_config.dart`
- No external env file used
- Switching environments: Change `useLocal = true/false` boolean
- Base URLs:
  - Web local: `http://localhost:3000/api`
  - Android emulator: `http://10.0.2.2:3000/api`
  - AWS production: `http://3.231.191.15:8080/api`
- Network timeouts: 30 seconds (connection and receive)

**Google Maps API Key Configuration:**
- Android: `android/app/src/main/AndroidManifest.xml` line 14-15
  - Key: AIzaSyAzF9BaCiVjkSZytnLS_85WDkxebS3MZhE
  - Meta-data tag: `com.google.android.geo.API_KEY`
- iOS: Not configured in Info.plist (needs to be added)
  - Key should be added to `ios/Runner/Info.plist`
  - Location: Typically in Info.plist as GoogleMapsAPIKey

**Secrets Management:**
- Backend `.env`: Not committed (`.gitignore` includes `.env`)
- Template provided: `.env.example` at project root
- Flutter config: Hardcoded in `app_config.dart` (safe - local IPs and non-sensitive)
- Maps API key: Hardcoded in native manifests (acceptable - Google restricts by package name)

---

*Integration audit: 2026-03-21*
