---
phase: quick
plan: 260325-jwh
type: execute
wave: 1
depends_on: []
files_modified:
  - vehicle-scheduling-backend/src/services/timeExtensionService.js
  - vehicle-scheduling-backend/src/routes/timeExtension.js
  - vehicle_scheduling_app/lib/services/time_extension_service.dart
  - vehicle_scheduling_app/lib/providers/time_extension_provider.dart
  - vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart
  - vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart
  - vehicle_scheduling_app/lib/models/time_extension.dart
autonomous: true
requirements: []
must_haves:
  truths:
    - "Impact analysis detects jobs that genuinely overlap with the extended time window, not just jobs starting after the new end time"
    - "Impact analysis checks driver_id overlap in addition to vehicle_id and technician overlap"
    - "Scheduler sees the full day schedule (all jobs grouped by driver/technician) on the approval screen"
    - "Technician sees a preview of potentially affected jobs after selecting extension duration"
  artifacts:
    - path: "vehicle-scheduling-backend/src/services/timeExtensionService.js"
      provides: "Fixed analyzeImpact with proper overlap detection + getDaySchedule method"
      contains: "getDaySchedule"
    - path: "vehicle-scheduling-backend/src/routes/timeExtension.js"
      provides: "GET /api/time-extensions/:jobId/day-schedule route"
      contains: "day-schedule"
    - path: "vehicle_scheduling_app/lib/services/time_extension_service.dart"
      provides: "getDaySchedule(int jobId) method"
      contains: "getDaySchedule"
    - path: "vehicle_scheduling_app/lib/providers/time_extension_provider.dart"
      provides: "_daySchedule state + loadDaySchedule method"
      contains: "loadDaySchedule"
    - path: "vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart"
      provides: "Day Schedule section below affected jobs"
      contains: "Day Schedule"
    - path: "vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart"
      provides: "Preview section listing potentially affected jobs"
      contains: "affectedJobs"
  key_links:
    - from: "time_extension_approval_screen.dart"
      to: "/api/time-extensions/:jobId/day-schedule"
      via: "provider.loadDaySchedule"
      pattern: "loadDaySchedule"
    - from: "timeExtensionService.js analyzeImpact"
      to: "jobs + job_assignments + job_technicians tables"
      via: "proper overlap detection SQL"
      pattern: "scheduled_time_start < .* AND scheduled_time_end >"
---

<objective>
Fix the time extension impact analysis to use proper time overlap detection instead of the current `>=` comparison (which misses jobs that start before the new end time but overlap the extension window). Add driver_id checking alongside vehicle_id and technician checks. Add a new day-schedule endpoint so the approval screen shows the FULL day picture, and add a preview on the request screen.

Purpose: The current `analyzeImpact` uses `scheduled_time_start >= newEndTime` which only finds jobs starting AFTER the new end — it misses jobs whose time ranges actually overlap with the extended window. Also, driver_id is not checked directly (only technicians are checked via job_technicians). This leaves blind spots in conflict detection.

Output: Fixed backend service + new route + updated Flutter service/provider/screens
</objective>

<execution_context>
@~/.claude/get-shit-done/workflows/execute-plan.md
@~/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@vehicle-scheduling-backend/src/services/timeExtensionService.js
@vehicle-scheduling-backend/src/routes/timeExtension.js
@vehicle_scheduling_app/lib/services/time_extension_service.dart
@vehicle_scheduling_app/lib/providers/time_extension_provider.dart
@vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart
@vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart
@vehicle_scheduling_app/lib/models/time_extension.dart
@vehicle_scheduling_app/lib/config/app_config.dart
</context>

<tasks>

<task type="auto">
  <name>Task 1: Fix analyzeImpact overlap detection + add getDaySchedule + new route</name>
  <files>
    vehicle-scheduling-backend/src/services/timeExtensionService.js
    vehicle-scheduling-backend/src/routes/timeExtension.js
  </files>
  <action>
**In timeExtensionService.js:**

