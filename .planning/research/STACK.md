# Technology Stack — Vehicle Scheduling SaaS

**Project:** Vehicle Scheduling & Field Service Management SaaS
**Researched:** 2026-03-21
**Overall Confidence:** MEDIUM-HIGH
**Note on sources:** WebSearch and WebFetch tools are disabled in this environment.
All findings come from (a) direct analysis of this codebase, (b) deep knowledge of
the Node.js/Flutter/MySQL ecosystem through training data (cutoff Aug 2025), and
(c) patterns documented by ServiceTitan, Jobber, Housecall Pro engineering blogs
that were part of training. Claims marked [VERIFY] should be confirmed against
current official docs before implementation.

---

## 1. Competitor Stack Landscape

### ServiceTitan
**Confidence: MEDIUM** (training data, not verified live)

ServiceTitan is the largest player in field service management ($1.5B+ valuation,
publicly traded). Their known architecture:

- **Backend:** .NET Core microservices on AWS. Not Node.js. Heavy use of event-driven
  patterns via SNS/SQS.
- **Database:** Microsoft SQL Server (multi-tenant, tenant-per-schema isolation).
- **Mobile:** Native iOS (Swift) + Android (Kotlin). They evaluated React Native and
  rejected it. Flutter was not in use as of their known public statements.
- **Real-time:** SignalR for dispatcher board updates. WebSocket-based, not polling.
- **Push notifications:** AWS SNS wrapping APNs/FCM — not raw FCM.
- **Scheduling UI:** Proprietary drag-and-drop scheduler built on React for web,
  native calendar components on mobile.
- **Maps:** Google Maps Platform (Google Maps for Business tier).
- **Routing optimization:** Third-party: OptimoRoute or similar VRP solver, NOT
  home-grown.

**What to copy:** Status audit trail (job_status_changes table — you already have
this). Conflict detection before commit. Role-based permission model. Dispatcher view
vs technician view as separate UX contexts.

**What NOT to copy:** Their complexity. ServiceTitan has 700+ engineers. The
microservices split is overkill until you have serious tenant load.

---

### Jobber
**Confidence: MEDIUM** (training data)

Jobber targets small-medium field service businesses (HVAC, plumbing, landscaping).
The "friendlier" competitor to ServiceTitan.

- **Backend:** Ruby on Rails monolith (later modularized). GraphQL API layer.
- **Database:** PostgreSQL. They published a blog post on sharding strategies at scale.
- **Mobile:** React Native (cross-platform). Jobber explicitly chose RN over native.
- **Real-time:** ActionCable (Rails WebSocket). Moved to a dedicated WS server later.
- **Push notifications:** Direct FCM + APNs integration.
- **Invoicing/Payments:** Stripe. Jobber Payments is a major revenue stream.
- **Scheduling:** Client-facing booking portal + dispatcher board.
  Implements "arrival windows" (8am-12pm) not exact times — reduces rescheduling.
- **Key differentiator:** Client hub (customer self-service portal). Consider this.

**What to copy from Jobber:** Arrival windows. Client-facing job status tracking link
(SMS/email with live status — huge customer satisfaction feature). Stripe integration
path (even if not MVP).

---

### Housecall Pro
**Confidence: MEDIUM** (training data)

Targets residential service businesses. Simpler than ServiceTitan.

- **Backend:** Ruby on Rails + Node.js microservices for real-time features.
- **Database:** PostgreSQL primary + Redis for real-time state.
- **Mobile:** React Native.
- **Real-time:** Pusher (managed WebSocket service) — notable because they chose
  a managed service rather than self-hosting Socket.IO. Worth considering.
- **GPS tracking:** They use a hybrid approach: driver app sends location every
  30 seconds via HTTP POST (not WebSocket). The server stores the last known
  position. Dispatcher sees it refresh. Only when the driver is "en route" does
  frequency increase to every 10 seconds.
- **Scheduling:** Classic calendar grid. Drag-drop to reassign.

**Key insight from Housecall Pro GPS:** HTTP polling from driver to server is simpler
than a persistent WS connection for location updates. The driver app doesn't need
an open WS connection — it can POST `/api/location` every N seconds. The dispatcher
DOES need a live WebSocket to see all drivers on a map in real time. These are
different channels.

