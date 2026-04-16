# 🚛 Vehicle Scheduling System: The Developer's Deep Dive

This guide provides an exhaustive look into how the system is built, from the database schema to the specific functions that power the application logic.

---

## 🏗️ System Overview

The system follows a classic **Client-Server-Database** architecture.
- **Backend**: Node.js/Express REST API (Stateless, uses JWT for Auth).
- **Frontend**: Flutter (Mobile/Web), using `Provider` for state management.
- **Database**: MySQL, storing relational data about jobs, vehicles, and users.

---

## 🗄️ Database Schema

The database is designed with strong referential integrity. Here are the core tables:

### 1. `jobs` Table
Stores all the work that needs to be done.
- `id`: Primary key.
- `job_number`: A human-readable ID like `JOB-2026-0001`.
- `job_type`: Enumerated values (`installation`, `delivery`, `miscellaneous`).
- `current_status`: Tracks the lifecycle (`pending` ➔ `assigned` ➔ `in_progress` ➔ `completed` ➔ `cancelled`).
- `priority`: (`low`, `normal`, `high`, `urgent`).

### 2. `job_assignments` Table
A junction table that connects a `job` to a `vehicle` and a `driver`.
- `job_id`: Links to `jobs.id`.
- `vehicle_id`: Links to `vehicles.id`.
- `driver_id`: Links to `users.id` (where the user is a technician).

---

## 🔑 Backend: Security & Logic

### 1. Role-Based Permissions (`src/config/constants.js`)
Permissions are not hardcoded into every route. Instead, a central `PERMISSIONS` map defines which roles can perform which actions.

```javascript
// Example from constants.js
const PERMISSIONS = {
  'jobs:create': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],
  'vehicles:delete': [USER_ROLE.ADMIN], // Only Admin can delete vehicles
};
```

### 2. Authentication Logic (`src/controllers/authController.js`)
When a user logs in, the `AuthController.login` function does three critical things:

1.  **Validation**: Checks the username and uses `bcrypt.compare()` to verify the hashed password.
2.  **Role Normalization**: Since some roles were renamed over time (e.g., `driver` became `technician`), the `_normaliseRole` function ensures the app uses a consistent name.
    ```javascript
    static _normaliseRole(dbRole) {
      const map = { driver: USER_ROLE.TECHNICIAN };
      return map[dbRole] ?? dbRole; // Returns technician if DB says driver
    }
    ```
3.  **Permission Computation**: It dynamically calculates a list of permission strings (like `['jobs:read', 'jobs:create']`) and sends them to the mobile app in the response body.

---

## 📱 Frontend: State & Services

### 1. Robust API Requests (`lib/services/api_service.dart`)
The `ApiService` class handles all communication with the server. It includes a specialized `_handleResponse` function designed to prevent app crashes if the server returns unexpected data.

```dart
// Snippet of the robust response handler
Map<String, dynamic> _handleResponse(http.Response response) {
  if (response.statusCode >= 200 && response.statusCode < 300) {
    final decoded = jsonDecode(response.body);
    // If the server returns a List instead of a Map, wrap it to avoid TypeErrors
    if (decoded is Map<String, dynamic>) return decoded;
    return {'success': true, 'data': decoded};
  }
  throw ApiException('Request failed', response.statusCode);
}
```

### 2. Auth Provider (`lib/providers/auth_provider.dart`)
The `AuthProvider` is the "Source of Truth" for the app's UI. It tells the app:
- "Is the user logged in?" (`isLoggedIn`)
- "What can they see?" (`hasPermission('jobs:create')`)

When a user logs in, it calls `injectToken()` to automatically add the `Authorization: Bearer <token>` header to every future API call made by the `ApiService`.

---

## 🔄 The Life of a Job: Step-by-Step

1.  **Creation**: A **Dispatcher** logs in. The app checks `hasPermission('jobs:create')` and shows the "+" button. They fill a form, calling `POST /api/jobs`.
2.  **Assignment**: The Dispatcher selects a vehicle and a technician, calling `POST /api/job-assignments`. The backend creates a row in `job_assignments` and updates the job status to `assigned`.
3.  **Execution**: The **Technician** logs in. They only see jobs assigned to them. They click "Start Job," calling `POST /api/job-status/update`, which changes the status to `in_progress`.
4.  **Completion**: Once finished, the technician marks it as `completed`.

---

## 🛠️ How to Debug Like a Pro

### "I click 'Assign' but nothing happens"
1.  **Check Backend Logs**: Look for `Login error` or `Database error` in the terminal where you ran `npm run dev`.
2.  **Check API Singleton**: In Flutter, ensure `ApiService().setAuthToken(token)` was called. If the token is missing, the server will return `401 Unauthorized`.
3.  **Check the Map**: Ensure the key you are looking for in the response (e.g., `response['jobs']`) matches what the backend actually sends.

---

## 📝 Summary of Key Functions

| Function | Location | Purpose |
| :--- | :--- | :--- |
| `login` | `authController.js` | Verifies credentials and generates a JWT. |
| `_getPermissionsForRole` | `authController.js` | Returns the list of actions a user is allowed to do. |
| `hasPermission` | `auth_provider.dart` | Hides/shows UI elements based on the user's role. |
| `_handleResponse` | `api_service.dart` | Safely parses JSON to prevent "TypeError" crashes. |

*For the full technical specification, see `PROJECT_DOCUMENTATION aws Fleet managment system.md`.*
