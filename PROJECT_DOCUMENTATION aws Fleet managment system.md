# Vehicle Scheduling App — Full Project Documentation

> Everything built in this session: the dispatcher role across Flutter + Node.js, and the full AWS EC2 deployment.

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Role System](#2-role-system)
3. [Flutter Changes](#3-flutter-changes)
   - [user.dart](#31-userdart)
   - [auth_provider.dart](#32-auth_providerdart)
   - [main.dart](#33-maindart)
   - [vehicles_list_screen.dart](#34-vehicles_list_screendart)
   - [app_config.dart](#35-app_configdart)
4. [Backend Changes](#4-backend-changes)
   - [constants.js](#41-constantsjs)
   - [authController.js](#42-authcontrollerjs)
5. [AWS EC2 Deployment](#5-aws-ec2-deployment)
   - [Architecture](#51-architecture)
   - [Security Group](#52-security-group)
   - [Install MySQL on EC2](#53-install-mysql-on-ec2)
   - [Create Database and User](#54-create-database-and-user)
   - [Import Your SQL File](#55-import-your-sql-file)
   - [Docker Setup](#56-docker-setup)
   - [Environment Variables](#57-environment-variables)
   - [Deploy the API Container](#58-deploy-the-api-container)
6. [Flutter Build for Production](#6-flutter-build-for-production)
7. [Useful Commands](#7-useful-commands)
8. [Database Backups](#8-database-backups)

---

## 1. Project Overview

A mobile vehicle scheduling system with a Flutter frontend and a Node.js/Express backend connected to MySQL. Users are assigned one of four roles, each with a different set of permissions and UI tabs.

**Tech stack:**
- Flutter (Android APK)
- Node.js + Express (REST API)
- MySQL 8
- Docker (API container only)
- AWS EC2 (Ubuntu, free tier)

---

## 2. Role System

| Role | Tabs | Can Do | Cannot Do |
|---|---|---|---|
| `admin` | Dashboard, Jobs, Vehicles, Schedule, Users | Everything | — |
| `dispatcher` | Dashboard, Jobs, Vehicles, Schedule | Create/edit jobs, assign drivers, swap vehicles, view vehicles | Add/edit/delete vehicles, manage users |
| `scheduler` | Dashboard, Jobs, Vehicles, Schedule | Same as dispatcher (legacy role name) | Same as dispatcher |
| `technician` | Dashboard, My Jobs | Update job status | Everything else |

**Key design decision:** `dispatcher` is the canonical role name going forward. `scheduler` is kept only for backwards compatibility with old database rows. Both have identical permissions. The backend used to silently map `dispatcher → scheduler` — that was removed.

---

## 3. Flutter Changes

### 3.1 `user.dart`
**File:** `lib/models/user.dart`

**What changed:**
- Added `bool get isDispatcher => role == 'dispatcher'`
- Added `'dispatcher': 'Dispatcher'` to `roleDisplayName`
- `isScheduler` kept as `role == 'scheduler'` for any legacy DB rows
- `hasPermission()` unchanged — it checks the server-returned `permissions` list

```dart
bool get isAdmin       => role == 'admin';
bool get isDispatcher  => role == 'dispatcher'; // ← NEW
bool get isScheduler   => role == 'scheduler';  // legacy rows only
bool get isTechnician  => role == 'technician';

String get roleDisplayName {
  switch (role) {
    case 'admin':       return 'Administrator';
    case 'dispatcher':  return 'Dispatcher';    // ← NEW
    case 'scheduler':   return 'Scheduler';
    case 'technician':  return 'Technician';
    default:            return role;
  }
}
```

---

### 3.2 `auth_provider.dart`
**File:** `lib/providers/auth_provider.dart`

**What changed:**
- Added `bool get isDispatcher => _user?.isDispatcher ?? false`
- `hasPermission()` now simply delegates to `_user?.hasPermission()` for ALL roles — no hardcoded permission sets. The server owns the permission list.

```dart
bool get isAdmin       => _user?.isAdmin       ?? false;
bool get isDispatcher  => _user?.isDispatcher  ?? false; // ← NEW
bool get isScheduler   => _user?.isScheduler   ?? false;
bool get isTechnician  => _user?.isTechnician  ?? false;

bool hasPermission(String permission) =>
    _user?.hasPermission(permission) ?? false;
```

---

### 3.3 `main.dart`
**File:** `lib/main.dart`

**What changed:**
- Dispatcher gets 4 tabs: Dashboard | Jobs | Vehicles | Schedule (same as scheduler, no Users tab)
- Dispatcher and scheduler share the same tab list and nav items — no duplication
- FAB on Jobs tab (index 1) shows for dispatcher automatically because it checks `hasPermission('jobs:create')` which the server returns for dispatcher
- Admin still gets the 5th Users tab exclusively

```
Tab layout per role:

  admin      → Dashboard | Jobs | Vehicles | Schedule | Users
  dispatcher → Dashboard | Jobs | Vehicles | Schedule
  scheduler  → Dashboard | Jobs | Vehicles | Schedule
  technician → Dashboard | My Jobs
```

**Tab building logic:**
```dart
// Dispatcher and scheduler share the same branch
if (auth.isAdmin) {
  return [ Dashboard, Jobs, Vehicles, Schedule, Users ]; // 5 tabs
}
if (auth.isTechnician) {
  return [ Dashboard, MyJobs ]; // 2 tabs
}
// dispatcher + scheduler both fall here
return [ Dashboard, Jobs, Vehicles, Schedule ]; // 4 tabs
```

---

### 3.4 `vehicles_list_screen.dart`
**File:** `lib/screens/vehicles/vehicles_list_screen.dart`

**What changed:**
- Added `_bannerMessage()` that returns a dispatcher-specific read-only banner
- `canManage` is gated by `vehicles:create` permission — dispatcher does not have this, so Add FAB, Edit, Delete and Toggle buttons are automatically hidden with no extra code

```dart
String _bannerMessage(AuthProvider auth) {
  if (auth.isTechnician)  return 'Assigned vehicle information';
  if (auth.isDispatcher)  return 'Vehicle overview — you can view vehicles but cannot add or edit them';
  return 'Vehicle overview — contact admin to add or edit vehicles';
}

// canManage drives everything — no role checks scattered in the UI
final canManage = auth.hasPermission('vehicles:create'); // false for dispatcher
```

---

### 3.5 `app_config.dart`
**File:** `lib/config/app_config.dart`

**What to change for production:** Switch the active `baseUrl` from the local WiFi IP to the EC2 public IP.

```dart
// Add this line
static const String baseUrlProduction = 'http://<EC2_PUBLIC_IP>:3000/api';

// Change this getter
static String get baseUrl => baseUrlProduction; // was baseUrlDevice
```

> ⚠️ Do this before running `flutter build apk --release`

---

## 4. Backend Changes

### 4.1 `constants.js`
**File:** `src/config/constants.js`

**What changed:**
- Added `USER_ROLE.DISPATCHER = 'dispatcher'`
- Every permission that `scheduler` has is also granted to `dispatcher` — they are identical
- `vehicles:create/update/delete` and all `users:*` remain admin-only

```js
const USER_ROLE = {
  ADMIN     : 'admin',
  DISPATCHER: 'dispatcher', // ← NEW
  SCHEDULER : 'scheduler',  // kept for backwards compatibility
  TECHNICIAN: 'technician',
};

// Example — dispatcher mirrors scheduler on every permission:
'jobs:create': [USER_ROLE.ADMIN, USER_ROLE.DISPATCHER, USER_ROLE.SCHEDULER],
'vehicles:create': [USER_ROLE.ADMIN], // dispatcher excluded — admin only
'users:read':     [USER_ROLE.ADMIN], // dispatcher excluded — admin only
```

**Full dispatcher permission set** (what the server returns at login):
```
jobs:read, jobs:create, jobs:update, jobs:updateStatus
assignments:read, assignments:create, assignments:update, assignments:delete
vehicles:read
dashboard:read
reports:read
```

---

### 4.2 `authController.js`
**File:** `src/controllers/authController.js`

**What changed — the root cause fix:**

The `_normaliseRole()` function was mapping `dispatcher → scheduler`, destroying the role identity before permissions were computed. This was removed.

```js
// BEFORE (broken):
static _normaliseRole(dbRole) {
  const map = {
    dispatcher: USER_ROLE.SCHEDULER, // ← this was the bug
    driver    : USER_ROLE.TECHNICIAN,
    ...
  };
}

// AFTER (fixed):
static _normaliseRole(dbRole) {
  const map = {
    [USER_ROLE.ADMIN]     : USER_ROLE.ADMIN,
    [USER_ROLE.DISPATCHER]: USER_ROLE.DISPATCHER, // passes through unchanged
    [USER_ROLE.SCHEDULER] : USER_ROLE.SCHEDULER,
    [USER_ROLE.TECHNICIAN]: USER_ROLE.TECHNICIAN,
    driver: USER_ROLE.TECHNICIAN, // only legacy mapping kept
  };
  return map[dbRole] ?? dbRole;
}
```

---

## 5. AWS EC2 Deployment

### 5.1 Architecture

```
EC2 Instance (t2.micro / t3.micro — 1GB RAM)
├── MySQL 8          — installed directly on the server (NOT in Docker)
│   └── database: vehicle_scheduling
│   └── user: vsapp (app-only access)
└── Node.js API      — single Docker container
    └── connects to MySQL via localhost:3306
```

**Why MySQL is NOT in Docker on free tier:**
Running two containers on 1GB RAM causes memory pressure. MySQL alone uses 400–500MB. Installing MySQL directly on the OS saves ~200MB of Docker overhead and keeps the system stable.

---

### 5.2 Security Group

In AWS Console → EC2 → Security Groups, set these inbound rules:

| Type | Port | Source | Purpose |
|---|---|---|---|
| SSH | 22 | Your IP only | Server access |
| Custom TCP | 3000 | 0.0.0.0/0 | Flutter app API calls |
| Custom TCP | 3306 | Your IP only | Emergency DB admin (optional) |

> ⚠️ Never open port 3306 to 0.0.0.0/0

---

### 5.3 Install MySQL on EC2

```bash
# SSH in first
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>

# Install MySQL (Ubuntu)
sudo apt update
sudo apt install -y mysql-server
sudo systemctl start mysql
sudo systemctl enable mysql

# Secure the installation
sudo mysql_secure_installation
# Set root password, remove test DB, disallow remote root login
```

---

### 5.4 Create Database and User

```bash
sudo mysql -u root -p
```

```sql
-- Create the database
CREATE DATABASE vehicle_scheduling;

-- Create a dedicated app user (never connect as root from the app)
CREATE USER 'vsapp'@'localhost' IDENTIFIED BY 'your_strong_password';

-- Grant access only to this database
GRANT ALL PRIVILEGES ON vehicle_scheduling.* TO 'vsapp'@'localhost';

FLUSH PRIVILEGES;
EXIT;
```

**Why create a separate user:**
If someone finds a vulnerability in the app, they'd only have access to the `vehicle_scheduling` database — not the ability to drop other databases or modify MySQL system tables.

---

### 5.5 Import Your SQL File

```bash
# On your laptop — copy the SQL file to EC2
scp -i your-key.pem your_schema.sql ubuntu@<EC2_PUBLIC_IP>:~/

# On EC2 — import it
mysql -u vsapp -p vehicle_scheduling < ~/your_schema.sql

# Verify tables were created
mysql -u vsapp -p vehicle_scheduling -e "SHOW TABLES;"
```

---

### 5.6 Docker Setup

**`Dockerfile`** — place in backend root:
```dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm ci --only=production
COPY src/ ./src/
EXPOSE 3000
CMD ["node", "src/server.js"]
```

**`docker-compose.yml`** — single container, host network so it reaches localhost MySQL:
```yaml
services:
  api:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: vehicle_api
    restart: unless-stopped
    env_file:
      - .env
    ports:
      - "3000:3000"
    network_mode: host
```

**`.dockerignore`:**
```
node_modules
npm-debug.log
.env
.git
*.md
```

> `network_mode: host` is critical — it lets the container use the EC2's own network interface so `DB_HOST=localhost` correctly hits the MySQL installed on the server.

---

### 5.7 Environment Variables

Create `.env` in the backend root on EC2:

```bash
nano .env
```

```env
DB_HOST=localhost
DB_PORT=3306
DB_NAME=vehicle_scheduling
DB_USER=vsapp
DB_PASSWORD=your_strong_password

JWT_SECRET=generate_with_openssl_rand_hex_32
JWT_EXPIRES=8h

NODE_ENV=production
PORT=3000
```

Generate a strong JWT secret:
```bash
openssl rand -hex 32
```

> ⚠️ Never commit `.env` to git. Add it to `.gitignore`.

---

### 5.8 Deploy the API Container

```bash
# Copy your backend code to EC2 (or git clone it)
scp -i your-key.pem -r ./vehicle-scheduling-backend ubuntu@<EC2_PUBLIC_IP>:~/
# OR
git clone https://github.com/your-org/vehicle-scheduling-backend.git

cd vehicle-scheduling-backend

# Build and start
docker compose up -d --build

# Watch logs
docker compose logs -f
# Should see: "Server running on port 3000"
```

**Health check:**
```bash
curl http://localhost:3000/api/health
```

---

## 6. Flutter Build for Production

Flutter compiles to an APK — there is nothing to host. Users install the APK on their Android phones.

**Before building**, update `app_config.dart`:
```dart
static const String baseUrlProduction = 'http://<EC2_PUBLIC_IP>:3000/api';
static String get baseUrl => baseUrlProduction;
```

**Build the APK:**
```bash
flutter build apk --release
```

Output file:
```
build/app/outputs/flutter-apk/app-release.apk
```

Distribute this file to your team via WhatsApp, email, or Google Drive. Users enable "Install from unknown sources" in Android settings and install it directly.

---

## 7. Useful Commands

```bash
# ── Docker ────────────────────────────────────────────────────
docker compose ps                        # view running containers
docker compose logs -f                   # live logs (all)
docker compose logs -f api               # live logs (API only)
docker compose up -d --build api         # redeploy after code change
docker compose down                      # stop containers
docker exec -it vehicle_api sh           # shell inside API container

# ── MySQL ─────────────────────────────────────────────────────
sudo systemctl status mysql              # check MySQL is running
mysql -u vsapp -p vehicle_scheduling     # open DB shell as app user
sudo mysql -u root -p                    # open DB shell as root

# ── EC2 general ───────────────────────────────────────────────
df -h                                    # check disk space
free -m                                  # check RAM usage
```

---

## 8. Database Backups

Since data lives on the EC2 disk, back it up regularly. If the EC2 instance is terminated without a backup, all data is lost.

**Manual backup:**
```bash
mkdir -p ~/backups
mysqldump -u vsapp -p'your_password' vehicle_scheduling > ~/backups/backup_$(date +%Y%m%d).sql
```

**Automated daily backup via cron:**
```bash
crontab -e

# Add this line — runs at 2am every day:
0 2 * * * mysqldump -u vsapp -p'your_password' vehicle_scheduling > ~/backups/backup_$(date +\%Y\%m\%d).sql
```

**Optional — copy backups to S3:**
```bash
aws s3 cp ~/backups/ s3://your-bucket/db-backups/ --recursive
```

---

## Summary Table

| Component | Where | How deployed |
|---|---|---|
| Flutter app | User's Android phone | `flutter build apk --release` → distribute .apk |
| Node.js API | EC2 Docker container | `docker compose up -d --build` |
| MySQL database | EC2 server (not Docker) | `apt install mysql-server` + import SQL file |
| DB data | EC2 disk | `mysqldump` daily cron backup |
| Permissions | Server-computed at login | `constants.js` PERMISSIONS map → sent in login response |
