# Feature Landscape: Field Service Management & Vehicle Scheduling

**Domain:** Field Service Management (FSM) / Vehicle Scheduling SaaS
**Researched:** 2026-03-21
**Confidence:** MEDIUM — based on training knowledge of ServiceTitan, Jobber, Housecall Pro, FieldPulse, and Samsara (cutoff August 2025). WebSearch unavailable. Claims grounded in platform documentation, published UX teardowns, and known industry patterns. Verify specific UI details against current platform screenshots before treating as authoritative.

---

## 1. Job Notifications — How Competitors Handle It

### 1.1 ServiceTitan

ServiceTitan is the most feature-rich FSM platform and sets the ceiling for notification UX.

**Notification channels:** Push (mobile app), SMS (to customer and technician), email, in-app bell icon.

**Trigger model:** Event-driven. Notifications fire on specific state transitions:
- Job created → dispatcher notified
- Job assigned → technician push + SMS
- Job status changes (pending → in_progress → completed) → admin/scheduler sees update in real time
- Job nearing start window (15 min, 30 min, 1 hour — configurable) → technician reminder push
- Job overdue (scheduled_time_end passed, still in_progress) → escalation push to dispatcher

**Customer-facing:** ServiceTitan sends automated appointment reminder SMS/email to the customer at configurable intervals (24h before, 2h before). This is a paid-tier feature. We are NOT building a customer portal in v1, so file this under future scope.

**Dispatcher control:** Schedulers can see a notification badge count. "Overdue" jobs surface as a red badge in the dispatcher view. There is no way to mute individual technician notifications — muting is all-or-nothing per notification type.

**Key UX pattern to replicate:** The two-tier alert. First alert is informational ("job starts in 30 min"). Second alert is urgent ("job is overdue — take action"). These use different visual treatments: amber for informational, red with persistent banner for overdue.

### 1.2 Jobber

Jobber targets small-to-medium service businesses and is notable for clean UX over feature depth.

**Notification channels:** Push, email, in-app. No native SMS (uses third-party integrations via Zapier).

**Trigger model:**
- New job assigned to field worker → immediate push
- "On my way" tap → notifies customer (customer-facing, out of our scope)
- Job completed → office notified via push + email digest

**Notification preferences:** Jobber allows per-user notification preferences. Each user toggles: new assignments, schedule changes, and reminders. This is per-user, not per-role.

**Key UX pattern:** Jobber's "Schedule Change Alert" is the most relevant for us. When a dispatcher moves a job's time, the assigned field worker immediately receives a push with the old time and new time side-by-side: "JOB-001 moved from 09:00 to 11:00." Actionable, no noise.

### 1.3 Housecall Pro

**Notification channels:** Push, SMS (included in all plans), email.

**Trigger model:**
- New job → technician push + SMS (simultaneously)
- Reminder set at job creation (default 1h before, adjustable per job)
- Job completion → photo-proof triggers auto-confirmation email to office

**Differentiator:** Housecall Pro has "HQ" — a notification center with a history feed sorted by recency. Each notification is tappable and deep-links into the relevant job record. There is a "mark all read" button. Unread count appears as a badge on the app icon.

**Key UX pattern:** The in-app notification center with deep-link navigation. This is the pattern we should build. User taps notification → lands directly on that job's detail screen, not the jobs list.

### 1.4 FieldPulse

FieldPulse is the closest competitor to our target market (small fleet, tight budget).

**Notification channels:** Push and email. SMS is an add-on.

**Trigger model:** FieldPulse uses a simpler "alert" model:
- New assignment → push
- Status change → push to supervisor
- No native time-based reminders (reminders via Google Calendar integration)

**Weakness:** FieldPulse's notification preferences are role-wide, not per-user. If you are a dispatcher, you get all dispatcher notifications with no granularity. This is a gap we can fill.

### 1.5 Recommended Notification Architecture for This Project

Map the required features (NOTIF-01 through NOTIF-04) to these patterns:

