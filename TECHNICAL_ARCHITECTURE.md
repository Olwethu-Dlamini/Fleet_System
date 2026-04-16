# 🏗️ Vehicle Scheduling System: Technical Architecture & Deep Dive

This document provides an exhaustive technical specification of the Vehicle Scheduling System. It is intended for senior developers and system architects to understand the low-level implementation details of the full-stack platform.

---

## 1. System Architecture Overview

The system is a distributed full-stack application utilizing a **Decoupled Client-Server Architecture**.

*   **Backend**: A stateless Node.js REST API built with Express. It manages business logic, data persistence via MySQL, and secure authentication using JWT (JSON Web Tokens).
*   **Frontend**: A Flutter-based mobile and web application. It uses the `Provider` pattern for reactive state management and a repository-like service layer for network communication.
*   **Database**: A relational MySQL 8.0 instance with a normalized schema, utilizing foreign key constraints and transactional integrity.
*   **Deployment**: Containerized via Docker and orchestrated on AWS EC2, with optimized networking to allow containers to access the host-installed MySQL service.

---

## 2. Backend Implementation (`vehicle-scheduling-backend`)

### 2.1 Server Configuration (`src/server.js`)
The server entry point initializes the Express application with critical middleware:

1.  **CORS Management**: Dynamically validates origins using regex patterns to allow `localhost` and `127.0.0.1` on any port (for Flutter Web debugging).
2.  **Request Parsing**: Configured with a `10mb` limit for both JSON and URL-encoded payloads to support future image uploads or large reports.
3.  **Authentication Routing**: Login and `/me` routes are prioritized and handled with specialized error wrapping to prevent leaking database internals during failed attempts.

```javascript
// Middleware order is critical for security
app.use(cors(corsOptions));
app.use(express.json());
app.use('/api', routes); // Main API router
```

### 2.2 Authentication & Role Normalization
The system employs a sophisticated role-mapping strategy to maintain backward compatibility with legacy database values.

*   **Role Normalization**: The `normaliseRole()` function acts as a translation layer between the database's `role` column and the application's internal `USER_ROLE` constants.
    *   `driver` ➔ `technician`
    *   `dispatcher` ➔ `scheduler` (or vice-versa depending on the version)
*   **JWT Strategy**: Tokens are signed with `HS256` and include the user's `id`, `role`, and `email`. The default expiration is set to `8h` to align with a standard work shift.

### 2.3 Permission Engine (`src/config/constants.js`)
Permissions are managed as a granular "Capabilities Map" rather than hard-coded role checks.

```javascript
const PERMISSIONS = {
  'jobs:create': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER],
  'vehicles:delete': [USER_ROLE.ADMIN],
};
```
When a user logs in, the backend performs a **Reverse Map Lookup**:
1.  Identify the user's normalized role.
2.  Filter the `PERMISSIONS` object for every key that includes that role.
3.  Return a flat array of permission strings to the client.

---

## 3. Database Specification (`vehicle_scheduling.sql`)

### 3.1 The `jobs` Table
The central entity of the system.

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | INT UNSIGNED | Auto-increment primary key. |
| `job_number` | VARCHAR(50) | Unique human-readable identifier (e.g., JOB-2024-001). |
| `job_type` | ENUM | installation, delivery, miscellaneous. |
| `current_status` | ENUM | pending, assigned, in_progress, completed, cancelled. |
| `priority` | ENUM | low, normal, high, urgent. |
| `scheduled_date` | DATE | Date of the job. |
| `scheduled_time_start`| TIME | Start window. |
| `created_by` | INT UNSIGNED | Foreign key to `users.id`. |

### 3.2 The `job_assignments` Table
A junction table enabling a many-to-one relationship between jobs and vehicles/drivers.

*   **Foreign Keys**: Implements `ON DELETE CASCADE` for jobs and `ON DELETE SET NULL` for drivers to prevent data orphaned by user deletion.
*   **Notes Field**: Allows dispatchers to provide specific instructions per assignment (e.g., "Park at the rear entrance").

---

## 4. Frontend Architecture (`vehicle_scheduling_app`)

### 4.1 State Management (The Provider Pattern)
The app avoids "Prop Drilling" by using `ChangeNotifier` and `Provider`.