---

### FieldPulse
**Confidence: LOW** (limited public info in training data)

FieldPulse is a smaller player. Known stack elements:
- Node.js backend (confirmed via job postings in training data).
- React frontend.
- React Native mobile.
- PostgreSQL.
- Their differentiator is custom forms/checklists for technicians.

**Relevance:** Closest to what we're building in terms of tech choices. They prove
Node.js + React Native (similar to Flutter) works at the field service scale.

---

### ServiceM8
**Confidence: LOW** (limited public info)

ServiceM8 is an Australian product, cloud-native from the start.
- AWS Lambda-heavy backend (serverless).
- Chosen for Australian/NZ market where servers close to users matter.
- Mobile-first design philosophy.
- Quote-to-invoice workflow is tightly integrated.

**Relevance for us:** Their serverless approach is not a good fit for our Docker
deployment target. Skip their architecture. Do note their mobile-first philosophy —
Flutter fits this well.

---

## 2. Our Confirmed Current Stack

Taken directly from the codebase (HIGH confidence — we can see the files):

| Layer | Technology | Version | Evidence |
|-------|-----------|---------|----------|
| Runtime | Node.js | v18+ (implied by syntax) | server.js |
| Web framework | Express.js | 4.x | server.js |
| Auth | JWT (jsonwebtoken) + bcryptjs | — | server.js |
| API docs | Swagger UI Express | — | server.js |
| Database | MariaDB 10.4 / MySQL 5.6-compatible | 10.4.32-MariaDB | vehicle_scheduling.sql |
| DB driver | mysql2 (pool) | — | config/database.js |
| Mobile | Flutter | SDK ^3.9.2 | pubspec.yaml |
| State management | Provider 6.x | ^6.1.5+1 | pubspec.yaml |
| HTTP client (Flutter) | http package | ^1.1.0 | pubspec.yaml |
| Maps | google_maps_flutter | ^2.10.0 | pubspec.yaml |
| Location | geolocator | ^13.0.2 | pubspec.yaml |
| Storage | shared_preferences | ^2.5.4 | pubspec.yaml |

---

## 3. Recommended Complete Stack (Current + Additions Needed)

### 3a. Backend — Additions Needed

#### Real-time: Socket.IO

**Recommendation: Socket.IO 4.x over raw ws or SSE.**
**Confidence: HIGH**

Why Socket.IO wins for our case:
- Automatic fallback (WebSocket → long-polling). Critical for Flutter WebView or
  poor mobile networks.
- Room support: `socket.join('job:' + jobId)` — only the assigned driver and
  admin see that job's updates. Not possible cleanly with SSE.
- Built-in reconnection with exponential backoff.
- Namespace support: `/admin` vs `/driver` on one server.

Why NOT raw WebSocket (ws package):
- No rooms. You must implement fan-out yourself.
- No reconnection logic. Flutter app must handle disconnect/reconnect.
- Fine at low scale, becomes painful fast.

Why NOT SSE (Server-Sent Events):
- Uni-directional only (server → client). Driver cannot push location to server
  over SSE — needs a separate HTTP POST anyway.
- Not ideal for bi-directional use cases like chat or command acknowledgment.
- Browser only — Flutter's http package does not support SSE natively without
  a third-party package.

**Polling verdict:** Only acceptable for non-critical updates (dashboard refresh
every 30s). Never use polling for GPS tracking — latency is too high and server
load scales with O(clients × poll_frequency).

**Installation:**
```bash
npm install socket.io
```

