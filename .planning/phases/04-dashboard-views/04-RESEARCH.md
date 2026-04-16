# Phase 04: Dashboard & Views - Research

**Researched:** 2026-03-21
**Domain:** Flutter dashboard UI, fl_chart bar charts, Node.js/Express dashboard aggregation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- "Jobs Today" card uses a mini bar chart showing jobs by hour — quick visual density overview
- Badge counts loaded on-load with pull-to-refresh — no real-time polling
- Dashboard cards in 2-column grid layout — fits mobile, equal card sizes
- fl_chart library for Flutter charts — lightweight, good for bar/line charts
- Weekend view as a filter toggle on existing jobs screen — not a separate screen
- "Clients view" groups jobs by client name instead of by driver — same data, different grouping
- SegmentedButton for Drivers/Clients toggle — consistent with Phase 3 range toggle pattern
- Weekend definition is Saturday+Sunday fixed for v1

### Claude's Discretion
- Backend endpoint structure for dashboard aggregation queries
- Color scheme for bar chart bars
- Card styling and spacing details
- Pull-to-refresh animation

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DASH-01 | "Jobs Today" card on dashboard shows scheduler preview (reference existing graphs page) | Backend `/api/dashboard/chart-data` endpoint returns jobs-by-hour; fl_chart BarChart renders inline in the existing manager dashboard card |
| DASH-02 | Weekend jobs view — button to filter/show weekend-scheduled jobs | JobProvider already has `setStatusFilter`; a `setWeekendFilter` boolean follows the same pattern; backend `loadJobs()` fetches all jobs so client-side filter works without new endpoint |
| DASH-03 | Weekday view toggle — switch between drivers-assigned view and clients view | SegmentedButton already used in scheduler_screen.dart with identical pattern; same data (`jobProvider.allJobs`), different grouping logic in the widget |
| DASH-04 | Job count badges on dashboard cards | `getQuickStats` endpoint already returns `todayTotal`, `todayCompleted`, `todayPending`, `todayAssigned`, `todayInProgress`; existing `_StatCardData` cards just need the badge overlay widget added |
</phase_requirements>

---

## Summary

Phase 4 is primarily a Flutter UI phase with one small backend addition. Three of the four requirements can be satisfied entirely client-side using data already loaded by `loadJobs()` and `getQuickStats`. The only net-new backend work is a single endpoint (`GET /api/dashboard/chart-data`) that returns jobs-per-hour for the bar chart — the existing `getDashboardSummary` already fetches `todayJobs` but does not aggregate them by hour.

The fl_chart library (v1.2.0) is the locked choice and is well-suited for the mini bar chart. It is not yet in `pubspec.yaml` and must be added. The SegmentedButton pattern for the Drivers/Clients toggle is already implemented in `scheduler_screen.dart`, making DASH-03 a straightforward copy of that pattern.

The existing dashboard controller has a gap: both `getDashboardSummary` and `getQuickStats` are missing `verifyToken` middleware and lack `tenant_id` scoping in their SQL queries. The chart-data endpoint must not repeat this gap.

**Primary recommendation:** Add `fl_chart: ^1.2.0` to pubspec.yaml, add one backend endpoint for hourly job counts (with verifyToken + tenant_id), and extend the existing Flutter dashboard screen with the chart card, weekend toggle in the jobs list, drivers/clients SegmentedButton, and badge overlays.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| fl_chart | ^1.2.0 | Flutter bar/line/pie charts | Locked decision; most-downloaded Flutter chart library; lightweight, no native dependencies |
| provider | ^6.1.5+1 | State management | Already in project; existing JobProvider/VehicleProvider |
| intl | ^0.20.2 | Date formatting for chart axis labels | Already in project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| flutter/material.dart | SDK | SegmentedButton, Badge widget | Already available; Badge widget added in Flutter 3.x for count overlays |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| fl_chart | syncfusion_flutter_charts | Syncfusion is commercial, requires license; fl_chart is free and MIT |
| fl_chart | charts_flutter | charts_flutter is deprecated/unmaintained by Google; fl_chart is actively maintained |
| Backend hourly endpoint | Client-side group from todayJobs | Client-side works if todayJobs is already loaded; simpler but duplicates logic if we ever need server-side aggregation |

