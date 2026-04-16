# Phase 2: User, Vehicle & Scheduler Enhancements - Context

**Gathered:** 2026-03-21
**Status:** Ready for planning

<domain>
## Phase Boundary

This phase adds contact numbers to users (CRUD + display), vehicle maintenance scheduling with date-range blocking, and the scheduler role with correct permissions. It extends existing CRUD patterns and the permission system established in Phase 1.

</domain>

<decisions>
## Implementation Decisions

### User Contact Numbers
- E.164 international format with default country code +268 (Eswatini), user can change country
- Multiple phone numbers supported (primary + secondary)
- Contact numbers displayed on user list table, detail view, and create/edit forms
- Tap-to-call (tel: link) enabled on mobile for quick calling

### Vehicle Maintenance
- Predefined maintenance types dropdown (Service, Repair, Inspection, Tyre Change) plus "Other" with free text
- 3-state lifecycle: Scheduled -> In Progress -> Completed
- No overlapping maintenance windows allowed per vehicle
- Orange "In Maintenance" badge on vehicle list card as visual indicator

### Scheduler Role & Permissions
- Role-based column with permissions map in constants.js — extends existing USER_ROLE/PERMISSIONS pattern
- Optional note field when scheduler swaps vehicles (for audit trail, not required)
- GPS visibility toggle stored in `settings` table with key-value pairs (extensible for future settings)
- Same screens as admin with conditionally hidden admin-only actions (no duplicate screens)

### Claude's Discretion
- Database migration ordering and column naming
- API endpoint naming and response structure consistency with existing patterns
- Flutter widget composition and state management details within Provider pattern

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `src/config/constants.js` — USER_ROLE, PERMISSIONS maps to extend with scheduler role
- `src/middleware/authMiddleware.js` — `verifyToken`, `requireRole`, `requirePermission` functions
- `src/models/Vehicle.js` — Vehicle CRUD and availability checks to extend with maintenance
- `src/models/Job.js` — Job CRUD patterns to follow for maintenance model
- `lib/providers/` — ChangeNotifier pattern for state management
- `lib/services/` — API client pattern to follow for new services

### Established Patterns
- Backend: Static class methods for models, controller-service-model layers
- Backend: File headers with `// ============` decoration pattern
- Backend: camelCase JS, snake_case SQL, PascalCase classes
- Flutter: snake_case files, Provider pattern, screen-per-feature in `lib/screens/`
- Database: tenant_id on all tables (Phase 1), FOR UPDATE transactions for race conditions

### Integration Points
- User CRUD: Existing user routes/controllers need contact_number columns added
- Vehicle model: Needs maintenance relationship and availability check extension
- Permission middleware: requireRole/requirePermission needs scheduler role added
- Flutter navigation: Conditional visibility based on role already possible via Provider
- Constants.js: PERMISSIONS map is the single source of truth for role capabilities

</code_context>

<specifics>
## Specific Ideas

- Default phone country code to +268 (Eswatini) — user's primary market
- Multiple phone numbers per user (primary + secondary fields)
- Maintenance types should include common field service categories: Service, Repair, Inspection, Tyre Change

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>
