# Environment Variables Reference

Complete reference for all environment variables used by the FleetScheduler Pro API server.

---

## Server Configuration

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `PORT` | No | `3000` | TCP port the Express server listens on | `3000` |
| `NODE_ENV` | No | `development` | Runtime environment. Affects logging, error detail in responses, and pino-pretty output | `production` |
| `LOG_LEVEL` | No | `info` (prod) / `debug` (dev) | Pino log level: `trace`, `debug`, `info`, `warn`, `error`, `fatal` | `info` |

**Notes:**
- In production (`NODE_ENV=production`), logs are emitted as raw JSON suitable for log shipping (Datadog, Loki, CloudWatch).
- In development, `pino-pretty` formats logs for human readability.

---

## Database

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `DB_HOST` | No | `localhost` | MySQL server hostname. Use `db` when running inside Docker Compose | `db` |
| `DB_PORT` | No | `3306` | MySQL port | `3306` |
| `DB_NAME` | No | `vehicle_scheduling` | MySQL database name | `vehicle_scheduling` |
| `DB_USER` | No | `root` | MySQL username | `fleetuser` |
| `DB_PASSWORD` | No | _(empty)_ | MySQL password | `fleetpass` |
| `DB_ROOT_PASSWORD` | No | `changeme` | MySQL root password (Docker Compose only, not used by the API) | `changeme` |

**Notes:**
- The connection pool maintains up to 10 simultaneous connections.
- All dates/timestamps are stored and returned in UTC (`timezone: '+00:00'`).
- `GROUP_CONCAT` length is increased to 65,536 bytes per connection to handle large technician lists.

---

## Authentication

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `JWT_SECRET` | **Yes** | — | Secret key for signing JWT tokens. The server **will not start** without this variable set. Must be a long random string. | `a94f5374...` |
| `JWT_EXPIRES` | No | `8h` | JWT token expiry in [zeit/ms](https://github.com/vercel/ms) format | `8h`, `1d`, `7d` |

**Generating a secure JWT_SECRET:**
```bash
node -e "console.log(require('crypto').randomBytes(64).toString('hex'))"
```

**Notes:**
- `JWT_SECRET` is validated at startup — the server exits with a clear error if it is missing.
- Tokens carry `userId`, `role`, and `tenant_id` in the payload.

---

## Email (SMTP)

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `SMTP_HOST` | No | — | SMTP server hostname. Email notifications are **disabled** when this is not set | `smtp.sendgrid.net` |
| `SMTP_PORT` | No | `587` | SMTP port (587 = STARTTLS, 465 = SSL/TLS, 25 = plain) | `587` |
| `SMTP_USER` | No | — | SMTP authentication username | `apikey` |
| `SMTP_PASS` | No | — | SMTP authentication password or API key | `SG.xxxx...` |

**Notes:**
- When `SMTP_HOST` is not configured, email notification dispatch is silently skipped.
- In-app notifications are always created regardless of SMTP configuration.
- Compatible with any SMTP provider: SendGrid, Mailgun, Gmail (app password), AWS SES.

---

## Firebase Cloud Messaging (Push Notifications)

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `FCM_SERVICE_ACCOUNT_PATH` | No | — | Absolute path to the Firebase Admin SDK service account JSON file. Push notifications are **disabled** when not set | `/app/secrets/firebase.json` |

**Obtaining the service account JSON:**
1. Open [Firebase Console](https://console.firebase.google.com)
2. Navigate to **Project Settings > Service accounts**
3. Click **Generate new private key**
4. Save the downloaded JSON file securely (never commit it)

**Notes:**
- The server starts normally without FCM configured — push is optional.
- Notification failures (FCM or email) are logged as warnings and never block the primary operation.
- FCM topic naming: `driver_{userId}` for technicians/drivers, `scheduler_{userId}` for admin/scheduler.

---

## Google Maps

| Variable | Required | Default | Description | Example |
|----------|----------|---------|-------------|---------|
| `GOOGLE_MAPS_API_KEY` | No | — | Google API key with **Routes API v2** enabled. Used server-side only for directions proxy. GPS directions feature is **disabled** when not set | `AIzaSy...` |

**Required Google Cloud APIs:**
- Routes API (for directions and ETA)

**Notes:**
- The key is used exclusively server-side — it is never sent to the Flutter client.
- When not configured, `GET /api/gps/directions` returns a 500 error for requests requiring directions.
- Restrict the key to your server's IP address and only the Routes API in the Google Cloud Console.

---

## Feature Availability Summary

| Feature | Enabled when |
|---------|-------------|
| Core API (jobs, vehicles, users) | Always |
| Push notifications | `FCM_SERVICE_ACCOUNT_PATH` is set |
| Email notifications | `SMTP_HOST` is set |
| GPS directions | `GOOGLE_MAPS_API_KEY` is set |
| Detailed error responses | `NODE_ENV=development` |
| Formatted log output | `NODE_ENV != production` |
