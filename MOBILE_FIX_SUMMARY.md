# Mobile Connection Fix — Summary

## Problem
App was working on laptop browser but not on the phone.
Server was running fine, AWS Security Group was correct (port 3000 open to 0.0.0.0/0).

## Root Cause
Mobile data carriers (MTN, Vodacom, etc.) block non-standard ports like 3000.
They only allow port **80** (HTTP) and **443** (HTTPS) by default.
The laptop worked because it was on WiFi/direct connection with no carrier filtering.

---

## Fix 1 — docker-compose.yml (on EC2)

Map port 80 on the host to port 3000 inside the container.
The app still runs on 3000 internally — only the external port changes.

```yaml
# Before
ports:
  - "3000:3000"

# After
ports:
  - "80:3000"
```

Apply the change:
```bash
cd ~/fleet/Fleet_System/vehicle-scheduling-backend
docker compose up -d
```

---

## Fix 2 — app_config.dart (Flutter)

Remove `:3000` from the URL — port 80 is the default for HTTP so no port needed.

```dart
// Before
static const String baseUrlDevice = 'http://3.231.191.15:3000/api';

// After
static const String baseUrlDevice = 'http://3.231.191.15/api';
```

---

## Fix 3 — AndroidManifest.xml (Flutter)

Added `android:usesCleartextTraffic="true"` to allow plain HTTP on Android 9+.
Without this Android blocks all non-HTTPS traffic by default.

```xml
<application
    android:label="vehicle_scheduling_app"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:usesCleartextTraffic="true">   ← this line added
```

---

## Fix 4 — pubspec.yaml (Flutter)

Added `flutter_launcher_icons` correctly:
- Moved the package to `dev_dependencies` (was missing)
- Moved the `flutter_launcher_icons:` config block to root level (was wrongly nested inside `flutter:`)
- Added `- assets/icon/` to the assets list

```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1   # ← added here

flutter_launcher_icons:             # ← root level, not inside flutter:
  android: true
  ios: false
  image_path: "assets/icon/app_icon.png"
  min_sdk_android: 21
  adaptive_icon_background: "#2196F3"
  adaptive_icon_foreground: "assets/icon/app_icon.png"
```

To generate icons and build:
```bash
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
```

---

## Database — vsapp User Removed

Decided to use `root` directly instead of a separate `vsapp` user for simplicity on free tier.

```sql
DROP USER 'vsapp'@'localhost';
FLUSH PRIVILEGES;
```

`.env` updated accordingly:
```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=          # blank or your root password
DB_NAME=vehicle_scheduling
```

---

## SQL File Import

Copied the local SQL file to EC2 and imported it:

```bash
# From laptop
scp -i "your-key.pem" "C:/Users/olwethu/Downloads/vehicle_scheduling.sql" ubuntu@<EC2_PUBLIC_IP>:~/

# On EC2
sudo mysql -u root vehicle_scheduling < ~/vehicle_scheduling.sql

# Verify
sudo mysql -u root vehicle_scheduling -e "SHOW TABLES;"
```

---

## Final State

| Component | Status |
|---|---|
| MySQL | Running directly on EC2 |
| Node.js API | Running in Docker, exposed on port 80 |
| Flutter APK | Built with EC2 IP, cleartext traffic enabled, port 80 |
| App icon | Configured via flutter_launcher_icons |
| Mobile data | Works — carrier port blocking resolved by switching to port 80 |
