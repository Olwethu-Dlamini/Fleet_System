# Phase 7: GPS, Maps & Live Tracking - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase adds Google Maps integration with directions/ETA on job views, live driver tracking via HTTP location POSTs with Socket.IO broadcasting, GPS consent compliance (POPIA/GDPR), admin controls for scheduler GPS visibility, and time-bounded tracking during working hours.

</domain>

<decisions>
## Implementation Decisions

### Maps & Directions
- Google Maps API key configured via .env (GOOGLE_MAPS_API_KEY) shared backend + Flutter
- Embedded Google Map with polyline route + text ETA/distance on job detail screen
- Directions always visible on job detail for jobs with addresses
- google_maps_flutter package for Flutter map rendering

### Live Tracking & Storage
- In-memory Map for live position cache (v1, single Docker instance)
- Driver location POST every 30 seconds during active jobs
- MySQL history flush every 5 minutes (batch insert from in-memory cache)
- Working hours: 6:00 AM to 8:00 PM tenant timezone — tracking only active during these hours

### Compliance & Admin Controls
- GPS consent screen shown on first app launch after login for driver/technician roles — one-time, stored in DB
- Settings toggle for consent revocation — user can disable GPS anytime, stops location POSTs
- Admin GPS visibility toggle: per-scheduler, reuses existing settings table from Phase 2
- Location snapshot on completion: reuse Phase 3 GPS capture (already in job_completions) — GPS-05 already satisfied

### Claude's Discretion
- Socket.IO server configuration and room structure
- GPS history table schema
- Google Directions API response parsing
- Flutter map widget composition and marker styling
- In-memory cache data structure details

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/config/constants.js` — status enums, role checks
- `src/services/cronService.js` — cron scheduling for GPS flush
- `lib/services/fcm_service.dart` — background service pattern
- `lib/screens/jobs/job_detail_screen.dart` — GPS capture pattern from Phase 3
- geolocator package already installed (Phase 3)
- Settings table from Phase 2 for admin toggles

### Established Patterns
- Backend: pino logging, tenant_id scoping, verifyToken middleware
- Flutter: Provider + ChangeNotifier, permission gating
- Database: idempotent migrations, indexes on tenant_id

### Integration Points
- Job detail screen: add map widget with directions
- Server.js: Socket.IO attachment to Express HTTP server
- Cron service: add GPS history flush job
- Settings API: reuse for GPS visibility toggle

</code_context>

<specifics>
## Specific Ideas

- Map should show route polyline from driver's current location to job address
- Live tracking map should show driver markers with last-update timestamp
- Consent screen should explain what data is collected, why, and how to revoke

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
