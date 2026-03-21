# External Integrations

**Analysis Date:** 2026-03-21

## APIs & External Services

**Location Services:**
- **Google Maps API** - Interactive map for job location selection
  - SDK/Client: `google_maps_flutter` 2.10.0
  - Usage: `vehicle_scheduling_app/lib/widgets/common/location_picker_popup.dart`
  - Configuration: API key required in Android/iOS native manifests
  - Features: Map display, tap-to-select location, camera animation

**Device Location:**
- **Geolocator** - Device GPS and location permission handling
  - SDK/Client: `geolocator` 13.0.2
  - Usage: `vehicle_scheduling_app/lib/widgets/common/location_picker_popup.dart`
  - Features: Permission requests, device position retrieval, location service detection

**URL Handling:**
- **url_launcher** - Opens external URLs (maps, browsers)
  - SDK/Client: `url_launcher` 6.3.1
  - Usage: Launching Google Maps navigation, web links from app

## Data Storage

**Databases:**
- **MySQL/MariaDB** 10.4.32+
  - Connection: `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT` (env vars)
  - Client: `mysql2/promise` 3.16.3 (Node.js driver)
  - Pool Config: `vehicle-scheduling-backend/src/config/database.js`
    - Max connections: 10
    - Keep-alive enabled
    - Auto-reconnect on drop
  - Database: `vehicle_scheduling` (default name)
  - Schema: `vehicle_scheduling.sql`, `vehicle_scheduling2.sql`
  - Tables:
    - `jobs` - Work orders (installation, delivery, misc)
    - `job_assignments` - Job-to-vehicle/driver mapping
    - `job_technicians` - Many-to-many: jobs to technicians/drivers
    - `job_status_changes` - Job status audit trail
    - `vehicles` - Fleet vehicles
    - `users` - Admin, scheduler, technician roles
    - `driver_availability` - Driver shift/availability calendar

**Local Device Storage:**
- **SharedPreferences** (Flutter)
  - Package: `shared_preferences` 2.5.4
  - Purpose: Persist JWT token, user profile, app preferences
  - Keys: `auth_token`, `user_id`, `username`, `full_name`, `user_role`, `user_email`, `user_permissions`
  - Location: `vehicle_scheduling_app/lib/services/auth_service.dart`
  - Persistence: Survives app restart, survives uninstall (platform-dependent)

**File Storage:**
- Local filesystem only - no cloud storage integrated
- App icons stored: `vehicle_scheduling_app/assets/icon/app_icon.png`
- Images stored: `vehicle_scheduling_app/assets/images/`

**Caching:**
- None configured - HTTP client uses default behavior
- In-memory Provider state stores current user, jobs, vehicles during session

## Authentication & Identity

**Auth Provider:**
- Custom JWT implementation
  - Implementation: `vehicle-scheduling-backend/src/server.js` (lines 78-162)
  - Flutter client: `vehicle_scheduling_app/lib/services/auth_service.dart`
  - Token Signing: `jsonwebtoken` 9.0.3 with `JWT_SECRET` env var
  - Token Duration: 8 hours (`JWT_EXPIRES` env var)
  - Bearer Token: Sent in `Authorization: Bearer {token}` header

**Password Security:**
- Hash Algorithm: bcryptjs 3.0.3 (or bcrypt 6.0.0 recommended)
- Verification: `bcrypt.compare()` in login route
- Database: Passwords stored as `password_hash` in `users` table

**User Roles:**
- **admin** - Full system access, can override scheduling conflicts
- **scheduler** (formerly dispatcher) - Schedule jobs, assign vehicles
- **technician** (formerly driver) - View assigned jobs, update status
- Role mapping: `vehicle-scheduling-backend/src/server.js` (lines 27-42)

**Authorization:**
- Permission system: `PERMISSIONS` constant in `vehicle-scheduling-backend/src/config/constants.js`
- Permissions returned on login and stored locally: `user_permissions` array
- Examples: `jobs:read`, `jobs:create`, `jobs:delete`, etc.
- Enforced via middleware (if implemented) or frontend UI hiding

