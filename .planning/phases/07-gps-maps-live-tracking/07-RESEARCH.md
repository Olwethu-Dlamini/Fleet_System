# Phase 7: GPS, Maps & Live Tracking - Research

**Researched:** 2026-03-21
**Domain:** Google Maps Flutter, Google Routes API, Socket.IO real-time tracking, GPS consent (POPIA/GDPR)
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Maps & Directions**
- Google Maps API key configured via .env (GOOGLE_MAPS_API_KEY) shared backend + Flutter
- Embedded Google Map with polyline route + text ETA/distance on job detail screen
- Directions always visible on job detail for jobs with addresses
- google_maps_flutter package for Flutter map rendering

**Live Tracking & Storage**
- In-memory Map for live position cache (v1, single Docker instance)
- Driver location POST every 30 seconds during active jobs
- MySQL history flush every 5 minutes (batch insert from in-memory cache)
- Working hours: 6:00 AM to 8:00 PM tenant timezone — tracking only active during these hours

**Compliance & Admin Controls**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| GPS-01 | Directions + estimated travel time displayed when creating/viewing a job (Google Directions API) | Google Routes API v2 via backend proxy; flutter_polyline_points 3.1.0 decodes polyline; ETA from `duration` field |
| GPS-02 | Live driver tracking — drivers POST location every 15-30 seconds via HTTP | New `/api/gps/location` POST endpoint; in-memory Map cache; 30-second Flutter Timer |
| GPS-03 | Real-time driver positions on map for admin/scheduler (Socket.IO broadcast) | socket.io 4.8.3 attached to HTTP server; socket_io_client 3.1.4 in Flutter; `tracking` room pattern |
| GPS-04 | Admin toggle to control scheduler GPS visibility | `scheduler_gps_visible` key already seeded in settings table from Phase 2; reuse SettingsService |
| GPS-05 | Location snapshot on job completion (audit trail) | Already implemented in Phase 3 (job_completions table). No new work needed. |
| GPS-06 | GPS consent screen on driver app (POPIA/GDPR compliance) | New `gps_consent` table; consent screen shown on first login post-upgrade for technician/driver roles |
| GPS-07 | Time-bounded tracking — only during working hours / active jobs | Working-hours check in Flutter before each POST; backend validates server-side too |
| GPS-08 | Two-tier GPS storage — in-memory/Redis for live, periodic MySQL flush for history | In-memory Map (v1); new `driver_location_history` table; 5-minute cron flush |
</phase_requirements>

---

## Summary

Phase 7 adds full GPS and maps capability: embedded route maps with directions on job detail, live driver tracking broadcast via Socket.IO, GPS consent compliance, and tiered storage. The codebase already has significant groundwork — `google_maps_flutter` and `geolocator` are installed, the Android manifest has location permissions, the iOS Info.plist has location usage descriptions, `destination_lat`/`destination_lng` are already in the `jobs` table, and `job_completions` has the Phase 3 GPS snapshot (GPS-05 is pre-satisfied).

The two new backend infrastructure items are: (1) Socket.IO must be added to `package.json` and attached to the `http.Server` — currently `app.listen()` is called directly but Socket.IO requires passing to `http.createServer(app)` first. (2) A `driver_location_history` table and a `gps_consent` table need to be created via idempotent startup migrations. The 5-minute MySQL flush is a new cron job added to `cronService.js` following the existing pattern.

