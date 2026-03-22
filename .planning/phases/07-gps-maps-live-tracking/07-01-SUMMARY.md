---
phase: 07
plan: 01
subsystem: backend-gps
tags: [gps, socket.io, real-time, tracking, consent, cron, mysql]
dependency_graph:
  requires: []
  provides: [gps-backend-infrastructure, socket.io-server, gps-consent-api, driver-location-api]
  affects: [vehicle-scheduling-backend/src/server.js, vehicle-scheduling-backend/src/services/gpsService.js, vehicle-scheduling-backend/src/routes/gps.js, vehicle-scheduling-backend/src/services/cronService.js]
tech_stack:
  added: [socket.io@4.8.3]
  patterns: [in-memory-location-cache, socket.io-tenant-rooms, jwt-socket-auth, batch-db-flush, working-hours-enforcement]
key_files:
  created:
    - vehicle-scheduling-backend/src/services/gpsService.js
    - vehicle-scheduling-backend/src/routes/gps.js
  modified:
    - vehicle-scheduling-backend/src/server.js
    - vehicle-scheduling-backend/src/routes/index.js
    - vehicle-scheduling-backend/src/services/cronService.js
    - vehicle-scheduling-backend/package.json
decisions:
  - Socket.IO JWT auth in handshake headers — consistent with REST auth pattern, no separate auth flow needed
  - In-memory Map keyed by driverId — O(1) reads, evicts stale entries >5 min on read, preserves live positions after flush
  - Batch INSERT for location history flush — single query for all cached positions, minimal DB overhead
  - gps_consent UNIQUE KEY on user_id — prevents duplicate consent records, ON DUPLICATE KEY UPDATE for idempotent upsert
metrics:
  duration_minutes: 8
  tasks_completed: 2
  files_created: 2
  files_modified: 4
  completed_date: "2026-03-22"
---

# Phase 7 Plan 1: Backend GPS Infrastructure Summary

**One-liner:** Socket.IO GPS tracking backend with JWT-authenticated rooms, in-memory location cache, consent CRUD, working-hours enforcement, and 5-minute MySQL history flush.

## What Was Built

### gpsService.js
Core GPS service with:
- `init(io)` — wires Socket.IO server for broadcasting
- `updateLocation()` — writes to in-memory Map and emits `driver_location` event to `tracking:{tenantId}` room
- `getDriverLocations(tenantId)` — filters cache by tenant, evicts entries older than 5 minutes
- `isWithinWorkingHours(tenantId)` — queries tenant timezone from settings table, checks 6AM-8PM window via `Intl.DateTimeFormat`
- `flushLocationHistory()` — batch INSERT to `driver_location_history`, preserves live cache
- `getConsent()` / `setConsent()` — SELECT / INSERT ON DUPLICATE KEY UPDATE for `gps_consent` table

### GPS Routes (gps.js)
- `POST /api/gps/location` — validates lat/lng, checks working hours, checks consent, updates cache + broadcasts
- `GET /api/gps/drivers` — admin/scheduler only; scheduler additionally blocked if `scheduler_gps_visible=false` setting
- `GET /api/gps/consent` — returns current user's consent record
- `POST /api/gps/consent` — first-time consent grant (returns 201)
- `PUT /api/gps/consent` — enable/disable GPS tracking

### server.js Refactor
- Wrapped Express app in `http.createServer()` for Socket.IO attachment
- `new Server(httpServer, { cors: { origin: '*' } })` — matches existing CORS policy
- Socket.IO connection handler: JWT verification on connect, `join_tracking` event scopes client to tenant room
- GPS table migrations added to startup IIFE after notification tables
- `app.listen()` replaced with `httpServer.listen()` — `module.exports = app` preserved for test imports

### cronService.js Addition
- New `*/5 * * * *` cron calls `GpsService.flushLocationHistory()` — tiered storage pattern

### DB Tables Created on Startup
- `gps_consent` — per-user GPS consent with `UNIQUE KEY uk_gps_consent_user (user_id)`
- `driver_location_history` — timestamped location history with tenant/driver indexes

## Deviations from Plan

None — plan executed exactly as written.

## Verification Results

All plan verification checks passed:
- `node -e "require('./src/server')"` loads without errors, GpsService initializes with Socket.IO
- `grep -c 'httpServer.listen' src/server.js` → 1
- `grep -c 'gps_consent' src/server.js` → 3
- `grep -c 'flushLocationHistory' src/services/cronService.js` → 1
- `grep -c "router.use.*gps" src/routes/index.js` → 1
- gpsService exports: init, updateLocation, getDriverLocations, isWithinWorkingHours, flushLocationHistory, getConsent, setConsent

## Commits

- `102d692` — feat(07-01): GPS service, routes, and cron flush
- `20b9d71` — feat(07-01): refactor server.js for Socket.IO and GPS DB migration

## Known Stubs

None — all data flows are wired. GPS location POSTs update live cache and broadcast immediately. Flush cron inserts to DB. Consent records are read from DB on every location POST.

## Self-Check: PASSED