| Requirement | Pattern Source | Design Decision |
|-------------|---------------|-----------------|
| NOTIF-01: Job start push | ServiceTitan / Housecall Pro | FCM push, 30 min before scheduled_time_start |
| NOTIF-02: Overdue push | ServiceTitan | Fire when current_time > scheduled_time_end AND status = in_progress. Two-tier: amber at scheduled_time_end, red at +30 min |
| NOTIF-03: Email toggle | Jobber | Per-user preference stored in DB. Email via SendGrid or Resend, not SMTP directly |
| NOTIF-04: In-app center | Housecall Pro | Persistent bell icon with unread badge. History feed, sorted newest-first. Tapping any entry deep-links to that job |

**Implementation approach for FCM:**
- Backend fires FCM via the `firebase-admin` SDK on status-change events and cron-triggered reminders
- Store a `fcm_token` field on the `users` table, populated by the Flutter app on login via `FirebaseMessaging.instance.getToken()`
- Cron job runs every 5 minutes checking for jobs where `scheduled_time_end < NOW()` and `status = 'in_progress'`
- All notification events should be stored in a `notifications` table (`id`, `user_id`, `job_id`, `type`, `message`, `read_at`, `created_at`) to power the in-app center

---

## 2. Time Extension / Job Overrun Workflows

### 2.1 How Competitors Handle Overruns

**ServiceTitan:** No native "request more time" button. Technicians call the dispatcher verbally. The dispatcher manually edits the job's scheduled end time. The system then re-checks for downstream conflicts and surfaces a conflict warning modal. This is considered a known gap by ServiceTitan users.

**Jobber:** Has a "time tracking" feature where workers log actual hours. If actual time exceeds estimated time, the job card visually flags the overrun with an amber timer icon. The scheduler must manually adjust. No automated impact analysis.

**Samsara (fleet-focused):** Samsara tracks actual vs scheduled drive time. When a driver is running late to the next stop, the dispatcher receives an ETA alert showing "Driver is 20 min behind schedule." This is the closest to an automated overrun workflow.

**FieldPulse:** No overrun workflow. Manual.

### 2.2 The Gap We Can Fill

None of the major competitors have a purpose-built "time extension request" workflow that:
1. Lets the technician request more time in-app with a reason
2. Calculates downstream impact automatically
3. Suggests rescheduling options
4. Routes to scheduler for approval

This is a genuine differentiator. The requirements (TIME-01 through TIME-05) map to an underserved workflow.

### 2.3 Recommended UX Pattern

**Technician side (mobile):**

When a job is `in_progress` and current time is within 15 minutes of `scheduled_time_end`, show a non-intrusive amber banner:
> "This job ends at 14:00. Need more time?"  [Request Extension]

Tapping "Request Extension" opens a bottom sheet with:
- Duration picker: +15 min / +30 min / +1 hour / Custom
- Reason field (required, free text, max 200 chars)
- [Submit Request] button

The request goes to `pending_extension` state. The job card shows a pulsing amber indicator.

**Scheduler side (dashboard):**

A prominent alert card appears in the scheduler's notification center AND as an inline banner on the affected job card:
> "JOB-2026-0042 — Alice requested +30 min. Reason: 'Installation more complex than expected.'"
> [Approve] [Deny] [View Impact]

"View Impact" opens a modal showing:
- Which other jobs this driver/vehicle has scheduled after this one
- The new projected completion time
- A list of 2-3 rescheduling suggestions for the next job (e.g., "Push JOB-2026-0043 to 15:30 — Bob is free at 15:30")

Approving saves the new `scheduled_time_end` to the database and notifies the driver. Denying sends a push: "Extension not approved. Complete by 14:00."

**Database additions required:**
- `time_extension_requests` table: `id`, `job_id`, `requested_by`, `requested_minutes`, `reason`, `status` (pending/approved/denied), `reviewed_by`, `created_at`
- Add `actual_time_end` column to `jobs` table for post-completion reporting

---

## 3. Load Balancing and Smart Assignment UX

### 3.1 How Competitors Visualize Driver Workload

**ServiceTitan — Dispatch Board:**
The dispatch board is ServiceTitan's crown jewel. It is a Gantt-style timeline view where:
- Rows = technicians (or vehicles)
- X-axis = time (day view default, week view available)
- Job blocks are color-coded by job type (installation = blue, maintenance = green, emergency = red)
- Each technician row shows a "utilization bar" — a thin colored strip at the top of the row that fills from left to right as jobs are added. 100% filled = fully booked.
- Unassigned jobs appear in a sidebar panel on the left, draggable onto the board