**Installation:**
```bash
# In vehicle_scheduling_app/
flutter pub add fl_chart
# Or manually add to pubspec.yaml:
#   fl_chart: ^1.2.0
flutter pub get
```

**Version verification:** Confirmed 1.2.0 from pub.dev (fetched 2026-03-21, published ~7 days prior).

---

## Architecture Patterns

### Existing Dashboard Structure

The current `dashboard_screen.dart` splits into two code paths:
- `_buildTechnicianDashboard()` — shows technician's own jobs
- `_buildManagerDashboard()` — shows all jobs + vehicles (target for DASH-01 to DASH-04)

All four DASH requirements apply to the manager/scheduler view only.

### Pattern 1: fl_chart BarChart for Jobs-Per-Hour

**What:** A `BarChart` widget renders a horizontal list of bars, one per hour (0–23). Bar height = job count for that hour.
**When to use:** Inside the "Jobs Today" card in `_buildManagerDashboard()`.

```dart
// Source: pub.dev/documentation/fl_chart/latest/
import 'package:fl_chart/fl_chart.dart';

Widget _buildJobsChart(List<Map<String, dynamic>> hourlyData) {
  return SizedBox(
    height: 80,  // mini preview height
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: hourlyData.isEmpty
            ? 5
            : hourlyData.map((h) => (h['count'] as int).toDouble()).reduce(
                (a, b) => a > b ? a : b) + 1,
        barGroups: List.generate(24, (hour) {
          final count = hourlyData
              .firstWhere(
                (h) => h['hour'] == hour,
                orElse: () => {'hour': hour, 'count': 0},
              )['count'] as int;
          return BarChartGroupData(
            x: hour,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                color: const Color(0xFF6366F1),  // indigo, matches _P.inst
                width: 6,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(3),
                ),
              ),
            ],
          );
        }),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 6,
              getTitlesWidget: (value, meta) => Text(
                '${value.toInt()}h',
                style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    ),
  );
}
```

### Pattern 2: SegmentedButton for Drivers/Clients Toggle

**What:** Reuse the exact SegmentedButton pattern from `scheduler_screen.dart`.
**When to use:** In the weekday jobs section of the manager dashboard.

```dart
// Source: existing scheduler_screen.dart pattern (Phase 3)
SegmentedButton<String>(
  segments: const [
    ButtonSegment(value: 'drivers', label: Text('Drivers')),
    ButtonSegment(value: 'clients', label: Text('Clients')),
  ],
  selected: {_scheduleView},  // 'drivers' or 'clients'
  onSelectionChanged: (s) => setState(() => _scheduleView = s.first),
  style: ButtonStyle(
    padding: WidgetStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 12),
    ),
  ),
)
```

The "clients" grouping iterates `todayJobs`, groups by `job.customerName`, and renders a section per client rather than per driver. No additional API calls required.

### Pattern 3: Weekend Filter Toggle