**Primary recommendation:** Add `socket.io` ^4.8.3 to backend, refactor `server.js` to use `http.createServer(app)`, implement the GPS location POST + Socket.IO broadcast service, add `socket_io_client` ^3.1.4 and `flutter_polyline_points` ^3.1.0 to Flutter, and wire everything together through the established Provider/ChangeNotifier pattern.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| socket.io (npm) | ^4.8.3 | Real-time bidirectional broadcast on backend | Current stable (verified npm registry 2026-03-21); matches socket_io_client 3.x protocol |
| socket_io_client (Dart) | ^3.1.4 | Flutter Socket.IO client | Latest version on pub.dev (published ~2 months ago); compatible with socket.io 4.x server |
| google_maps_flutter | ^2.10.0 | Map rendering in Flutter | Already in pubspec.yaml; Google-maintained official plugin |
| flutter_polyline_points | ^3.1.0 | Decode Routes API encoded polyline + call Routes API | Supports Google Routes API v2 natively via `getRouteBetweenCoordinatesV2`; avoids deprecated Directions API |
| @googlemaps/google-maps-services-js | ^3.4.2 | Google Routes API calls from Node.js backend | Official Google client; handles auth + request formatting; verified npm (3.4.2) |
| geolocator (Dart) | ^13.0.2 | Device GPS position acquisition | Already in pubspec.yaml from Phase 3; no reinstall needed |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| node:http (built-in) | Node.js built-in | Create HTTP server to attach Socket.IO | Required — Socket.IO wraps http.Server, not Express app |
| shared_preferences (Dart) | ^2.5.4 | Cache consent flag locally | Already in pubspec.yaml; use to avoid re-checking DB on every app launch |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @googlemaps/google-maps-services-js | Raw `node-fetch` / `axios` to Routes API | Google client handles encoding, retries, type safety; custom fetch is more work for no gain |
| flutter_polyline_points | Manual Routes API call + polyline decoder | flutter_polyline_points 3.x handles both; custom implementation is a hand-rolled solution |
| In-memory Map | Redis | Redis adds a new infrastructure dependency; in-memory is correct for v1 single-Docker-instance |

**Installation (backend):**
```bash
cd vehicle-scheduling-backend && npm install socket.io @googlemaps/google-maps-services-js
```

**Installation (Flutter):**
```bash
cd vehicle_scheduling_app && flutter pub add socket_io_client flutter_polyline_points
```

---

## Architecture Patterns

### Recommended Project Structure

New files to create:

```
vehicle-scheduling-backend/src/
├── routes/
│   └── gps.js                     # POST /api/gps/location, GET /api/gps/drivers
├── services/
│   └── gpsService.js              # In-memory cache, history flush, Socket.IO emit
└── migrations/
    └── 03-gps-maps.sql            # gps_consent + driver_location_history tables

vehicle_scheduling_app/lib/
├── providers/
│   └── gps_provider.dart          # GpsProvider: ChangeNotifier for tracking state
├── services/
│   └── gps_service.dart           # location POST, Socket.IO connect/disconnect
├── screens/
│   └── gps/
│       ├── consent_screen.dart    # One-time GPS consent screen
│       └── tracking_map_screen.dart # Admin/scheduler live tracking map
└── widgets/
    └── job_map_widget.dart        # Embedded map + polyline for job detail screen
```

### Pattern 1: Socket.IO Server Attachment to Express

**What:** Socket.IO requires an `http.Server` instance, not a raw Express `app`. The current `server.js` calls `app.listen()` directly which creates an internal http.Server that Socket.IO cannot access. Must wrap before `listen`.

**When to use:** Any time Socket.IO is added to an existing Express server.

**Example:**
```javascript
// Source: https://socket.io/docs/v4/tutorial/step-3
const { createServer } = require('node:http');
const { Server } = require('socket.io');

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*',   // tighten per environment
    methods: ['GET', 'POST'],
  },
});

// Replace: app.listen(PORT, ...)
// With:
httpServer.listen(PORT, () => {
  logger.info({ port: PORT }, 'FleetScheduler API listening');
});
```

The `io` instance must be accessible in `gpsService.js`. Pass it as a module export or use a singleton initializer pattern (e.g., `gpsService.init(io)` called from server.js after Socket.IO setup).

### Pattern 2: GPS Location POST + Socket.IO Broadcast

**What:** Driver POSTs current coordinates to backend; backend updates in-memory cache and broadcasts to `tracking` room.

**When to use:** Every 30-second timer tick on driver's device.

**Example (backend `gpsService.js`):**
```javascript
// In-memory cache: Map<driverId, { lat, lng, accuracy_m, updated_at, tenant_id }>
const locationCache = new Map();
let _io = null;

function init(io) { _io = io; }

function updateLocation({ driverId, tenantId, lat, lng, accuracyM }) {
  locationCache.set(driverId, { lat, lng, accuracy_m: accuracyM, updated_at: Date.now(), tenant_id: tenantId });
  // Broadcast to tenant-scoped tracking room
  if (_io) {
    _io.to(`tracking:${tenantId}`).emit('driver_location', {
      driver_id: driverId, lat, lng, accuracy_m: accuracyM, updated_at: Date.now(),
    });
  }
}

function getDriverLocations(tenantId) {
  const result = [];
  for (const [driverId, pos] of locationCache.entries()) {
    if (pos.tenant_id === tenantId) result.push({ driver_id: driverId, ...pos });
  }
  return result;
}
```

