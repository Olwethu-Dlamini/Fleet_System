# FleetScheduler Pro

A full-stack vehicle and fleet scheduling system with a Node.js/Express REST API backend and a Flutter mobile/web frontend. Designed for field service companies that need to schedule jobs, assign vehicles and technicians, track GPS locations, and manage time extensions -- all from a single platform.

## Architecture

```
vehicle-scheduling-backend/    Node.js + Express 5.x REST API
  src/
    server.js                  Entry point (Express + Socket.IO)
    routes/                    API route definitions
    controllers/               Request handlers
    models/                    Database models (MySQL)
    services/                  Business logic layer
    middleware/                 Auth, rate limiting, validation
    config/                    Database, Firebase, Swagger, logging

vehicle_scheduling_app/        Flutter (Dart) mobile and web app
  lib/
    main.dart                  App entry point
    config/app_config.dart     API base URL and endpoint constants
    models/                    Data models
    providers/                 State management (Provider pattern)
    screens/                   UI screens (dashboard, jobs, vehicles, etc.)
    services/                  API service layer
    widgets/                   Reusable UI components

vehicle_scheduling.sql         Database schema (MySQL)
```

### Backend

- **Runtime:** Node.js 18+
- **Framework:** Express 5.x
- **Database:** MySQL 8.x via `mysql2`
- **Auth:** JWT-based (access + refresh tokens) with bcrypt password hashing
- **Real-time:** Socket.IO for live GPS tracking
- **Push notifications:** Firebase Cloud Messaging (optional)
- **Email notifications:** Nodemailer via SMTP (optional)
- **Job scheduling:** node-cron for auto-status transitions and notification checks
- **API docs:** Swagger UI auto-generated from JSDoc annotations
- **Logging:** Pino (structured JSON logging)
- **Security:** Helmet, CORS, express-rate-limit, express-validator

### Frontend

- **Framework:** Flutter (Dart SDK ^3.9.2)
- **State management:** Provider pattern
- **Charts:** fl_chart for dashboard visualizations
- **Maps:** Google Maps Flutter plugin + Geolocator for GPS
- **Push notifications:** Firebase Messaging + flutter_local_notifications
- **Real-time:** Socket.IO client for live GPS updates

### Database

- **Engine:** MySQL 8.x (InnoDB, utf8mb4)
- **Schema:** Multi-tenant with `tenant_id` scoping
- **Key tables:** users, jobs, vehicles, job_assignments, job_status_history, notifications, notification_preferences, time_extension_requests, gps_consent, vehicle_maintenance, settings, audit_log, emerald_sync_log

## Prerequisites

| Dependency  | Version  | Notes                                     |
|-------------|----------|-------------------------------------------|
| Node.js     | 18+      | LTS recommended                           |
| npm         | 9+       | Comes with Node.js                        |
| MySQL       | 8.x      | Or MariaDB 10.6+                          |
| Flutter     | 3.x      | Dart SDK ^3.9.2                           |
| Git         | 2.x      | For cloning the repository                |

**Optional:**
- Firebase account (for push notifications)
- Google Cloud project with Routes API v2 enabled (for GPS directions)
- SMTP server (for email notifications)

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd <project-directory>
```

### 2. Database Setup

Create the MySQL database and import the schema:

```bash
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS vehicle_scheduling;"
mysql -u root -p vehicle_scheduling < vehicle_scheduling.sql
```

The schema includes test data suitable for development and demos.

### 3. Backend Setup

```bash
cd vehicle-scheduling-backend

# Install dependencies
npm install

# Create environment file
cp .env.example .env

# Edit .env with your database credentials and a secure JWT secret
# At minimum, set: DB_PASSWORD, JWT_SECRET

# Start the development server (with auto-reload)
npm run dev
```

The API server starts at **http://localhost:3000**.

### 4. Frontend Setup

```bash
cd vehicle_scheduling_app

# Install Flutter dependencies
flutter pub get

# Run on connected device, emulator, or web browser
flutter run

# Or run specifically for web
flutter run -d chrome
```

The Flutter app connects to `http://localhost:3000/api` by default (configurable in `lib/config/app_config.dart`).

## Environment Variables

All environment variables are configured in `vehicle-scheduling-backend/.env`. See `.env.example` for a fully documented template.