**What:** A boolean flag `_showWeekendOnly` in `JobsListScreen` state. When true, the displayed list filters to jobs where `scheduledDate.weekday >= 6` (Saturday=6, Sunday=7 in Dart's `DateTime`).
**When to use:** Filter toggle button in the jobs list AppBar actions.

```dart
// Dart DateTime.weekday: Monday=1 ... Saturday=6, Sunday=7
List<Job> get _weekendJobs => jobProvider.allJobs
    .where((j) =>
        j.scheduledDate.weekday == DateTime.saturday ||
        j.scheduledDate.weekday == DateTime.sunday)
    .toList();
```

Note: `DateTime.saturday` = 6, `DateTime.sunday` = 7. These are named constants in Dart's core library — use them, not raw integers.

### Pattern 4: Badge Counts on Dashboard Cards

**What:** Flutter's Material `Badge` widget wraps an icon or card to show a numeric count.
**When to use:** On each stat card to overlay a count.

```dart
// Material 3 Badge — available in Flutter 3.x (project uses SDK ^3.9.2)
Badge(
  label: Text('$count'),
  isLabelVisible: count > 0,
  child: Icon(Icons.pending_outlined),
)
```

For the 2-column card grid in `_buildStatCards`, a simpler `Stack` + `Positioned` with a `Container` is more reliable for full-card badges than wrapping the card widget itself.

### Pattern 5: Backend — Jobs-Per-Hour Endpoint

**What:** New endpoint `GET /api/dashboard/chart-data` on the backend that returns hourly job counts for today.

```javascript
// dashboardController.js addition
static async getChartData(req, res) {
  try {
    const tenantId = req.user.tenant_id;  // from verifyToken
    const today = new Date().toISOString().slice(0, 10);

    const [rows] = await db.query(
      `SELECT
         HOUR(scheduled_time_start) AS hour,
         COUNT(*) AS count
       FROM jobs
       WHERE scheduled_date = ?
         AND tenant_id = ?
         AND current_status NOT IN ('cancelled')
       GROUP BY HOUR(scheduled_time_start)
       ORDER BY hour ASC`,
      [today, tenantId]
    );

    return res.json({
      success: true,
      date: today,
      hourly: rows.map(r => ({
        hour: Number(r.hour),
        count: Number(r.count),
      })),
    });
  } catch (err) {
    log.error({ err }, 'getChartData error');
    return res.status(500).json({ success: false, error: err.message });
  }
}
```

Route registration in `dashboard.js`:
```javascript
const { verifyToken } = require('../middleware/authMiddleware');
router.get('/chart-data', verifyToken, dashboardController.getChartData);
```

### Recommended Project Structure (additions only)

```
vehicle_scheduling_app/lib/
├── screens/
│   ├── dashboard/
│   │   └── dashboard_screen.dart   ← EXTEND: add chart card, toggle, badges
│   └── jobs/
│       └── jobs_list_screen.dart   ← EXTEND: add weekend filter toggle
vehicle-scheduling-backend/src/
├── controllers/
│   └── dashboardController.js      ← ADD: getChartData method
└── routes/
    └── dashboard.js                ← ADD: /chart-data route with verifyToken
```

### Anti-Patterns to Avoid

- **Polling for badge counts:** CONTEXT.md locked "pull-to-refresh only". Do not add periodic timers.
- **Separate screen for weekend view:** CONTEXT.md locked "filter toggle on existing jobs screen". Do not create a new route.
- **Clientless view as separate screen:** The clients view is a display mode toggle, not navigation.
- **Missing verifyToken on new backend endpoint:** The existing `/api/dashboard/summary` and `/api/dashboard/stats` routes currently lack `verifyToken`. The new `/chart-data` endpoint MUST include it. The planner should also note the existing routes need it added — this is a security gap discovered in research.
- **Missing tenant_id in existing dashboard queries:** `getDashboardSummary` and `getQuickStats` both query `jobs` without `WHERE tenant_id = ?`. This means they return cross-tenant data. New endpoint must not repeat this. Fixing the existing endpoints is a bonus task.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Bar chart rendering | Custom Canvas painting | fl_chart BarChart | Touch handling, axis labels, animation are all built-in; canvas approach requires hundreds of lines |
| Badge overlays | Custom positioned container | Flutter Material `Badge` widget | Available since Flutter 3.7; handles RTL, accessibility, overflow text |
| Date filtering for weekends | Manual weekday arithmetic | `DateTime.saturday`, `DateTime.sunday` constants | Less error-prone than magic integers 6/7 |
| Grouping jobs by client | Custom Map reduce | Simple `groupBy` using Dart collection syntax | No external package needed; 5 lines of code |

**Key insight:** fl_chart handles the majority of visual complexity. The chart data model is pure Dart — no serialization edge cases.

---

## Common Pitfalls

### Pitfall 1: Dashboard routes missing verifyToken
**What goes wrong:** `/api/dashboard/summary` and `/api/dashboard/stats` currently have no auth middleware (confirmed by reading `dashboard.js`). Any unauthenticated request returns data.
**Why it happens:** Original implementation did not wire up auth middleware on the dashboard routes.
**How to avoid:** The new `/chart-data` route MUST add `verifyToken`. Consider fixing the existing routes in the same plan.
**Warning signs:** API returns 200 with data on requests with no Authorization header.

### Pitfall 2: Missing tenant_id in dashboard queries
**What goes wrong:** `getDashboardSummary` and `getQuickStats` query `jobs` without `AND tenant_id = ?`. In a multi-tenant production database, this returns all tenants' data.
**Why it happens:** Dashboard controller was written before tenant scoping was introduced in Phase 1.
**How to avoid:** New `getChartData` must include `tenant_id = ?` (using `req.user.tenant_id`). The plan should patch the existing two methods as well.
**Warning signs:** Two tenants see each other's job counts on the dashboard.

### Pitfall 3: fl_chart BarChart height must be explicit
**What goes wrong:** A `BarChart` inside a `Column` or `ListView` without an explicit height throws a layout error: "Horizontal viewport was given unbounded height."
**Why it happens:** fl_chart's chart widgets require bounded height to measure themselves.
**How to avoid:** Always wrap in `SizedBox(height: N)` or a `Container` with explicit height. The mini chart in the dashboard card should be `height: 80` to `height: 100`.
**Warning signs:** Flutter layout exception at runtime on the dashboard screen.

### Pitfall 4: DateTime.weekday values in Dart
**What goes wrong:** Using `weekday == 0` or `weekday == 1` for Sunday/Monday (JavaScript convention) — in Dart, Monday=1, Sunday=7.
**Why it happens:** Developers familiar with JavaScript's `Date.getDay()` (0=Sunday) apply the wrong offset.
**How to avoid:** Use `DateTime.saturday` (==6) and `DateTime.sunday` (==7) named constants.
**Warning signs:** Weekend filter includes Monday or misses Sunday.

### Pitfall 5: Chart data fetched separately from main dashboard load
**What goes wrong:** A second API call for chart data fires after `_loadDashboard()` completes, causing a double loading state or a visible "chart pop-in" effect.
**Why it happens:** Fetching chart data in a separate `initState` future instead of inside `_loadDashboard()`.
**How to avoid:** Add `getChartData` to the `Future.wait([...])` block inside `_loadDashboard()` alongside the existing summary call.
**Warning signs:** Dashboard renders stat cards first, then chart appears 200ms later.

---

## Code Examples

### BarChart minimal working example

```dart
// Source: pub.dev/packages/fl_chart
import 'package:fl_chart/fl_chart.dart';

SizedBox(
  height: 90,
  child: BarChart(
    BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: 8,
      barGroups: [
        BarChartGroupData(
          x: 8,
          barRods: [BarChartRodData(toY: 3, color: Colors.indigo, width: 8)],
        ),
        BarChartGroupData(
          x: 9,
          barRods: [BarChartRodData(toY: 5, color: Colors.indigo, width: 8)],
        ),
        BarChartGroupData(
          x: 14,
          barRods: [BarChartRodData(toY: 2, color: Colors.indigo, width: 8)],
        ),
      ],
      titlesData: const FlTitlesData(show: false),
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
    ),
  ),
)
```

### Weekend filter in JobProvider

```dart
// Add to JobProvider
bool _weekendFilter = false;

bool get weekendFilter => _weekendFilter;

void setWeekendFilter(bool value) {
  _weekendFilter = value;
  notifyListeners();
}

List<Job> get _filteredJobs {
  return _jobs.where((job) {
    final matchesStatus =
        _statusFilter == null || job.currentStatus == _statusFilter;
    final matchesType = _typeFilter == null || job.jobType == _typeFilter;
    final matchesWeekend = !_weekendFilter ||
        job.scheduledDate.weekday == DateTime.saturday ||
        job.scheduledDate.weekday == DateTime.sunday;
    return matchesStatus && matchesType && matchesWeekend;
  }).toList();
}
```

### Clients grouping view (dashboard)

```dart
// Groups allJobs by customerName for the 'clients' toggle view
Map<String, List<Job>> _groupByClient(List<Job> jobs) {
  final map = <String, List<Job>>{};
  for (final job in jobs) {
    map.putIfAbsent(job.customerName, () => []).add(job);
  }
  return map;
}
```

### AppConfig endpoint addition

```dart
// lib/config/app_config.dart — add to existing endpoints
static String get dashboardChartEndpoint =>
    '$dashboardEndpoint/chart-data';
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| charts_flutter (Google) | fl_chart | ~2022 (charts_flutter deprecated) | fl_chart is the new standard; don't use charts_flutter |
| Material `Chip` for badges | Material `Badge` widget | Flutter 3.7 (stable Dec 2022) | `Badge` has proper accessibility support and overflow handling |
| Manual weekday numbers (6, 0) | `DateTime.saturday`, `DateTime.sunday` | Dart 2.x | Named constants prevent off-by-one errors |

---

## Open Questions

1. **Should the existing `/api/dashboard/summary` and `/api/dashboard/stats` routes get `verifyToken` + tenant scoping added in this phase?**
   - What we know: They currently have no auth middleware and no tenant_id filtering.
   - What's unclear: Whether the planner should include this fix in Phase 4 plans or defer to a security cleanup phase.
   - Recommendation: Include it in Plan 1 (backend) since we are touching the dashboard controller anyway. It is a 2-line change per method.

2. **Does the chart card appear in the technician dashboard or only admin/scheduler?**
   - What we know: The bar chart is described as "Jobs Today" scheduler preview — CONTEXT implies it is for schedulers.
   - What's unclear: Not explicitly stated for technicians.
   - Recommendation: Add only to `_buildManagerDashboard()`, skip technician view.

---

## Validation Architecture

Config key `workflow.nyquist_validation` is absent from `.planning/config.json` — treat as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None configured — no test runner detected in backend or Flutter |
| Config file | None — `npm test` is a placeholder per CLAUDE.md |
| Quick run command | `cd vehicle_scheduling_app && flutter analyze` (static analysis only) |
| Full suite command | N/A — no test suite exists yet (TEST-01 to TEST-05 are Phase 8) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DASH-01 | Jobs Today bar chart renders without layout errors | Widget smoke | `flutter analyze` (static) | ❌ Wave 0 |
| DASH-02 | Weekend filter shows only Sat/Sun jobs | Unit (filter logic) | N/A — no test runner | ❌ Wave 0 |
| DASH-03 | Clients toggle groups jobs by customerName | Unit (grouping logic) | N/A — no test runner | ❌ Wave 0 |
| DASH-04 | Badge counts match actual job status counts | Integration | N/A — no test runner | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `flutter analyze` in `vehicle_scheduling_app/` — static analysis, catches type errors and missing imports
- **Per wave merge:** Manual smoke test on emulator/device
- **Phase gate:** Manual verification per `/gsd:verify-work` criteria

### Wave 0 Gaps
No test framework to install (Phase 8 handles TEST-01 to TEST-05). For this phase, validation is manual + `flutter analyze`.

*(No automated test infrastructure gaps to close in this phase — testing is deferred to Phase 8.)*

---

## Sources

### Primary (HIGH confidence)
- `pub.dev/packages/fl_chart` — version 1.2.0 confirmed, BarChartData API verified
- `vehicle_scheduling_app/lib/screens/jobs/scheduler_screen.dart` — SegmentedButton pattern confirmed (lines 22–50 of that file)
- `vehicle_scheduling_app/lib/screens/dashboard/dashboard_screen.dart` — existing `_buildManagerDashboard` and `_StatCardData` patterns confirmed
- `vehicle-scheduling-backend/src/controllers/dashboardController.js` — existing endpoints, confirmed no tenant_id scoping
- `vehicle-scheduling-backend/src/routes/dashboard.js` — confirmed no verifyToken middleware
- `vehicle_scheduling_app/lib/providers/job_provider.dart` — `setStatusFilter` pattern confirmed, `_filteredJobs` getter confirmed

### Secondary (MEDIUM confidence)
- `pub.dev/documentation/fl_chart/latest/fl_chart/BarChartData-class.html` — BarChartData constructor parameters verified via WebFetch

### Tertiary (LOW confidence)
- None

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — fl_chart locked decision, version confirmed from pub.dev
- Architecture: HIGH — all patterns confirmed from existing source files
- Pitfalls: HIGH — verifyToken gap and tenant_id gap confirmed by direct code inspection

**Research date:** 2026-03-21
**Valid until:** 2026-04-20 (fl_chart is actively developed; check for breaking changes if >30 days)