### Pattern 3: Socket.IO Room Structure

**What:** Tenant-scoped rooms to prevent cross-tenant data leakage.

**Room naming:**
- `tracking:{tenantId}` — admin/scheduler clients subscribe to receive driver location updates
- Drivers never join this room; they only POST via HTTP

**Flutter client joins room:**
```dart
// Source: socket_io_client 3.1.4 - pub.dev
import 'package:socket_io_client/socket_io_client.dart' as IO;

final socket = IO.io(AppConfig.wsUrl, IO.OptionBuilder()
  .setTransports(['websocket'])
  .setExtraHeaders({'Authorization': 'Bearer $token'})
  .build());

socket.onConnect((_) {
  socket.emit('join_tracking', {'tenant_id': tenantId});
});

socket.on('driver_location', (data) {
  // update GpsProvider markers
});
```

### Pattern 4: Google Routes API via Backend Proxy

**What:** Directions are fetched from the backend (not directly from Flutter) to keep the API key server-side.

**Endpoint:** `GET /api/gps/directions?job_id=X` — backend fetches from Routes API, returns `{ polyline, duration_text, distance_text }`.

**Backend Routes API call:**
```javascript
// Source: @googlemaps/google-maps-services-js official docs
const { Client } = require('@googlemaps/google-maps-services-js');
const client = new Client({});

async function getDirections(originLat, originLng, destLat, destLng) {
  // Using Routes API v2 (POST https://routes.googleapis.com/directions/v2:computeRoutes)
  const response = await fetch('https://routes.googleapis.com/directions/v2:computeRoutes', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': process.env.GOOGLE_MAPS_API_KEY,
      'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
    },
    body: JSON.stringify({
      origin: { location: { latLng: { latitude: originLat, longitude: originLng } } },
      destination: { location: { latLng: { latitude: destLat, longitude: destLng } } },
      travelMode: 'DRIVE',
    }),
  });
  const json = await response.json();
  const route = json.routes?.[0];
  if (!route) throw new Error('No route found');
  return {
    encoded_polyline: route.polyline.encodedPolyline,
    duration_text: route.duration,        // e.g. "1250s"
    distance_meters: route.distanceMeters,
  };
}
```

**Flutter decodes + displays:**
```dart
// Source: flutter_polyline_points 3.1.0 - pub.dev
// The backend returns encoded_polyline string
// Flutter decodes client-side for efficiency
final points = PolylinePoints().decodePolyline(encodedPolyline);
final polylineCoordinates = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

// Add to GoogleMap widget
Set<Polyline> _polylines = {
  Polyline(
    polylineId: const PolylineId('route'),
    points: polylineCoordinates,
    color: Colors.blue,
    width: 4,
  ),
};
```

### Pattern 5: GPS Consent Screen (POPIA/GDPR)

**What:** One-time consent screen for technician/driver roles after first login. Stored in `gps_consent` table (DB-authoritative) with local SharedPreferences cache.

**Check flow in Flutter:**
1. After login, if `role == technician || role == driver`: check `SharedPreferences.getBool('gps_consent_given')`
2. If not set: call `GET /api/gps/consent` → backend checks `gps_consent` table
3. If no consent record: navigate to `ConsentScreen` before main app shell
4. Consent screen has "I Agree" (stores in DB + SharedPreferences) and "Decline" (sets `gps_enabled = false`, no tracking)

**Consent revocation:** Settings screen toggle calls `PUT /api/gps/consent` with `{ enabled: false }`. Flutter stops Timer-based POSTs when `gpsEnabled == false`.

**POPIA requirements (MEDIUM confidence):**
- Consent must be voluntary, specific, and informed
- Must state: what data (location coordinates), why (dispatch optimization), when (working hours only), how to revoke
- Records of consent must be maintained (hence storing in DB, not just device)

### Pattern 6: 5-Minute History Flush Cron

