# FleetScheduler Pro — Admin User Manual

**Role:** Administrator
**Version:** 1.0
**Last updated:** March 2026

---

## Introduction

This manual covers every feature available to an administrator in FleetScheduler Pro. As an admin, you have full access to all areas of the application — user management, vehicle management, job scheduling, live GPS tracking, notifications, reports, and system settings.

If you manage a team of schedulers or dispatchers, this guide will help you get up and running quickly and confidently.

---

## Getting Started

### Logging In

1. Open the FleetScheduler Pro app on your mobile device.
2. Enter your **email address** and **password** in the login fields.
3. Tap **Log In**.
4. If your credentials are correct, you will be taken directly to the Dashboard.

> **Note:** If you see a "GPS Consent" screen after logging in, this only appears for driver/technician accounts. Admin accounts bypass GPS consent.

### Navigating the App

The app uses a bottom navigation bar with **7 tabs**:

| Tab | What It Contains |
|-----|-----------------|
| Dashboard | Job overview, charts, and quick stats |
| Jobs | Full job list and job creation |
| Vehicles | Vehicle list and maintenance |
| Users | User accounts and roles |
| Assignments | Driver and vehicle assignment to jobs |
| Reports | Generated reports |
| Settings | System-wide configuration |

Tap any tab to switch between sections instantly.

---

## Dashboard

The Dashboard is the home screen you see after logging in. It gives you a real-time overview of your fleet's activity.

### What You Will See

- **Jobs Today card** — A summary of how many jobs are scheduled for today, broken down by status (pending, assigned, in progress, completed, cancelled).
- **Bar chart** — A visual breakdown of jobs by hour of day, so you can see when your team is busiest.
- **Badge counts** — Quick counters for jobs in each status.
- **Weekend filter toggle** — By default the dashboard shows weekday jobs. Tap the weekend toggle to include or exclude Saturday and Sunday jobs.
- **View toggle** — Switch between two views:
  - **Drivers Assigned view** — Shows each driver and which jobs they are assigned to today.
  - **Clients view** — Shows jobs listed by customer name.

### Using the Dashboard

1. Open the app — the Dashboard loads automatically.
2. To filter out weekend jobs, tap the **Weekend** toggle at the top of the screen.
3. To change the view between drivers and clients, tap the **toggle switch** on the Jobs Today card.
4. The bar chart refreshes automatically when you navigate to the Dashboard.

> **Note:** The dashboard only shows data for your organisation (tenant). You will never see another company's jobs.

---

## User Management

Admins are the only role that can create, edit, and delete user accounts.

### User Roles

FleetScheduler Pro has three user roles:

| Role | What They Can Do |
|------|-----------------|
| **Admin** | Full access to all features including user and vehicle management |
| **Scheduler** | Can manage jobs, assignments, and view reports — cannot add/remove users or vehicles |
| **Technician / Driver** | Can view assigned jobs, update job status, request time extensions |

### Viewing the User List

1. Tap the **Users** tab in the bottom navigation bar.
2. You will see a list of all users in your organisation with their name, role, and contact number.

### Creating a New User

1. Tap the **Users** tab.
2. Tap the **+ (Add)** button (usually in the top-right corner or as a floating action button).
3. Fill in the required fields:
   - **Full Name** — The user's full name.
   - **Email Address** — Used to log in. Must be unique.
   - **Password** — Set a temporary password. Ask the user to change it on first use.
   - **Role** — Select Admin, Scheduler, or Technician.
   - **Contact Phone Number** — The user's mobile number for contact purposes.
4. Tap **Save** or **Create User**.
5. The new user will appear in the user list and can now log in.

### Editing a User

1. Tap the **Users** tab.
2. Find the user you want to edit and tap on their name.
3. Update any fields as needed (name, email, role, phone number).
4. Tap **Save**.

### Deleting a User

1. Tap the **Users** tab.
2. Find the user and tap on their name to open their profile.
3. Tap the **Delete** option (usually a trash icon or button at the bottom).
4. Confirm the deletion when prompted.

