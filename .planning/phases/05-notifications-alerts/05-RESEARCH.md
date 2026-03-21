# Phase 5: Notifications & Alerts - Research

**Researched:** 2026-03-21
**Domain:** Firebase Cloud Messaging (FCM v1), nodemailer SMTP, flutter_local_notifications, node-cron
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Push Notifications (FCM)**
- Firebase service account configured via JSON key file path in .env (FCM_SERVICE_ACCOUNT_PATH)
- Fixed 15-minute lead time for "about to start" notifications (v1)
- Overdue notification triggers 5 minutes past scheduled end time
- No retry on FCM failure for v1 — log and move on, cron catches on next cycle
- FCM topic subscriptions per user on login (driver_{userId}, scheduler_{userId})

**Email Notifications**
- SMTP via nodemailer — universal, works with any provider
- Per-user boolean toggle in notification_preferences table (email_enabled)
- Simple HTML email templates with inline styles
- SMTP config via .env variables (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS)

**In-App Notification Center**
- Bell icon in AppBar with unread count badge
- 30-day notification history retention
- Both individual tap-to-read and "Mark all read" button
- Chronological list display, newest first

### Claude's Discretion
- Notification table schema column naming
- FCM message payload structure
- Email template HTML layout
- Cron scheduling details for notification checks
- Flutter notification handling and foreground/background behavior

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| NOTIF-01 | Push notifications via Firebase Cloud Messaging (FCM v1 HTTP API with firebase-admin SDK) | firebase-admin 13.7.0 confirmed; HTTP v1 API via getMessaging().send() |
| NOTIF-02 | Notification when job is about to start (configurable lead time — fixed 15 min in v1) | Cron query: WHERE start time is within 15 minutes; dedup via notification_log |
| NOTIF-03 | Notification when job is overdue (past scheduled end, not completed) | Cron query: WHERE end time + 5 min passed AND status != completed |
| NOTIF-04 | Email notifications via nodemailer (togglable per user in settings) | nodemailer 8.0.3; check email_enabled flag in notification_preferences before send |
| NOTIF-05 | In-app notification center with read/unread status and history | notifications table + GET/PATCH endpoints; Flutter NotificationProvider + screen |
| NOTIF-06 | FCM topic-based subscriptions per user (driver_{userId}, scheduler_{userId}) | admin.messaging().subscribeToTopic(token, topic) called in login response |
| NOTIF-07 | Background cron job (node-cron) for checking overdue jobs and upcoming starts | Extend existing cronService.js with two new schedules |
</phase_requirements>

---

## Summary

This phase builds a three-channel notification system: push (FCM), email (nodemailer), and in-app. The backend is already well-prepared — node-cron 4.2.1 is installed and `cronService.js` (Phase 3) provides the exact extension point needed. The pattern is: extend `startCronJobs()` with two new schedules, add a `notificationService.js` for FCM and email dispatch, and add two new DB tables.

The Flutter side requires adding `firebase_messaging` and `flutter_local_notifications` (both new dependencies). Firebase setup requires a `google-services.json` placed in `android/app/` and the Firebase Android SDK gradle entries — this is the most error-prone step. The in-app notification center follows the established Provider + ChangeNotifier pattern with a new `NotificationProvider` and `NotificationScreen`.

FCM topic subscriptions are managed server-side via `admin.messaging().subscribeToTopic()` — this should be called in the login endpoint after JWT signing, sending the FCM registration token (provided by the Flutter app in the login request body) to the backend.

