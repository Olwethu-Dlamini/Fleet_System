# Phase 6: Time Management - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase implements the time extension workflow: technicians/drivers request more time on in-progress jobs, the system calculates impact on subsequent jobs and generates rescheduling suggestions, and the scheduler approves/denies with one tap. All affected parties are notified of changes.

</domain>

<decisions>
## Implementation Decisions

### Time Extension Request
- Preset duration options: 30min, 1hr, 2hr, custom — quick selection for common cases
- Free text reason field with 10-character minimum
- One active request at a time per job — previous must be resolved before new
- Both drivers and technicians assigned to the job can request extensions

### Impact Analysis & Suggestions
- Impact scope: same driver AND same vehicle — both affected by delay
- System generates 2-3 rescheduling options
- Suggestion types: Push (shift all later jobs), Swap (reassign driver), Custom (scheduler decides)
- Impact visualization: timeline list showing before/after times for affected jobs

### Approval Flow & Notifications
- Dedicated approval screen with impact details and suggestion cards — accessed from push notification
- Scheduler can pick a suggestion OR enter custom times
- Optional reason on denial — quick deny for obvious cases
- Notifications after approval: driver + all technicians on job + any affected drivers from rescheduled jobs

### Claude's Discretion
- Database table schema for time_extension_requests and reschedule_options
- Impact calculation algorithm specifics
- API endpoint naming and response structure
- Flutter screen layout and widget composition

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/services/notificationService.js` — Phase 5 notification sending (FCM + email)
- `src/services/jobAssignmentService.js` — job assignment queries, driver availability
- `src/models/Job.js` — job queries, getJobsByDate
- `lib/providers/job_provider.dart` — job state management
- `lib/providers/notification_provider.dart` — notification state

### Established Patterns
- Backend: Static service methods, pino logging, tenant_id scoping
- Backend: Cron extensions in cronService.js
- Flutter: Provider + ChangeNotifier, permission gating
- Notifications: FCM topic-based sending from Phase 5

### Integration Points
- Job detail screen: add "Add More Time" button for in-progress jobs
- Notification system: trigger push notifications for extension requests and approvals
- Job status service: apply rescheduling changes to affected jobs

</code_context>

<specifics>
## Specific Ideas

- "Add More Time" button should be prominent on the job detail screen when job is in_progress
- Approval screen should show the full impact timeline so scheduler can make informed decisions
- Push notification for extension request should deep-link to the approval screen

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