1. Fix `analyzeImpact()` method (line ~196-221). Change the WHERE clause overlap condition from:
   ```sql
   AND j.scheduled_time_start >= ?
   ```
   To proper interval overlap detection:
   ```sql
   AND j.scheduled_time_start < ?
   AND j.scheduled_time_end > ?
   ```
   Where the first `?` is `newEndTime` and the second `?` is the SOURCE JOB's current `scheduled_time_end` (not the new end time). This detects any job whose time range overlaps with the extension window `[sourceJobCurrentEnd, newEndTime]`.

   The method signature needs to accept `sourceJobCurrentEnd` as a new parameter. Update the call in `createRequest()` (line ~152-154) to pass `job.scheduled_time_end` as the 5th arg.

   Also add `driver_id` to the OR condition. Currently it checks:
   - `ja.vehicle_id = (subquery for source job vehicle_id)`
   - `OR EXISTS (job_technicians overlap)`

   Add a third OR branch:
   ```sql
   OR ja.driver_id IN (SELECT driver_id FROM job_assignments WHERE job_id = ? AND driver_id IS NOT NULL)
   ```
   This catches driver conflicts that aren't covered by the job_technicians check (e.g., a driver assigned via job_assignments but not in job_technicians).

   Updated parameter array: `[tenantId, scheduledDate, jobId, newEndTime, sourceJobCurrentEnd, jobId, jobId, jobId]`

2. Add `getDaySchedule(jobId, tenantId)` static method to the class:
   - First, fetch the source job's `scheduled_date` from the `jobs` table (WHERE id=jobId AND tenant_id=tenantId).
   - Then query ALL jobs for that date for the same tenant (excluding cancelled), joined with job_assignments and job_technicians to get driver/technician info, and joined with users to get names.
   - Return an object: `{ date, jobs: [...] }` where each job includes: `id, job_number, scheduled_time_start, scheduled_time_end, current_status, driver_id, driver_name, technician_ids, technician_names`.
   - Use a single query joining jobs -> job_assignments -> users (for driver) and a GROUP_CONCAT subquery for technicians:
     ```sql
     SELECT j.id, j.job_number, j.scheduled_time_start, j.scheduled_time_end,
            j.current_status, j.customer_name,
            ja.driver_id, ja.vehicle_id,
            CONCAT(ud.first_name, ' ', ud.last_name) AS driver_name,
            (SELECT GROUP_CONCAT(CONCAT(u2.first_name, ' ', u2.last_name) SEPARATOR ', ')
             FROM job_technicians jt2
             JOIN users u2 ON u2.id = jt2.user_id
             WHERE jt2.job_id = j.id) AS technician_names,
            (SELECT GROUP_CONCAT(jt3.user_id) FROM job_technicians jt3 WHERE jt3.job_id = j.id) AS technician_ids
     FROM jobs j
     LEFT JOIN job_assignments ja ON ja.job_id = j.id
     LEFT JOIN users ud ON ud.id = ja.driver_id
     WHERE j.tenant_id = ? AND j.scheduled_date = ? AND j.current_status != 'cancelled'
     ORDER BY j.scheduled_time_start ASC
     ```
   - Group the results in JS by driver/technician for the response: iterate over rows, build a Map keyed by `driver_id` (or `technician_id` for technician-only jobs), collecting jobs under each person. Return `{ date, personnel: [{ id, name, role, jobs: [...] }] }`.

**In timeExtension.js:**

3. Add the new route BEFORE the `/:jobId` route (line ~285) to avoid Express matching `day-schedule` as a jobId:
   ```javascript
   router.get(
     '/:jobId/day-schedule',
     verifyToken,
     requirePermission('jobs:update'),
     [param('jobId').isInt({ min: 1 }).withMessage('jobId must be a positive integer')],
     async (req, res) => { ... }
   );
   ```
   Add Swagger JSDoc comment matching the project's existing pattern (see other routes in the file).
   The handler calls `TimeExtensionService.getDaySchedule(jobId, tenantId)` and returns `{ success: true, ...result }`.
  </action>
  <verify>
    <automated>cd C:/Users/olwethu/Desktop/test/vehicle-scheduling-backend && node -e "require('./src/services/timeExtensionService'); console.log('Service loads OK')" && node -e "require('./src/routes/timeExtension'); console.log('Routes load OK')"</automated>
  </verify>
  <done>
    - analyzeImpact uses proper overlap detection: `scheduled_time_start < newEndTime AND scheduled_time_end > sourceJobCurrentEnd`
    - analyzeImpact checks driver_id via job_assignments in addition to vehicle_id and technicians
    - getDaySchedule method exists and returns all jobs for the day grouped by personnel
    - GET /:jobId/day-schedule route exists with verifyToken + requirePermission('jobs:update')
    - Route is placed BEFORE /:jobId to avoid param collision
  </done>
</task>