**Primary recommendation:** Implement in three sequential waves: (1) DB schema + backend notification service + cron extensions, (2) FCM token registration at login + topic subscription, (3) Flutter in-app notification center UI.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| firebase-admin | 13.7.0 | FCM HTTP v1 API, topic subscription management | Official Google SDK; handles auth, retries, and HTTP/2 multiplexing |
| nodemailer | 8.0.3 | SMTP email delivery | Zero-dependency, universal SMTP client; works with Gmail, SendGrid, any provider |
| node-cron | 4.2.1 | Background job scheduling | Already installed; used in Phase 3 cronService.js |
| firebase_messaging | 16.1.2 | Flutter FCM token retrieval, topic subscription, push handling | Official FlutterFire plugin by firebase.google.com |
| flutter_local_notifications | 21.0.0 | Display notifications in foreground (FCM blocks foreground on Android) | Required because Android FCM does not show notification UI when app is in foreground |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| badges | 3.1.2 | Unread count badge on bell icon | Clean badge overlay widget; avoids manual Stack+Positioned implementation |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| firebase-admin (server topic subscription) | Client-side subscribeToTopic() only | Server-side gives audit trail and allows admin to manage user topics; client-only is simpler but less controllable |
| Simple HTML string templates | Handlebars/EJS templating engine | Template engines add dependency; inline HTML strings are sufficient for 2-3 email types in v1 |

### Installation

```bash
# Backend
cd vehicle-scheduling-backend
npm install firebase-admin nodemailer

# Flutter
cd vehicle_scheduling_app
flutter pub add firebase_messaging flutter_local_notifications badges
```

**Verified versions (npm registry, 2026-03-21):**
- firebase-admin: 13.7.0
- nodemailer: 8.0.3
- node-cron: 4.2.1 (already installed)

**Verified versions (pub.dev, 2026-03-21):**
- firebase_messaging: 16.1.2
- flutter_local_notifications: 21.0.0
- badges: 3.1.2

---

## Architecture Patterns

### Recommended Project Structure

```
vehicle-scheduling-backend/src/
├── services/
│   ├── cronService.js            # EXTEND: add notification cron jobs
│   ├── notificationService.js    # NEW: FCM dispatch + email dispatch
│   └── emailService.js           # NEW: nodemailer transport + templates
├── routes/
│   └── notifications.js          # NEW: GET /notifications, PATCH /notifications/:id/read
└── controllers/
    └── notificationController.js # NEW: list, mark-read, mark-all-read

vehicle_scheduling_app/lib/
├── providers/
│   └── notification_provider.dart  # NEW: ChangeNotifier for bell badge + list
├── services/
│   ├── notification_service.dart   # NEW: API calls + FCM token registration
│   └── fcm_service.dart            # NEW: Firebase init, token get, foreground handler
├── screens/
│   └── notifications/
│       └── notification_center_screen.dart  # NEW: bell tap destination
└── widgets/
    └── notification_bell.dart      # NEW: AppBar bell with badge
```

### Pattern 1: FCM Service Account Initialization

**What:** Load service account from JSON file path in .env, initialize firebase-admin once at startup.

**When to use:** Server startup, before any FCM calls.

```javascript
// Source: firebase-admin official docs
// src/config/firebase.js
const admin = require('firebase-admin');
const serviceAccount = require(process.env.FCM_SERVICE_ACCOUNT_PATH);

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

module.exports = admin;
```

**Critical:** Add `FCM_SERVICE_ACCOUNT_PATH` to the startup guard in `server.js` (alongside `JWT_SECRET`) so the server refuses to start without it.

### Pattern 2: Send FCM to a Topic

**What:** Dispatch a push notification to all devices subscribed to a topic.

**When to use:** Cron notification triggers, job status change hooks.

```javascript
// Source: Firebase Cloud Messaging official docs
// src/services/notificationService.js
const admin = require('../config/firebase');

async function sendTopicNotification(topic, title, body, data = {}) {
  const message = {
    notification: { title, body },
    data,          // Extra key-value pairs (e.g. jobId, type)
    topic,         // e.g. 'driver_42' or 'scheduler_7'
  };
  try {
    const response = await admin.messaging().send(message);
    logger.info({ topic, messageId: response }, 'FCM sent');
  } catch (err) {
    // NOTIF decision: no retry on failure — log and move on
    logger.warn({ topic, err: err.message }, 'FCM send failed — skipping');
  }
}
```