**Workload indicator:** ServiceTitan shows a utilization percentage next to each tech name: "Alice — 85%". Clicking opens a detail pane with job breakdown.

**Jobber:**
Jobber uses a simpler calendar view. Technician names appear as column headers in a week grid. Jobs appear as blocks. No explicit workload percentage — you judge load by visual density. There is a "team schedule" filter to show one technician at a time.

**Housecall Pro:**
Housecall Pro's scheduling UI is the most polished for small teams. The "board view" shows:
- Technician avatars as column headers
- Jobs stacked vertically by time
- A small colored dot under each avatar: green = light load (1-2 jobs), amber = moderate (3-4), red = heavy (5+)
- Hovering the dot shows a tooltip: "3 jobs today, 6.5 estimated hours"

**FieldPulse:**
Basic calendar. No load indicators. Assignment is entirely manual with no system guidance.

### 3.2 Recommended Load Balancing UX for This Project

Map to requirements ASGN-01 through ASGN-04:

**Driver selection panel during assignment:**

When a scheduler opens the "Assign Job" dialog, the driver picker should NOT be a plain dropdown. It should show a list of driver cards, each containing:

```
[ Avatar ] Alice Johnson           [TODAY: 3 jobs | 5h 30m]
           Fleet Driver             [TOTAL: 247 jobs]
           ● ● ●                   (3 colored job dots for today)
```

Visual treatment:
- Drivers with 0-2 jobs today: card has a soft green left border glow
- Drivers with 3-4 jobs: amber left border glow
- Drivers with 5+ jobs: red left border glow (but still selectable, with a warning)
- The "recommended" driver (fewest jobs in that time window) gets a subtle "Suggested" chip

Sorting: Default sort is ascending by job count (least busy first). Scheduler can re-sort by name or total historical jobs.

**Load calculation logic (backend):**
- "Jobs today" = count of non-cancelled, non-completed jobs for that driver on the selected `scheduled_date`
- "Hours today" = sum of `estimated_duration_minutes` for those jobs
- "Total jobs" = count of all `completed` jobs ever for that driver
- These should be computed in the `/api/users?role=technician&date=YYYY-MM-DD` endpoint so the frontend just renders what it receives

**Driver conflict check:**
- Before assignment, check for time overlap (existing logic via `409` response)
- If conflict exists, show inline warning on the driver card: "Booked 09:00-11:00" rather than waiting for the API to reject

---

## 4. Vehicle Maintenance Scheduling Patterns

### 4.1 How Competitors Handle Maintenance

**Samsara (fleet-specific):**
Samsara has the most complete maintenance module. Key patterns:
- "Maintenance Reminders" based on mileage, engine hours, or calendar date
- When a vehicle enters "Scheduled Maintenance" status, it is automatically excluded from the dispatch board for the specified date range
- Maintenance history log per vehicle with technician notes
- Dashboard widget: "X vehicles due for maintenance this week"

**ServiceTitan:**
ServiceTitan treats maintenance scheduling as a job type ("maintenance visit" job). There is no dedicated "vehicle out of service" toggle — teams work around it by marking the vehicle as a "non-billable job" placeholder.

**Fleetio (fleet management SaaS):**
Fleetio is purpose-built for this. Patterns:
- Maintenance "Work Orders" with status (scheduled / in_progress / completed)
- "Inspection" checklists per vehicle
- Integration with GPS data to trigger mileage-based reminders
- Vehicle availability shown as a calendar: blocked dates shown in grey

**FieldPulse:**
No maintenance module. Manual workaround: create a "dummy job" to block a vehicle.

### 4.2 Recommended Maintenance UX for This Project

Map to requirements MAINT-01 through MAINT-03:

**Vehicle Card — Maintenance Button:**
Each vehicle entry in the vehicle list should have a wrench icon button. Tapping opens a maintenance scheduling dialog:

