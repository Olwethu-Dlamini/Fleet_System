# Emerald v6 Integration Guide

This document covers the integration between FleetScheduler Pro and Emerald v6, an ISP billing and service management system. The integration allows FleetScheduler to pull customer data and work orders (incidents) from Emerald, reducing manual data entry for field service scheduling.

## Table of Contents

1. [Overview](#overview)
2. [Configuration](#configuration)
3. [API Connection Details](#api-connection-details)
4. [Available Sync Operations](#available-sync-operations)
5. [Data Mapping](#data-mapping)
6. [Sync Log](#sync-log)
7. [Admin UI](#admin-ui)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The Emerald integration is a one-way data pull:

```
Emerald v6  ──(HTTP POST)──>  FleetScheduler Backend  ──>  MySQL Database
```

- **Customers** are pulled from Emerald and used to update customer contact information on existing jobs
- **Incidents** (work orders) are pulled from Emerald and created as new jobs in FleetScheduler
- The sync is manual (triggered by an admin) -- there is no automatic background sync
- All sync operations are logged to the `emerald_sync_log` table for audit purposes

The integration is entirely optional. FleetScheduler works fully without it.

---

## Configuration

### Environment Variables

Add these to your `vehicle-scheduling-backend/.env` file:

```bash
# Emerald v6 API base URL (e.g., https://your-emerald-server.com)
EMERALD_API_URL=https://your-emerald-server.com

# Emerald API credentials (used for per-request authentication)
EMERALD_API_USER=your-emerald-username
EMERALD_API_PASSWORD=your-emerald-password

# Master switch: set to 'true' to enable sync endpoints
EMERALD_SYNC_ENABLED=false
```

All three credential variables (`EMERALD_API_URL`, `EMERALD_API_USER`, `EMERALD_API_PASSWORD`) must be set for the integration to work. If any are missing, API calls will throw an `EmeraldConnectionError`.

The `EMERALD_SYNC_ENABLED` flag controls whether the sync POST endpoints are active:
- When `false`: Sync endpoints (`POST /api/emerald/sync/*`) return `400 Bad Request`
- When `true`: Sync endpoints process normally
- The status check endpoint (`GET /api/emerald/status`) always works regardless of this flag

### Admin Settings Screen

Alternatively, Emerald connection settings can be configured via the Admin Settings screen in the Flutter app. Navigate to **Settings > Emerald Integration** to enter the API URL and credentials.

---

## API Connection Details

### How the Backend Connects to Emerald

The backend's `emeraldService.js` makes HTTP POST requests to Emerald's API endpoint:

```
POST {EMERALD_API_URL}/api.ews
Content-Type: application/x-www-form-urlencoded
```

Each request includes:

| Parameter        | Description                       |
|------------------|-----------------------------------|
| `login_user`     | From `EMERALD_API_USER` env var   |
| `login_password` | From `EMERALD_API_PASSWORD` env var |
| `action`         | Emerald API action name           |
| `format`         | Always `json`                     |
| (additional)     | Action-specific parameters        |

Authentication is per-request (no session tokens). The backend sends credentials with every API call.

### Timeouts and Error Handling

- HTTP timeout: 30 seconds per request
- On connection failure: `EmeraldConnectionError` is thrown and logged
- On Emerald API error (non-zero retcode): `EmeraldApiError` is thrown with the Emerald error message
- All errors are logged via Pino structured logging

---

## Available Sync Operations

All Emerald API endpoints require admin authentication (JWT) and admin role.

### 1. Test Connection

```
GET /api/emerald/status
Authorization: Bearer <admin-jwt-token>
```

Tests whether the backend can reach and authenticate with the Emerald API. Returns:

```json
{
  "success": true,
  "connected": true,
  "sync_enabled": true,
  "message": "Connected to Emerald API"
}
```

Use this to verify credentials are correct before attempting a sync.

### 2. Sync Customers

```
POST /api/emerald/sync/customers
Authorization: Bearer <admin-jwt-token>
```

Pulls customer data from Emerald and updates matching jobs in FleetScheduler:

- Fetches up to 1000 customers from Emerald
- For each customer, finds jobs in FleetScheduler with a matching `customer_name`
- Updates `customer_phone` and `customer_address` fields (only if the Emerald value is non-empty)
- Data is scoped to the admin's tenant

Response:

```json
{
  "success": true,
  "synced": 12,
  "message": "Synced 12 customer record(s) from Emerald"
}
```

### 3. Sync Incidents (Work Orders)

```
POST /api/emerald/sync/incidents
Authorization: Bearer <admin-jwt-token>
Content-Type: application/json
```

Optional request body for date filtering:

```json
{
  "date_from": "2026-01-01",
  "date_to": "2026-01-31"
}
```

Pulls incidents from Emerald and creates them as new jobs:

- Each Emerald incident gets a job number prefixed with `EMR-` (e.g., `EMR-12345`)
- Duplicate detection: if a job with the same `EMR-` prefixed number already exists, it is skipped
- New jobs are created with `current_status: 'pending'` and `job_type: 'installation'`
- Data is scoped to the admin's tenant

Response:

```json
{
  "success": true,
  "created": 8,
  "skipped": 3,
  "message": "Created 8 job(s) from Emerald incidents (3 skipped as duplicates)"
}
```

### 4. Search Customers (Typeahead)

```
GET /api/emerald/customers?search=Smith&limit=10
Authorization: Bearer <admin-jwt-token>
```

Proxies a customer search to the Emerald API. Used by the Flutter app for typeahead/autocomplete when creating jobs:

```json
{
  "success": true,
  "customers": [
    { "name": "John Smith", "phone": "+27821234567", "address": "123 Main St" }
  ]
}
```

---

## Data Mapping

### Customer Sync Mapping

| Emerald Field                       | FleetScheduler Field     |
|-------------------------------------|--------------------------|
| `name` or `customer_name`          | `jobs.customer_name` (match key) |
| `phone` or `contact_phone`         | `jobs.customer_phone`    |
| `address` or `street_address`      | `jobs.customer_address`  |

### Incident Sync Mapping

| Emerald Field                                | FleetScheduler Field          | Default              |
|----------------------------------------------|-------------------------------|----------------------|
| `id` or `incident_id` or `reference`        | `jobs.job_number` (as `EMR-{id}`) | `EMR-{timestamp}` |
| `customer_name` or `name`                    | `jobs.customer_name`          | `Unknown Customer`   |
| `customer_phone` or `phone`                  | `jobs.customer_phone`         | `null`               |
| `address` or `customer_address`              | `jobs.customer_address`       | (empty string)       |
| `description` or `notes` or `subject`        | `jobs.description`            | (empty string)       |
| `priority`                                    | `jobs.priority`               | `medium`             |
| `scheduled_date` or `date`                   | `jobs.scheduled_date`         | `null`               |
| (not mapped)                                  | `jobs.job_type`               | `installation`       |
| (not mapped)                                  | `jobs.current_status`         | `pending`            |

---

## Sync Log

Every sync operation (success or failure) is recorded in the `emerald_sync_log` table:

| Column           | Type         | Description                              |
|------------------|--------------|------------------------------------------|
| `id`             | INT          | Auto-increment primary key               |
| `sync_type`      | VARCHAR(50)  | `customers` or `incidents`               |
| `records_synced` | INT          | Number of records synced/created         |
| `status`         | ENUM         | `success` or `failed`                    |
| `error_message`  | TEXT         | Error details (null on success)          |
| `synced_by`      | INT          | User ID of the admin who triggered sync  |
| `tenant_id`      | INT          | Tenant scope                             |
| `created_at`     | TIMESTAMP    | When the sync was executed               |

The `emerald_sync_log` table is auto-created on server startup (idempotent `CREATE TABLE IF NOT EXISTS`).

### Querying Sync History

```sql
-- View recent sync operations
SELECT * FROM emerald_sync_log ORDER BY created_at DESC LIMIT 20;

-- View failed syncs
SELECT * FROM emerald_sync_log WHERE status = 'failed' ORDER BY created_at DESC;

-- View sync totals by type
SELECT sync_type, COUNT(*) as sync_count, SUM(records_synced) as total_records
FROM emerald_sync_log
WHERE status = 'success'
GROUP BY sync_type;
```

---

## Admin UI

The Flutter app includes an Emerald integration section accessible from the admin settings screen:

1. **Connection status** -- Shows whether the Emerald API is reachable and authenticated
2. **Sync customers** -- Button to trigger a customer data pull
3. **Sync incidents** -- Button to trigger a work order import (with optional date range filter)
4. **Sync history** -- View recent sync operations and results

---

## Troubleshooting

### "Emerald sync is disabled"

**Cause:** `EMERALD_SYNC_ENABLED` is not set to `true` in `.env`.

**Fix:** Set `EMERALD_SYNC_ENABLED=true` and restart the backend. The status check endpoint (`GET /api/emerald/status`) still works even when sync is disabled -- use it to verify credentials first.

### "EMERALD_API_URL is not configured"

**Cause:** The `EMERALD_API_URL` environment variable is empty or not set.

**Fix:** Add the full Emerald API base URL to `.env`:
```bash
EMERALD_API_URL=https://your-emerald-server.com
```

### "Emerald API credentials are not configured"

**Cause:** Either `EMERALD_API_USER` or `EMERALD_API_PASSWORD` is missing from `.env`.

**Fix:** Set both variables in `.env`.

### "Emerald API HTTP 401: Unauthorized"

**Cause:** The Emerald API credentials are incorrect.

**Fix:** Verify the username and password with your Emerald system administrator. Use the status check endpoint to test:
```bash
curl -H "Authorization: Bearer <admin-token>" http://localhost:3000/api/emerald/status
```

### "Emerald API connection failed"

**Cause:** The backend cannot reach the Emerald server (network issue, wrong URL, firewall).

**Fix:**
1. Verify the URL is correct and accessible from the backend server
2. Check firewall rules allow outbound HTTP/HTTPS to the Emerald server
3. Test connectivity: `curl -v <EMERALD_API_URL>/api.ews`

### Sync created 0 records

**Possible causes:**
- The Emerald API returned no data for the given filters
- All incidents were already imported (duplicate detection by job number)
- Customer names in Emerald don't match any existing job customer names

**Debug:** Check the `emerald_sync_log` table for details and check server logs for the full Emerald API response.