### Pattern 3: Topic Subscription at Login

**What:** Flutter sends FCM token in login request body; backend subscribes the token to user-specific topics.

**When to use:** POST /api/auth/login response — after JWT is signed.

```javascript
// Backend login handler addition
const fcmToken = req.body.fcm_token; // Flutter sends this in login body
if (fcmToken) {
  const role = normalisedRole; // 'technician' or 'scheduler'/'admin'
  const topicName = role === 'technician'
    ? `driver_${user.id}`
    : `scheduler_${user.id}`;
  // Fire-and-forget — don't block login response
  admin.messaging()
    .subscribeToTopic([fcmToken], topicName)
    .catch(err => logger.warn({ err }, 'FCM topic subscription failed'));
}
```

```dart
// Flutter: send FCM token with login
// Source: firebase_messaging FlutterFire docs
final fcmToken = await FirebaseMessaging.instance.getToken();
// Include fcm_token in login POST body alongside username/password
```

### Pattern 4: Foreground Notification Display (Flutter)

**What:** FCM suppresses notification UI when Flutter app is in foreground on Android. Must show via flutter_local_notifications.

**When to use:** Always — this is required for foreground FCM on Android.

```dart
// Source: FlutterFire messaging/notifications docs
// lib/services/fcm_service.dart

// Top-level function — required by firebase_messaging (cannot be anonymous or a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are auto-displayed by the OS on Android
  // No flutter_local_notifications needed here
}

class FcmService {
  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Android notification channel (required for Android 8.0+)
    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Job Notifications',
      importance: Importance.high,
    );
    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Foreground: show local notification ourselves
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifs.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              importance: Importance.high,
            ),
          ),
        );
      }
    });
  }
}
```

### Pattern 5: Notification Deduplication in Cron

**What:** Cron runs every minute. Without dedup, a job approaching its start time would generate a notification on every cron tick.

**When to use:** All cron-triggered notifications.

```javascript
// Add sent_at timestamp to notifications table.
// Query pattern: only notify if no notification of this type
// exists for this job in the last 20 minutes.
const [existing] = await db.query(`
  SELECT id FROM notifications
  WHERE job_id = ? AND type = ? AND created_at > DATE_SUB(NOW(), INTERVAL 20 MINUTE)
`, [job.id, 'job_starting_soon']);

if (existing.length === 0) {
  // Send notification + insert record
}
```

### Pattern 6: Extending cronService.js

**What:** Add notification check schedules to the existing `startCronJobs()` function.

**When to use:** Phase 5 — do not create a second cron service file.

```javascript
// src/services/cronService.js — extend startCronJobs()
function startCronJobs() {
  // Existing: STAT-01 auto-transition (every minute)
  cron.schedule('* * * * *', async () => { /* existing code */ });

  // NEW: NOTIF-02 — jobs starting in ~15 minutes
  cron.schedule('* * * * *', async () => {
    await NotificationService.checkUpcomingJobs();
  });

  // NEW: NOTIF-03 — overdue jobs (5 min past scheduled end)
  cron.schedule('* * * * *', async () => {
    await NotificationService.checkOverdueJobs();
  });

  logger.info('Cron jobs started (auto-transition + notifications every 1 minute)');
}
```

### Anti-Patterns to Avoid