**Session Management:**
- Stateless JWT (no backend session storage required)
- Token stored on device: `SharedPreferences` in Flutter
- Token cleared on logout
- Logout endpoint: `POST /api/auth/logout` (optional - JWT is stateless)

## Monitoring & Observability

**Error Tracking:**
- Not configured - errors logged to console/stdout only
- Backend: `console.error()` in `src/server.js`
- Flutter: `print()` statements in service classes (e.g., `job_service.dart`)

**Logs:**
- **Backend:** stdout/stderr to Docker container logs
  - Accessed via: `docker logs -f vehicle_backend_dev` or `docker logs vehicle_backend_dev`
  - Entry point: `src/server.js` startup sequence
  - Sample output: `✅ Database connection successful`, `🚀 Vehicle Scheduling API`
- **Flutter:** Device log/Logcat (Android) or Console (iOS)
  - Access: `flutter logs` command
  - Prefix: `print()` calls in service classes

**Health Check:**
- **Backend:** `GET /health` endpoint in `src/server.js` (line 185)
  - Returns: `{ status: 'healthy', uptime: ..., timestamp: ... }`
  - Used by: Docker health checks (optional), load balancers
- **Database:** Test query on startup in `src/server.js` (line 208)
  - `SELECT 1 as test` validates connectivity

## CI/CD & Deployment

**Hosting:**
- **Backend:** AWS EC2 instance
  - Public IP: 3.231.191.15 (documented in `app_config.dart`)
  - Docker port mapping: 8080:3000 (EC2 port 8080 → container port 3000)
  - Deployment guide: `fleet_backend_docker_guide.md`
- **Database:** MySQL/MariaDB on same EC2 host (bound to 0.0.0.0)
- **Mobile:** APK distributed to phones (not via app store)

**CI Pipeline:**
- Not configured - manual deployment
- Deployment process:
  1. Build Docker image: `docker build -t vehicle-backend .`
  2. Run container: `docker run -d -p 8080:3000 --name vehicle_backend_dev --env-file .env vehicle-backend`
  3. Validate: `docker logs vehicle_backend_dev`

**Docker Setup:**
- **Image:** `node:20-alpine`
- **Dockerfile location:** `vehicle-scheduling-backend/Dockerfile` (documented)
- **Build context:** `vehicle-scheduling-backend/` directory
- **Entrypoint:** `npm run dev` (nodemon for development)
- **Port exposed:** 3000 (internal), mapped to 8080 on host

**Environment Configuration on EC2:**
- `.env` file in backend root with:
  - `DB_HOST=host.docker.internal` (for local MySQL access from container)
  - Database credentials for `fleet_user` (limited permissions user)
  - `JWT_SECRET` and `JWT_EXPIRES`

## Webhooks & Callbacks

**Incoming:**
- None implemented - no external systems pushing events to this API

**Outgoing:**
- None implemented - no external services receive notifications from this system
- Future consideration: Job status updates to external TMS, driver notifications, customer SMS

## Environment Configuration

**Required env vars (Backend):**
```
DB_HOST=localhost              # MySQL server
DB_USER=root                   # MySQL user
DB_PASSWORD=your_password      # MySQL password
DB_NAME=vehicle_scheduling     # Database name
DB_PORT=3306                   # MySQL port
PORT=3000                      # Node.js port
NODE_ENV=development           # development|production
JWT_SECRET=<secure_key>        # Token signing secret
JWT_EXPIRES=8h                 # Token expiration duration
```

**Required env vars (Flutter App):**
- All configured in `vehicle_scheduling_app/lib/config/app_config.dart`:
  - `useLocal` boolean - toggles between localhost and AWS
  - Base URLs for web, Android emulator, AWS EC2
  - Timeout durations (30 sec default)

**Secrets location:**
- Backend: `.env` file (not committed - `.env` in `.gitignore`)
- Example template: `.env.example` at project root
- Flutter: Hardcoded in `app_config.dart` (local IPs), safe for open source
- Google Maps API keys: Native manifest files (Android, iOS)

**Notes on Production Secrets:**
- No `.env` checked into git
- EC2 deployment uses separate `.env` with production credentials
- Database user `fleet_user` has limited permissions (not root)
- JWT_SECRET should be rotated periodically

---

*Integration audit: 2026-03-21*
