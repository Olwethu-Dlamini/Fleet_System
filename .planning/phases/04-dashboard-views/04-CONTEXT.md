# Phase 4: Dashboard & Views - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase enhances the dashboard with a "Jobs Today" card featuring a scheduler preview chart, weekend jobs filter, weekday driver/client toggle, and badge counts on dashboard cards. Primarily Flutter UI work with supporting backend endpoints.

</domain>

<decisions>
## Implementation Decisions

### Dashboard Layout & Cards
- "Jobs Today" card uses a mini bar chart showing jobs by hour — quick visual density overview
- Badge counts loaded on-load with pull-to-refresh — no real-time polling
- Dashboard cards in 2-column grid layout — fits mobile, equal card sizes
- fl_chart library for Flutter charts — lightweight, good for bar/line charts

### Views & Toggles
- Weekend view as a filter toggle on existing jobs screen — not a separate screen
- "Clients view" groups jobs by client name instead of by driver — same data, different grouping
- SegmentedButton for Drivers/Clients toggle — consistent with Phase 3 range toggle pattern
- Weekend definition is Saturday+Sunday fixed for v1

### Claude's Discretion
- Backend endpoint structure for dashboard aggregation queries
- Color scheme for bar chart bars
- Card styling and spacing details
- Pull-to-refresh animation

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/controllers/dashboardController.js` — existing dashboard metrics aggregation
- `src/services/dashboardService.js` — existing dashboard queries
- `lib/screens/dashboard/` — existing dashboard screen
- `lib/providers/job_provider.dart` — job state management with fetch methods

### Established Patterns
- Flutter: SegmentedButton for toggle UIs (Phase 3 precedent)
- Flutter: Provider pattern for state management
- Backend: Static service methods for aggregation queries
- Database: tenant_id scoping on all queries

### Integration Points
- Dashboard screen: extend existing with new cards and toggles
- Backend: may need new dashboard endpoints for chart data and badge counts
- fl_chart: new dependency to add to pubspec.yaml

</code_context>

<specifics>
## Specific Ideas

- Bar chart should show job count per hour for the current day
- Badge counts should show today's totals (pending, in progress, completed)
- Weekend filter should be a simple toggle that filters the job list to Saturday/Sunday dates

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