- **Blocking the login response on FCM subscription:** subscribeToTopic is fire-and-forget; never await it in the login handler.
- **Anonymous background message handler:** firebase_messaging requires a top-level named function decorated with `@pragma('vm:entry-point')` — anonymous functions crash.
- **Missing Android notification channel:** flutter_local_notifications on Android 8+ requires an explicit AndroidNotificationChannel; notifications silently fail without it.
- **Initializing firebase-admin multiple times:** Guard with `if (!admin.apps.length)` — duplicate initialization throws.
- **Storing FCM tokens in the database without TTL:** FCM tokens rotate. For v1, subscribe-at-login is sufficient; storing tokens long-term creates stale token problems.
- **Including sensitive data in FCM data payload:** Payloads are visible in device logs. Use job IDs and types, not full job details.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| SMTP transport | Custom TCP email sender | nodemailer | TLS/STARTTLS negotiation, auth, connection pooling, retry — all handled |
| FCM HTTP auth | Manual OAuth2 token refresh for HTTP v1 | firebase-admin SDK | Service account credential refresh every 60 minutes; SDK handles automatically |
| Local notification display | Custom native plugin | flutter_local_notifications | Android notification channels, importance levels, and notification IDs require platform-specific code |
| Cron scheduling | setInterval loops | node-cron (already installed) | setInterval drifts, doesn't survive system sleep, no timezone support |
| Badge count overlay | Manual Stack+Positioned+Container | badges package | Handles positioning, count formatting (99+), and hide-when-zero logic |

**Key insight:** The FCM HTTP v1 API requires OAuth2 bearer tokens that expire every 60 minutes. firebase-admin handles this refresh cycle transparently. Any hand-rolled HTTP approach must re-implement token refresh — this is a known maintenance trap.

---

## Common Pitfalls

### Pitfall 1: Missing google-services.json
**What goes wrong:** Flutter build fails or FCM token returns null at runtime with no clear error.
**Why it happens:** firebase_messaging requires `google-services.json` placed in `android/app/`. It is NOT included in git (contains project credentials).
**How to avoid:** In the plan, Wave 0 task must include: download `google-services.json` from Firebase Console and place at `android/app/google-services.json`. Also requires `google-services` classpath in `android/build.gradle` and `apply plugin: 'com.google.gms.google-services'` in `android/app/build.gradle`.
**Warning signs:** `FirebaseApp not initialized` exception; `getToken()` returns null.

### Pitfall 2: FCM Foreground Suppression on Android
**What goes wrong:** Push notifications arrive and are handled, but no visual notification appears when the app is open.
**Why it happens:** The Firebase Android SDK intentionally blocks notification display in the foreground. The `notification` object in the FCM payload is only auto-displayed when the app is in the background.
**How to avoid:** Always route foreground messages through `flutter_local_notifications`. Set up `FirebaseMessaging.onMessage.listen()` with a local notification show call.
**Warning signs:** Background notifications work; foreground notifications silently disappear.

### Pitfall 3: Cron Notification Storms (No Deduplication)
**What goes wrong:** A job's "about to start" notification is sent every minute for 15 minutes until start time.
**Why it happens:** Cron fires every minute. Without a dedup check, every cron tick qualifies the same job.
**How to avoid:** Before inserting a notification record and sending FCM, query the notifications table for an existing record of the same `(job_id, type)` within the past 20 minutes.
**Warning signs:** Users receive 15 identical push notifications for the same upcoming job.

### Pitfall 4: flutter_local_notifications v21 Permission Requirements
**What goes wrong:** Notifications fail silently on Android 13+ (API 33+); scheduled notifications fail on Android 12+.
**Why it happens:** flutter_local_notifications 16+ no longer auto-declares permissions in its own AndroidManifest. Developers must manually add `POST_NOTIFICATIONS` (Android 13+) and channel configuration.
**How to avoid:** Add `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` to AndroidManifest.xml. Request runtime permission via `flutter_local_notifications` or `permission_handler`.
**Warning signs:** Notifications work on API < 33 but not on newer Android.

### Pitfall 5: node-cron 4.x Breaking Changes
**What goes wrong:** If upgrading from node-cron 3.x, scheduled tasks may behave differently.
**Why it happens:** node-cron 4.x changed the API slightly — `cron.schedule()` still works but some callback and options signatures changed.
**How to avoid:** Already on 4.2.1 per package.json. The existing cronService.js pattern (`cron.schedule('* * * * *', async () => {})`) is confirmed valid for 4.x.
**Warning signs:** Not applicable here — already on the correct version.