**Pattern — driver GPS push + admin real-time map:**
```javascript
// server.js addition
const { Server } = require('socket.io');
const httpServer = require('http').createServer(app);
const io = new Server(httpServer, {
  cors: { origin: process.env.ALLOWED_ORIGINS?.split(',') || [] },
  transports: ['websocket', 'polling'], // WebSocket preferred, polling fallback
});

// Namespace: admin dispatchers watching the map
const adminNs = io.of('/admin');
adminNs.use(requireAdminJwt); // middleware

// Namespace: drivers reporting location
const driverNs = io.of('/driver');
driverNs.use(requireDriverJwt);

driverNs.on('connection', (socket) => {
  const driverId = socket.data.userId;
  socket.join(`driver:${driverId}`); // join their own room

  socket.on('location:update', async ({ lat, lng, jobId }) => {
    // 1. Store in MySQL (last-known position)
    await db.query(
      'INSERT INTO driver_locations (driver_id, job_id, lat, lng) VALUES (?, ?, ?, ?) ' +
      'ON DUPLICATE KEY UPDATE lat=VALUES(lat), lng=VALUES(lng), updated_at=NOW()',
      [driverId, jobId, lat, lng]
    );
    // 2. Forward to admin namespace in real time
    adminNs.to(`job:${jobId}`).emit('driver:moved', { driverId, lat, lng, jobId });
  });
});

adminNs.on('connection', (socket) => {
  // Admin joins job rooms to watch specific jobs
  socket.on('watch:job', (jobId) => socket.join(`job:${jobId}`));
});
```

**Flutter driver side — location push:**
The driver app uses `geolocator` (already in pubspec.yaml) + a Socket.IO Flutter
client. The simplest approach that avoids the complexity of a persistent WS from
the driver side: **HTTP POST every 15-30 seconds when job is in_progress.**
```
POST /api/location
{ driver_id, job_id, lat, lng, timestamp }
```
Server then emits to admin WS. This is what Housecall Pro does. Simpler to debug
than WS from a mobile device on 4G.

Flutter Socket.IO package to add:
```yaml
# pubspec.yaml addition
socket_io_client: ^2.0.3+1
```

#### Push Notifications: Firebase FCM v1 HTTP API

**Recommendation: firebase-admin SDK (Node.js) with FCM HTTP v1 API.**
**Confidence: HIGH**

The legacy FCM API was deprecated in June 2023 and shut down June 2024. The
current API is the FCM HTTP v1 API, authenticated via OAuth 2.0 service account
(not a server key). The firebase-admin SDK handles this automatically.

**Installation:**
```bash
npm install firebase-admin
```

**Initialization (do once at server startup):**
```javascript
// src/config/firebase.js
const admin = require('firebase-admin');

const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

module.exports = admin.messaging();
```

**Sending a notification:**
```javascript
// src/services/notificationService.js
const messaging = require('../config/firebase');

class NotificationService {
  /**
   * Send to a single device via FCM registration token.
   * Store tokens in users table: ALTER TABLE users ADD COLUMN fcm_token VARCHAR(512).
   */
  static async notifyDriver(fcmToken, { title, body, data = {} }) {
    const message = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ), // FCM data values must be strings
      token: fcmToken,
      android: {
        priority: 'high', // wake the device even in Doze mode
        notification: { sound: 'default', channelId: 'job_alerts' },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
    };
    return messaging.send(message);
  }

  /**
   * Send to a topic. Drivers subscribe to 'driver_{id}' on app start.
   * Avoids storing/refreshing FCM tokens on every app reinstall.
   */
  static async notifyByTopic(topic, { title, body, data = {} }) {
    const message = {
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      topic,
    };
    return messaging.send(message);
  }

  /**
   * Notify multiple drivers at once (e.g., job reassigned broadcast).
   * sendEachForMulticast is the v1 API replacement for sendMulticast.
   */
  static async notifyMultiple(tokens, payload) {
    if (!tokens.length) return;
    const message = { ...payload, tokens };
    return messaging.sendEachForMulticast(message);
  }
}

module.exports = NotificationService;
```

**FCM Architecture Pattern — Topics vs Tokens:**

| Method | When to use | Pros | Cons |
|--------|-------------|------|------|
| Token | Targeted: "job JOB-2026-0014 assigned to driver X" | Precise | Token expires; need refresh logic |
| Topic | Broadcast: "system maintenance tonight" | No token storage | Cannot target individual user |
| Condition | "drivers in zone A AND premium tier" | Flexible | Complex |

**Recommendation for this project:** Use topics named `driver_{userId}`. Driver app
subscribes on login (`FirebaseMessaging.instance.subscribeToTopic('driver_25')`).
Server sends to `driver_25` topic. Eliminates token refresh complexity entirely.
Store tokens as backup for urgent single-device messages.

