# Phase 3: Job Assignment & Status Automation - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase adds smart job assignment with load balancing visuals, automatic job status transitions via cron, completion restrictions to assigned personnel, GPS capture on completion, and a full assignment audit trail. It builds on the existing job and assignment system from Phase 1.

</domain>

<decisions>
## Implementation Decisions

### Job Assignment & Load Balancing
- Job count filterable by time range: yearly, monthly, and weekly counts — user can toggle between ranges on the assignment picker
- Binary green highlight on drivers with fewer jobs than average (based on selected filter)
- "Suggested" chip on the driver with lowest count among available drivers (based on selected filter)
- Assignment history tracks all events: create, reassign, swap, cancel — full audit trail in assignment_history table

### Job Status Automation
- Cron runs every 1 minute to auto-transition jobs to "in progress" at scheduled start time
- GPS capture on completion: required but with fallback — attempt GPS, if unavailable store null + "no_gps" flag
- GPS accuracy threshold: 50 meters for field service
- Completion confirmation: confirm dialog — "Are you sure? This cannot be undone." before marking complete

### Multi-Technician & Driver Enforcement
- Chip-based multi-select for adding technicians — search and add as chips, remove with X
- No hard limit on technicians per job
- One driver per vehicle enforced
- Driver shown as primary (bold) in UI, technicians as secondary list — clear hierarchy

### Claude's Discretion
- Cron library choice (node-cron already in requirements)
- Database migration structure and column naming
- Flutter widget composition details
- Exact SQL queries for load balancing calculations

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/services/jobAssignmentService.js` — existing assignment logic to extend with load balancing
- `src/services/jobStatusService.js` — existing status transitions to extend with auto-transition
- `src/models/Job.js` — job queries, multi-technician GROUP_CONCAT patterns
- `src/config/constants.js` — JOB_STATUS enum, PERMISSIONS map
- `lib/providers/job_provider.dart` — job state management
- `lib/services/job_service.dart` — job API client

### Established Patterns
- Backend: Static class methods, controller-service-model layers
- Backend: FOR UPDATE transactions for race conditions (Phase 1)
- Backend: pino structured logging (Phase 1)
- Flutter: Provider pattern, ChangeNotifier
- Flutter: Permission gating via hasPermission() (Phase 2)
- Database: tenant_id on all tables, idempotent migrations with ADD COLUMN IF NOT EXISTS

### Integration Points
- Job assignment picker: extend existing create/edit job screens
- Status transitions: extend jobStatusService with cron trigger
- GPS capture: Flutter geolocator package for coordinates
- Assignment history: new table, logged from existing assignment endpoints

</code_context>

<specifics>
## Specific Ideas

- Job count filters (yearly/monthly/weekly) should be toggleable in the assignment picker UI
- GPS fallback stores null coordinates with a "no_gps" flag for audit purposes
- Confirm dialog on completion prevents accidental job closures in the field

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