### Pitfall 6: Firebase Service Account JSON Path on Different OSes
**What goes wrong:** `require(process.env.FCM_SERVICE_ACCOUNT_PATH)` works locally on Windows but fails in Docker if the path uses backslashes.
**Why it happens:** Windows path separators vs. Linux path separators in .env file.
**How to avoid:** Document in .env.example that `FCM_SERVICE_ACCOUNT_PATH` must use forward slashes (e.g., `./config/firebase-service-account.json`). Docker mounts use Linux paths.
**Warning signs:** Works in dev, fails in production Docker container.

---

## Database Schema

These are the two new tables this phase requires.

### notifications table

```sql
CREATE TABLE IF NOT EXISTS notifications (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  tenant_id       INT NOT NULL,
  user_id         INT NOT NULL,                    -- recipient
  job_id          INT,                             -- nullable: some notifs are not job-specific
  type            VARCHAR(50) NOT NULL,            -- 'job_starting_soon' | 'job_overdue' | 'job_status_changed'
  title           VARCHAR(255) NOT NULL,
  body            TEXT NOT NULL,
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_notifications_tenant_user (tenant_id, user_id),
  INDEX idx_notifications_job (job_id),
  INDEX idx_notifications_created (created_at)
);
```

### notification_preferences table

```sql
CREATE TABLE IF NOT EXISTS notification_preferences (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  tenant_id       INT NOT NULL,
  user_id         INT NOT NULL UNIQUE,
  email_enabled   BOOLEAN NOT NULL DEFAULT TRUE,
  push_enabled    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_notif_prefs_user (user_id)
);
```

**30-day retention:** Add a cron schedule (runs daily) to delete `notifications WHERE created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)`.

---

## Code Examples

### Email Service (nodemailer)

```javascript
// Source: nodemailer official docs (nodemailer.com)
// src/services/emailService.js
const nodemailer = require('nodemailer');
const logger = require('../config/logger').child({ service: 'emailService' });

const transporter = nodemailer.createTransport({
  host    : process.env.SMTP_HOST,
  port    : parseInt(process.env.SMTP_PORT || '587'),
  secure  : process.env.SMTP_PORT === '465',   // true for 465 (SSL), false for 587 (STARTTLS)
  auth    : {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

function buildJobNotificationHtml(title, bodyText, jobNumber, scheduledTime) {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2 style="color: #2196F3;">${title}</h2>
      <p style="color: #333;">${bodyText}</p>
      <table style="border-collapse: collapse; width: 100%;">
        <tr>
          <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Job Number</td>
          <td style="padding: 8px; border: 1px solid #ddd;">${jobNumber}</td>
        </tr>
        <tr>
          <td style="padding: 8px; border: 1px solid #ddd; font-weight: bold;">Scheduled</td>
          <td style="padding: 8px; border: 1px solid #ddd;">${scheduledTime}</td>
        </tr>
      </table>
      <p style="color: #999; font-size: 12px; margin-top: 20px;">
        FleetScheduler Pro — automated notification
      </p>
    </div>`;
}

async function sendJobNotification({ to, subject, title, bodyText, jobNumber, scheduledTime }) {
  try {
    await transporter.sendMail({
      from   : `"FleetScheduler" <${process.env.SMTP_USER}>`,
      to,
      subject,
      html   : buildJobNotificationHtml(title, bodyText, jobNumber, scheduledTime),
    });
    logger.info({ to, subject }, 'Email sent');
  } catch (err) {
    logger.warn({ to, err: err.message }, 'Email send failed — skipping');
  }
}

