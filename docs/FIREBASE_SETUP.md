# Firebase Push Notification Setup

This guide walks through configuring Firebase Cloud Messaging (FCM) for push notifications in FleetScheduler Pro. Push notifications are optional -- the system works without them, falling back to in-app and email notifications only.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Firebase Console Setup](#firebase-console-setup)
3. [Android Configuration](#android-configuration)
4. [iOS Configuration](#ios-configuration)
5. [Backend Configuration](#backend-configuration)
6. [How Notifications Flow](#how-notifications-flow)
7. [Notification Types](#notification-types)
8. [Testing Notifications](#testing-notifications)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- A Google account with access to [Firebase Console](https://console.firebase.google.com)
- The Flutter app source code (`vehicle_scheduling_app/`)
- Access to the backend server environment variables

The Flutter app already includes the required Firebase packages:
- `firebase_core: ^3.13.0`
- `firebase_messaging: ^15.2.5`
- `flutter_local_notifications: ^18.0.1`

---

## Firebase Console Setup

### 1. Create a Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add project**
3. Enter a project name (e.g., "FleetScheduler Pro")
4. Optionally enable Google Analytics
5. Click **Create project**

### 2. Add Android App

1. In your Firebase project, click **Add app** and select the Android icon
2. Enter the Android package name: `com.example.vehicle_scheduling_app`
   - Find this in `vehicle_scheduling_app/android/app/build.gradle` under `applicationId`
3. Enter an app nickname (e.g., "FleetScheduler Android")
4. (Optional) Enter the SHA-1 signing certificate fingerprint
5. Click **Register app**
6. Download `google-services.json`
7. Place it in `vehicle_scheduling_app/android/app/google-services.json`

### 3. Add iOS App (Optional)

1. In your Firebase project, click **Add app** and select the iOS icon
2. Enter the iOS bundle ID from `vehicle_scheduling_app/ios/Runner.xcodeproj`
3. Enter an app nickname (e.g., "FleetScheduler iOS")
4. Click **Register app**
5. Download `GoogleService-Info.plist`
6. Place it in `vehicle_scheduling_app/ios/Runner/GoogleService-Info.plist`

---

## Android Configuration

After placing `google-services.json` in `android/app/`:

1. Verify `android/build.gradle` includes the Google services classpath:
   ```gradle
   buildscript {
     dependencies {
       classpath 'com.google.gms:google-services:4.4.0'
     }
   }
   ```

2. Verify `android/app/build.gradle` applies the plugin:
   ```gradle
   apply plugin: 'com.google.gms.google-services'
   ```

3. Ensure minimum SDK version is 21 or higher in `android/app/build.gradle`:
   ```gradle
   minSdkVersion 21
   ```

---

## iOS Configuration

After placing `GoogleService-Info.plist` in `ios/Runner/`:

1. Open `ios/Runner.xcworkspace` in Xcode
2. Enable Push Notifications capability:
   - Select the Runner target
   - Go to **Signing & Capabilities**
   - Click **+ Capability**
   - Add **Push Notifications**
3. Enable Background Modes:
   - Add **Background Modes** capability
   - Check **Background fetch** and **Remote notifications**

---

## Backend Configuration

The backend uses the Firebase Admin SDK to send push notifications server-side.

### 1. Generate a Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com) and select your project
2. Click the gear icon and go to **Project settings**
3. Select the **Service accounts** tab
4. Click **Generate new private key**
5. Save the downloaded JSON file to a secure location on your server
   - Example: `/etc/fleet-scheduler/firebase-service-account.json`
   - **Never commit this file to version control**

### 2. Set the Environment Variable

Add the path to your `.env` file:

```bash
FCM_SERVICE_ACCOUNT_PATH=/etc/fleet-scheduler/firebase-service-account.json
```

### 3. Restart the Backend

```bash
npm run dev  # or npm start in production
```

On startup you should see in the logs:

```
Firebase Admin SDK initialized
```

If the path is missing or invalid, the server still starts but logs a warning:

```
FCM_SERVICE_ACCOUNT_PATH not set -- Firebase Admin not initialized (FCM push disabled)
```

---

## How Notifications Flow

The notification system has three layers:

### 1. Cron Service (Automated Triggers)

The backend runs a cron job every minute (`cronService.js`) that:

- **Checks for upcoming jobs** -- Finds jobs starting in 10-20 minutes (targeting ~15 min lead time)
- **Checks for overdue jobs** -- Finds jobs that should have ended 5+ minutes ago but are still in progress
- **Deduplicates** -- Skips if the same job+user+type was already notified within 20 minutes

### 2. Notification Service (Delivery)

When a notification is triggered (`notificationService.js`):

1. **Database record** -- Inserts a row into the `notifications` table (always happens)
2. **FCM push** -- Sends an FCM topic notification to the driver's topic (e.g., `driver_42`)
   - Fails gracefully if Firebase is not configured
   - No retry on failure (logged and skipped per design decision)
3. **Email** -- Sends an email notification via SMTP if the user has email notifications enabled in their preferences
   - Respects the `email_enabled` flag in `notification_preferences`

### 3. Frontend (Display)

The Flutter app handles notifications through:

- **Firebase Messaging** -- Receives FCM pushes via `firebase_messaging` package
- **Foreground notifications** -- Shows local notification banners via `flutter_local_notifications`
- **Notification bell** -- The `NotificationBell` widget polls `/api/notifications/unread-count` and shows a badge count
- **Notification center** -- Tapping the bell opens the notification list screen
- **Deep linking** -- Tapping a notification navigates to the relevant screen (job detail, time extension, etc.)

### 4. Manual Triggers

Notifications are also created when:

- A technician requests a time extension (notifies schedulers)
- A scheduler approves or denies a time extension (notifies the requesting technician)
- Job status changes (via the status transition service)

---

## Notification Types

| Type                       | Trigger                                    | Recipients            | Timing                     |
|----------------------------|--------------------------------------------|-----------------------|----------------------------|
| `job_starting_soon`        | Cron detects job starting in ~15 min       | Assigned technician   | 10-20 min before start     |
| `job_overdue`              | Cron detects job past scheduled end time   | Assigned technician   | 5+ min after scheduled end |
| `time_extension_requested` | Technician submits extension request       | Admin/scheduler users | Immediately                |
| `time_extension_approved`  | Scheduler approves extension request       | Requesting technician | Immediately                |
| `time_extension_denied`    | Scheduler denies extension request         | Requesting technician | Immediately                |

### FCM Topic Naming

Notifications are sent to FCM topics based on the user's role and ID:

- Technician/driver: `driver_{user_id}` (e.g., `driver_42`)
- Scheduler: `scheduler_{user_id}` (e.g., `scheduler_7`)

The Flutter app subscribes to the appropriate topic on login.

---

## Testing Notifications

### Verify Backend Configuration

1. Check the server startup logs for Firebase initialization:
   ```
   Firebase Admin SDK initialized
   ```

2. Test the notification service by creating a job scheduled ~15 minutes from now with an assigned technician. Within one cron cycle (1 minute), a `job_starting_soon` notification should appear.

### Verify Frontend Configuration

1. Log in as a technician user in the Flutter app
2. Check the notification bell icon in the app bar
3. Navigate to the notification center to see existing notifications
4. Trigger a new notification (e.g., create a job starting soon)

### Send a Test Push (Firebase Console)

1. Go to Firebase Console > Cloud Messaging
2. Click **Send your first message**
3. Enter a title and body
4. Target a topic (e.g., `driver_1`)
5. Click **Send test message**

---

## Troubleshooting

### "FCM_SERVICE_ACCOUNT_PATH not set"

**Cause:** The `FCM_SERVICE_ACCOUNT_PATH` environment variable is not set in `.env`.

**Fix:** Add the path to your Firebase service account JSON file:
```bash
FCM_SERVICE_ACCOUNT_PATH=/path/to/firebase-service-account.json
```

### "Firebase Admin init failed"

**Cause:** The service account JSON file is missing, has incorrect permissions, or contains invalid credentials.

**Fix:**
1. Verify the file exists at the specified path
2. Verify the file is valid JSON (download a fresh one from Firebase Console if needed)
3. Verify the Node.js process has read access to the file

### "Firebase Admin not initialized -- skipping FCM push"

**Cause:** Firebase Admin SDK was not initialized (either path not set or init failed).

**Fix:** Check the earlier startup logs for the root cause (usually one of the above two issues).

### "FCM initialization skipped" (Flutter)

**Cause:** The `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) file is missing or misconfigured.

**Fix:**
1. Verify `google-services.json` is in `vehicle_scheduling_app/android/app/`
2. Verify the package name in the JSON matches your `applicationId`
3. Run `flutter clean && flutter pub get` and rebuild

### Notifications not appearing on device

**Checklist:**
1. Is the backend FCM configured? (Check startup logs)
2. Is the Flutter app subscribed to the correct FCM topic? (Check login flow)
3. Are push permissions granted on the device? (Check device notification settings)
4. Is the app in the foreground? (Foreground notifications use `flutter_local_notifications`)
5. Are notification preferences enabled for the user? (Check `/api/notifications/preferences`)

### Email notifications not sending

**Cause:** SMTP is not configured or credentials are wrong.

**Fix:**
1. Set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, and `SMTP_PASS` in `.env`
2. Verify your SMTP provider allows the connection (check firewall, IP whitelist, app passwords)
3. Check server logs for SMTP error details