*   **`AuthProvider`**: Manages the global authentication state. It exposes `isLoggedIn`, `isAdmin`, and the `hasPermission(String)` helper.
*   **Token Injection**: Upon successful login, the `AuthProvider` calls the `ApiService` singleton to set the `Authorization` header for all subsequent calls.

### 4.2 Robust Networking (`lib/services/api_service.dart`)
The `ApiService` is designed to be resilient against backend schema drift.

*   **Singleton Pattern**: Ensures only one HTTP client is active, optimizing memory and connection pooling.
*   **Response Handling**: The `_handleResponse` method includes defensive programming to handle non-Map JSON responses (like arrays or primitives) without throwing `TypeError`.

```dart
// Defensive decoding logic
final decoded = jsonDecode(response.body);
if (decoded is Map<String, dynamic>) {
  return decoded;
} else {
  return {'success': true, 'data': decoded};
}
```

### 4.3 Data Modeling & Serialization
The app uses sophisticated model classes with custom `fromJson` factories.

*   **`Job` Model**: Includes "Virtual Getters" like `statusDisplayName` and `formattedTimeRange` to move UI formatting logic out of the Widgets and into the data layer.
*   **Technician List**: Jobs now support multiple technicians via the `JobTechnician` sub-model, parsed from a JSON array returned by the backend's JOIN queries.

---

## 5. Deployment & DevOps

### 5.1 Dockerization
The API is containerized using a multi-stage `Dockerfile` based on `node:20-alpine`.

*   **Security**: Runs as a non-root user.
*   **Optimization**: `.dockerignore` excludes `node_modules` and local `.env` files to keep the image small (~150MB).

### 5.2 AWS EC2 Hosting
*   **Instance**: `t2.micro` or `t3.micro`.
*   **Networking**: Uses `network_mode: host` in Docker Compose. This allows the Node.js app to reach the MySQL instance on `localhost:3306` without complex Docker bridge networking, reducing latency.
*   **Reverse Proxy**: Recommended setup includes Nginx as a reverse proxy to handle SSL (HTTPS) termination.

---

## 6. Security Protocol

1.  **Password Hashing**: Uses `bcryptjs` with a salt round of 10. Passwords are never stored in plain text.
2.  **JWT Signing**: Uses a 256-bit secret key.
3.  **Environment Variables**: All sensitive data (DB passwords, JWT secrets) is stored in a `.env` file and never committed to version control.
4.  **SQL Injection Prevention**: All database queries use **Prepared Statements** (parameterized queries) provided by the `mysql2` driver.

---

## 7. Operational Workflows

### 7.1 Job Assignment Flow
1.  Dispatcher selects a job.
2.  Frontend fetches available vehicles (`GET /api/vehicles`).
3.  Frontend fetches available technicians (`GET /api/users?role=technician`).
4.  Dispatcher submits assignment (`POST /api/job-assignments`).
5.  Backend:
    *   Starts a DB transaction.
    *   Creates record in `job_assignments`.
    *   Updates `jobs.current_status` to 'assigned'.
    *   Commits transaction.

### 7.2 Technician Workflow
1.  Technician logs in.
2.  Dashboard filters jobs: `WHERE driver_id = ? AND current_status IN ('assigned', 'in_progress')`.
3.  Technician clicks "Start": `PUT /api/jobs/:id/status` ➔ 'in_progress'.
4.  Technician clicks "Complete": `PUT /api/jobs/:id/status` ➔ 'completed'.

---

## 8. Common Troubleshooting & Error Codes

| Code | Meaning | Resolution |
| :--- | :--- | :--- |
| `401` | Unauthorized | Token expired or missing. Trigger `logout()` in Flutter. |
| `403` | Forbidden | User lacks the specific permission string for this route. |
| `409` | Conflict | Attempting to assign a vehicle that is already booked for that time slot. |
| `500` | Server Error | Check backend logs for `ER_BAD_FIELD_ERROR` or connection timeouts. |

---

## 9. Future Extensibility Points

1.  **Real-time Tracking**: The architecture is ready for **WebSockets (Socket.io)** to push live job updates to technicians.
2.  **Image Uploads**: The `ApiService` can be extended with `http.MultipartRequest` to support "Proof of Work" photos.
3.  **Push Notifications**: Integration with Firebase Cloud Messaging (FCM) is planned to alert technicians of new assignments.

---

*Document Version: 1.2.0*  
*Last Updated: March 2026*