> **Important:** Deleting a user removes their access immediately. Any jobs assigned to them will need to be reassigned.

---

## Vehicle Management

Admins can add, edit, activate, deactivate, and remove vehicles from the fleet.

### Viewing the Vehicle List

1. Tap the **Vehicles** tab.
2. You will see all vehicles with their name, license plate, type, and current status.

### Adding a Vehicle

1. Tap the **Vehicles** tab.
2. Tap the **+ (Add)** button.
3. Fill in the vehicle details:
   - **Vehicle Name** — A descriptive name (e.g., "Van 1" or "Truck 3").
   - **License Plate** — The vehicle's registration number.
   - **Vehicle Type** — The type of vehicle (e.g., van, truck, bakkie).
   - **Capacity** — How many people or how much load the vehicle carries.
4. Tap **Save**.
5. The vehicle is now available for job assignments.

### Editing a Vehicle

1. Tap the **Vehicles** tab.
2. Tap on the vehicle you want to edit.
3. Update the relevant fields.
4. Tap **Save**.

### Activating and Deactivating a Vehicle

- **Deactivate** a vehicle if it is temporarily out of service (e.g., under repairs not tracked in the app). Deactivated vehicles cannot be assigned to jobs.
- To activate or deactivate, open the vehicle's detail screen and toggle the **Active** switch.

### Removing a Vehicle

1. Open the vehicle's detail screen.
2. Tap the **Delete** button and confirm.

> **Note:** Vehicles cannot be deleted if they are currently assigned to an active job. Reassign or complete the job first.

---

## Vehicle Maintenance

Track scheduled maintenance periods to prevent vehicles from being accidentally booked during downtime.

### Scheduling Maintenance

1. Tap the **Vehicles** tab.
2. Tap on the vehicle that needs maintenance.
3. Tap the **Schedule Maintenance** button.
4. Enter:
   - **Start Date** — When maintenance begins.
   - **End Date** — When maintenance is expected to finish.
   - **Reason** (optional) — Notes about the maintenance (e.g., "annual service", "tyre replacement").
5. Tap **Save**.

The vehicle will be marked as unavailable during those dates.

### How Maintenance Affects Job Assignment

- When assigning a vehicle to a job, vehicles scheduled for maintenance on the job date are **automatically excluded** from the available vehicle list.
- If you try to assign a vehicle that is in maintenance, the system will warn you.

> **Important:** You cannot bypass maintenance blocks. If you need the vehicle urgently, you must delete the maintenance record first.

### Viewing Maintenance History

1. Tap the **Vehicles** tab.
2. Tap on a vehicle.
3. Scroll down to the **Maintenance History** section to see all past and scheduled maintenance records.

---

## Job Management

Jobs are the core of FleetScheduler Pro. Each job represents a service call or task that needs to be completed at a customer's location.

### Job Statuses Explained

| Status | Meaning |
|--------|---------|
| **Pending** | Job created but not yet assigned to a driver |
| **Assigned** | A driver and vehicle have been assigned |
| **In Progress** | The driver has started working on the job |
| **Completed** | The job is finished — driver confirmed completion |
| **Cancelled** | The job was cancelled and will not be completed |

### Viewing the Job List

1. Tap the **Jobs** tab.
2. You will see all jobs for your organisation, sorted by scheduled date.
3. Use the filter or search options to find specific jobs.

### Creating a New Job

1. Tap the **Jobs** tab.
2. Tap the **+ (Add)** button.
3. Fill in the job details:
   - **Customer Name** — The name of the client or customer.
   - **Customer Phone Number** — Contact number for the customer.
   - **Customer Address** — The job site address. Tap the map icon to pick the location on the map.
   - **Job Type** — The category of work (e.g., plumbing, HVAC, electrical).
   - **Scheduled Date** — The date the job is planned for.
   - **Scheduled Time** — The start time for the job.
   - **Priority** — Low, medium, or high priority.
   - **Description** — Additional notes or instructions for the driver.