```
Schedule Maintenance
Vehicle: Truck A (ABC-123)

Start Date:  [Date Picker]
End Date:    [Date Picker]
Reason:      [Text Field — e.g., "Oil change", "Brake inspection"]
Notes:       [Optional text]

[Cancel]  [Schedule Maintenance]
```

**Availability enforcement (MAINT-02):**
- Store maintenance windows in a `vehicle_maintenance` table: `id`, `vehicle_id`, `start_date`, `end_date`, `reason`, `notes`, `created_by`, `created_at`
- When scheduler loads available vehicles for a job on a given date, the backend filters out any vehicle where `job_date BETWEEN start_date AND end_date`
- The vehicle list shows: "Truck A — MAINTENANCE (Mar 22-24)" with a greyed-out, non-selectable card
- A maintenance badge appears on the vehicle in all list views

**Maintenance history (MAINT-03):**
- Vehicle detail screen has a "Maintenance History" tab
- Shows a chronological list: date range, reason, who scheduled it
- Status of each entry: Upcoming / Active / Completed (auto-calculated from dates)

**Dashboard integration:**
- Scheduler dashboard shows a small "Fleet Health" widget: "2 vehicles in maintenance | 1 due this week"

---

## 5. Scheduler Dashboard Designs

### 5.1 View Paradigms in FSM Tools

The three dominant scheduler dashboard paradigms in FSM software:

**A. Gantt / Timeline View (ServiceTitan, Dispatch Board)**
- Rows = resources (drivers or vehicles)
- X-axis = time (hours in day view, days in week view)
- Jobs appear as horizontal blocks with width proportional to duration
- Best for: seeing the full day's schedule, identifying gaps, drag-and-drop rescheduling
- Complexity: High to implement correctly. Requires precise time math and drag-and-drop gesture handling in Flutter

**B. Calendar Grid View (Jobber, Google Calendar-style)**
- Columns = days of week
- Rows = time slots (15-min or 30-min increments)
- Jobs appear as event blocks
- Best for: weekly overview, spotting sparse days
- Complexity: Medium. `flutter_calendar_carousel` or `table_calendar` packages handle the grid

**C. Map View (Samsara, some ServiceTitan tiers)**
- Map is the primary surface
- Jobs appear as pins on the map, color-coded by status or driver
- Driver locations shown as avatar icons (live or last-known)
- Sidebar shows a list version of the same jobs
- Best for: spatial understanding of job distribution, route optimization
- Complexity: Medium (Google Maps Flutter already integrated)

**D. Kanban / Board View (Housecall Pro)**
- Columns = job statuses (Pending, Assigned, In Progress, Completed)
- Cards represent jobs
- Best for: seeing pipeline by status
- Complexity: Low

### 5.2 Recommended Dashboard for This Project

Map to requirements SCHED-01 through SCHED-05:

**Primary View: Split — Timeline + Map**

The scheduler dashboard should have two main layout modes, togglable via a tab bar at the top:

1. **"Schedule View" (default):** Timeline/Gantt
   - Horizontal scroll for time, vertical scroll for drivers
   - Each driver row shows their jobs as colored blocks
   - Unassigned jobs panel in a collapsible left drawer
   - Day / Week toggle in the top right
   - "Today" button to snap back to current date
   - Weekend indicator: Saturday/Sunday columns render with a slightly lighter background. The "Weekend View" button (SCHED-04) simply navigates the date picker to the next weekend block

2. **"Map View":** Map with sidebar
   - Full-width Google Map
   - Job pins colored by status: pending = grey, assigned = blue, in_progress = amber, completed = green
   - Driver markers (letter avatar) at last known location (or job site if in_progress)
   - Right sidebar: scrollable job list filtered to map viewport
   - Tap a pin → job summary card slides up from bottom

**Secondary View: "Clients View" vs "Drivers View" toggle (SCHED-05)**
- Drivers View: rows = drivers (default)
- Clients View: rows = customers / job locations. Shows the geographic distribution of clients being served today. Useful for route density checks.

**Status bar at top of dashboard (SCHED-03):**
```
| Today | Pending: 3 | Assigned: 7 | In Progress: 4 | Completed: 12 |
```
These are tappable chips that filter the job list/board to that status.

