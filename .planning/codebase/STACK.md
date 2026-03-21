# Technology Stack

**Analysis Date:** 2026-03-21

## Languages

**Primary:**
- **JavaScript/Node.js** (v20 recommended) - Backend API (`vehicle-scheduling-backend/src/`)
- **Dart** (3.9.2+) - Flutter mobile app (`vehicle_scheduling_app/`)
- **SQL** - MySQL database schema (`vehicle_scheduling.sql`)

**Secondary:**
- **Kotlin** - Android native bindings (Flutter)
- **Swift** - iOS native bindings (Flutter)
- **Bash/Shell** - Deployment scripts

## Runtime

**Environment:**
- **Node.js** v20-alpine (Docker runtime)
- **Flutter SDK** 3.9.2+
- **MySQL/MariaDB** 10.4.32+
- **JVM** (for Android build tooling)
- **Xcode** (for iOS build tooling on macOS)

**Package Manager:**
- **npm** (Node.js packages)
  - Lockfile: Present (`package-lock.json`)
- **Dart pub** (Flutter packages)
  - Lockfile: Present (`pubspec.lock`)

## Frameworks

**Core:**
- **Express.js** 5.2.1 - REST API framework for Node.js backend
- **Flutter** 3.9.2+ - Cross-platform mobile framework (Android, iOS, Web)
- **Provider** 6.1.5+1 - State management for Flutter

**Testing:**
- **flutter_test** - Built-in Flutter testing framework
- No unit testing framework configured (placeholder in package.json)

**Build/Dev:**
- **nodemon** 3.1.11 - Auto-reload for Node.js during development
- **flutter_launcher_icons** 0.13.1 - Icon generation for Android builds
- **flutter_lints** 5.0.0 - Dart linting

**Documentation:**
- **Swagger/OpenAPI** - API documentation via `swagger-ui-express` 5.0.1 and `swagger-jsdoc` 6.2.8

## Key Dependencies

**Backend Critical:**
- **express** 5.2.1 - HTTP server framework
- **mysql2** 3.16.3 - MySQL client with promise support
- **jsonwebtoken** 9.0.3 - JWT token generation/verification
- **bcryptjs** 3.0.3 - Password hashing (deprecated duplicate)
- **bcrypt** 6.0.0 - Password hashing (recommended)
- **cors** 2.8.6 - Cross-origin request handling
- **dotenv** 17.2.4 - Environment variable loading

**Backend Documentation:**
- **swagger-ui-express** 5.0.1 - Swagger UI server
- **swagger-jsdoc** 6.2.8 - JSDoc to OpenAPI converter

**Flutter Critical:**
- **http** 1.1.0 - HTTP client for API calls
- **provider** 6.1.5+1 - Reactive state management
- **shared_preferences** 2.5.4 - Local device key-value storage
- **intl** 0.20.2 - Internationalization (date, currency formatting)
- **fluttertoast** 9.0.0 - Toast notifications

**Flutter Location/Maps:**
- **google_maps_flutter** 2.10.0 - Google Maps SDK for Flutter
- **geolocator** 13.0.2 - Device location services
- **url_launcher** 6.3.1 - Opens URLs in browser/maps app

**Flutter UI:**
- **cupertino_icons** 1.0.8 - iOS-style icons

## Configuration

**Environment:**
- **Backend `.env` variables required:**
  - `DB_HOST` - MySQL server address (default: localhost)
  - `DB_USER` - MySQL username (default: root)
  - `DB_PASSWORD` - MySQL password (default: empty)
  - `DB_NAME` - Database name (default: vehicle_scheduling)
  - `DB_PORT` - MySQL port (default: 3306)
  - `PORT` - Node.js server port (default: 3000)
  - `NODE_ENV` - Environment (development/production)
  - `JWT_SECRET` - Token signing secret (default: vehicle_scheduling_secret_2024)
  - `JWT_EXPIRES` - Token expiration (default: 8h)
- `.env.example` file present at project root for template

**Build:**
- **Backend:** No build config required (run-time Node.js)
- **Flutter:**
  - `pubspec.yaml` - Flutter package manifest
  - Android manifest: `android/app/src/main/AndroidManifest.xml`
  - iOS info: `ios/Runner/Info.plist`
  - `analysis_options.yaml` - Dart linting config

## Platform Requirements

**Development:**
- **Backend:** Node.js v20+, npm, MySQL 5.6+ (or MariaDB 10.4+)
- **Flutter:** Flutter SDK 3.9.2+, Android SDK (for Android), Xcode (for iOS)
- **Local Dev:** XAMPP or native MySQL installation, localhost setup

**Production:**
- **Deployment Target:** AWS EC2 instance (documented in `fleet_backend_docker_guide.md`)
- **Container Runtime:** Docker (Node.js backend only currently)
- **Database Host:** EC2-hosted MySQL/MariaDB
- **Mobile Deployment:** Android APK build, iOS TestFlight/App Store
- **API Access:** EC2 public IP with port 3000 (or 8080 if reverse proxied)

## Notable Stack Decisions

**Why mysql2 with promises:**
- `mysql2/promise` chosen over callback-based `mysql` for async/await syntax
- Connection pooling configured (10 max connections) for concurrent request handling

**Why JWT:**
- Stateless authentication, no server-side session storage required
- 8-hour expiration balances security with user experience

**Why Provider for Flutter:**
- Lightweight, performant state management without boilerplate
- `SharedPreferences` for persisting user session between app restarts

**Google Maps + Geolocator:**
- Maps: Embedded job location selection by users
- Geolocator: Real-time device location for driver tracking capability (initialized but usage in progress)

**Swagger Documentation:**
- API self-documents at `/swagger` endpoint for frontend developers
- JSDoc comments in routes converted to OpenAPI spec

---

*Stack analysis: 2026-03-21*