4. Tap **Save** or **Create Job**.
5. The job is created with **Pending** status and appears in the job list.

### Editing a Job

1. Open the job from the **Jobs** tab.
2. Tap the **Edit** button (pencil icon).
3. Update the fields you need to change.
4. Tap **Save**.

> **Note:** Editing a job does not notify assigned drivers automatically. If you change the time or address, notify the driver manually or use the notifications feature.

### Cancelling a Job

1. Open the job from the **Jobs** tab.
2. Tap the **Cancel Job** option.
3. Confirm the cancellation.

The job status changes to **Cancelled** and it remains in the list for record-keeping.

---

## Job Assignment

After creating a job, you assign a driver (or technician) and a vehicle to it.

### Assigning a Driver and Vehicle

1. Tap the **Assignments** tab, or open a job and tap the **Assign** button.
2. You will see the job details and two selection areas: **Driver** and **Vehicle**.
3. Select a driver:
   - Each driver shows their **current job count** — the number of jobs already assigned to them today.
   - Drivers with **fewer jobs than average** are highlighted with a **green glow** — this is the load balancing indicator. Selecting a lower-load driver keeps your team's workload balanced.
   - A **Suggested** chip appears next to the recommended driver for this job.
4. Select a vehicle:
   - Only vehicles that are **active and not in maintenance** on the job date are shown.
5. Tap **Assign** to confirm.

The job status changes from **Pending** to **Assigned**.

### Assigning Multiple Technicians

Some jobs require more than one technician. You can assign multiple technicians to the same job:

1. Open the job's assignment screen.
2. After selecting the primary driver and vehicle, use the **Add Technician** option to add more personnel.
3. Each technician will receive a notification that they have been assigned.

### Vehicle Swap (Hotswap)

If a vehicle becomes unavailable after a job is already assigned (e.g., breakdown), you can swap it for another vehicle without losing the job assignment:

1. Open the assigned job.
2. Tap the **Swap Vehicle** button.
3. Select the replacement vehicle from the available vehicles list.
4. Tap **Confirm Swap**.

The assignment is updated immediately. The driver keeps their assignment.

### Viewing Assignment History

Each job keeps a full history of all assignment changes (who was assigned, when the swap happened, etc.). Open the job detail screen and scroll to the **Assignment History** section.

---

## Reports

The Reports section gives you insight into your fleet's performance over time.

### Viewing Reports

1. Tap the **Reports** tab.
2. Select the type of report you want to view.
3. The report loads and displays the data on screen.

### Available Report Types

- **Jobs by Status** — How many jobs are in each status over a date range.
- **Driver Performance** — Jobs completed per driver.
- **Vehicle Utilisation** — How often each vehicle is being used.
- **Job Completion Times** — How long jobs take from assignment to completion.

> **Note:** Reports are generated from your organisation's data only.

---

## Notifications

FleetScheduler Pro sends you alerts so you never miss an important event.

### The Notification Bell

- A **bell icon** appears in the top-right corner of the app on most screens.
- A **badge number** on the bell shows how many unread notifications you have.

### Opening the Notification Center

1. Tap the **bell icon** at the top of the screen.
2. The Notification Center opens, showing all recent notifications.
3. Unread notifications appear highlighted.
4. Tap a notification to open the related job or action.
5. Tap **Mark All as Read** to clear the badge.

### Notification Types

| Type | When It Appears |
|------|----------------|
| **Job Assigned** | A driver has been assigned to a job |
| **Job Starting Soon** | A job is about to begin (sent in advance) |
| **Job Overdue** | A job's scheduled time has passed but it is still not completed |
| **Time Extension Request** | A driver on an active job is requesting more time |

### Email Notifications

You can choose to receive notifications by email as well as in-app:

1. Go to your **profile** or **notification settings**.
2. Toggle **Email Notifications** on or off.
3. When enabled, you will receive an email for each notification event.

