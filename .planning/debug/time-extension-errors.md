---
status: diagnosed
trigger: "Debug the Add Time feature - loads an error when using time extension"
created: 2026-03-25T00:00:00Z
updated: 2026-03-25T00:00:00Z
---

## Current Focus

hypothesis: Multiple SQL column-name mismatches in backend service cause 500 errors
test: Traced all SQL queries against actual DB schema
expecting: Column references match schema
next_action: Report findings

## Symptoms

expected: Technician taps Add More Time, fills form, submits, backend processes successfully
actual: Error returned when using the time extension feature
errors: Likely 500 Internal Server Error from backend SQL failures
reproduction: Submit a time extension request on any in-progress job
started: After recent modifications to timeExtensionService.js

## Eliminated

(none - issues found on first pass)

## Evidence

- timestamp: 2026-03-25
  checked: users table schema in vehicle_scheduling.sql and vehicle_scheduling2.sql
  found: users table has column `full_name` (varchar 100). Does NOT have `first_name` or `last_name` columns.
  implication: Any SQL referencing first_name/last_name will fail with SQL error

- timestamp: 2026-03-25
  checked: getDaySchedule SQL query (line 259-260)
  found: References `ud.first_name`, `ud.last_name`, `u2.first_name`, `u2.last_name` - none of these columns exist
  implication: getDaySchedule will throw SQL error every time it runs

- timestamp: 2026-03-25
  checked: _buildSuggestions SQL query (line 382)
  found: References `u.first_name`, `u.last_name` - columns don't exist
  implication: Swap suggestion generation will fail (caught by try/catch, so non-fatal)

- timestamp: 2026-03-25
  checked: _buildSuggestions JS code (line 402)
  found: References `driver.first_name` and `driver.last_name` which would be undefined even if SQL succeeded
  implication: Driver name would be empty string, falling back to "Driver #id"

- timestamp: 2026-03-25
  checked: getPendingRequests SQL query (line 469)
  found: References `u.full_name AS requester_name` - this IS correct, matches schema
  implication: getPendingRequests works fine

- timestamp: 2026-03-25
  checked: users table role enum
  found: role is enum('admin','dispatcher','driver') - no 'technician' or 'scheduler' roles
  implication: Queries filtering by role IN ('driver','technician') will miss technician users (if any exist); queries for role IN ('admin','scheduler','dispatcher') will never match 'scheduler'

- timestamp: 2026-03-25
  checked: Route ordering in timeExtension.js
  found: /pending before /:jobId, and /:jobId/day-schedule before /:jobId - ordering is correct
  implication: No route-shadowing issues

- timestamp: 2026-03-25
  checked: Flutter analyze output
  found: 17 info-level issues only (deprecations, async context warnings). No errors or warnings.
  implication: Flutter code compiles fine, no structural issues

- timestamp: 2026-03-25
  checked: Backend JS syntax check (node -c)
  found: Both timeExtensionService.js and timeExtension.js pass syntax validation
  implication: No syntax errors in backend

- timestamp: 2026-03-25
  checked: createRequest flow for the POST endpoint
  found: The createRequest method calls analyzeImpact and _buildSuggestions AFTER committing the request. Both have SQL errors but are wrapped in try/catch (line 175-178), so the request IS created but affectedJobs and suggestions will be empty arrays.
  implication: Submit may appear to "succeed" but with empty impact data; OR the error from getDaySchedule on the approval screen causes visible errors

## Resolution

root_cause: |
  Three SQL queries in timeExtensionService.js reference non-existent columns `first_name` and `last_name` on the `users` table. The actual column is `full_name`.

  1. getDaySchedule() method (line 259-260): SQL uses `ud.first_name`, `ud.last_name`, `u2.first_name`, `u2.last_name` -- will throw SQL error, causing 500 on GET /api/time-extensions/:jobId/day-schedule
  2. _buildSuggestions() method (line 382): SQL uses `u.first_name`, `u.last_name` -- will throw SQL error (non-fatal, caught)
  3. _buildSuggestions() JS code (line 402): References `driver.first_name`/`driver.last_name` properties

  Secondary issue: The `role` enum in the DB only has ('admin','dispatcher','driver'). Code references 'technician' and 'scheduler' roles that don't exist in the enum.

fix: (not applied per instructions)
verification: (not applied)
files_changed: []