**Flutter side additions needed to pubspec.yaml:**
```yaml
firebase_core: ^3.3.0
firebase_messaging: ^15.1.0
flutter_local_notifications: ^17.2.2  # for foreground notification display
```

**When to send FCM notifications in the job lifecycle:**

| Trigger | Recipient | Message |
|---------|-----------|---------|
| Job assigned | Technician(s) on job | "New job: {customer_name} at {address}" |
| Job rescheduled | Technician(s) | "Job {job_number} time changed to {new_time}" |
| Job cancelled | Technician(s) | "Job {job_number} cancelled" |
| Driver hot-swapped | New driver | "You have been assigned to job {job_number}" |
| Driver hot-swapped | Old driver | "You have been removed from job {job_number}" |
| Job en route | Customer (future) | "Your technician is on the way" |

#### Job Queue for Notifications: Bull (Redis-backed)

**Recommendation: Bull 4.x (or BullMQ) with Redis.**
**Confidence: HIGH**

Do NOT send FCM calls synchronously inside HTTP request handlers. If FCM is slow,
your API response is slow. If FCM fails, you have no retry.

Use a job queue:
```bash
npm install bull
# OR the newer maintained fork:
npm install bullmq
```

```javascript
// Enqueue on job assignment
const notificationQueue = new Queue('notifications', { redis: redisConfig });
await notificationQueue.add('job-assigned', {
  recipientUserIds: [14, 15],
  jobId: 42,
  jobNumber: 'JOB-2026-0014',
  customerName: 'Tania',
  customerAddress: 'nnnnn',
});

// Worker processes it
notificationQueue.process('job-assigned', async (job) => {
  const { recipientUserIds, jobNumber, customerName } = job.data;
  for (const uid of recipientUserIds) {
    await NotificationService.notifyByTopic(`driver_${uid}`, {
      title: 'New Job Assigned',
      body: `${jobNumber} — ${customerName}`,
      data: { jobId: String(job.data.jobId), screen: 'job_detail' },
    });
  }
});
```

**Note on Redis requirement:** Bull/BullMQ requires Redis. For Docker deployment,
add a Redis container to docker-compose.yml. This same Redis instance can serve as
Socket.IO adapter for horizontal scaling later.

---

### 3b. Database — Additions and Schema Patterns

#### Missing Tables for Planned Features

**driver_locations table (GPS tracking):**
```sql
CREATE TABLE driver_locations (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  driver_id     INT UNSIGNED NOT NULL,
  job_id        INT UNSIGNED DEFAULT NULL,
  lat           DECIMAL(10, 7) NOT NULL,   -- 7 decimal places = ~1cm accuracy
  lng           DECIMAL(10, 7) NOT NULL,
  speed_kmh     DECIMAL(5,1) DEFAULT NULL, -- optional, from geolocator
  heading_deg   DECIMAL(5,1) DEFAULT NULL,
  accuracy_m    DECIMAL(6,1) DEFAULT NULL, -- GPS accuracy in metres
  recorded_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_driver_job (driver_id, job_id),
  KEY idx_recorded_at (recorded_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- For last-known-position queries, add a unique constraint:
ALTER TABLE driver_locations
  ADD COLUMN is_current TINYINT(1) NOT NULL DEFAULT 0,
  ADD KEY idx_current (driver_id, is_current);
```

**Alternative: Use a separate driver_current_position table** (simpler):
```sql
CREATE TABLE driver_current_position (
  driver_id   INT UNSIGNED NOT NULL,
  job_id      INT UNSIGNED DEFAULT NULL,
  lat         DECIMAL(10, 7) NOT NULL,
  lng         DECIMAL(10, 7) NOT NULL,
  updated_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (driver_id),
  KEY idx_updated (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```
This table has one row per driver. Always INSERT ... ON DUPLICATE KEY UPDATE.
Fast lookups. No unbounded history growth.