module.exports = { sendJobNotification };
```

### Upcoming Jobs Cron Check

```javascript
// src/services/notificationService.js (checkUpcomingJobs)
async function checkUpcomingJobs() {
  // Select assigned/in_progress jobs starting in 10-20 minutes (15-min window)
  // that have not yet had a 'job_starting_soon' notification in the last 20 min
  const [jobs] = await db.query(`
    SELECT
      j.id, j.job_number, j.job_title, j.tenant_id,
      CONCAT(j.scheduled_date, ' ', j.scheduled_time_start) AS start_dt,
      u.id AS user_id, u.email,
      COALESCE(np.email_enabled, 1) AS email_enabled
    FROM jobs j
    JOIN job_assignments ja ON ja.job_id = j.id
    JOIN users u ON u.id = ja.driver_id
    LEFT JOIN notification_preferences np
           ON np.user_id = u.id AND np.tenant_id = j.tenant_id
    WHERE j.current_status IN ('assigned', 'in_progress')
      AND CONCAT(j.scheduled_date, ' ', j.scheduled_time_start)
            BETWEEN DATE_ADD(NOW(), INTERVAL 10 MINUTE)
                AND DATE_ADD(NOW(), INTERVAL 20 MINUTE)
      AND NOT EXISTS (
        SELECT 1 FROM notifications n2
        WHERE n2.job_id = j.id
          AND n2.user_id = u.id
          AND n2.type = 'job_starting_soon'
          AND n2.created_at > DATE_SUB(NOW(), INTERVAL 20 MINUTE)
      )
  `);

  for (const job of jobs) {
    // Insert notification record (in-app)
    await db.query(
      `INSERT INTO notifications (tenant_id, user_id, job_id, type, title, body)
       VALUES (?, ?, ?, 'job_starting_soon', ?, ?)`,
      [job.tenant_id, job.user_id, job.id,
       `Job Starting Soon: ${job.job_number}`,
       `${job.job_title} starts at ${job.start_dt}`]
    );
    // FCM push
    await sendTopicNotification(
      `driver_${job.user_id}`,
      `Job Starting Soon`,
      `${job.job_title} starts in ~15 minutes`
    );
    // Email if enabled
    if (job.email_enabled) {
      await EmailService.sendJobNotification({
        to           : job.email,
        subject      : `Job Starting Soon: ${job.job_number}`,
        title        : 'Job Starting Soon',
        bodyText     : `Your job ${job.job_title} is starting in approximately 15 minutes.`,
        jobNumber    : job.job_number,
        scheduledTime: job.start_dt,
      });
    }
  }
}
```

### Notification Provider (Flutter)

```dart
// lib/providers/notification_provider.dart
// Follows established ChangeNotifier pattern (same as JobProvider, VehicleProvider)
class NotificationProvider extends ChangeNotifier {
  final NotificationService _service = NotificationService();

  List<AppNotification> _notifications = [];
  int _unreadCount = 0;
  bool _loading = false;

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _loading;

  Future<void> loadNotifications() async {
    _loading = true;
    notifyListeners();
    try {
      final result = await _service.getNotifications();
      _notifications = result;
      _unreadCount = result.where((n) => !n.isRead).length;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(int notificationId) async {
    await _service.markRead(notificationId);
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx >= 0) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }
  }