**What:** Drain in-memory cache to `driver_location_history` table every 5 minutes.

**Add to `cronService.js`:**
```javascript
// GPS-08: Flush in-memory location cache to MySQL every 5 minutes
cron.schedule('*/5 * * * *', async () => {
  try {
    await GpsService.flushLocationHistory();
  } catch (err) {
    logger.error({ err }, 'GPS history flush error');
  }
});
```

### Anti-Patterns to Avoid

- **Socket.IO directly on Express app:** `new Server(app)` does not work correctly; always use `new Server(httpServer)` where `httpServer = http.createServer(app)`.
- **Calling Google Maps API from Flutter directly:** Exposes API key in client binary. Always proxy through backend.
- **Storing consent only in SharedPreferences:** App reinstall loses consent record. DB is authoritative; SharedPreferences is a cache layer only.
- **Emitting to all sockets without tenant scoping:** Multi-tenant data leak. Always use `tracking:{tenantId}` rooms.
- **Flushing every location update to MySQL:** High write load. In-memory cache + 5-minute batch is the correct v1 pattern.
- **Background location on iOS without always-on permission:** iOS kills foreground-only location after screen lock. For this v1, tracking is only required during active job hours with app in foreground; NSLocationWhenInUseUsageDescription (already in Info.plist) is sufficient.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Polyline decoding | Custom encoded polyline parser | flutter_polyline_points 3.1.0 | Google's encoding is complex (variable-length signed integers); hand-rolling is error-prone |
| Routes API HTTP client | Raw fetch with manual header construction | @googlemaps/google-maps-services-js | Handles auth headers, field masks, error types |
| Socket.IO protocol | Custom WebSocket server | socket.io 4.8.3 | Reconnection, rooms, CORS, transport fallback all built in |
| Working hours timezone check | Custom UTC offset math | Use `tenant_timezone` field (Phase 1) + `Intl.DateTimeFormat` or `moment-timezone` | DST edge cases; tenant_timezone is already stored |

**Key insight:** The polyline encoding algorithm and timezone-aware working-hours checks are well-known traps for hand-rolled solutions. Both have battle-tested library implementations that handle edge cases.

---

## Database Schema (New Tables)