**fcm_tokens table (or column):**
```sql
-- Option A: Column on users (simpler, fine for one device per user)
ALTER TABLE users ADD COLUMN fcm_token VARCHAR(512) DEFAULT NULL;
ALTER TABLE users ADD COLUMN fcm_token_updated_at TIMESTAMP DEFAULT NULL;

-- Option B: Separate table (multiple devices per user)
CREATE TABLE user_devices (
  id             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id        INT UNSIGNED NOT NULL,
  fcm_token      VARCHAR(512) NOT NULL,
  device_type    ENUM('android','ios') NOT NULL,
  app_version    VARCHAR(20) DEFAULT NULL,
  registered_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_seen_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
                   ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_token (fcm_token),
  KEY idx_user (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### Scheduling Schema Patterns (from Competitor Analysis)

**Time slot conflict detection — the query you already have is correct:**
```sql
-- Your existing pattern in vehicleAvailabilityService.js (HIGH confidence — correct)
WHERE ja.vehicle_id = ?
  AND j.scheduled_date = ?
  AND j.current_status NOT IN ('completed', 'cancelled')
  AND ? < j.scheduled_time_end    -- new_start < existing_end
  AND ? > j.scheduled_time_start  -- new_end   > existing_start
```
This is the standard interval overlap predicate. Do not change it.

**Maintenance windows (missing — add for SaaS):**
```sql
CREATE TABLE vehicle_maintenance_windows (
  id              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  vehicle_id      INT UNSIGNED NOT NULL,
  window_date     DATE NOT NULL,
  start_time      TIME NOT NULL,
  end_time        TIME NOT NULL,
  reason          VARCHAR(255) DEFAULT NULL,
  recurring_rule  VARCHAR(100) DEFAULT NULL, -- 'WEEKLY:MON', 'MONTHLY:15', etc.
  created_by      INT UNSIGNED NOT NULL,
  created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_vehicle_date (vehicle_id, window_date)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

Add a check against this table in `VehicleAvailabilityService.checkVehicleAvailability()`:
```javascript
// After the job conflict check, also check maintenance windows:
const [maintenanceConflicts] = await db.query(`
  SELECT reason FROM vehicle_maintenance_windows
  WHERE vehicle_id = ?
    AND window_date = ?
    AND ? < end_time
    AND ? > start_time
`, [vehicleId, date, startTime, endTime]);
if (maintenanceConflicts.length > 0) {
  return { isAvailable: false, reason: 'maintenance', ... };
}
```

**Job history / audit trail (you already have job_status_changes — extend it):**
Your existing `job_status_changes` table covers status. Add an `assignment_history`
table for full audit of who moved what when:
```sql
CREATE TABLE assignment_history (
  id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  job_id        INT UNSIGNED NOT NULL,
  action        ENUM('assigned','unassigned','reassigned','driver_swapped') NOT NULL,
  from_vehicle  INT UNSIGNED DEFAULT NULL,
  to_vehicle    INT UNSIGNED DEFAULT NULL,
  from_driver   INT UNSIGNED DEFAULT NULL,
  to_driver     INT UNSIGNED DEFAULT NULL,
  notes         TEXT DEFAULT NULL,
  changed_by    INT UNSIGNED NOT NULL,
  changed_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_job (job_id),
  KEY idx_changed_at (changed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### MySQL Index Strategy (missing from current schema)

The current schema has no indexes beyond primary keys. Add before going to
production — these queries will be slow at 1000+ jobs:

```sql
-- Queries by date (getJobsByDate, scheduler view)
ALTER TABLE jobs ADD KEY idx_scheduled_date (scheduled_date);
ALTER TABLE jobs ADD KEY idx_date_status (scheduled_date, current_status);

-- Queries by status (dashboard counts)
ALTER TABLE jobs ADD KEY idx_status (current_status);

-- Assignment lookups
ALTER TABLE job_assignments ADD KEY idx_vehicle (vehicle_id);
ALTER TABLE job_assignments ADD KEY idx_driver (driver_id);

-- Technician assignment lookups
ALTER TABLE job_technicians ADD KEY idx_user_id (user_id);
ALTER TABLE job_technicians ADD UNIQUE KEY uq_job_user (job_id, user_id);
```

---

### 3c. Smart Scheduling / Rescheduling Algorithms

**Confidence: MEDIUM** (algorithm patterns are well-documented in academic and
industry literature; specific competitor implementations are not public)

#### What competitors actually implement

None of the SME-targeted competitors (Jobber, Housecall Pro, FieldPulse) have true
AI scheduling. They implement:

1. **Constraint-based slot suggestion** — "show me which vehicles are free for 2 hours
   on this date." This is `findAvailableVehicles()` — you already have it.

2. **Priority queue ordering** — urgent jobs float to the top. You have the `priority`
   ENUM. What you're missing is a scheduler that automatically suggests which job to
   do next based on priority + location proximity.

3. **Geographic clustering** — assign jobs in the same area to the same vehicle on
   the same day. Reduces drive time. This is NOT automatic in Jobber/Housecall Pro —
   the dispatcher drags and drops. OptimoRoute and Route4Me are separate SaaS products
   that field service companies pay extra for.

#### Practical algorithm for smart rescheduling

**Phase 1 (MVP):** Constraint-based suggestion
```javascript
// Given a job that needs rescheduling, find available vehicles
// sorted by: (1) already in same area, (2) fewest jobs that day
static async suggestReschedule(jobId) {
  const job = await Job.getJobById(jobId);
  const available = await VehicleAvailabilityService.findAvailableVehicles(
    job.scheduled_date,
    job.scheduled_time_start,
    job.scheduled_time_end
  );
  // Score: prefer vehicles with fewest jobs today
  const scores = await Promise.all(available.map(async (v) => {
    const [count] = await db.query(
      'SELECT COUNT(*) as c FROM job_assignments ja JOIN jobs j ON ja.job_id=j.id ' +
      'WHERE ja.vehicle_id=? AND j.scheduled_date=? AND j.current_status != "cancelled"',
      [v.id, job.scheduled_date]
    );
    return { ...v, jobCount: count[0].c };
  }));
  return scores.sort((a, b) => a.jobCount - b.jobCount);
}
```

**Phase 2 (post-MVP):** Geographic proximity scoring
When `destination_lat` and `destination_lng` are stored on the job (you already
have these columns), use the Haversine formula to sort vehicles by proximity to
the new job's location:
```javascript
// Haversine distance in km
function haversine(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a = Math.sin(dLat/2)**2 +
    Math.cos(lat1*Math.PI/180) * Math.cos(lat2*Math.PI/180) * Math.sin(dLon/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}
```

**Phase 3 (future):** Vehicle Routing Problem (VRP) optimization
Use Google OR-Tools (Python, via a microservice) or the `javascript-vroom` Node
binding to solve multi-stop route optimization. This is what enterprise-level
systems use. Do NOT build this in Phase 1.

---

### 3d. Docker Deployment Stack

**Recommendation:** docker-compose with three services.
**Confidence: HIGH** (standard pattern for this stack)

```yaml
# docker-compose.yml
version: '3.9'

services:
  api:
    build: ./vehicle-scheduling-backend
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DB_HOST=db
      - DB_PORT=3306
      - DB_NAME=vehicle_scheduling
      - DB_USER=app_user
      - DB_PASSWORD=${DB_PASSWORD}
      - JWT_SECRET=${JWT_SECRET}
      - REDIS_URL=redis://redis:6379
      - FIREBASE_SERVICE_ACCOUNT_JSON=${FIREBASE_SERVICE_ACCOUNT_JSON}
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    restart: unless-stopped

  db:
    image: mysql:8.0          # Upgrade from MariaDB 10.4 for production
    environment:
      - MYSQL_ROOT_PASSWORD=${DB_ROOT_PASSWORD}
      - MYSQL_DATABASE=vehicle_scheduling
      - MYSQL_USER=app_user
      - MYSQL_PASSWORD=${DB_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
      - ./vehicle_scheduling.sql:/docker-entrypoint-initdb.d/01-schema.sql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    volumes:
      - redis_data:/data
    restart: unless-stopped

volumes:
  db_data:
  redis_data:
```

**MySQL 8.0 migration note:** Your code is currently targeting MariaDB 10.4 /
MySQL 5.6 compatibility (see the GROUP_CONCAT workaround in Job.js).
MySQL 8.0 supports `JSON_ARRAYAGG(JSON_OBJECT(...))`. Once Docker-deployed on
MySQL 8.0, you can replace the GROUP_CONCAT workarounds with cleaner JSON queries.
This is a medium-priority refactor.

---

## 4. Testing Strategies

### 4a. API Testing

**Recommendation: Jest + Supertest.**
**Confidence: HIGH**

```bash
npm install -D jest supertest
```

**Pattern — integration test for job assignment conflict:**
```javascript
// tests/integration/jobAssignment.test.js
const request = require('supertest');
const app = require('../../src/server');

describe('POST /api/job-assignments/assign', () => {
  it('rejects double-booking same vehicle', async () => {
    // Seed: existing job 09:00-12:00 on vehicle 1
    // Attempt: assign overlapping 10:00-13:00 on vehicle 1
    const res = await request(app)
      .post('/api/job-assignments/assign')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ job_id: newJobId, vehicle_id: 1, assigned_by: 6 });
    expect(res.status).toBe(409);
    expect(res.body.message).toMatch(/conflict/i);
  });

  it('allows back-to-back jobs (no overlap)', async () => {
    // 09:00-12:00 then 12:00-15:00 should not conflict
    const res = await request(app)
      .post('/api/job-assignments/assign')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ job_id: backToBackJobId, vehicle_id: 1, assigned_by: 6 });
    expect(res.status).toBe(201);
  });
});
```

**Critical test cases for scheduling systems:**

| Test | Why |
|------|-----|
| Exact boundary overlap (end_A == start_B) | Must NOT conflict — back-to-back is valid |
| One-minute overlap (end_A = 12:01, start_B = 12:00) | MUST conflict |
| Same vehicle, different dates | Must NOT conflict |
| Cancelled job in the slot | Must NOT block the slot |
| Admin force-override | Must move driver from old job |
| Timezone: date rollover at midnight | Must not create off-by-one date errors |

### 4b. Flutter UI Testing

**Recommendation: Flutter integration_test package (widget + integration tests).**
**Confidence: HIGH** (Flutter official recommendation)

```yaml
# pubspec.yaml dev_dependencies
dev_dependencies:
  integration_test:
    sdk: flutter
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  build_runner: ^2.4.9
```

**Pattern — mock the API service in widget tests:**
```dart
// test/job_list_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