| Variable                   | Required | Default       | Description                                      |
|----------------------------|----------|---------------|--------------------------------------------------|
| `PORT`                     | No       | `3000`        | API server port                                  |
| `NODE_ENV`                 | No       | `development` | Environment (development/production/test)        |
| `DB_HOST`                  | No       | `localhost`   | MySQL host                                       |
| `DB_PORT`                  | No       | `3306`        | MySQL port                                       |
| `DB_NAME`                  | No       | `vehicle_scheduling` | MySQL database name                       |
| `DB_USER`                  | No       | `root`        | MySQL username                                   |
| `DB_PASSWORD`              | Yes      |               | MySQL password                                   |
| `JWT_SECRET`               | Yes      |               | JWT signing secret (server won't start without it) |
| `JWT_EXPIRES`              | No       | `8h`          | JWT token expiry (e.g., 1h, 8h, 7d)             |
| `SMTP_HOST`                | No       |               | SMTP server for email notifications              |
| `SMTP_PORT`                | No       | `587`         | SMTP port                                        |
| `SMTP_USER`                | No       |               | SMTP username                                    |
| `SMTP_PASS`                | No       |               | SMTP password                                    |
| `FCM_SERVICE_ACCOUNT_PATH` | No       |               | Path to Firebase service account JSON            |
| `GOOGLE_MAPS_API_KEY`      | No       |               | Google Maps API key (server-side only)           |
| `EMERALD_API_URL`          | No       |               | Emerald v6 API base URL                          |
| `EMERALD_API_USER`         | No       |               | Emerald API username                             |
| `EMERALD_API_PASSWORD`     | No       |               | Emerald API password                             |
| `EMERALD_SYNC_ENABLED`     | No       | `false`       | Enable Emerald data sync                         |

## Default Credentials (Development Only)

> **WARNING:** These credentials are for local development and testing only. Change them before any production deployment.

| Email             | Password    | Role  |
|-------------------|-------------|-------|
| admin@fleet.com   | Admin@123   | Admin |

## API Documentation

Interactive Swagger documentation is available when the backend is running:

**http://localhost:3000/api-docs**

All endpoints are documented with request/response schemas, authentication requirements, and example payloads.

For a quick reference of all endpoints, see [docs/API_REFERENCE.md](docs/API_REFERENCE.md).

## Available Scripts

### Backend (`vehicle-scheduling-backend/`)

| Command                  | Description                              |
|--------------------------|------------------------------------------|
| `npm run dev`            | Start with nodemon (auto-reload)         |
| `npm start`              | Start production server                  |
| `npm test`               | Run all tests (Jest)                     |
| `npm run test:unit`      | Run unit tests only                      |
| `npm run test:integration` | Run integration tests only             |
| `npm run test:api`       | Run API tests                            |
| `npm run test:e2e`       | Run Playwright end-to-end tests          |
| `npm run test:coverage`  | Run tests with coverage report           |

### Frontend (`vehicle_scheduling_app/`)

| Command             | Description                              |
|---------------------|------------------------------------------|
| `flutter pub get`   | Install dependencies                     |
| `flutter run`       | Run on connected device/emulator         |
| `flutter run -d chrome` | Run in Chrome browser                |
| `flutter build apk` | Build Android APK                        |
| `flutter build web` | Build for web deployment                 |

## Key Features

- **Job scheduling** -- Create, assign, and track installation, delivery, and miscellaneous jobs
- **Vehicle management** -- Fleet tracking with maintenance scheduling
- **Driver assignment** -- Load-balanced driver assignment with conflict detection
- **Real-time GPS tracking** -- Live driver positions with POPIA/GDPR consent management
- **Time extensions** -- Technicians can request extra time; schedulers approve/deny with rescheduling suggestions
- **Dashboard** -- Summary stats, hourly job charts, and quick status overview
- **Reports** -- Per-vehicle, per-technician, daily volume, utilisation, and CSV export
- **Notifications** -- Push (FCM) and email alerts for upcoming jobs, overdue jobs, and time extension updates
- **Emerald integration** -- Sync customers and work orders from Emerald v6 billing system
- **Audit logging** -- Track login, logout, password resets, and data changes
- **Multi-tenant** -- Data isolation via tenant_id scoping
- **Role-based access** -- Admin, scheduler, and technician roles with granular permissions

## Additional Documentation

| Document | Description |
|----------|-------------|
| [docs/API_REFERENCE.md](docs/API_REFERENCE.md) | Complete API endpoint reference |
| [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) | Firebase push notification setup guide |
| [docs/EMERALD_INTEGRATION.md](docs/EMERALD_INTEGRATION.md) | Emerald v6 integration guide |

## Project Structure

```
.
├── vehicle-scheduling-backend/
│   ├── src/
│   │   ├── server.js               # Express app entry point + Socket.IO
│   │   ├── config/
│   │   │   ├── database.js         # MySQL connection pool
│   │   │   ├── firebase.js         # Firebase Admin SDK init
│   │   │   ├── swagger.js          # Swagger/OpenAPI config
│   │   │   ├── logger.js           # Pino logger config
│   │   │   └── constants.js        # Roles, permissions, enums
│   │   ├── routes/
│   │   │   ├── index.js            # Route registry
│   │   │   ├── authRoutes.js       # Login, logout, refresh, password reset
│   │   │   ├── jobs.js             # Job CRUD + scheduling
│   │   │   ├── vehicles.js         # Vehicle CRUD
│   │   │   ├── users.js            # User management
│   │   │   ├── jobAssignmentRoutes.js  # Assign/unassign vehicles and drivers
│   │   │   ├── jobStatusRoutes.js  # Status transitions + history
│   │   │   ├── dashboard.js        # Dashboard summary + charts
│   │   │   ├── reports.js          # Analytics + CSV export
│   │   │   ├── notifications.js    # Notification CRUD + preferences
│   │   │   ├── timeExtension.js    # Time extension workflow
│   │   │   ├── gps.js              # GPS directions, tracking, consent
│   │   │   ├── settings.js         # Admin key-value settings
│   │   │   ├── emerald.js          # Emerald v6 sync endpoints
│   │   │   ├── audit.js            # Audit log viewer
│   │   │   ├── availabilityRoutes.js   # Driver/vehicle availability checks
│   │   │   └── vehicle-maintenance.js  # Maintenance scheduling
│   │   ├── controllers/            # Request handlers
│   │   ├── services/               # Business logic
│   │   │   ├── jobAssignmentService.js
│   │   │   ├── jobStatusService.js
│   │   │   ├── notificationService.js
│   │   │   ├── timeExtensionService.js
│   │   │   ├── emeraldService.js
│   │   │   ├── gpsService.js
│   │   │   ├── directionsService.js
│   │   │   ├── cronService.js
│   │   │   └── emailService.js
│   │   ├── models/                 # Database models
│   │   ├── middleware/             # Auth, rate limiter, validation
│   │   └── utils/                  # Pagination, helpers
│   ├── package.json
│   └── .env.example
│
├── vehicle_scheduling_app/
│   ├── lib/
│   │   ├── main.dart               # App entry point
│   │   ├── config/
│   │   │   └── app_config.dart     # API URLs + endpoints
│   │   ├── models/                 # Dart data models
│   │   ├── providers/              # State management (Provider)
│   │   ├── screens/
│   │   │   ├── dashboard/          # Main dashboard
│   │   │   ├── jobs/               # Job list + detail
│   │   │   ├── vehicles/           # Vehicle list + detail
│   │   │   ├── users/              # User management
│   │   │   ├── assignments/        # Job assignment
│   │   │   ├── reports/            # Reports + charts
│   │   │   ├── notifications/      # Notification center
│   │   │   ├── time_management/    # Time extension screens
│   │   │   ├── gps/                # GPS tracking + consent
│   │   │   ├── settings/           # App settings
│   │   │   └── login_screen.dart   # Login screen
│   │   ├── services/               # API service layer
│   │   └── widgets/                # Reusable UI components
│   ├── pubspec.yaml
│   └── assets/
│
├── vehicle_scheduling.sql          # Database schema + seed data
├── docker-compose.yml              # Docker deployment config
├── docs/                           # Additional documentation
└── e2e/                            # Playwright end-to-end tests
```

## License

See [LICENSE](LICENSE) for details.