  Future<void> markAllRead() async {
    await _service.markAllRead();
    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();
  }
}
```

### Bell Icon with Badge (Flutter)

```dart
// lib/widgets/notification_bell.dart
// Uses badges ^3.1.2
import 'package:badges/badges.dart' as badges;

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notifProvider, _) {
        final count = notifProvider.unreadCount;
        return IconButton(
          icon: badges.Badge(
            showBadge: count > 0,
            badgeContent: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => Navigator.pushNamed(context, '/notifications'),
        );
      },
    );
  }
}
```

---

## API Endpoints

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | /api/notifications | verifyToken | Get current user's notifications (30-day history) |
| PATCH | /api/notifications/:id/read | verifyToken | Mark single notification as read |
| PATCH | /api/notifications/read-all | verifyToken | Mark all notifications as read |
| GET | /api/notifications/preferences | verifyToken | Get user's notification preferences |
| PUT | /api/notifications/preferences | verifyToken | Update email_enabled / push_enabled toggles |
| POST | /api/auth/fcm-token | verifyToken | Register/refresh FCM token (call on login + token refresh) |

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| FCM Legacy HTTP API (direct POST to fcm.googleapis.com) | FCM HTTP v1 API via firebase-admin SDK | 2023, legacy deprecated June 2024 | Must use firebase-admin; do not write raw HTTP to fcm.googleapis.com |
| sendMulticast() in firebase-admin | sendEachForMulticast() | firebase-admin v11+ | sendMulticast is deprecated; use sendEachForMulticast for multi-device sends |
| flutter_local_notifications auto-permission declaration | Manual permission declaration in AndroidManifest (v16+) | flutter_local_notifications v16 | Must manually add POST_NOTIFICATIONS and channel declarations |

**Deprecated/outdated:**
- FCM Legacy API (`https://fcm.googleapis.com/fcm/send` with server key): Fully shut down. Do not use.
- `admin.messaging().sendMulticast()`: Deprecated, use `sendEachForMulticast()`.
- `admin.messaging().sendToDevice()`: Deprecated, replaced by `send()` with `token` field.

---

## Firebase Android Setup Checklist

This is the most common source of setup errors. The plan must include these steps explicitly.

**android/build.gradle (project-level):**
```groovy
buildscript {
  dependencies {
    classpath 'com.google.gms:google-services:4.4.2'
  }
}
```

**android/app/build.gradle (app-level):**
```groovy
apply plugin: 'com.google.gms.google-services'

android {
  compileSdk 35
  defaultConfig {
    minSdk 21
  }
  compileOptions {
    coreLibraryDesugaringEnabled true
    sourceCompatibility JavaVersion.VERSION_17
    targetCompatibility JavaVersion.VERSION_17
  }
}

dependencies {
  coreLibraryDesugaring 'com.android.tools.build:desugaring:2.1.4'
}
```

**android/app/src/main/AndroidManifest.xml (additions):**
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
```

**Required file (from Firebase Console):**
- `android/app/google-services.json` — download from Firebase Console > Project Settings > Your apps

---

## Open Questions

1. **FCM token for web platform**
   - What we know: The app has web support (`kIsWeb` check in AppConfig). firebase_messaging supports web but requires a VAPID key from Firebase Console.
   - What's unclear: Is web notification support required in v1?
   - Recommendation: Skip web FCM for v1; focus on Android. The `getToken()` call returns null on web without a VAPID key, which is non-fatal.

2. **Notification sound and vibration customization**
   - What we know: flutter_local_notifications 21.x supports custom sounds via AndroidNotificationDetails.
   - What's unclear: Does the client want custom sounds?
   - Recommendation: Use system defaults (Importance.high) for v1. Custom sounds are a cosmetic change deferred to later.

3. **Scheduler role notifications**
   - What we know: Context specifies topics `driver_{userId}` and `scheduler_{userId}`. Overdue notifications should go to schedulers.
   - What's unclear: Does the overdue cron notify the driver, the scheduler, or both?
   - Recommendation: Notify both — driver gets "your job is overdue", scheduler gets "job X assigned to driver Y is overdue".

---

## Validation Architecture

The `.planning/config.json` does not set `workflow.nyquist_validation: false`, so this section is included.

### Test Framework

| Property | Value |
|----------|-------|
| Framework | Jest 30.x (already installed) |
| Config file | None found — uses package.json test scripts |
| Quick run command | `cd vehicle-scheduling-backend && npm test -- --testPathPattern=notifications` |
| Full suite command | `cd vehicle-scheduling-backend && npm test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| NOTIF-01 | firebase-admin initializes without error | unit | `npm test -- --testPathPattern=notificationService` | Wave 0 |
| NOTIF-02 | upcoming job query returns jobs in 10-20 min window | unit | `npm test -- --testPathPattern=notificationService` | Wave 0 |
| NOTIF-03 | overdue job query returns jobs 5+ min past end time | unit | `npm test -- --testPathPattern=notificationService` | Wave 0 |
| NOTIF-04 | email skipped when email_enabled = false | unit | `npm test -- --testPathPattern=emailService` | Wave 0 |
| NOTIF-05 | GET /api/notifications returns user's notifications scoped to tenant | integration | `npm test -- --testPathPattern=notifications.routes` | Wave 0 |
| NOTIF-05 | PATCH /api/notifications/:id/read marks notification read | integration | `npm test -- --testPathPattern=notifications.routes` | Wave 0 |
| NOTIF-06 | subscribeToTopic called with correct topic on login | unit | `npm test -- --testPathPattern=auth` | Wave 0 |
| NOTIF-07 | cron check functions are exported and callable | unit | `npm test -- --testPathPattern=cronService` | Wave 0 |