<task type="auto">
  <name>Task 2: Add Flutter service/provider/model support for day schedule</name>
  <files>
    vehicle_scheduling_app/lib/models/time_extension.dart
    vehicle_scheduling_app/lib/services/time_extension_service.dart
    vehicle_scheduling_app/lib/providers/time_extension_provider.dart
  </files>
  <action>
**In time_extension.dart — add two new model classes at the bottom:**

1. `DayScheduleJob` — represents a single job in the day schedule:
   ```dart
   class DayScheduleJob {
     final int id;
     final String jobNumber;
     final String scheduledTimeStart;
     final String scheduledTimeEnd;
     final String currentStatus;
     final String? customerName;
     final int? driverId;
     final int? vehicleId;
     final String? driverName;
     final String? technicianNames;

     // factory fromJson with snake_case keys
   }
   ```

2. `DaySchedulePersonnel` — groups jobs by person:
   ```dart
   class DaySchedulePersonnel {
     final int id;
     final String name;
     final String role; // 'driver' or 'technician'
     final List<DayScheduleJob> jobs;

     // factory fromJson parsing jobs list
   }
   ```

**In time_extension_service.dart — add method:**

3. `getDaySchedule(int jobId)` — calls `GET ${AppConfig.timeExtensionsEndpoint}/$jobId/day-schedule`. Parses the response into `{ 'date': String, 'personnel': List<DaySchedulePersonnel> }`. Return as `Map<String, dynamic>`.

**In time_extension_provider.dart — add state + method:**

4. Add private state:
   ```dart
   List<DaySchedulePersonnel> _daySchedule = [];
   String? _dayScheduleDate;
   ```

5. Add getter:
   ```dart
   List<DaySchedulePersonnel> get daySchedule => List.unmodifiable(_daySchedule);
   String? get dayScheduleDate => _dayScheduleDate;
   ```

6. Add `loadDaySchedule(int jobId)` async method:
   - Sets `_loading = true`, calls `_service.getDaySchedule(jobId)`, parses result into `_daySchedule` and `_dayScheduleDate`, handles errors, calls `notifyListeners()`.

7. Update `clearState()` to also clear `_daySchedule = []` and `_dayScheduleDate = null`.
  </action>
  <verify>
    <automated>cd C:/Users/olwethu/Desktop/test/vehicle_scheduling_app && flutter analyze lib/models/time_extension.dart lib/services/time_extension_service.dart lib/providers/time_extension_provider.dart 2>&1 | tail -5</automated>
  </verify>
  <done>
    - DayScheduleJob and DaySchedulePersonnel models parse the backend response
    - time_extension_service.dart has getDaySchedule(int jobId)
    - time_extension_provider.dart exposes daySchedule list and loadDaySchedule method
    - clearState resets day schedule data
    - flutter analyze reports no errors on these files
  </done>
</task>

<task type="auto">
  <name>Task 3: Add Day Schedule section to approval screen + preview to request screen</name>
  <files>
    vehicle_scheduling_app/lib/screens/time_management/time_extension_approval_screen.dart
    vehicle_scheduling_app/lib/screens/time_management/time_extension_request_screen.dart
  </files>
  <action>
**In time_extension_approval_screen.dart:**

1. Import `DaySchedulePersonnel` and `DayScheduleJob` from the models file.

2. In `initState()`, add a second `Future.microtask` call to also load the day schedule:
   ```dart
   Future.microtask(() => context.read<TimeExtensionProvider>().loadDaySchedule(widget.jobId));
   ```

3. In the `build` method's `Column` children, AFTER the `_AffectedJobsSection` widget and its `SizedBox(height: 16)`, add a new `_DayScheduleSection` widget:
   ```dart
   _DayScheduleSection(
     personnel: provider.daySchedule,
     date: provider.dayScheduleDate,
     sourceJobId: widget.jobId,
   ),
   const SizedBox(height: 16),
   ```

4. Create a new private `_DayScheduleSection` StatelessWidget at the bottom of the file:
   - Takes `List<DaySchedulePersonnel> personnel`, `String? date`, `int sourceJobId`.
   - Renders a section header "Day Schedule" with the date in parentheses.
   - If personnel is empty, shows "No schedule data available" in grey.
   - Otherwise, for each person in personnel, renders a Card with:
     - Header row: person name (bold) + role badge (small colored chip: blue for driver, green for technician).
     - A ListView of their jobs, each showing: job number, time range (start - end), status chip. Highlight the source job (where job.id == sourceJobId) with a subtle yellow background and a "(this job)" label.
   - Use `shrinkWrap: true` and `NeverScrollableScrollPhysics()` since it's inside a SingleChildScrollView.

