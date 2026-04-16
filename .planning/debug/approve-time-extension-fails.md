---
status: diagnosed
trigger: "failed to fetch api/time-extensions/1/approve when trying to approve a time extension request"
created: 2026-03-25T00:00:00Z
updated: 2026-03-25T00:00:00Z
---

## Current Focus

hypothesis: Multiple issues found - CORS missing PATCH, DB enum mismatch, and changes_json parsing bug in approveRequest
test: Code-level trace of full approve flow end-to-end
expecting: Identify all failure points
next_action: Report diagnosis

## Symptoms

expected: PATCH /api/time-extensions/1/approve succeeds and approves the time extension
actual: "failed to fetch" error when trying to approve
errors: "failed to fetch api/time-extensions/1/approve"
reproduction: Open approval screen, select a suggestion, click Approve
started: After recent modifications to handle cancel/unschedule actions

## Eliminated

(none)

## Evidence

- timestamp: 2026-03-25
  checked: CORS config in server.js line 82
  found: methods array is ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'] — PATCH is NOT listed
  implication: CRITICAL — Browser pre-flight OPTIONS check will reject PATCH requests. This alone causes the "failed to fetch" error.

- timestamp: 2026-03-25
  checked: reschedule_options table schema in vehicle_scheduling.sql line 466
  found: type column is enum('push','swap','custom') — only 3 values
  implication: CRITICAL — Backend _buildSuggestions creates suggestions with types 'none', 'push', 'reassign', 'cancel', 'custom'. Types 'none', 'reassign', and 'cancel' are NOT in the DB enum. INSERT will fail with a MySQL data truncation error for those types.

- timestamp: 2026-03-25
  checked: approveRequest in timeExtensionService.js lines 594-605
  found: When a suggestion_id is provided, the code parses changes_json but does NOT unwrap the new payload format. It does `changes = JSON.parse(opts[0].changes_json)` which returns `{changes: [...], recommended: true, metadata: {...}}` — then iterates `for (const change of changes)` which iterates over object keys, not the array.
  implication: CRITICAL — changes will be the wrapper object, not the array. The for-loop will iterate over keys ("changes", "recommended", "metadata") which are strings, not objects with jobId/newStart/newEnd. The changes won't be applied.

- timestamp: 2026-03-25
  checked: Flutter _rebuildCustomChanges in approval_screen.dart lines 104-111
  found: Uses keys 'job_id' and 'new_start'/'new_end' (snake_case)
  implication: Backend approveRequest at line 628 checks `change.jobId` (camelCase). Mismatch means custom changes will be silently skipped because `change.jobId` is undefined (the `if (!change.jobId) continue` guard at line 628 will skip every entry).

- timestamp: 2026-03-25
  checked: Route mounting in routes/index.js line 44
  found: timeExtensionRoutes mounted at '/time-extensions' under '/api' router
  implication: Route path /api/time-extensions/:id/approve is correct. No issue here.

- timestamp: 2026-03-25
  checked: Flutter ApiService.patch() method in api_service.dart lines 118-136
  found: Correctly sends PATCH with JSON body and auth headers
  implication: Flutter side is sending the right HTTP method. The failure is server-side CORS rejection.

- timestamp: 2026-03-25
  checked: getActiveRequest in timeExtensionService.js lines 540-548
  found: Correctly unwraps new payload format {changes, recommended, metadata} when reading suggestions back
  implication: The read path is fixed but the approve path (line 601) was NOT updated to match

## Resolution

root_cause: Three distinct bugs causing the approve flow to fail:

1. **CORS blocks PATCH** (server.js:82) — The CORS `methods` array does not include 'PATCH'. The browser pre-flight OPTIONS request fails, causing "failed to fetch" before the request even reaches Express.

2. **DB enum mismatch** (vehicle_scheduling.sql:466) — The `reschedule_options.type` column is `enum('push','swap','custom')` but the backend now creates suggestions with types 'none', 'reassign', and 'cancel'. These INSERTs fail silently (caught by the non-fatal try/catch in createRequest), meaning no suggestions are saved to the DB, meaning the approval screen has no suggestion_id to send.

3. **changes_json not unwrapped in approveRequest** (timeExtensionService.js:601) — `createRequest` stores changes_json as `{changes: [...], recommended: bool, metadata: {...}}` but `approveRequest` does `changes = JSON.parse(opts[0].changes_json)` which gets the wrapper object, not the inner array. It then iterates over the wrapper object's keys instead of the changes array.

4. **Custom changes key mismatch** (approval_screen.dart:106-109 vs timeExtensionService.js:628) — Flutter sends `{job_id, new_start, new_end}` (snake_case) but the backend checks `change.jobId`, `change.newStart`, `change.newEnd` (camelCase). All custom changes are silently skipped.

fix: (not applied — diagnosis only)
verification: (not applied — diagnosis only)
files_changed: []