### `gps_consent` table
```sql
-- GPS-06: Track driver GPS consent per user
CREATE TABLE IF NOT EXISTS gps_consent (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenant_id   INT UNSIGNED NOT NULL,
  user_id     INT UNSIGNED NOT NULL UNIQUE,
  gps_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  consented_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_gps_consent_tenant_user (tenant_id, user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

### `driver_location_history` table
```sql
-- GPS-08: Periodic flush of in-memory location cache
CREATE TABLE IF NOT EXISTS driver_location_history (
  id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
  tenant_id   INT UNSIGNED NOT NULL,
  driver_id   INT UNSIGNED NOT NULL,
  lat         DOUBLE NOT NULL,
  lng         DOUBLE NOT NULL,
  accuracy_m  FLOAT DEFAULT NULL,
  recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_dlh_tenant_driver (tenant_id, driver_id),
  KEY idx_dlh_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
```

Both tables follow established project conventions: `ADD COLUMN IF NOT EXISTS` / `CREATE TABLE IF NOT EXISTS` for idempotent startup migration, `tenant_id` on all tables, indexes on `tenant_id`.

---

## Common Pitfalls

### Pitfall 1: Socket.IO + Express — Must Use `http.createServer(app)`
**What goes wrong:** `new Server(app)` silently creates a non-functioning Socket.IO instance; connections time out or fail CORS.
**Why it happens:** Socket.IO wraps a Node.js `http.Server`, not an Express `Application`. Express `app` is a request handler function, not a server.
**How to avoid:** In `server.js`, replace `const server = app.listen(...)` with `const httpServer = http.createServer(app); const io = new Server(httpServer); httpServer.listen(...)`.
**Warning signs:** Socket.IO `connect` event never fires in client; 400/404 on `/socket.io/` path.

### Pitfall 2: Flutter Socket.IO — Must Force WebSocket Transport
**What goes wrong:** Default socket_io_client tries XHR polling first (not available in Flutter non-web), causing connection failures or silent fallbacks.
**Why it happens:** The Dart socket_io_client was ported from JavaScript; browser polling transport doesn't work in native Flutter runtime.
**How to avoid:** Always set `setTransports(['websocket'])` in the `OptionBuilder`.
**Warning signs:** Slow connect, `connect_error` events, or connection timeout on emulator even with correct URL.

### Pitfall 3: Google Maps API Key Missing on Android
**What goes wrong:** Map renders blank/grey with "For Development Purposes Only" watermark or no map at all.
**Why it happens:** The API key in `AndroidManifest.xml` must match the key enabled for "Maps SDK for Android" in Google Cloud Console.
**How to avoid:** The key `YOUR_GOOGLE_MAPS_API_KEY` is already in `AndroidManifest.xml`. Backend needs `GOOGLE_MAPS_API_KEY` in `.env` with "Routes API" enabled separately. Verify both are enabled in GCP Console.
**Warning signs:** Map tile loading errors in logcat; Routes API returning 403.

### Pitfall 4: iOS Location — `NSLocationWhenInUseUsageDescription` Already Present
**What goes wrong:** Developers add duplicate keys or wrong keys for background location.
**Why it happens:** Confusion between foreground-only and always-on location.
**How to avoid:** `NSLocationWhenInUseUsageDescription` is already in `Info.plist` from Phase 3. For v1 (foreground-only during active hours), this is sufficient. Do NOT add `NSLocationAlwaysAndWhenInUseUsageDescription` unless background tracking is needed (it's already present too — acceptable, but foreground is enough for this use case).
**Warning signs:** App crashes on first location request with `NSInternalInconsistencyException`.

### Pitfall 5: GPS-05 Already Satisfied — Don't Duplicate
**What goes wrong:** Phase 7 plan re-implements completion GPS capture.
**Why it happens:** GPS-05 is listed in requirements without noting it was implemented in Phase 3.
**How to avoid:** `job_completions` table with `lat, lng, accuracy_m, gps_status` already exists and is populated by `completeJobWithGps()` in `JobService`. GPS-05 is done. Plan should note this and skip.

### Pitfall 6: In-Memory Cache Leaks Stale Positions
**What goes wrong:** Drivers who stopped tracking still appear on map with old positions.
**Why it happens:** In-memory Map never evicts; positions stay indefinitely.
**How to avoid:** Include `updated_at` in cache entry. On `getDriverLocations()`, filter out entries older than 5 minutes (2x the 30-second POST interval with generous buffer). On map, show "last seen X minutes ago" timestamp in marker info window.

### Pitfall 7: Working Hours Check Must Use Tenant Timezone
**What goes wrong:** UTC-based check silently stops tracking at wrong wall-clock time for South African tenants.
**Why it happens:** Backend runs UTC (`TZ=UTC` Docker setting from Phase 1). Simple `new Date().getHours()` is UTC.
**How to avoid:** Load `tenant_timezone` setting (already in `users` table / tenant config). Use `Intl.DateTimeFormat` with `timeZone` option or `moment-timezone` for the 6AM–8PM check on both backend (location POST endpoint) and Flutter (Timer start/stop logic).

---

## Existing Assets — What's Already Done

| Asset | Location | Phase | Status |
|-------|----------|-------|--------|
| `google_maps_flutter` in pubspec | `pubspec.yaml` line 42 | 3/pre | Already installed |
| `geolocator` in pubspec | `pubspec.yaml` line 43 | 3 | Already installed |
| Android location permissions | `AndroidManifest.xml` | 3 | Already present |
| iOS location usage strings | `Info.plist` | 3 | Already present |
| Android Maps API key | `AndroidManifest.xml` meta-data | Pre-phase | Already configured |
| `destination_lat/lng` on jobs table | `vehicle_scheduling2.sql` | Pre-phase | Already in schema |
| `job_completions` with GPS fields | `vehicle_scheduling2.sql` | 3 | GPS-05 satisfied |
| `scheduler_gps_visible` settings seed | `02-user-vehicle-scheduler.sql` | 2 | Already seeded |
| `SettingsService.dart` | `lib/services/settings_service.dart` | 2 | Reusable for GPS-04 |
| `cronService.js` | `src/services/cronService.js` | 3/5 | Extend for GPS flush |
| `shared_preferences` in pubspec | `pubspec.yaml` | 1 | Available for consent cache |

---

## Code Examples

### Flutter: Tracking Map with Live Driver Markers
```dart
// Source: google_maps_flutter official docs + socket_io_client 3.1.4
class TrackingMapScreen extends StatefulWidget { ... }

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  final Map<MarkerId, Marker> _driverMarkers = {};
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    _socket = IO.io(AppConfig.wsUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .setExtraHeaders({'Authorization': 'Bearer ${AuthService.token}'})
      .build());

    _socket.onConnect((_) {
      _socket.emit('join_tracking', {'tenant_id': currentUser.tenantId});
    });

    _socket.on('driver_location', (data) {
      setState(() {
        final markerId = MarkerId('driver_${data['driver_id']}');
        _driverMarkers[markerId] = Marker(
          markerId: markerId,
          position: LatLng(data['lat'], data['lng']),
          infoWindow: InfoWindow(
            title: data['driver_name'] ?? 'Driver ${data['driver_id']}',
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }
}
```

### Flutter: 30-Second Location POST
```dart
// Source: geolocator 13.0.2 + http 1.1.0 patterns
Timer? _locationTimer;

void startTracking() {
  _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
    if (!_isWithinWorkingHours()) return;
    if (!_gpsConsentEnabled) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      await _gpsService.postLocation(lat: pos.latitude, lng: pos.longitude, accuracyM: pos.accuracy);
    } catch (e) {
      // Non-fatal — log and continue
    }
  });
}

bool _isWithinWorkingHours() {
  final now = DateTime.now(); // Flutter uses device local time — matches driver's timezone
  return now.hour >= 6 && now.hour < 20;
}
```

### Backend: Socket.IO Room Join with Auth
```javascript
// Source: socket.io 4.8.3 official docs
io.on('connection', (socket) => {
  const token = socket.handshake.headers.authorization?.replace('Bearer ', '');
  if (!token) { socket.disconnect(); return; }

  try {
    const user = jwt.verify(token, process.env.JWT_SECRET);
    socket.userId = user.id;
    socket.tenantId = user.tenant_id;
    socket.role = user.role;
  } catch {
    socket.disconnect();
    return;
  }

  socket.on('join_tracking', (data) => {
    // Only admin/scheduler can view tracking
    if (['admin', 'scheduler'].includes(socket.role)) {
      socket.join(`tracking:${socket.tenantId}`);
    }
  });
});
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Google Directions API (REST v1) | Google Routes API v2 (`/directions/v2:computeRoutes`) | 2022 (GA 2023) | Routes API is the successor; Directions API still works but Routes API is the recommended path |
| XHR polling transport in socket_io_client | WebSocket transport via `setTransports(['websocket'])` | socket_io_client 2.x+ | Flutter non-web must force WebSocket; polling doesn't work in Dart runtime |
| socket_io_client 2.x | socket_io_client 3.x (3.1.4) | 2024 | Protocol compatibility with socket.io 4.x server; use matching major versions |

**Deprecated/outdated:**
- Google Directions API (legacy): Still functional but Routes API is the preferred path for new implementations. `flutter_polyline_points` 3.x supports Routes API natively.
- socket_io_client 1.x: Protocol version mismatch with socket.io 4.x; do not mix.

---

## Open Questions

1. **GOOGLE_MAPS_API_KEY already in AndroidManifest.xml as hardcoded value**
   - What we know: The key `YOUR_GOOGLE_MAPS_API_KEY` is hardcoded in `android/app/src/main/AndroidManifest.xml`. The CONTEXT.md decision says to use `.env` (GOOGLE_MAPS_API_KEY) for the backend.
   - What's unclear: Whether this same key is enabled for "Routes API" in Google Cloud Console (not just Maps SDK for Android). The Flutter key and backend key can be different; both need to be active.
   - Recommendation: The plan should include a verification task — confirm Routes API is enabled for the key used by the backend. The Flutter manifest key handles map display; the backend key handles Routes API calls. They can be the same key as long as both APIs are enabled in GCP.

2. **Consent UI storage — DB table vs. settings table**
   - What we know: CONTEXT.md says "stored in DB". Settings table already exists but is per-tenant, not per-user.
   - What's unclear: Whether the user intended to reuse `settings` table or create a separate `gps_consent` table.
   - Recommendation: Use a dedicated `gps_consent` table (per-user, not per-tenant). The settings table uses `(tenant_id, setting_key)` unique key — it cannot store per-user values. GPS consent is a per-user record.

3. **iOS background tracking during lock screen**
   - What we know: `NSLocationWhenInUseUsageDescription` is in Info.plist. v1 tracks only during working hours.
   - What's unclear: Whether drivers are expected to keep the phone unlocked while driving.
   - Recommendation: Treat as foreground-only for v1. If the screen locks, iOS will stop location updates. This is acceptable for Phase 7. Document in plan as a known limitation; background location is a v2 enhancement.

---

## Validation Architecture

> `workflow.nyquist_validation` not set in `.planning/config.json` — treating as enabled.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Jest 30.3.0 (backend) |
| Config file | none — see package.json scripts |
| Quick run command | `cd vehicle-scheduling-backend && npm test -- --testPathPattern=tests/unit/gps` |
| Full suite command | `cd vehicle-scheduling-backend && npm test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| GPS-01 | Backend returns directions payload from Routes API | unit (mock fetch) | `npm test -- --testPathPattern=gps` | ❌ Wave 0 |
| GPS-02 | POST /api/gps/location updates in-memory cache | unit | `npm test -- --testPathPattern=gps` | ❌ Wave 0 |
| GPS-03 | Socket.IO emits `driver_location` to `tracking:{tenantId}` room | unit (mock io) | `npm test -- --testPathPattern=gps` | ❌ Wave 0 |
| GPS-04 | Admin toggle `scheduler_gps_visible` — already covered by settings tests | integration | `npm test -- --testPathPattern=settings` | ❌ Wave 0 |
| GPS-05 | Job completion GPS capture — ALREADY SATISFIED (Phase 3) | — | — | ✅ Existing |
| GPS-06 | GET /api/gps/consent returns user's consent record | integration (accepts 401) | `npm test -- --testPathPattern=gps` | ❌ Wave 0 |
| GPS-07 | Working hours check blocks location POST outside 6AM–8PM | unit | `npm test -- --testPathPattern=gps` | ❌ Wave 0 |
| GPS-08 | flushLocationHistory writes cache entries to DB | unit (mock db) | `npm test -- --testPathPattern=gps` | ❌ Wave 0 |

### Wave 0 Gaps
- [ ] `tests/unit/gps.test.js` — covers GPS-01 through GPS-08 backend logic
- [ ] Mock for `@googlemaps/google-maps-services-js` fetch call
- [ ] Socket.IO test setup: `socket.io` in-memory server for emit assertions

---

## Sources

### Primary (HIGH confidence)
- https://socket.io/docs/v4/tutorial/step-3 — Socket.IO 4.x Express integration pattern
- https://pub.dev/packages/socket_io_client — Version 3.1.4 confirmed (published ~2 months ago)
- https://pub.dev/packages/flutter_polyline_points — Version 3.1.0, Routes API v2 support confirmed
- https://developers.google.com/maps/documentation/routes/compute_route_directions — Routes API v2 request/response format
- npm registry — socket.io 4.8.3, @googlemaps/google-maps-services-js 3.4.2 confirmed (2026-03-21)

### Secondary (MEDIUM confidence)
- https://pub.dev/packages/geolocator — Verified already at ^13.0.2 in pubspec.yaml
- POPIA consent requirements — multiple sources confirm: voluntary, specific, informed, recorded
- https://socket.io/docs/v4/server-api/ — Room emit pattern `io.to('room').emit(...)`

### Tertiary (LOW confidence)
- Working hours timezone handling approach — standard Node.js `Intl.DateTimeFormat` pattern; no single authoritative source, but cross-verified with Phase 1 decision (TZ=UTC in Docker, tenant_timezone stored)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified against npm registry and pub.dev as of 2026-03-21
- Architecture: HIGH — Socket.IO patterns from official docs; Routes API from Google developers docs
- Pitfalls: HIGH — Socket.IO/Express integration and Flutter transport pitfalls are well-documented; GPS-05 pre-satisfaction verified directly in codebase
- POPIA requirements: MEDIUM — general consent principles confirmed across multiple sources; specific GPS screen format not codified in regulation

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable libraries; Routes API v2 is current path)