**Scheduler permission boundaries (SCHED-01):**
The scheduler role sees everything the admin sees on the dashboard EXCEPT:
- No "Add Driver" button (hidden, not disabled)
- No "Add Vehicle" button (hidden)
- No "Delete User" option
- Can swap vehicles on jobs (SCHED-02) — this is a scheduler-only capability that admins can also do

---

## 6. GPS Tracking and Geofencing in Field Service Apps

### 6.1 How Competitors Implement Live Tracking

**Samsara:**
Samsara is the industry standard for fleet GPS tracking. Architecture:
- Physical GPS hardware installed in vehicles, reporting location every 1-10 seconds
- Web platform shows real-time vehicle positions on a map
- "Breadcrumb" trail showing route taken
- Geofence alerts: define a radius around a location; get a notification when a vehicle enters or exits
- ETA calculation for next stop using Google Maps Distance Matrix API

For a software-only product (no hardware), the approach is different: use the driver's smartphone GPS.

**Housecall Pro:**
Housecall Pro uses phone GPS (no hardware). Technicians must have the app running. When a job is `in_progress`:
- The app reports location every 30 seconds to the backend via a background service
- The dispatcher map shows technician locations as colored pins
- No breadcrumb trail in the basic tier
- Location updates stop when the job is marked complete

**ServiceTitan:**
ServiceTitan also offers phone-based tracking. The "Titan Intelligence" tier adds:
- Route optimization (TSP — Traveling Salesman Problem) across a driver's jobs for the day
- Live ETA updates to customers via SMS
- Geo-departure detection: detect when the tech leaves the job site

**FieldPulse:**
Basic phone GPS tracking. Location visible to admins only. 60-second update interval.

### 6.2 Recommended GPS UX for This Project

Map to requirements GPS-01 through GPS-04:

**GPS-01: Directions and travel time on job view**
Already partially built (url_launcher to Google Maps). Enhance by:
- When viewing a job, if the viewing user is a driver with a job `in_progress` or `assigned`, show:
  - "Travel Time: ~24 min" (computed via Google Maps Directions API at job creation or assignment time)
  - "Navigate" button opens Google Maps app with turn-by-turn
- Travel time is best-effort, stored at assignment time, not real-time (avoids API cost explosion)

**GPS-02: Live driver tracking**
Architecture:
- Flutter background location service using `geolocator` (already in pubspec)
- Driver app calls `PUT /api/users/:id/location` every 30 seconds when app is foregrounded AND user has an `in_progress` job
- Backend stores `last_lat`, `last_lng`, `last_location_updated_at` on the `users` table
- Scheduler dashboard polls `GET /api/users/locations` every 30 seconds and updates driver markers on map
- For real-time feel without WebSockets: 30-second polling is acceptable for v1. Socket.io (already noted in architecture) is the v2 upgrade path.

**Background location note:** True background location in Flutter requires specific permissions (`ACCESS_BACKGROUND_LOCATION` on Android, `Always` permission on iOS). For v1, document that drivers must keep the app foregrounded during jobs. The UI should show a persistent foreground notification: "FleetScheduler is tracking your location for JOB-2026-0042."

**GPS-03: Admin controls GPS visibility**
- `admin_settings` table or a settings field: `scheduler_can_see_gps` (boolean, default true)
- Admin settings screen has a toggle: "Allow scheduler to see live driver locations"
- If false: the map view is still visible to schedulers but driver location pins are hidden
- The `GET /api/users/locations` endpoint checks this setting and returns an empty array if the requesting user is a scheduler and the setting is off

**GPS-04: Geo-capture on job completion (STAT-03 overlap)**
When a driver taps "Mark Complete":
1. Flutter calls `geolocator.getCurrentPosition()` with `desiredAccuracy: LocationAccuracy.high`
2. The resulting coordinates are included in the `PUT /api/jobs/:id/status` request body as `completion_lat` and `completion_lng`
3. Backend stores these on the `jobs` table
4. Job detail screen shows "Completed at: [address]" (reverse geocoded via Google Maps Geocoding API, or just show raw coordinates for v1)

This creates an audit trail: you can verify the driver was actually at the job site when they marked it complete. This is a significant compliance feature for enterprise customers.