> **Note:** Email notifications are sent to the email address registered on your account.

---

## Time Extensions

Drivers can request extra time on in-progress jobs. As an admin, you review and approve or deny these requests.

### Receiving a Time Extension Request

1. When a driver submits a time extension request, you will receive a **push notification** and an in-app notification.
2. Tap the notification to open the **Time Extension Review** screen.

### Reviewing a Time Extension Request

The review screen shows:
- **Which job** the request is for and which driver submitted it.
- **How much extra time** the driver is requesting.
- **The reason** they provided.
- **Impact analysis** — which other jobs or drivers are affected if this job runs longer.
- **Rescheduling suggestions** — 2-3 options for how to handle any affected jobs (e.g., "move Job #42 to 3pm").

### Approving or Denying a Request

1. Review all the information on the screen.
2. Tap **Approve** to grant the extra time, or **Deny** to reject the request.
3. The driver receives a push notification with your decision immediately.

> **Note:** If you approve an extension, consider using the rescheduling suggestions to adjust any affected jobs.

---

## GPS and Live Tracking

FleetScheduler Pro includes real-time GPS tracking so you can see where your drivers are during working hours.

### Live Tracking Map

1. Tap the **GPS / Tracking** option (accessible from the Dashboard or Jobs screens).
2. The **Live Tracking** map screen opens.
3. Each active driver appears as a pin on the map with their name.
4. Pins older than 5 minutes are automatically removed to avoid clutter from offline drivers.

### Viewing Directions and ETA for a Job

1. Open a job from the **Jobs** tab.
2. The job detail screen shows the customer's address on a map.
3. Tap the **Directions** button to see the route and estimated travel time from the driver's current location to the job site.

### GPS Consent System

FleetScheduler Pro complies with privacy laws (POPIA/GDPR). Drivers are shown a **GPS Consent screen** when they first log in. They must agree to location tracking before their position is shared.

- Driver location is only tracked **during working hours** and **active job periods**.
- If a driver declines consent, their position will not appear on the live tracking map.
- The consent decision is recorded for compliance auditing purposes.

### Admin GPS Settings

You control whether schedulers can see the live tracking map:

1. Tap the **Settings** tab.
2. Find the **Scheduler GPS Visibility** toggle.
3. Turn it **on** to allow schedulers to see live driver positions, or **off** to restrict GPS visibility to admins only.

---

## Settings

The Settings tab is only accessible to administrators.

### Accessing Settings

1. Tap the **Settings** tab in the bottom navigation bar.

### Available Settings

| Setting | What It Does |
|---------|-------------|
| **Scheduler GPS Visibility** | Toggle whether schedulers can see the live driver tracking map |

> **Note:** More settings options may be added in future versions of the application.

### Saving Settings

Settings save automatically when you toggle them. There is no separate Save button needed.

---

## Tips and Best Practices

- **Assign jobs promptly** — Jobs left in "Pending" status too long will trigger overdue notifications.
- **Use load balancing** — The green glow on drivers with fewer jobs helps distribute work fairly across your team.
- **Schedule maintenance in advance** — Enter vehicle maintenance periods as soon as you know about them to prevent accidental double-booking.
- **Review time extension requests quickly** — Drivers in the field are waiting for your decision. Delayed approvals affect customer service.
- **Keep contact numbers up to date** — Phone numbers on user profiles help schedulers contact drivers when the app is unavailable.
- **Check the dashboard each morning** — The jobs today view gives you an immediate picture of the day's workload before you start assigning jobs.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Cannot assign a vehicle to a job | Check if the vehicle is in maintenance on that date, or deactivated |
| A user cannot log in | Check their email and password. Reset if needed from the Users screen |
| GPS pins not showing | The driver may have declined GPS consent, or their GPS may be off |
| Notifications not arriving | Check that email notifications are enabled; check device notification permissions |
| Dashboard showing no data | Ensure jobs are scheduled for today's date range |

---

*FleetScheduler Pro — Admin User Manual — v1.0*
