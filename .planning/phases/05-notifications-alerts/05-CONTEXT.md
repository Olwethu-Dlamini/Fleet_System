# Phase 5: Notifications & Alerts - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase implements the full notification system: push notifications via Firebase Cloud Messaging, email notifications via nodemailer, an in-app notification center with read/unread history, and a background cron for checking upcoming and overdue jobs. All notifications respect tenant isolation.

</domain>

<decisions>
## Implementation Decisions

### Push Notifications (FCM)
- Firebase service account configured via JSON key file path in .env (FCM_SERVICE_ACCOUNT_PATH)
- Fixed 15-minute lead time for "about to start" notifications (v1)
- Overdue notification triggers 5 minutes past scheduled end time
- No retry on FCM failure for v1 — log and move on, cron catches on next cycle
- FCM topic subscriptions per user on login (driver_{userId}, scheduler_{userId})

### Email Notifications
- SMTP via nodemailer — universal, works with any provider
- Per-user boolean toggle in notification_preferences table (email_enabled)
- Simple HTML email templates with inline styles
- SMTP config via .env variables (SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS)

### In-App Notification Center
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

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/services/cronService.js` — existing cron service (Phase 3) to extend with notification checks
- `src/config/constants.js` — JOB_STATUS enum for status-based triggers
- `lib/providers/` — Provider pattern for notification state
- `lib/services/api_service.dart` — API client with auth headers

### Established Patterns
- Backend: Static service methods, pino logging
- Backend: tenant_id scoping on all queries
- Flutter: Provider + ChangeNotifier for state
- Flutter: Permission-based UI gating

### Integration Points
- Cron service: add notification check jobs alongside existing auto-transition
- Job status changes: trigger notifications on status transitions
- Flutter: firebase_messaging plugin for push handling
- Flutter: flutter_local_notifications for foreground display

</code_context>

<specifics>
## Specific Ideas

- Bell icon should show count badge only when unread > 0
- Email toggle should be accessible from user profile/settings
- Push notifications should include job title and scheduled time in the message

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