---

## 7. Role-Based Permissions in Multi-User Scheduling Systems

### 7.1 FSM Permission Models

**ServiceTitan — Three-tier with granular overrides:**
Roles: Office Staff / Tech / Manager / Admin. Each role has a baseline permission set. Admins can additionally grant or revoke individual capabilities per user ("John is Office Staff but can also see financial reports"). The UI shows permission toggles per capability.

This is powerful but complex to build. The existing codebase's capabilities-map approach is well-suited to grow in this direction.

**Jobber — Simple three-tier:**
Roles: Owner / Admin / Field Worker. No per-user overrides. Field Workers see only their own jobs. Simple and effective for small teams.

**Housecall Pro — Four-tier with department concept:**
Roles: Owner / Admin / Office Staff / Technician. "Office Staff" is equivalent to our Scheduler role — they can schedule and dispatch but cannot manage users or billing.

### 7.2 Recommended Permission Model

The existing system's capabilities map is the right architectural choice. Extend it for the new requirements:

**Role definitions:**

| Role | Description |
|------|-------------|
| admin | Full access. Can manage users, vehicles, all settings. |
| scheduler | Can create/edit/assign jobs. Can swap vehicles. Cannot add/remove users or vehicles. |
| driver | Sees only their own assigned jobs. Can start/complete jobs. Can request time extensions. |
| technician | Same as driver but may be assigned to jobs without driving. In most cases, driver and technician are the same person. |

**Critical permissions table (extend `constants.js`):**

| Permission Key | Admin | Scheduler | Driver | Technician |
|---------------|-------|-----------|--------|------------|
| `jobs:create` | Y | Y | N | N |
| `jobs:edit` | Y | Y | N | N |
| `jobs:delete` | Y | N | N | N |
| `jobs:assign` | Y | Y | N | N |
| `jobs:start` | Y | Y | Y | Y |
| `jobs:complete` | Y | N | Y | Y |
| `jobs:request_extension` | Y | N | Y | Y |
| `jobs:approve_extension` | Y | Y | N | N |
| `vehicles:create` | Y | N | N | N |
| `vehicles:delete` | Y | N | N | N |
| `vehicles:swap` | Y | Y | N | N |
| `vehicles:maintenance:schedule` | Y | N | N | N |
| `users:create` | Y | N | N | N |
| `users:delete` | Y | N | N | N |
| `gps:view_live` | Y | conditional | N | N |
| `settings:edit` | Y | N | N | N |

**`gps:view_live` conditional logic:**
The scheduler's access to this permission is controlled by the `admin_settings.scheduler_can_see_gps` flag, checked at JWT validation time or on each protected request.

**UI enforcement:**
- Buttons for forbidden actions are hidden (not just disabled) for non-admin/scheduler roles
- API routes return `403` with a descriptive error if the JWT lacks the required permission string
- The existing reverse-lookup pattern at login handles this without database migrations

---

## 8. Weekend / After-Hours Scheduling Patterns

### 8.1 How Competitors Handle Non-Standard Hours

**ServiceTitan:**
ServiceTitan has a "business hours" configuration in company settings. Jobs scheduled outside business hours get a visual indicator ("After Hours") on the dispatch board. The system does not block after-hours scheduling — it just flags it. Overtime cost calculations are a separate feature.

**Jobber:**
No concept of business hours in the core product. The calendar simply shows all 7 days. There is a "work week view" (Mon-Fri) and a "full week view" toggle.

**Housecall Pro:**
Housecall Pro has a scheduling widget that respects "available days." If the company marks itself as "closed Sundays," the Sunday column in the scheduler is greyed out but still bookable by admins.

**Samsara:**
Samsara has "driving policy" rules: no driving before 6am, no driving after 8pm. Violations are flagged. Not applicable to scheduling UX but relevant to the GPS compliance angle.

### 8.2 Recommended Weekend Scheduling UX

Map to requirements SCHED-04 and SCHED-05:

**Weekend View button (SCHED-04):**
In the scheduler dashboard, add a "Weekend" quick-nav button in the date navigation bar (alongside "Today", "< Prev", "Next >"):

