# Technology Stack

**Analysis Date:** 2026-03-21

## Languages

**Primary:**
- JavaScript (Node.js) - Backend REST API server and routing
- Dart (3.9.2+) - Flutter mobile and web application framework
- SQL (MySQL/MariaDB) - Database queries and schema definition

**Secondary:**
- Kotlin - Android native layer for Flutter
- Swift - iOS native layer for Flutter

## Runtime

**Environment:**
- Node.js (v14+ inferred, v20 recommended for production)
- Dart SDK 3.9.2+
- Flutter SDK 3.9.2+
- MySQL 5.6+ / MariaDB 10.4.32+

**Package Manager:**
- npm (Node.js packages) - Lockfile: `package-lock.json` present
- pub (Dart packages) - Lockfile: `pubspec.lock` present

## Frameworks

**Core:**
- Express.js 5.2.1 - HTTP REST API framework
- Flutter (all platforms) - Mobile/web framework for Android, iOS, web, desktop

**API Documentation:**
- swagger-jsdoc 6.2.8 - Generate OpenAPI specs from JSDoc comments
- swagger-ui-express 5.0.1 - Interactive Swagger UI at `/swagger` endpoint
- OpenAPI 3.0.0 spec: `src/config/swagger.js`

**Authentication & Security:**
- jsonwebtoken 9.0.3 - JWT token generation and verification
- bcryptjs 3.0.3 - Password hashing (deprecated, present alongside newer bcrypt)
- bcrypt 6.0.0 - Modern password hashing library

**HTTP & Data:**
- mysql2 3.16.3 - Promise-based MySQL client with connection pooling
- mysql 2.18.1 - Legacy MySQL client (redundant, deprecated)
- cors 2.8.6 - Cross-origin resource sharing middleware
- dotenv 17.2.4 - Environment variable loading from `.env` files

**Build & Development:**
- nodemon 3.1.11 (devDependency) - Auto-restart Node server on file changes
- flutter_launcher_icons 0.13.1 - Generate adaptive app icons from single source
- flutter_test (built-in) - Unit and widget testing framework
- flutter_lints 5.0.0 - Dart linting rules

## Key Dependencies

**Backend Critical:**
- express 5.2.1 - Core HTTP server
- mysql2 3.16.3 - Database client (preferred over mysql)
- jsonwebtoken 9.0.3 - JWT token handling
- bcryptjs or bcrypt - Password hashing
- cors 2.8.6 - CORS handling
- dotenv 17.2.4 - Env var loading
- swagger-ui-express 5.0.1 - API documentation UI
- swagger-jsdoc 6.2.8 - API spec generation

**Frontend (Flutter) Critical:**
- http 1.1.0 - HTTP client for API calls
- provider 6.1.5+1 - State management and dependency injection
- shared_preferences 2.5.4 - Persistent local storage (tokens, user data)
- intl 0.20.2 - Internationalization and date/time formatting

**Frontend (Flutter) - Maps & Location:**
- google_maps_flutter 2.10.0 - Google Maps widget for job location selection
- geolocator 13.0.2 - Device location and permission handling
- url_launcher 6.3.1 - Open URLs in browser/native apps

**Frontend (Flutter) - UI:**
- cupertino_icons 1.0.8 - iOS-style icon set
- fluttertoast 9.0.0 - Native toast notifications

## Configuration

**Environment Variables (Backend):**
- `DB_HOST` - MySQL server address (default: localhost)
- `DB_USER` - MySQL username (default: root)
- `DB_PASSWORD` - MySQL password (default: empty)
- `DB_NAME` - Database name (default: vehicle_scheduling)
- `DB_PORT` - MySQL port (default: 3306)
- `PORT` - Node.js server port (default: 3000)
- `NODE_ENV` - environment flag (development/production)
- `JWT_SECRET` - Token signing key (default: vehicle_scheduling_secret_2024)
- `JWT_EXPIRES` - Token expiration (default: 8h)
- Template: `.env.example` at repository root

**Backend Configuration Files:**
- `src/config/database.js` - MySQL connection pool (10 max connections, keep-alive enabled)
- `src/config/swagger.js` - OpenAPI 3.0.0 specification
- `src/config/constants.js` - User roles and permission mappings

**Frontend Configuration (Flutter):**
- `lib/config/app_config.dart` - API base URLs and environment switching
  - Local dev: `http://localhost:3000/api` (web), `http://10.0.2.2:3000/api` (Android emulator)
  - Production: `http://3.231.191.15:8080/api` (AWS EC2 with Docker port mapping)
  - Toggle: `useLocal` boolean flag
  - Timeout: 30 seconds (connection and receive)

**Build Configuration:**
- `pubspec.yaml` - Flutter dependencies and app metadata
- `android/app/src/main/AndroidManifest.xml` - Android app config and Google Maps API key
- `ios/Runner/Info.plist` - iOS app config with location permission descriptions
- `flutter_launcher_icons` config in `pubspec.yaml` - Icon generation settings

## Platform Requirements

**Development:**
- Node.js v14+ (v20 recommended)
- npm with `package-lock.json`
- MySQL 5.6+ or MariaDB 10.4+
- Dart SDK 3.9.2+
- Flutter SDK 3.9.2+
- Android SDK (API 21+) for Android development
- Xcode for iOS development

**Production:**
- AWS EC2 instance (IP: 3.231.191.15)
- Docker runtime (node:20-alpine image)
- MySQL/MariaDB database (EC2-hosted)
- Google Maps API key (configured in native manifests)
- Reverse proxy for port mapping (8080 → 3000)

**Mobile Deployment:**
- Android: minSdkVersion 21, adaptive icons enabled
- iOS: iOS 13+ (typical Flutter minimum)
- Web: Browser with WebGL support
- Desktop: Linux, macOS, Windows (Flutter desktop enabled)

## Key Stack Decisions

**mysql2 with Promise support:**
- Chosen over callback-based `mysql` for modern async/await syntax
- Connection pooling (10 max) for concurrent request handling
- Keep-alive enabled to prevent connection timeouts

**JWT Authentication:**
- Stateless tokens - no server-side session storage
- 8-hour expiration balances security and UX
- Roles: admin, scheduler (dispatcher), technician (driver)

**Provider for State Management:**
- Lightweight, performant, minimal boilerplate
- Integrates with SharedPreferences for session persistence

**Google Maps + Geolocator Integration:**
- Maps: Job location selection and visualization
- Geolocator: Device location services and permission handling
- url_launcher: Opens maps app for directions

**Swagger/OpenAPI Documentation:**
- Self-documenting API at `/swagger` endpoint
- JSDoc comments in route files auto-generate spec
- Enables frontend developers to explore endpoints without reading code

---

*Stack analysis: 2026-03-21*