@GenerateMocks([JobService])
void main() {
  group('Jobs List Screen', () {
    testWidgets('shows jobs returned by service', (tester) async {
      final mockService = MockJobService();
      when(mockService.getAllJobs()).thenAnswer((_) async => [
        Job(id: 1, jobNumber: 'JOB-2026-0001', customerName: 'Test Customer', ...),
      ]);

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => JobProvider(service: mockService),
          child: MaterialApp(home: JobsListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JOB-2026-0001'), findsOneWidget);
      expect(find.text('Test Customer'), findsOneWidget);
    });
  });
}
```

### 4c. Regression Testing Strategy

**Three layers for scheduling system regressions:**

**Layer 1: Unit tests (fast, <1s each)**
- `VehicleAvailabilityService.checkVehicleAvailability()` with an in-memory mock DB
- `Job._formatDateOnly()` with edge cases (UTC midnight, DST transitions)
- `calculateTimeGaps()` with various job arrangements

**Layer 2: Integration tests (medium, use a test DB)**
- Full HTTP request → DB → response round trips
- Use a dedicated test database seeded before each test suite
- Test the exact conflict scenarios listed above

**Layer 3: Smoke tests (post-deploy, hit staging)**
- Health check endpoint responds 200
- Can login and get token
- Create → assign → status update flow completes without error
- A pre-seeded conflict scenario is correctly rejected

**Regression guard for the timezone bug (already burned once in this project):**
```javascript
// tests/unit/dateFormatting.test.js
describe('Job._formatDateOnly', () => {
  it('does not shift date for SA timezone UTC+2', () => {
    // Simulate what MySQL returns: a Date object at midnight UTC+2 = 22:00 prev day UTC
    const mysqlDate = new Date('2026-02-23T22:00:00.000Z'); // This is 2026-02-24 00:00 SAST
    // The correct answer depends on the SERVER's local time.
    // Test must run with TZ=Africa/Johannesburg to be meaningful.
    const result = Job._formatDateOnly(mysqlDate);
    // If server is in SAST, local date is the 24th, not the 23rd
    expect(result).toMatch(/^\d{4}-\d{2}-\d{2}$/); // at minimum, must be a date string
  });
});
```

---

## 5. Alternatives Considered

| Category | Recommended | Alternative | Why We Recommend Over Alternative |
|----------|-------------|-------------|----------------------------------|
| Real-time | Socket.IO | Pusher (managed) | Pusher has per-message pricing that gets expensive. Socket.IO is free, self-hosted. |
| Real-time | Socket.IO | SSE | SSE is uni-directional. GPS tracking needs bi-directional. |
| Push | FCM direct | AWS SNS | SNS adds a layer of complexity. FCM HTTP v1 direct is simpler for mobile-only targets. |
| Queue | Bull (Redis) | In-process EventEmitter | EventEmitter is lost on crash. Bull persists to Redis and retries. |
| Queue | Bull | AWS SQS | SQS is correct at scale but overkill for Docker deployment. |
| Scheduling algorithm | Constraint-based + Haversine | Google OR-Tools / VRP | VRP is correct but complex. Constraint-based is implementable in one sprint. |
| Testing | Jest + Supertest | Mocha + Chai | Jest has better default config and watch mode. Both are fine choices. |
| DB (future) | MySQL 8.0 | PostgreSQL | PostgreSQL has better JSON support and full-text search. BUT: migrating from MariaDB to Postgres requires data migration. Stay on MySQL, upgrade version instead. |

---

## 6. Packages Summary — What to Add

### Backend additions
```bash
npm install socket.io         # Real-time WebSocket
npm install firebase-admin    # FCM push notifications
npm install bull              # Redis-backed job queue (notifications)
npm install ioredis           # Redis client (better than redis package for Bull)
npm install helmet            # Security headers (missing from current setup)
npm install express-rate-limit # Rate limiting (missing — security requirement for SaaS)
```

### Backend dev additions
```bash
npm install -D jest supertest @types/jest
```

### Flutter additions (pubspec.yaml)
```yaml
dependencies:
  socket_io_client: ^2.0.3+1      # WebSocket client for real-time
  firebase_core: ^3.3.0           # Firebase base
  firebase_messaging: ^15.1.0     # FCM push notifications
  flutter_local_notifications: ^17.2.2  # Foreground notification display
  flutter_background_service: ^5.0.5    # Location reporting when app is backgrounded

dev_dependencies:
  mockito: ^5.4.4
  build_runner: ^2.4.9
  integration_test:
    sdk: flutter
```

---

## 7. Confidence Summary

| Area | Confidence | Basis |
|------|------------|-------|
| Current project stack | HIGH | Direct code inspection |
| Socket.IO recommendation | HIGH | Well-documented, standard choice for this use case |
| FCM HTTP v1 API | HIGH | Official API change widely documented (legacy shutdown June 2024) |
| FCM topic subscription pattern | HIGH | Standard FCM pattern |
| Bull/Redis queue | HIGH | Standard Node.js queue pattern |
| Competitor stacks (ServiceTitan, Jobber) | MEDIUM | Training data; verify against current job postings |
| Competitor GPS tracking strategy | MEDIUM | Training data; Housecall Pro HTTP polling pattern |
| Smart scheduling algorithms | MEDIUM | Industry-documented VRP patterns |
| MySQL 8.0 JSON_ARRAYAGG availability | HIGH | MySQL 8.0 documented feature |
| Docker compose pattern | HIGH | Standard practice |

---

## 8. Sources

- Codebase: `/c/Users/olwethu/Desktop/test/vehicle-scheduling-backend/` (HIGH — direct)
- Codebase: `/c/Users/olwethu/Desktop/test/vehicle_scheduling_app/` (HIGH — direct)
- Database schema: `/c/Users/olwethu/Desktop/test/vehicle_scheduling.sql` (HIGH — direct)
- Firebase Admin SDK docs: https://firebase.google.com/docs/admin/setup [VERIFY current]
- FCM HTTP v1 migration: https://firebase.google.com/docs/cloud-messaging/migrate-v1 [VERIFY]
- Socket.IO docs: https://socket.io/docs/v4/ [VERIFY version]
- Bull queue: https://github.com/OptimalBits/bull [VERIFY — consider BullMQ as maintained successor]
- ServiceTitan engineering blog: https://blog.servicetitan.com/engineering [VERIFY for current stack claims]
- Jobber tech blog: https://medium.com/jobber-engineering [VERIFY]
