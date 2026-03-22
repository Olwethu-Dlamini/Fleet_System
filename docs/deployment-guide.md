# FleetScheduler Pro — Deployment Guide

This guide explains how to deploy the full FleetScheduler Pro stack (MySQL + Node.js API) from a fresh clone to a production-ready server using Docker Compose.

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Docker | 24.x+ | [Install Docker](https://docs.docker.com/get-docker/) |
| Docker Compose | 2.x+ | Included with Docker Desktop; install separately on Linux |
| Git | Any | For cloning the repository |
| Domain name | Optional | Required only for SSL/HTTPS |

Verify your installation:
```bash
docker --version
docker compose version
git --version
```

---

## Quick Start

Get the full stack running in 5 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/your-org/fleet-scheduler-pro.git
cd fleet-scheduler-pro

# 2. Copy the environment template
cp vehicle-scheduling-backend/.env.example .env

# 3. Set the required JWT secret (mandatory — server won't start without it)
# Generate a secure random key:
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
# Then edit .env and set JWT_SECRET=<generated-key>

# 4. Start the full stack in detached mode
docker-compose up -d

# 5. Verify both services are running
docker-compose ps

# API should be available at:
# http://localhost:3000/api/health
# Swagger UI at:
# http://localhost:3000/swagger
```

The `db` service starts first and runs the healthcheck. The `api` service waits until MySQL is healthy before connecting. Initial startup takes 30-60 seconds on first run while MySQL initialises.

---

## Database Setup

### Automatic Initialisation

The database schema is **automatically loaded** on first startup. The `docker-compose.yml` mounts `vehicle_scheduling.sql` as an init script:

```yaml
volumes:
  - ./vehicle_scheduling.sql:/docker-entrypoint-initdb.d/01-schema.sql
```

This runs once when the `mysql_data` Docker volume is empty. Subsequent starts skip it (the volume already exists).

### Importing Test Data

For presentations or development, import the test dataset:

```bash
# Copy the test SQL file into the running container and import it
docker-compose exec db mysql -u fleetuser -pfleetpass vehicle_scheduling < vehicle_scheduling2.sql
```

### Resetting the Database

To wipe the database and re-run the schema:

```bash
docker-compose down -v   # -v removes the mysql_data volume
docker-compose up -d     # Re-creates volume and re-runs init scripts
```

---

## Configuration

All configuration is done via environment variables in the `.env` file at the project root. Docker Compose automatically reads this file.

See [environment-variables.md](./environment-variables.md) for the complete reference with defaults, descriptions, and examples.

**Minimum required configuration:**

```ini
# .env — minimum required
JWT_SECRET=your-very-long-random-secret-here
```

**Optional but recommended for production:**

```ini
DB_ROOT_PASSWORD=strong-root-password
DB_USER=fleetuser
DB_PASSWORD=strong-db-password
NODE_ENV=production
LOG_LEVEL=info
```

---

## Production Deployment

### 1. Switch to Production Mode

The Dockerfile currently uses `npm run dev` (nodemon) as the CMD. For production, override this in docker-compose.yml:

```yaml
# docker-compose.yml — add to the api service
services:
  api:
    ...
    command: ["npm", "start"]
```

Or set `NODE_ENV=production` in your `.env` and modify the Dockerfile CMD:

```dockerfile
# vehicle-scheduling-backend/Dockerfile — change the last line
CMD ["npm", "start"]
```

### 2. Set Production Environment Variables

```ini
# .env
NODE_ENV=production
JWT_SECRET=<64-byte-random-hex>
DB_ROOT_PASSWORD=<strong-password>
DB_USER=fleetuser
DB_PASSWORD=<strong-password>
JWT_EXPIRES=8h
```

### 3. Reverse Proxy with Nginx

Use Nginx to terminate SSL and proxy to the API container. Install Nginx on the host:

```bash
sudo apt update && sudo apt install nginx
```

Create `/etc/nginx/sites-available/fleetscheduler`:

```nginx
server {
    listen 80;
    server_name api.yourdomain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name api.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/api.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/fleetscheduler /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

### 4. SSL with Let's Encrypt

```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com
```

Certbot automatically renews the certificate. Verify renewal:
```bash
sudo certbot renew --dry-run
```

---

## Flutter App Configuration

### Point the App to Your Production Server

Edit `vehicle_scheduling_app/lib/config/app_config.dart`:

```dart
class AppConfig {
  static const String baseUrl = 'https://api.yourdomain.com/api';
  // Change from: 'http://localhost:3000/api'
}
```

### Building the APK

```bash
cd vehicle_scheduling_app

# Get dependencies
flutter pub get

# Build a release APK
flutter build apk --release

# The APK is at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Building for iOS (macOS only)

```bash
flutter build ios --release
# Then use Xcode to archive and distribute
```

---

## Backup and Maintenance

### Database Backup

Back up the MySQL data using `mysqldump` inside the running container:

```bash
# Create a timestamped backup
docker-compose exec db mysqldump \
  -u fleetuser -pfleetpass \
  vehicle_scheduling > backup_$(date +%Y%m%d_%H%M%S).sql
```

Automate daily backups with cron:
```bash
# Add to crontab: crontab -e
0 2 * * * cd /opt/fleet-scheduler && docker-compose exec -T db mysqldump -u fleetuser -pfleetpass vehicle_scheduling > /backups/fleet_$(date +\%Y\%m\%d).sql
```

### Docker Volume Management

```bash
# List volumes
docker volume ls

# Inspect the data volume
docker volume inspect fleet-scheduler-pro_mysql_data

# Remove unused volumes (be careful — this deletes data)
docker volume prune
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# API only
docker-compose logs -f api

# Last 100 lines
docker-compose logs --tail=100 api
```

---

## Troubleshooting

### API container exits immediately

**Symptom:** `docker-compose ps` shows `api` as exited.

**Cause:** `JWT_SECRET` is missing.

**Fix:** Add `JWT_SECRET=<your-secret>` to `.env` and restart:
```bash
docker-compose up -d
docker-compose logs api  # Should show "Server running on port 3000"
```

---

### Database connection refused

**Symptom:** API logs show `ECONNREFUSED` or `ER_ACCESS_DENIED_ERROR`.

**Cause:** MySQL is still initialising or credentials mismatch.

**Fix:** Wait for the healthcheck to pass (up to 60s on first start), then check credentials:
```bash
docker-compose ps  # db should show "(healthy)"
# Verify DB_USER and DB_PASSWORD match in .env
```

---

### Email notifications not sending

**Symptom:** No emails delivered, no errors in logs.

**Cause:** `SMTP_HOST` is not configured.

**Fix:** Set `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, and `SMTP_PASS` in `.env`. Email is intentionally optional — the server does not treat missing SMTP config as an error.

---

### Push notifications not working

**Symptom:** FCM push not delivered.

**Cause:** `FCM_SERVICE_ACCOUNT_PATH` not set or file not found.

**Fix:**
1. Download Firebase service account JSON from Firebase Console.
2. Place it on the server (e.g., `/opt/secrets/firebase.json`).
3. Set `FCM_SERVICE_ACCOUNT_PATH=/opt/secrets/firebase.json` in `.env`.
4. Restart: `docker-compose up -d api`

---

### GPS directions return 500

**Symptom:** `GET /api/gps/directions` returns `Failed to fetch directions`.

**Cause:** `GOOGLE_MAPS_API_KEY` not set or Routes API not enabled.

**Fix:** Set `GOOGLE_MAPS_API_KEY` in `.env` and ensure the **Routes API** is enabled in the Google Cloud Console for your key.

---

### Swagger UI shows "Failed to fetch"

**Symptom:** Swagger UI loads but all requests fail.

**Cause:** Swagger UI is blocked by browser CORS if accessed from a different origin.

**Fix:** Access Swagger at `http://localhost:3000/swagger` when testing locally, or configure your Nginx reverse proxy to include the API's domain in the Swagger server URL.

---

## Updating

```bash
# 1. Pull the latest code
git pull origin main

# 2. Rebuild the API container (picks up dependency changes)
docker-compose build api

# 3. Restart the stack (zero-downtime restart of API, DB unaffected)
docker-compose up -d

# 4. Verify the update
docker-compose ps
docker-compose logs --tail=20 api
```

If the database schema changed, import the new migration SQL:
```bash
docker-compose exec db mysql -u fleetuser -pfleetpass vehicle_scheduling < migrations/YYYYMMDD_description.sql
```
