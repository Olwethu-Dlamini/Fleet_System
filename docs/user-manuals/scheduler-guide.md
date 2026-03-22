# FleetScheduler Pro — Scheduler User Manual

**Role:** Scheduler
**Version:** 1.0
**Last updated:** March 2026

---

## Introduction

This manual covers every feature available to a scheduler in FleetScheduler Pro. Schedulers have nearly the same access as administrators — you can manage jobs, assign drivers, review time extension requests, and generate reports.

The main difference from the admin role is that you **cannot add or remove users or vehicles**. Those functions belong to administrators. This guide notes these differences clearly wherever they apply.

---

## Getting Started

### Logging In

1. Open the FleetScheduler Pro app on your mobile device.
2. Enter your **email address** and **password**.
3. Tap **Log In**.
4. You will be taken to the Dashboard.

### Navigating the App

The app uses a bottom navigation bar with **7 tabs**:

| Tab | What You Can Do |
|-----|----------------|
| Dashboard | View job overview, charts, and stats |
| Jobs | Create, edit, view, and cancel jobs |
| Vehicles | View vehicles and schedule maintenance |
| Users | View user list (read-only — cannot add or delete users) |
| Assignments | Assign drivers and vehicles to jobs |
| Reports | View and generate reports |
| Settings | _(Not available to schedulers)_ |

> **Note:** The Settings tab is visible to administrators only. As a scheduler you will not see it in your navigation.

---

## Dashboard

The Dashboard gives you a real-time overview of the day's jobs and your team's workload.

### What You Will See

- **Jobs Today card** — Summary of today's jobs broken down by status (pending, assigned, in progress, completed, cancelled).
- **Bar chart** — Jobs visualised by hour of day, so you can quickly see when the team is busiest.
- **Badge counts** — Quick counters for each job status.
- **Weekend filter toggle** — Switch between weekday-only and all-days view.
- **View toggle** — Switch between:
  - **Drivers Assigned view** — See each driver's assigned jobs for today.
  - **Clients view** — See jobs organised by customer name.

### Using the Dashboard

1. The Dashboard loads automatically when you open the app.
2. Tap the **Weekend** toggle to include or exclude weekend jobs.
3. Tap the **view toggle** on the Jobs Today card to switch between drivers and clients view.
4. The bar chart refreshes automatically when you navigate to the Dashboard.

---

## Job Management

As a scheduler, you have full control over jobs — you can create, edit, view, and cancel them.

### Job Statuses Explained

| Status | Meaning |
|--------|---------|
| **Pending** | Job created but no driver assigned yet |
| **Assigned** | Driver and vehicle have been assigned |
| **In Progress** | Driver is actively working on the job |
| **Completed** | Driver confirmed the job is done |
| **Cancelled** | Job was cancelled and will not run |

### Viewing the Job List

1. Tap the **Jobs** tab.
2. All jobs for your organisation are listed, sorted by scheduled date.
3. Use the search or filter options to find specific jobs.

### Creating a New Job

1. Tap the **Jobs** tab.
2. Tap the **+ (Add)** button.
3. Fill in the job details:
   - **Customer Name** — The client's name.
   - **Customer Phone Number** — Contact number for the customer.
   - **Customer Address** — The job site address. Tap the map icon to pick the location on a map.
   - **Job Type** — Category of work (e.g., HVAC, plumbing, electrical).
   - **Scheduled Date** — When the job is planned.
   - **Scheduled Time** — The start time.
   - **Priority** — Low, medium, or high.
   - **Description** — Notes or instructions for the driver.
4. Tap **Save**.
5. The job is created with **Pending** status.

### Editing a Job

1. Open the job from the **Jobs** tab.
2. Tap the **Edit** button.
3. Update the fields you need to change.
4. Tap **Save**.

> **Tip:** If you change the time or address on an assigned job, let the driver know directly or send a notification.

### Cancelling a Job

1. Open the job from the **Jobs** tab.
2. Tap **Cancel Job**.
3. Confirm when prompted.

The job status changes to **Cancelled** and stays in the list for record-keeping.

---

## Job Assignment

Assigning a driver (or technician) and vehicle to a job is one of your main responsibilities as a scheduler.

### Assigning a Driver and Vehicle

1. Tap the **Assignments** tab, or open a job and tap the **Assign** button.
2. You will see the job details with selection areas for **Driver** and **Vehicle**.
3. Choose a driver:
   - Each driver shows their **current job count** for the day.
   - Drivers with **fewer jobs than average** are highlighted with a **green glow** — this is the load balancing indicator, helping you keep workloads balanced.
   - A **Suggested** chip appears next to the recommended driver.
4. Choose a vehicle:
   - Only vehicles that are **active and not in maintenance** on the job date appear.
5. Tap **Assign** to confirm.

The job moves from **Pending** to **Assigned**.

### Assigning Multiple Technicians

For jobs requiring more than one person:

1. Open the job's assignment screen.
2. After selecting the primary driver and vehicle, use the **Add Technician** option.
3. Select additional technicians.
4. Each technician receives a notification that they have been assigned.

### Vehicle Swap

If a vehicle becomes unavailable after assignment:

1. Open the assigned job.
2. Tap **Swap Vehicle**.
3. Select a replacement from the available vehicles.
4. Tap **Confirm Swap**.

The vehicle is swapped without losing the driver assignment.

> **Note:** You can swap vehicles on jobs. You cannot add new vehicles to the system — that is an admin function.

---

## Vehicle Maintenance

You can schedule maintenance on vehicles and view maintenance history. You **cannot add new vehicles** or remove existing ones.

### Scheduling Maintenance