### Wave 0 Gaps

- [ ] `tests/unit/notificationService.test.js` — covers NOTIF-01, NOTIF-02, NOTIF-03, NOTIF-04
- [ ] `tests/unit/emailService.test.js` — covers NOTIF-04 (email toggle logic)
- [ ] `tests/integration/notifications.routes.test.js` — covers NOTIF-05
- [ ] Firebase Admin mock: `jest.mock('../config/firebase')` pattern needed in test files

---

## Sources

### Primary (HIGH confidence)
- `npm view firebase-admin version` — confirmed 13.7.0 (2026-03-21)
- `npm view nodemailer version` — confirmed 8.0.3 (2026-03-21)
- `npm view node-cron version` — confirmed 4.2.1 (2026-03-21)
- pub.dev firebase_messaging — confirmed 16.1.2 (published 19 days ago by firebase.google.com)
- pub.dev flutter_local_notifications — confirmed 21.0.0 (published 16 days ago by dexterx.dev)
- pub.dev badges — confirmed 3.1.2
- [Firebase Cloud Messaging — Send to Topic](https://firebase.google.com/docs/cloud-messaging/send-topic-messages) — topic message payload structure
- [Firebase Manage Topic Subscriptions](https://firebase.google.com/docs/cloud-messaging/manage-topic-subscriptions) — subscribeToTopic API
- [FlutterFire — Cloud Messaging Usage](https://firebase.flutter.dev/docs/messaging/usage/) — Flutter FCM setup, token, topic subscription patterns
- [FlutterFire — Notifications](https://firebase.flutter.dev/docs/messaging/notifications/) — foreground/background handling
- [nodemailer.com](https://nodemailer.com/) — SMTP transport configuration

### Secondary (MEDIUM confidence)
- WebSearch: "firebase-admin SDK FCM HTTP v1 sendEachForMulticast 2025" — confirmed sendMulticast deprecated, sendEachForMulticast is current API
- WebSearch: "flutter firebase_messaging foreground background 2025" — confirmed FCM blocks foreground on Android, flutter_local_notifications required
- flutter_local_notifications changelog — confirmed v16+ requires manual permission declarations

### Tertiary (LOW confidence)
- None — all critical claims verified against official sources or package registries.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all versions verified against npm registry and pub.dev on 2026-03-21
- Architecture: HIGH — patterns verified against official Firebase/FlutterFire docs
- Pitfalls: HIGH — FCM foreground suppression and permission changes verified against official changelog and docs
- Database schema: HIGH — follows established patterns from Phase 1 (tenant_id, indexes, IF NOT EXISTS)

**Research date:** 2026-03-21
**Valid until:** 2026-04-21 (stable libraries; FCM HTTP v1 API is now the only supported API so unlikely to change)