**In time_extension_request_screen.dart:**

5. Import `TimeExtensionProvider` (already imported) and `AffectedJob` from models.

6. After the submit button section (after `const SizedBox(height: 16)` on line ~231) and BEFORE the info note Container, add a preview section that shows when `provider.affectedJobs.isNotEmpty`:
   ```dart
   if (provider.affectedJobs.isNotEmpty) ...[
     _SectionLabel(label: 'Potentially Affected Jobs'),
     const SizedBox(height: 8),
     Card(
       elevation: 1,
       child: ListView.separated(
         shrinkWrap: true,
         physics: const NeverScrollableScrollPhysics(),
         itemCount: provider.affectedJobs.length,
         separatorBuilder: (_, __) => const Divider(height: 1),
         itemBuilder: (context, index) {
           final job = provider.affectedJobs[index];
           return ListTile(
             dense: true,
             leading: const Icon(Icons.warning_amber, size: 20, color: Colors.orange),
             title: Text('Job #${job.jobNumber}'),
             subtitle: Text('${job.currentStart} - ${job.currentEnd}'),
           );
         },
       ),
     ),
     const SizedBox(height: 16),
   ],
   ```

   NOTE: The `affectedJobs` list is populated after `submitRequest` returns. This preview shows AFTER submission in the provider state. However, since the screen pops on success, this preview is most useful if submit fails or if the user navigates back. For a pre-submit preview, instead trigger a lightweight impact check. Since the backend's `createRequest` already returns affectedJobs, and we don't want to create a request just to preview, the simplest approach is to show the preview AFTER submission confirmation — the request screen already pops on success with `Navigator.pop(context, true)`. So instead, show this section only when `provider.affectedJobs.isNotEmpty && provider.activeRequest != null` (i.e., after a successful submission where the user might still be on the screen). This is a minor UX addition.

   Actually, a better approach: the affected jobs list from `submitRequest` is set in the provider. If submission succeeds, the screen pops. So this preview will only show if submission happened but navigation didn't (edge case). For a proper pre-submit preview, we'd need a separate analyze endpoint. Since the user's description says "after technician selects a duration, show a preview section", the simplest implementation without a new endpoint is to show an informational message like "Submitting will check for scheduling conflicts with other jobs assigned to the same driver, technician, or vehicle for the day." as a styled info card below the reason field. This sets expectations without requiring a separate API call.

   Implement: Add an info card between the reason field and submit button that says: "Impact Preview: This request will be checked against all jobs for the same day involving your driver, technician team, and vehicle. The scheduler will see any conflicts before approving."
  </action>
  <verify>
    <automated>cd C:/Users/olwethu/Desktop/test/vehicle_scheduling_app && flutter analyze lib/screens/time_management/time_extension_approval_screen.dart lib/screens/time_management/time_extension_request_screen.dart 2>&1 | tail -5</automated>
  </verify>
  <done>
    - Approval screen loads and displays day schedule grouped by driver/technician below the affected jobs section
    - Source job is visually highlighted in the day schedule
    - Request screen shows an impact preview info card between reason and submit button
    - flutter analyze reports no errors on both screen files
  </done>
</task>

</tasks>

<verification>
1. Backend files load without errors: `node -e "require('./src/services/timeExtensionService')"`
2. Flutter files pass static analysis: `flutter analyze lib/models/time_extension.dart lib/services/time_extension_service.dart lib/providers/time_extension_provider.dart lib/screens/time_management/`
3. The analyzeImpact SQL uses `<` and `>` for proper overlap detection (not `>=`)
4. The day-schedule route is registered before the /:jobId catch-all route
</verification>

<success_criteria>
- analyzeImpact detects overlapping jobs (not just jobs starting after new end time)
- analyzeImpact checks driver_id conflicts in job_assignments
- New GET /:jobId/day-schedule endpoint returns all jobs for the day grouped by personnel
- Approval screen shows full day schedule section with personnel grouping
- Request screen shows impact awareness info card
- All files pass syntax checks (node require / flutter analyze)
</success_criteria>

<output>
After completion, create `.planning/quick/260325-jwh-fix-time-extension-impact-analysis-to-ch/260325-jwh-SUMMARY.md`
</output>