1. Tap the **Vehicles** tab.
2. Tap on the vehicle that needs maintenance.
3. Tap **Schedule Maintenance**.
4. Enter:
   - **Start Date** — When maintenance begins.
   - **End Date** — When it is expected to finish.
   - **Reason** (optional) — e.g., "annual service", "brake pads".
5. Tap **Save**.

Vehicles under maintenance on a given date will not appear as available options when assigning that day's jobs.

### Viewing Maintenance History

1. Tap the **Vehicles** tab.
2. Tap on a vehicle.
3. Scroll down to **Maintenance History** to see all past and upcoming maintenance records.

---

## Notifications

FleetScheduler Pro keeps you informed with real-time alerts.

### The Notification Bell

- A **bell icon** appears in the top-right corner of the screen.
- A **badge** on the bell shows the number of unread notifications.

### Opening the Notification Center

1. Tap the **bell icon**.
2. All recent notifications are listed, with unread items highlighted.
3. Tap a notification to go directly to the related job or action.
4. Tap **Mark All as Read** to clear the unread badge.

### Notification Types You Will Receive

| Type | When |
|------|------|
| **Job Assigned** | Confirmation when you assign a driver to a job |
| **Job Starting Soon** | Alert before a job is due to start |
| **Job Overdue** | A job's start time has passed but it is not yet in progress or complete |
| **Time Extension Request** | A driver is requesting extra time on an active job |

### Email Notifications

1. Open your account profile or notification settings.
2. Toggle **Email Notifications** on or off.
3. When enabled, you receive an email for each notification event (at your registered email address).

---

## Time Extensions

Drivers on active jobs can request extra time. You review, assess the impact, and approve or deny requests.

### Receiving a Time Extension Request

1. When a driver submits a request, you receive a **push notification** and an in-app alert.
2. Tap the notification to open the **Time Extension Review** screen.

### Reviewing the Request

The review screen displays:
- **Which job** the request is for and which driver submitted it.
- **How much extra time** they are requesting.
- **The reason** the driver provided.
- **Impact analysis** — other jobs or drivers affected if this job runs over time.
- **Rescheduling suggestions** — 2 to 3 options for handling any affected jobs.

### Approving or Denying

1. Review all information on the screen.
2. Tap **Approve** to grant the extra time, or **Deny** to reject it.
3. The driver receives a push notification with your decision immediately.

> **Tip:** If you approve the extension, use the rescheduling suggestions to adjust any other affected jobs quickly.

---

## GPS and Live Tracking

If your administrator has enabled GPS visibility for schedulers, you can view real-time driver positions on a map.

### Checking If GPS Is Enabled for You

- If GPS tracking is visible, you will see a **Tracking** or **Live Map** option on the Dashboard or Jobs screens.
- If you cannot find the live map, your administrator may have restricted GPS visibility to admins only. Contact your admin to enable it.

### Viewing the Live Tracking Map

1. Open the **Live Tracking** screen from the Dashboard or Jobs area.
2. Each active driver appears as a pin on the map.
3. Pins older than 5 minutes are automatically hidden (drivers who are offline or not moving).

### Directions and ETA on a Job

1. Open a job from the **Jobs** tab.
2. The job detail screen shows the customer's address on a map.
3. Tap **Directions** to see the route and estimated travel time to the job site.

> **Note:** GPS tracking requires drivers to have given consent when they first logged in. Drivers who declined GPS consent will not appear on the tracking map.

---

## Reports

Reports give you visibility into job performance, driver activity, and vehicle usage.

### Generating a Report

1. Tap the **Reports** tab.
2. Select the report type you want.
3. The report data loads and displays on screen.

### Available Report Types

- **Jobs by Status** — Count of jobs in each status over a date range.
- **Driver Performance** — Jobs completed per driver.
- **Vehicle Utilisation** — How often each vehicle is being used.
- **Job Completion Times** — How long jobs take from assignment to completion.

---

## Key Differences from Admin

As a scheduler, there are a small number of things you **cannot do** that administrators can:

| Feature | Admin | Scheduler |
|---------|-------|-----------|
| Add new users | Yes | No |
| Delete users | Yes | No |
| Edit user roles | Yes | No |
| Add new vehicles | Yes | No |
| Delete vehicles | Yes | No |
| Access Settings tab | Yes | No |
| Toggle Scheduler GPS visibility | Yes | No |
| All job and assignment functions | Yes | Yes |
| Schedule vehicle maintenance | Yes | Yes |
| Approve/deny time extensions | Yes | Yes |
| View live GPS tracking | Yes | Only if admin enables it |
| View user list (read-only) | Yes | Yes |

If you need to add a user or vehicle, contact your system administrator.

---

## Tips and Best Practices

- **Assign jobs early** — Jobs left as "Pending" for too long will trigger overdue alerts.
- **Use the green glow** — When selecting a driver, the green glow shows who has less work. Use it to keep the team's workload balanced.
- **Check the dashboard each morning** — The jobs today overview shows you what the day looks like before you start assigning work.
- **Review time extensions quickly** — Drivers in the field are waiting on your decision. A fast response means better service for customers.
- **Use the weekend toggle** — If your team works weekends, toggle on the weekend view to see the full picture on Fridays.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cannot add a user | This is an admin-only function. Contact your administrator |
| Cannot add a vehicle | This is an admin-only function. Contact your administrator |
| Vehicle not appearing in assignment | It may be in maintenance or deactivated. Check with your admin |
| Cannot see live GPS map | GPS visibility for schedulers may be disabled. Ask your admin to enable it |
| Notifications not arriving | Check your device notification permissions and the email toggle in your profile |
| Dashboard showing no data | Make sure jobs are scheduled for today's date; check the weekend toggle |

---

*FleetScheduler Pro — Scheduler User Manual — v1.0*