```
[< Prev]  [Today]  [Weekend]  [Next >]   March 21, 2026
```

Tapping "Weekend" navigates to the Saturday of the current week. The view shows Saturday and Sunday as a 2-day timeline. The button is stateful: if already on a weekend date, it jumps to the NEXT weekend.

**Visual differentiation for weekend jobs:**
- Weekend job cards in the timeline use a slightly different color saturation (desaturated version of the job type color) to visually distinguish them from weekday jobs
- A small "SAT" or "SUN" badge appears in the corner of each weekend job card

**After-hours job indicator:**
Define business hours in settings (e.g., 07:00-18:00). Jobs scheduled with `scheduled_time_start` before 07:00 or `scheduled_time_end` after 18:00 get a small moon icon on their card in all views. This is informational only — does not block creation.

**Weekend filter in list view:**
On the jobs list, add a filter chip: "Weekends Only." This filters `WHERE DAYOFWEEK(scheduled_date) IN (1, 7)` (Sunday = 1, Saturday = 7 in MySQL). Useful for reviewing weekend workload quickly.

---

## Table Stakes

Features every FSM SaaS must have. Missing any of these makes the product feel incomplete to buyers.

| Feature | Why Expected | Complexity | Status |
|---------|--------------|------------|--------|
| Push notifications on job assignment | Standard since 2015 | Medium | Not built |
| In-app notification history | Standard in all B2B apps | Low | Not built |
| Overdue job alerts | Core dispatcher need | Medium | Not built |
| Load indicator on driver picker | Industry standard UX | Low | Not built |
| Vehicle blocked during maintenance | Basic fleet management | Low | Not built |
| Scheduler vs admin role distinction | All FSM tools have this | Low | Partially built |
| Geo-capture on job completion | Compliance / audit trail | Medium | Not built |
| Live driver location (basic polling) | Expected by enterprise buyers | High | Not built |
| Weekend/after-hours indicator | Basic scheduling | Low | Not built |
| Day/week toggle on scheduler | Standard calendar UX | Medium | Not built |

---

## Differentiators

Features that competitors do NOT consistently offer, where we can stand out.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Time extension request workflow | ServiceTitan has no native overrun workflow. This fills a real gap. | Medium | Impact analysis + scheduling suggestions is the key differentiator |
| Admin-controlled GPS visibility toggle | None of the competitors have per-role GPS visibility controls | Low | Privacy feature, important for trust |
| Smart "Suggested" driver badge during assignment | Housecall Pro has load dots, but no explicit recommendation | Low | Easy to implement, high perceived value |
| Geo-verified job completion audit trail | Samsara does this for hardware GPS. We do it software-only. | Medium | Strong compliance selling point for enterprise |
| Maintenance auto-excludes vehicle from dispatch | FieldPulse doesn't do this at all. Jobber doesn't either. | Low | Simple DB query, high practical value |

---

## Anti-Features

Features to explicitly not build in v1.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Route optimization (TSP) | Requires Google Maps Routes API + complex algorithm. High cost, low v1 ROI. | Show travel time only. Link to Google Maps for navigation. |
| Customer-facing portal / SMS | Out of scope per PROJECT.md. Adds auth complexity, GDPR surface area, customer data handling. | Internal ops only for v1. Flag as v2 milestone. |
| Real-time WebSocket location updates | Polling every 30 seconds is sufficient for v1. Socket.io adds infra complexity. | Use polling. Design data layer for Socket.io swap later. |
| In-app chat / messaging | Distraction from core scheduling. Adds heavy infra (message persistence, read receipts). | Use existing communication tools. |
| Automated route sequencing (drag to reorder) | High-effort mobile UX. Requires drag-and-drop in a timeline view. | Manual scheduling only for v1. |
| Mileage / fuel tracking | Requires hardware GPS or manual input. Out of scope for a scheduling tool. | Out of scope. Recommend Fleetio integration in v2. |
| Invoice generation / billing | Different product category entirely. | Out of scope. |

---

## Feature Dependencies

