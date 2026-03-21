---
phase: 01-foundation-security-hardening
plan: 03
subsystem: backend-security
tags: [security, middleware, rate-limiting, validation, jwt, helmet]
dependency_graph:
  requires: [01-01]
  provides: [rate-limiter-middleware, validate-middleware, tenant-id-jwt, helmet-headers, jwt-startup-guard]
  affects: [01-04, all-api-routes]
tech_stack:
  added: [helmet, express-rate-limit, express-validator, pino, pino-http]
  patterns: [fail-fast-startup-guard, scoped-helmet, rate-limiter-middleware, express-validator-chain]
key_files:
  created:
    - vehicle-scheduling-backend/src/middleware/rateLimiter.js
    - vehicle-scheduling-backend/src/middleware/validate.js
  modified:
    - vehicle-scheduling-backend/src/server.js
    - vehicle-scheduling-backend/src/middleware/authMiddleware.js
    - vehicle-scheduling-backend/src/routes/jobs.js
    - vehicle-scheduling-backend/src/routes/vehicles.js
    - vehicle-scheduling-backend/src/routes/users.js
    - vehicle-scheduling-backend/package.json
decisions:
  - "helmet() scoped to /api only — Swagger UI uses inline scripts which helmet CSP would block"
  - "loginLimiter uses skipSuccessfulRequests: true — offices share NAT/proxy IPs, only failed attempts count"
  - "tenant_id added to JWT payload at login — downstream phases need it for tenant-scoped queries"
  - "JWT_SECRET startup guard placed before any require() calls — ensures no fallback runs even transiently"
metrics:
  duration_minutes: 3
  completed_date: "2026-03-21"
  tasks_completed: 3
  tasks_total: 3
  files_created: 2
  files_modified: 6
---

# Phase 01 Plan 03: Security Middleware Hardening Summary

**One-liner:** Brute-force protection (rate limiting), production JWT startup guard, helmet security headers on /api only, express-validator input validation on all mutating routes, and tenant_id wired into JWT payload.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Install packages and create middleware files | 3efc1c9 | package.json, rateLimiter.js, validate.js |
| 2 | Harden server.js and authMiddleware | ad2d16d | server.js, authMiddleware.js |
| 3 | Add express-validator chains to mutating routes | 34dab17 | jobs.js, vehicles.js, users.js |

## What Was Built

### New Middleware Files

**`src/middleware/rateLimiter.js`**
- `apiLimiter`: 200 requests/IP/15min on all `/api` routes
- `loginLimiter`: 10 attempts/IP/15min on the login endpoint only, with `skipSuccessfulRequests: true` (shared NAT protection)

**`src/middleware/validate.js`**
- Reads `validationResult(req)` from express-validator
- Returns `HTTP 400` with field-level error array if any validation fails
- Calls `next()` when all validations pass

### server.js Changes

- **JWT startup guard**: `process.exit(1)` with FATAL message if `JWT_SECRET` is not set — fires before any require() or route registration
- **Fallback secret removed**: `const JWT_SECRET = process.env.JWT_SECRET` (no `||` fallback)
- **helmet on /api only**: `app.use('/api', helmet())` — Swagger UI at `/swagger` remains unaffected by CSP headers
- **apiLimiter on /api**: `app.use('/api', apiLimiter)` — covers all API routes
- **loginLimiter on login**: `app.post('/api/auth/login', loginLimiter, ...)` — stricter limit
- **tenant_id in JWT**: Login SELECT now fetches `tenant_id` from users table; `jwt.sign()` includes `tenant_id: user.tenant_id` in payload

### authMiddleware.js Changes

- Fallback secret removed: `const JWT_SECRET = process.env.JWT_SECRET` (startup guard in server.js guarantees it is always set)

### Route Validation (FOUND-06)

**jobs.js — `createJobValidation`:**
- `job_type`: must be `installation|delivery|miscellaneous`
- `customer_name`: 2-100 characters
- `customer_address`: required, non-empty
- `scheduled_date`: YYYY-MM-DD format
- `scheduled_time_start/end`: HH:MM or HH:MM:SS format
- `estimated_duration_minutes`: integer 1-1440
- `priority`: optional, must be `low|normal|high|urgent`
- `destination_lat/lng`: optional, valid coordinate ranges

**jobs.js — `updateJobValidation`:** all fields optional, same rules

**vehicles.js — `createVehicleValidation`:** `name` (2-100 chars), `license_plate` (required), `type` (optional, max 50), `capacity` (optional positive int)

**vehicles.js — `updateVehicleValidation`:** all optional; `status` must be `available|assigned|maintenance|inactive`

**users.js — `createUserValidation`:** `username` (3-50), `email` (valid email), `password` (min 8 chars), `role` (admin|scheduler|technician|dispatcher|driver), `full_name` (optional, max 100)

**users.js — `updateUserValidation`:** all optional, same rules for email and role

## Verification Results

| Check | Result |
|-------|--------|
| `JWT_SECRET` unset → FATAL + exit code 1 | PASS |
| Hardcoded fallback removed from server.js | PASS |
| Hardcoded fallback removed from authMiddleware.js | PASS |
| `helmet()` applied to `/api` only | PASS |
| `apiLimiter` applied to `/api` routes | PASS |
| `loginLimiter` applied to login POST handler | PASS |
| `tenant_id` in `jwt.sign()` payload | PASS |
| `apiLimiter` and `loginLimiter` export as functions | PASS |
| `validate` middleware module loads correctly | PASS |
| All three route files load without error | PASS |
| `express-validator` imported in all 3 route files | PASS |
| `estimated_duration_minutes` bounded 1-1440 | PASS |
| `isEmail` validation on users route | PASS |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — all validation chains are fully wired to their respective routes.

## Self-Check: PASSED

Files created/exist:
- FOUND: `vehicle-scheduling-backend/src/middleware/rateLimiter.js`
- FOUND: `vehicle-scheduling-backend/src/middleware/validate.js`

Commits exist:
- FOUND: 3efc1c9 — Task 1
- FOUND: ad2d16d — Task 2
- FOUND: 34dab17 — Task 3
