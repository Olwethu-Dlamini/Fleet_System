# API Reference

Quick reference for all FleetScheduler Pro REST API endpoints.

**Base URL:** `http://localhost:3000/api`

**Authentication:** Most endpoints require a JWT token in the `Authorization` header:
```
Authorization: Bearer <jwt-token>
```

**Interactive docs:** Full Swagger UI with request/response schemas is available at `http://localhost:3000/api-docs` when the server is running.

---

## Table of Contents

- [Authentication](#authentication)
- [Jobs](#jobs)
- [Vehicles](#vehicles)
- [Users](#users)
- [Job Assignments](#job-assignments)
- [Job Status](#job-status)
- [Dashboard](#dashboard)
- [Reports](#reports)
- [Notifications](#notifications)
- [Time Extensions](#time-extensions)
- [GPS](#gps)
- [Availability](#availability)
- [Vehicle Maintenance](#vehicle-maintenance)
- [Settings](#settings)
- [Emerald Integration](#emerald-integration)
- [Audit](#audit)
- [Health](#health)

---

## Authentication

| Method | Path                      | Auth | Description                                      |
|--------|---------------------------|------|--------------------------------------------------|
| POST   | `/api/auth/login`         | No   | Login with email and password, returns JWT token |
| POST   | `/api/auth/logout`        | Yes  | Invalidate current session                       |
| GET    | `/api/auth/me`            | Yes  | Get current authenticated user profile           |
| POST   | `/api/auth/refresh`       | No   | Refresh access token using refresh token         |
| POST   | `/api/auth/forgot-password` | No | Request a 6-digit password reset code via email  |
| POST   | `/api/auth/reset-password`  | No | Reset password using the 6-digit code            |

### Login Request

```json
POST /api/auth/login
{
  "email": "admin@fleet.com",
  "password": "Admin@123"
}
```

### Login Response

```json
{
  "success": true,
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": {
    "id": 1,
    "username": "admin",
    "full_name": "System Admin",
    "email": "admin@fleet.com",
    "role": "admin"
  }
}
```

---

## Jobs

| Method | Path                           | Auth | Role              | Description                                 |
|--------|--------------------------------|------|-------------------|---------------------------------------------|
| GET    | `/api/jobs`                    | Yes  | All (scoped)      | List jobs (technicians see only their own)  |
| GET    | `/api/jobs/my-jobs`            | Yes  | Technician        | List jobs assigned to current user          |
| GET    | `/api/jobs/:id`                | Yes  | All               | Get job details by ID                       |
| POST   | `/api/jobs`                    | Yes  | Admin/Scheduler   | Create a new job                            |
| PUT    | `/api/jobs/:id`                | Yes  | Admin/Scheduler   | Update job details                          |
| PUT    | `/api/jobs/:id/schedule`       | Yes  | Admin/Scheduler   | Reschedule a job (date/time)                |
| PUT    | `/api/jobs/:id/technicians`    | Yes  | Admin/Scheduler   | Assign technicians to a job                 |
| PUT    | `/api/jobs/:id/swap-vehicle`   | Yes  | Admin/Scheduler   | Hotswap vehicle on an active job            |
| DELETE | `/api/jobs/:id/vehicle`        | Yes  | Admin/Scheduler   | Remove vehicle assignment from a job        |

### Query Parameters for GET /api/jobs

| Parameter    | Type   | Description                                      |
|--------------|--------|--------------------------------------------------|
| `search`     | string | Search job number, customer name, description    |
| `status`     | string | Filter by status (pending, assigned, in_progress, completed, cancelled) |
| `date`       | string | Filter by scheduled date (YYYY-MM-DD)            |
| `priority`   | string | Filter by priority (low, normal, high, urgent)   |
| `page`       | int    | Page number (default: 1)                         |
| `limit`      | int    | Results per page (default: 20, max: 200)         |

---

## Vehicles

| Method | Path                  | Auth | Role  | Description                                      |
|--------|-----------------------|------|-------|--------------------------------------------------|
| GET    | `/api/vehicles`       | No   | All   | List all vehicles (with pagination and search)   |
| GET    | `/api/vehicles/:id`   | No   | All   | Get vehicle details by ID                        |
| POST   | `/api/vehicles`       | Yes  | Admin | Create a new vehicle                             |
| PUT    | `/api/vehicles/:id`   | Yes  | Admin | Update vehicle details                           |
| DELETE | `/api/vehicles/:id`   | Yes  | Admin | Delete/deactivate a vehicle (soft-delete if assigned) |

### Query Parameters for GET /api/vehicles

| Parameter    | Type   | Description                                      |
|--------------|--------|--------------------------------------------------|
| `search`     | string | Search vehicle name, license plate, type         |
| `status`     | string | Filter by active status (`true` or `false`)      |
| `activeOnly` | string | Legacy alias for status=true                     |
| `page`       | int    | Page number (default: 1)                         |
| `limit`      | int    | Results per page (default: 20, max: 200)         |

---

## Users

| Method | Path                              | Auth | Role            | Description                          |
|--------|-----------------------------------|------|-----------------|--------------------------------------|
| GET    | `/api/users`                      | Yes  | Admin/Scheduler | List users (with filters)            |
| GET    | `/api/users/:id`                  | Yes  | Admin/Scheduler | Get user details by ID               |
| POST   | `/api/users`                      | Yes  | Admin           | Create a new user                    |
| PUT    | `/api/users/:id`                  | Yes  | Admin           | Update user details                  |
| DELETE | `/api/users/:id`                  | Yes  | Admin           | Deactivate a user (soft-delete)      |
| POST   | `/api/users/:id/reset-password`   | Yes  | Admin           | Reset a user's password              |

### Roles

| App Role    | DB Role      | Description                                |
|-------------|--------------|--------------------------------------------|
| `admin`     | `admin`      | Full access to all features                |
| `scheduler` | `dispatcher` | Can manage jobs, view reports, assign work |
| `technician`| `driver`     | Can view assigned jobs, update status      |

---

## Job Assignments

| Method | Path                                        | Auth | Description                                        |
|--------|---------------------------------------------|------|----------------------------------------------------|
| GET    | `/api/job-assignments/driver-load`          | Yes  | Get driver load stats for balanced assignment      |
| POST   | `/api/job-assignments/assign`               | Yes  | Assign a vehicle and driver to a job               |
| POST   | `/api/job-assignments/unassign`             | Yes  | Remove assignment (cancels job, clears vehicle/driver) |
| POST   | `/api/job-assignments/check-conflict`       | Yes  | Check for scheduling conflicts before assigning    |
| PUT    | `/api/job-assignments/:jobId/technicians`   | Yes  | Assign technicians to a job                        |
| GET    | `/api/job-assignments/vehicle/:vehicle_id`  | Yes  | Get all assignments for a specific vehicle         |

---

## Job Status

| Method | Path                                           | Auth | Description                                    |
|--------|-------------------------------------------------|------|------------------------------------------------|
| POST   | `/api/job-status/complete`                     | Yes  | Complete a job (with optional GPS coordinates) |
| POST   | `/api/job-status/update`                       | Yes  | Update job status                              |
| GET    | `/api/job-status/history/:job_id`              | Yes  | Get status change history for a job            |
| GET    | `/api/job-status/allowed-transitions/:job_id`  | Yes  | Get allowed next statuses for a job            |
| POST   | `/api/job-status/validate-transition`          | Yes  | Validate if a status transition is allowed     |
| GET    | `/api/job-status/recent-changes`               | Yes  | Get recent status changes across all jobs      |

### Status Flow

```
pending --> assigned --> in_progress --> completed
                |                |
                v                v
            cancelled        cancelled
```

- `pending` -> `assigned`: When vehicle/driver assigned
- `assigned` -> `in_progress`: Auto-transition by cron when start time passes
- `in_progress` -> `completed`: Manual completion (or job finish)
- Any active status -> `cancelled`: Admin/scheduler can cancel

---

## Dashboard

| Method | Path                         | Auth | Description                                      |
|--------|------------------------------|------|--------------------------------------------------|
| GET    | `/api/dashboard/summary`     | Yes  | Full dashboard: job counts, vehicles, drivers, today's jobs |
| GET    | `/api/dashboard/stats`       | Yes  | Quick stats only (lightweight)                   |
| GET    | `/api/dashboard/chart-data`  | Yes  | Hourly job counts for today (bar chart data)     |

---

## Reports

All report endpoints require admin or scheduler role. All accept optional `date_from` and `date_to` query parameters (YYYY-MM-DD, defaults to last 30 days).

| Method | Path                                       | Auth | Description                                   |
|--------|--------------------------------------------|------|-----------------------------------------------|
| GET    | `/api/reports/summary`                     | Yes  | KPI overview cards                            |
| GET    | `/api/reports/jobs-by-vehicle`             | Yes  | Job count and breakdown per vehicle           |
| GET    | `/api/reports/jobs-by-technician`          | Yes  | Job count and breakdown per technician        |
| GET    | `/api/reports/jobs-by-type`                | Yes  | Jobs grouped by type (installation/delivery/misc) |
| GET    | `/api/reports/cancellations`               | Yes  | Cancellation detail with reasons              |
| GET    | `/api/reports/daily-volume`                | Yes  | Jobs per day over the date range (chart data) |
| GET    | `/api/reports/vehicle-utilisation`         | Yes  | % of working days each vehicle was used       |
| GET    | `/api/reports/technician-performance`      | Yes  | Completion rate, average duration per tech    |
| GET    | `/api/reports/executive-dashboard`         | Yes  | All reports combined in one response          |
| GET    | `/api/reports/export/csv`                  | Yes  | Download job data as CSV file                 |

### CSV Export Query Parameters

| Parameter  | Type   | Description                                      |
|------------|--------|--------------------------------------------------|
| `date_from`| string | Start date (YYYY-MM-DD, default: 30 days ago)   |
| `date_to`  | string | End date (YYYY-MM-DD, default: today)            |
| `status`   | string | Filter by job status                             |
| `job_type` | string | Filter by job type                               |

---

## Notifications

| Method | Path                                    | Auth | Description                                      |
|--------|-----------------------------------------|------|--------------------------------------------------|
| GET    | `/api/notifications`                    | Yes  | List notifications for current user (paginated)  |
| GET    | `/api/notifications/unread-count`       | Yes  | Get count of unread notifications                |
| GET    | `/api/notifications/preferences`        | Yes  | Get notification preferences (push, email, types)|
| PATCH  | `/api/notifications/read-all`           | Yes  | Mark all notifications as read                   |
| PATCH  | `/api/notifications/:id/read`           | Yes  | Mark a single notification as read               |
| PUT    | `/api/notifications/preferences`        | Yes  | Update notification preferences                  |

---

## Time Extensions

| Method | Path                                           | Auth | Role              | Description                                    |
|--------|-------------------------------------------------|------|-------------------|------------------------------------------------|
| POST   | `/api/time-extensions`                         | Yes  | Technician        | Create a time extension request                |
| GET    | `/api/time-extensions/pending`                 | Yes  | Admin/Scheduler   | List all pending extension requests            |
| GET    | `/api/time-extensions/:jobId/day-schedule`     | Yes  | Admin/Scheduler   | Get full day schedule for approval context     |
| GET    | `/api/time-extensions/:jobId`                  | Yes  | All               | Get active extension request for a job         |
| PATCH  | `/api/time-extensions/:id/approve`             | Yes  | Admin/Scheduler   | Approve an extension request                   |
| PATCH  | `/api/time-extensions/:id/deny`                | Yes  | Admin/Scheduler   | Deny an extension request                      |

### Time Extension Workflow

1. **Technician requests** -- POST with `job_id`, `duration_minutes` (1-480), and `reason` (min 10 chars)
2. **System calculates impact** -- Returns affected downstream jobs and 2-3 rescheduling suggestions
3. **Scheduler reviews** -- Sees the day schedule, affected jobs, and options
4. **Scheduler approves/denies** -- Can select a suggestion or provide custom time changes

---

## GPS

| Method | Path                    | Auth | Role              | Description                                      |
|--------|-------------------------|------|-------------------|--------------------------------------------------|
| GET    | `/api/gps/directions`   | Yes  | All               | Get directions to a job destination (Google Routes API) |
| POST   | `/api/gps/location`     | Yes  | Technician        | Post driver's current GPS coordinates            |
| GET    | `/api/gps/drivers`      | Yes  | Admin/Scheduler   | Get live driver positions (in-memory, stale filtered) |
| GET    | `/api/gps/consent`      | Yes  | All               | Get current user's GPS consent status            |
| POST   | `/api/gps/consent`      | Yes  | All               | Grant GPS consent (first-time POPIA/GDPR record) |
| PUT    | `/api/gps/consent`      | Yes  | All               | Update GPS consent (enable/disable tracking)     |

### GPS Directions Query Parameters

| Parameter    | Type   | Required | Description                          |
|--------------|--------|----------|--------------------------------------|
| `job_id`     | int    | Yes      | Job ID to get directions to          |
| `origin_lat` | float  | No       | Driver's current latitude            |
| `origin_lng` | float  | No       | Driver's current longitude           |

If origin coordinates are omitted, only the destination is returned (no route/ETA).

### GPS Privacy Controls

- **Working hours:** Location updates are rejected outside 6AM-8PM
- **Consent required:** Drivers must grant GPS consent before tracking activates
- **Admin control:** Admin can disable GPS visibility for schedulers via the `scheduler_gps_visible` setting
- **Stale filtering:** Positions older than 5 minutes are automatically excluded from the drivers endpoint

---

## Availability

Pre-flight availability checks for the assignment UI. These endpoints help the Flutter app grey out busy vehicles and drivers before the user submits.

| Method | Path                                  | Auth | Description                                      |
|--------|---------------------------------------|------|--------------------------------------------------|
| GET    | `/api/availability/drivers`           | Yes  | Check driver availability for a date/time range  |
| GET    | `/api/availability/vehicles`          | Yes  | Check vehicle availability for a date/time range |
| POST   | `/api/availability/check-drivers`     | Yes  | Batch-check multiple drivers for availability    |

### Query Parameters

| Parameter        | Type   | Required | Description                              |
|------------------|--------|----------|------------------------------------------|
| `date`           | string | Yes      | Date to check (YYYY-MM-DD)               |
| `start_time`     | string | Yes      | Start time (HH:MM:SS)                    |
| `end_time`       | string | Yes      | End time (HH:MM:SS)                      |
| `exclude_job_id` | int    | No       | Exclude this job's assignments (for edits) |

---

## Vehicle Maintenance

| Method | Path                                  | Auth | Permission         | Description                              |
|--------|---------------------------------------|------|--------------------|------------------------------------------|
| GET    | `/api/vehicle-maintenance`            | Yes  | maintenance:read   | List maintenance records for a vehicle   |
| GET    | `/api/vehicle-maintenance/active`     | Yes  | maintenance:read   | List vehicles currently in maintenance   |
| POST   | `/api/vehicle-maintenance`            | Yes  | maintenance:create | Create a maintenance record              |
| PUT    | `/api/vehicle-maintenance/:id`        | Yes  | maintenance:create | Update a maintenance record              |
| DELETE | `/api/vehicle-maintenance/:id`        | Yes  | maintenance:create | Soft-delete (mark as completed)          |

---

## Settings

Key-value settings store for admin configuration toggles.

| Method | Path                      | Auth | Permission       | Description                          |
|--------|---------------------------|------|------------------|--------------------------------------|
| GET    | `/api/settings`           | Yes  | settings:read    | Get all settings for the tenant      |
| GET    | `/api/settings/:key`      | Yes  | settings:read    | Get a single setting by key          |
| PUT    | `/api/settings/:key`      | Yes  | settings:update  | Create or update a setting           |

---

## Emerald Integration

All Emerald endpoints require admin role.

| Method | Path                              | Auth | Description                                      |
|--------|-----------------------------------|------|--------------------------------------------------|
| GET    | `/api/emerald/status`             | Yes  | Test Emerald API connection                      |
| POST   | `/api/emerald/sync/customers`     | Yes  | Pull customers from Emerald, update local jobs   |
| POST   | `/api/emerald/sync/incidents`     | Yes  | Pull incidents from Emerald, create as new jobs  |
| GET    | `/api/emerald/customers`          | Yes  | Proxy search for Emerald customers (typeahead)   |

See [EMERALD_INTEGRATION.md](EMERALD_INTEGRATION.md) for full details.

---

## Audit

| Method | Path          | Auth | Role  | Description                              |
|--------|---------------|------|-------|------------------------------------------|
| GET    | `/api/audit`  | Yes  | Admin | Get paginated audit logs with filters    |

### Query Parameters

| Parameter     | Type   | Description                                      |
|---------------|--------|--------------------------------------------------|
| `page`        | int    | Page number (default: 1)                         |
| `limit`       | int    | Results per page (default: 50)                   |
| `action`      | string | Filter by action (login, logout, password_reset) |
| `entity_type` | string | Filter by entity type (user, job)                |
| `user_id`     | int    | Filter by user ID                                |
| `date_from`   | string | Filter from date (YYYY-MM-DD)                    |
| `date_to`     | string | Filter to date (YYYY-MM-DD)                      |

---

## Health

| Method | Path           | Auth | Description                          |
|--------|----------------|------|--------------------------------------|
| GET    | `/api/health`  | No   | Health check (returns status: OK)    |

Response:

```json
{
  "status": "OK",
  "timestamp": "2026-04-09T12:00:00.000Z"
}
```

---

## Common Response Formats

### Success Response

```json
{
  "success": true,
  "data": { ... },
  "message": "Operation completed"
}
```

### Error Response

```json
{
  "success": false,
  "error": "Description of what went wrong"
}
```

### Paginated Response

```json
{
  "success": true,
  "data": [ ... ],
  "count": 10,
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45,
    "totalPages": 3
  }
}
```

---

## Rate Limiting

The API applies rate limiting to protect against abuse:

- **General API:** Requests are rate-limited per IP
- **Login endpoint:** Stricter rate limit to prevent brute force attacks

Rate limit headers are included in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1680000000
```