```
FCM Push Notifications (NOTIF-01, NOTIF-02)
  → Requires: fcm_token on users table
  → Requires: firebase-admin SDK on backend
  → Requires: flutter_firebase_messaging on frontend

In-App Notification Center (NOTIF-04)
  → Requires: notifications table in DB
  → Requires: notification write on every trigger event (assignment, overdue, extension)

Time Extension Workflow (TIME-01 to TIME-05)
  → Requires: time_extension_requests table
  → Requires: NOTIF-04 (extension request notification to scheduler)
  → Requires: downstream job impact calculation (backend logic)

Load Balancing Driver UX (ASGN-01, ASGN-02)
  → Requires: job count query scoped by date and driver in GET /api/users endpoint
  → Requires: historical job count (COUNT from job_technicians WHERE user_id = ?)

Vehicle Maintenance (MAINT-01, MAINT-02, MAINT-03)
  → Requires: vehicle_maintenance table
  → Requires: vehicle availability filter in job assignment query

Live GPS Tracking (GPS-02)
  → Requires: last_lat, last_lng, last_location_updated_at on users table
  → Requires: location reporting endpoint (PUT /api/users/:id/location)
  → Requires: background-capable location permission setup in Flutter
  → Requires: GPS-03 (admin visibility toggle) to be designed concurrently

Geo-Capture on Completion (GPS-04, STAT-03)
  → Requires: completion_lat, completion_lng on jobs table
  → Requires: geolocator already in pubspec (done)
  → Requires: modified job completion endpoint to accept coordinates

Scheduler Dashboard Views (SCHED-01 to SCHED-05)
  → Requires: getJobsByDate already exists (done)
  → Requires: day/week date range query for timeline view
  → Requires: driver workload data from load balancing feature (ASGN-01)
  → Requires: GPS-02 for map view to show live driver positions
```

---

## MVP Recommendation

Phase the active requirements by dependency order and complexity:

**Build first (foundational, low risk):**
1. Load balancing driver picker UX (ASGN-01, ASGN-02) — pure frontend + one backend query change
2. Vehicle maintenance scheduling (MAINT-01, MAINT-02, MAINT-03) — new table, simple UI
3. Scheduler role permissions (SCHED-01, SCHED-02) — extend existing permissions map
4. Geo-capture on job completion (GPS-04, STAT-03) — geolocator already in pubspec
5. Weekend view button + after-hours indicator (SCHED-04) — date navigation only

**Build second (medium complexity, high value):**
6. Push notifications infrastructure (NOTIF-01, NOTIF-02) — FCM setup, cron job
7. In-app notification center (NOTIF-04) — notifications table + bell UI
8. Time extension request workflow (TIME-01 to TIME-05) — new table + scheduler approval UI
9. Email notification toggle (NOTIF-03) — depends on NOTIF-04 infrastructure

**Build last (high complexity, infrastructure-heavy):**
10. Live GPS tracking (GPS-02, GPS-03) — background location, polling, map UI
11. Scheduler dashboard timeline view (SCHED-03, SCHED-05) — Gantt-style timeline in Flutter
12. Directions / travel time on job view (GPS-01) — Directions API integration

**Defer:**
- STAT-01 (auto-update to in_progress at start time) — cron job, risk of incorrect auto-state
- API/UI tests (TEST-01 to TEST-04) — run alongside feature development, not as a separate phase

---

## Sources

**Confidence note:** WebSearch was unavailable. Findings are drawn from:
- Training knowledge of ServiceTitan (docs.servicetitan.com, reviewed through August 2025)
- Training knowledge of Jobber (getjobber.com documentation)
- Training knowledge of Housecall Pro (housecallpro.com)
- Training knowledge of FieldPulse (fieldpulse.com)
- Training knowledge of Samsara (samsara.com fleet tracking)
- Training knowledge of Fleetio (fleetio.com)
- Existing project codebase analysis (PROJECT.md, TECHNICAL_ARCHITECTURE.md, TECHNICAL_SPECIFICATION_V2.md)
- Flutter ecosystem knowledge (firebase_messaging, geolocator, google_maps_flutter packages)

All specific UX details (button labels, exact feature names, tier availability) should be verified against current platform screenshots or trial accounts before treating as authoritative. Core patterns (notification triggers, permission models, load visualization approaches) are stable across platform versions and HIGH confidence.
