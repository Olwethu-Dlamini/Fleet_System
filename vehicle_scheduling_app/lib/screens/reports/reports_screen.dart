// ============================================
// FILE: lib/screens/reports/reports_screen.dart
// PURPOSE: Admin analytics & reporting — vibrant light UI
// DESIGN: Clean white base · vivid gradient accents · big bold numbers
// ============================================

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/services/report_service.dart';
import 'package:vehicle_scheduling_app/screens/vehicles/vehicle_utilization_screen.dart';
import 'package:vehicle_scheduling_app/services/csv_download.dart' as csv_dl;

// ════════════════════════════════════════════════════════════════
// DESIGN TOKENS
// ════════════════════════════════════════════════════════════════
class _D {
  static const bg = Color(0xFFF4F6FB);
  static const surface = Colors.white;
  static const divider = Color(0xFFE8EDF5);

  static const indigo = Color(0xFF4361EE);
  static const violet = Color(0xFF7B2FBE);
  static const teal = Color(0xFF0CC0A4);
  static const coral = Color(0xFFFF5A5F);
  static const amber = Color(0xFFFF9F1C);
  static const sky = Color(0xFF0EA5E9);

  static const gIndigo = [Color(0xFF4361EE), Color(0xFF7B61FF)];
  static const gTeal = [Color(0xFF0CC0A4), Color(0xFF00E5C4)];
  static const gCoral = [Color(0xFFFF5A5F), Color(0xFFFF8A65)];
  static const gAmber = [Color(0xFFFF9F1C), Color(0xFFFFD166)];
  static const gViolet = [Color(0xFF7B2FBE), Color(0xFFB44FEF)];
  static const gSky = [Color(0xFF0EA5E9), Color(0xFF38BDF8)];

  static const ink = Color(0xFF0F172A);
  static const inkMid = Color(0xFF475569);
  static const inkLight = Color(0xFF94A3B8);

  static const TextStyle heroNum = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: -2,
    height: 1.0,
  );
  static const TextStyle bigNum = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900,
    color: ink,
    letterSpacing: -1,
    height: 1.0,
  );
  static const TextStyle sectionHead = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: 1.6,
  );
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: ink,
  );
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: inkMid,
  );
  static const TextStyle tiny = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: inkLight,
    letterSpacing: 0.4,
  );
}

// ════════════════════════════════════════════════════════════════
// HELPERS
// ════════════════════════════════════════════════════════════════
String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _displayDate(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final p = iso.split('T').first.split('-');
    if (p.length < 3) return iso;
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${m[int.parse(p[1])]} ${p[2]}';
  } catch (_) {
    return iso;
  }
}

// ════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ════════════════════════════════════════════════════════════════
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _svc = ReportService();

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();

  bool _loading = false;
  String? _error;
  ExecutiveDashboardData? _data;

  List<CancelledJob>? _cancelJobs;
  List<CancellationReason>? _cancelReasons;
  int _cancelTotal = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final f = _fmtDate(_from), t = _fmtDate(_to);
      final results = await Future.wait([
        _svc.getExecutiveDashboard(dateFrom: f, dateTo: t),
        _svc.getCancellations(dateFrom: f, dateTo: t),
      ]);
      final dash = results[0] as ExecutiveDashboardData;
      final cancel =
          results[1]
              as ({
                int total,
                List<CancellationReason> byReason,
                List<CancelledJob> jobs,
              });
      if (mounted)
        setState(() {
          _data = dash;
          _cancelTotal = cancel.total;
          _cancelReasons = cancel.byReason;
          _cancelJobs = cancel.jobs;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _loading = false;
        });
    }
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTheme.primaryColor,
            onPrimary: Colors.white,
            surface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (r == null) return;
    setState(() {
      _from = r.start;
      _to = r.end;
    });
    await _load();
  }

  void _preset(int days) {
    setState(() {
      _to = DateTime.now();
      _from = _to.subtract(Duration(days: days - 1));
    });
    _load();
  }

  // ── CSV Export ─────────────────────────────────────────────────
  void _exportCurrentTabCsv() {
    if (_data == null) return;
    final tabIndex = _tabs.index;
    String csv;
    String filename;
    final range = '${_fmtDate(_from)}_to_${_fmtDate(_to)}';

    switch (tabIndex) {
      case 0: // Overview
        csv = _buildOverviewCsv(_data!);
        filename = 'overview_$range.csv';
        break;
      case 1: // Vehicles
        csv = _buildVehiclesCsv(_data!);
        filename = 'vehicles_$range.csv';
        break;
      case 2: // Technicians
        csv = _buildTechniciansCsv(_data!);
        filename = 'technicians_$range.csv';
        break;
      case 3: // Job Types
        csv = _buildJobTypesCsv(_data!);
        filename = 'job_types_$range.csv';
        break;
      case 4: // Cancellations
        csv = _buildCancellationsCsv();
        filename = 'cancellations_$range.csv';
        break;
      case 5: // Utilization — no report service data, skip
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Utilization tab uses live data. Switch to another tab to export.'),
            backgroundColor: AppTheme.warningColor,
          ),
        );
        return;
      default:
        return;
    }

    try {
      csv_dl.downloadCsvFile(csv, filename);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported $filename'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  String _buildOverviewCsv(ExecutiveDashboardData data) {
    final s = data.summary;
    final buf = StringBuffer();
    buf.writeln('Metric,Value');
    buf.writeln('Total Jobs,${s.total}');
    buf.writeln('Completed,${s.completed}');
    buf.writeln('In Progress,${s.inProgress}');
    buf.writeln('Assigned,${s.assigned}');
    buf.writeln('Pending,${s.pending}');
    buf.writeln('Cancelled,${s.cancelled}');
    buf.writeln('Completion Rate,${s.completionRate.toStringAsFixed(1)}%');
    buf.writeln('Cancellation Rate,${s.cancellationRate.toStringAsFixed(1)}%');
    buf.writeln('Active Vehicles,${s.activeVehicles}');
    buf.writeln('Active Technicians,${s.activeTechnicians}');
    buf.writeln('Avg Jobs/Day,${s.avgJobsPerDay.toStringAsFixed(1)}');
    if (data.dailyVolume.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Date,Total,Completed,Cancelled');
      for (final d in data.dailyVolume) {
        buf.writeln('${d.date},${d.total},${d.completed},${d.cancelled}');
      }
    }
    return buf.toString();
  }

  String _buildVehiclesCsv(ExecutiveDashboardData data) {
    final buf = StringBuffer();
    buf.writeln('Vehicle Name,License Plate,Type,Total Jobs,Completed,Cancelled,In Progress,Days Used,Utilisation %');
    for (final v in data.vehicles) {
      buf.writeln('"${v.vehicleName}","${v.licensePlate}","${v.vehicleType}",${v.totalJobs},${v.completed},${v.cancelled},${v.inProgress},${v.daysUsed},${v.utilisationPct.toStringAsFixed(1)}');
    }
    return buf.toString();
  }

  String _buildTechniciansCsv(ExecutiveDashboardData data) {
    final buf = StringBuffer();
    buf.writeln('Full Name,Total Jobs,Completed,Cancelled,Completion Rate %,Cancellation Rate %');
    for (final t in data.technicians) {
      buf.writeln('"${t.fullName}",${t.totalJobs},${t.completed},${t.cancelled},${t.completionRate.toStringAsFixed(1)},${t.cancellationRate.toStringAsFixed(1)}');
    }
    return buf.toString();
  }

  String _buildJobTypesCsv(ExecutiveDashboardData data) {
    final buf = StringBuffer();
    buf.writeln('Job Type,Total,Completed,Cancelled,In Progress,Pending,Completion Rate %');
    for (final t in data.byType) {
      buf.writeln('"${t.jobType}",${t.total},${t.completed},${t.cancelled},${t.inProgress},${t.pending},${t.completionRate.toStringAsFixed(1)}');
    }
    return buf.toString();
  }

  String _buildCancellationsCsv() {
    final buf = StringBuffer();
    if (_cancelReasons != null && _cancelReasons!.isNotEmpty) {
      buf.writeln('Cancellation Reason,Count');
      for (final r in _cancelReasons!) {
        buf.writeln('"${r.reason}",${r.count}');
      }
      buf.writeln('');
    }
    buf.writeln('Customer Name,Job Type,Priority,Scheduled Date,Cancel Reason,Vehicle,Technicians');
    if (_cancelJobs != null) {
      for (final j in _cancelJobs!) {
        buf.writeln('"${j.customerName}","${j.jobType}","${j.priority}","${j.scheduledDate}","${j.cancelReason ?? ''}","${j.vehicleName ?? ''}","${j.technicianNames ?? ''}"');
      }
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _D.bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const _LoadingView()
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _data == null
          ? const SizedBox()
          : TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(data: _data!),
                _VehiclesTab(data: _data!),
                _TechniciansTab(data: _data!),
                _JobTypesTab(data: _data!),
                _CancellationsTab(
                  total: _cancelTotal,
                  reasons: _cancelReasons ?? [],
                  jobs: _cancelJobs ?? [],
                ),
                const VehicleUtilizationBody(),
              ],
            ),
      floatingActionButton: (_data != null && !_loading)
          ? FloatingActionButton.extended(
              onPressed: _exportCurrentTabCsv,
              icon: const Icon(Icons.download),
              label: const Text('Export CSV'),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  // ── AppBar matching jobs_list_screen.dart style ──────────────
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('Analytics'),
      automaticallyImplyLeading: true,
      actions: [
        // Date-range preset chips
        _PresetChip('7D', () => _preset(7)),
        const SizedBox(width: 4),
        _PresetChip('30D', () => _preset(30)),
        const SizedBox(width: 4),
        _PresetChip('90D', () => _preset(90)),
        const SizedBox(width: 4),

        // Calendar picker
        IconButton(
          icon: const Icon(Icons.date_range_rounded),
          tooltip: 'Pick date range',
          onPressed: _pickRange,
        ),

        // Refresh / loading indicator
        _loading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            : IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _load,
              ),
      ],
      // Date range subtitle + tab bar in the bottom slot
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active date range banner — mirrors the filter banner in jobs list
            GestureDetector(
              onTap: _pickRange,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 7,
                ),
                color: AppTheme.primaryColor.withOpacity(0.08),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 13,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_displayDate(_fmtDate(_from))}  →  ${_displayDate(_fmtDate(_to))}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: AppTheme.primaryColor,
                    ),
                  ],
                ),
              ),
            ),

            // Tab bar — white text on primary background
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              tabs: const [
                Tab(text: 'OVERVIEW'),
                Tab(text: 'VEHICLES'),
                Tab(text: 'TECHNICIANS'),
                Tab(text: 'JOB TYPES'),
                Tab(text: 'CANCELLATIONS'),
                Tab(text: 'UTILIZATION'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 0 — OVERVIEW
// ════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final ExecutiveDashboardData data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final s = data.summary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: _GradientHeroCard(
                value: '${s.total}',
                label: 'Total Jobs',
                sublabel: '${s.avgJobsPerDay} avg / day',
                gradientColors: _D.gIndigo,
                icon: Icons.work_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _GradientHeroCard(
                value: '${s.completionRate.toStringAsFixed(0)}%',
                label: 'Completion',
                sublabel: '${s.completed} completed',
                gradientColors: _D.gTeal,
                icon: Icons.verified_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _GradientHeroCard(
                value: '${s.cancellationRate.toStringAsFixed(0)}%',
                label: 'Cancel Rate',
                sublabel: '${s.cancelled} cancelled',
                gradientColors: _D.gCoral,
                icon: Icons.cancel_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _GradientHeroCard(
                value: '${s.inProgress}',
                label: 'In Progress',
                sublabel: '${s.pending} pending',
                gradientColors: _D.gAmber,
                icon: Icons.bolt_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        _SectionLabel('STATUS BREAKDOWN'),
        const SizedBox(height: 12),
        _StatusDonutCard(summary: s),
        const SizedBox(height: 28),

        _SectionLabel('RESOURCES'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ResourceTile(
                value: '${s.activeVehicles}',
                label: 'Vehicles',
                icon: Icons.local_shipping_rounded,
                colors: _D.gSky,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResourceTile(
                value: '${s.activeTechnicians}',
                label: 'Technicians',
                icon: Icons.engineering_rounded,
                colors: _D.gViolet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ResourceTile(
                value: '${s.assigned}',
                label: 'Assigned',
                icon: Icons.assignment_turned_in_rounded,
                colors: _D.gTeal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        if (data.dailyVolume.isNotEmpty) ...[
          _SectionLabel('DAILY JOB VOLUME'),
          const SizedBox(height: 12),
          _DailyBarChart(days: data.dailyVolume),
          const SizedBox(height: 28),
        ],

        _SectionLabel('ALL STATUS COUNTS'),
        const SizedBox(height: 12),
        _StatusCountStrip(summary: s),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 1 — VEHICLES
// ════════════════════════════════════════════════════════════════
class _VehiclesTab extends StatelessWidget {
  final ExecutiveDashboardData data;
  const _VehiclesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final vehicles = data.vehicles;
    if (vehicles.isEmpty)
      return const _EmptyState(message: 'No vehicle data for this period.');
    final sorted = [...vehicles]
      ..sort((a, b) => b.totalJobs.compareTo(a.totalJobs));
    final maxJobs = sorted.first.totalJobs.clamp(1, 999999);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _SectionLabel('VEHICLE PERFORMANCE  ·  ${vehicles.length} ACTIVE'),
        const SizedBox(height: 14),
        _VehicleBarChart(vehicles: sorted, maxJobs: maxJobs),
        const SizedBox(height: 28),
        _SectionLabel('DETAIL CARDS'),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map(
          (e) => _VehicleCard(vehicle: e.value, rank: e.key + 1),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2 — TECHNICIANS
// ════════════════════════════════════════════════════════════════
class _TechniciansTab extends StatelessWidget {
  final ExecutiveDashboardData data;
  const _TechniciansTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final techs = data.technicians;
    if (techs.isEmpty)
      return const _EmptyState(message: 'No technician data for this period.');
    final sorted = [...techs]
      ..sort((a, b) {
        // 1. Higher completion rate wins
        final rateCompare = b.completionRate.compareTo(a.completionRate);
        if (rateCompare != 0) return rateCompare;
        // 2. More completed jobs wins (more work done at same rate)
        final completedCompare = b.completed.compareTo(a.completed);
        if (completedCompare != 0) return completedCompare;
        // 3. Lower cancellation rate wins
        final cancelCompare = a.cancellationRate.compareTo(b.cancellationRate);
        if (cancelCompare != 0) return cancelCompare;
        // 4. More total jobs wins (most active)
        return b.totalJobs.compareTo(a.totalJobs);
      });

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _SectionLabel('LEADERBOARD  ·  ${techs.length} ACTIVE'),
        const SizedBox(height: 14),
        _TechLeaderboard(techs: sorted),
        const SizedBox(height: 28),
        _SectionLabel('PERFORMANCE CARDS'),
        const SizedBox(height: 12),
        ...sorted.asMap().entries.map(
          (e) => _TechCard(tech: e.value, rank: e.key + 1),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 3 — JOB TYPES
// ════════════════════════════════════════════════════════════════
class _JobTypesTab extends StatelessWidget {
  final ExecutiveDashboardData data;
  const _JobTypesTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final types = data.byType;
    if (types.isEmpty)
      return const _EmptyState(message: 'No job type data for this period.');
    final total = types.fold<int>(0, (s, t) => s + t.total);
    const colors = [_D.indigo, _D.violet, _D.amber, _D.teal, _D.sky];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        _SectionLabel('TYPE DISTRIBUTION  ·  $total TOTAL'),
        const SizedBox(height: 14),
        _TypeDonutCard(types: types, colors: colors),
        const SizedBox(height: 28),
        _SectionLabel('TYPE BREAKDOWN'),
        const SizedBox(height: 12),
        ...types.asMap().entries.map(
          (e) => _TypeCard(
            type: e.value,
            grandTotal: total,
            color: colors[e.key % colors.length],
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 4 — CANCELLATIONS
// ════════════════════════════════════════════════════════════════
class _CancellationsTab extends StatelessWidget {
  final int total;
  final List<CancellationReason> reasons;
  final List<CancelledJob> jobs;

  const _CancellationsTab({
    required this.total,
    required this.reasons,
    required this.jobs,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: _D.gCoral,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _D.coral.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$total',
                    style: _D.heroNum.copyWith(fontSize: 56, height: 1),
                  ),
                  const Text(
                    'CANCELLED JOBS',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white70,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        if (reasons.isNotEmpty) ...[
          _SectionLabel('CANCELLATION REASONS'),
          const SizedBox(height: 12),
          _ReasonBarChart(reasons: reasons, total: total),
          const SizedBox(height: 28),
        ],

        _SectionLabel('CANCELLED JOBS LIST'),
        const SizedBox(height: 12),
        if (jobs.isEmpty)
          const _EmptyState(message: 'No cancelled jobs in this period.')
        else
          ...jobs.map((j) => _CancelledJobCard(job: j)),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CHARTS — CustomPainter
// ════════════════════════════════════════════════════════════════

class _StatusDonutCard extends StatelessWidget {
  final ReportSummary summary;
  const _StatusDonutCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final segments = [
      (label: 'Completed', value: summary.completed, color: _D.teal),
      (label: 'In Progress', value: summary.inProgress, color: _D.amber),
      (label: 'Assigned', value: summary.assigned, color: _D.sky),
      (label: 'Pending', value: summary.pending, color: _D.inkLight),
      (label: 'Cancelled', value: summary.cancelled, color: _D.coral),
    ].where((s) => s.value > 0).toList();
    final total = summary.total;

    return _WhiteCard(
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: _DonutPainter(
                segments: segments
                    .map(
                      (s) =>
                          _DonutSeg(value: s.value.toDouble(), color: s.color),
                    )
                    .toList(),
                total: total.toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: _D.bigNum.copyWith(fontSize: 30)),
                    const Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _D.inkLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: segments.map((s) {
                final pct = total > 0
                    ? (s.value / total * 100).toStringAsFixed(1)
                    : '0.0';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.label,
                          style: _D.caption.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: s.color,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '(${s.value})',
                        style: _D.tiny.copyWith(color: _D.inkMid),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutSeg {
  final double value;
  final Color color;
  const _DonutSeg({required this.value, required this.color});
}

class _DonutPainter extends CustomPainter {
  final List<_DonutSeg> segments;
  final double total;
  const _DonutPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = math.min(cx, cy) - 8;
    double startAngle = -math.pi / 2;

    for (final seg in segments) {
      final sweep = total > 0 ? (seg.value / total) * 2 * math.pi : 0.0;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx + 1, cy + 2), radius: r),
        startAngle,
        sweep - 0.04,
        false,
        Paint()
          ..color = seg.color.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 28,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startAngle,
        sweep - 0.04,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.butt,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => false;
}

class _DailyBarChart extends StatelessWidget {
  final List<DailyVolume> days;
  const _DailyBarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final visible = days.length > 14 ? days.sublist(days.length - 14) : days;
    final maxVal = visible.fold<int>(1, (m, d) => d.total > m ? d.total : m);

    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _LegendDot(color: _D.teal, label: 'Completed'),
              const SizedBox(width: 16),
              _LegendDot(color: _D.amber, label: 'Active'),
              const SizedBox(width: 16),
              _LegendDot(color: _D.coral, label: 'Cancelled'),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 170,
            child: CustomPaint(
              size: const Size(double.infinity, 170),
              painter: _BarChartPainter(days: visible, maxVal: maxVal),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: visible.map((d) {
              final lbl = d.date.length >= 10 ? d.date.substring(5) : d.date;
              return Expanded(
                child: Text(
                  lbl,
                  style: _D.tiny,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<DailyVolume> days;
  final int maxVal;
  const _BarChartPainter({required this.days, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;
    final barW = size.width / days.length;
    final gap = barW * 0.22;
    final barNet = barW - gap;
    final maxH = size.height - 6;

    for (int i = 1; i <= 4; i++) {
      final y = size.height - maxH * i / 4;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFE8EDF5)
          ..strokeWidth = 1,
      );
    }

    for (int i = 0; i < days.length; i++) {
      final d = days[i];
      final x = i * barW + gap / 2;
      final totH = maxVal > 0 ? (d.total / maxVal) * maxH : 0.0;
      final cmpH = maxVal > 0 ? (d.completed / maxVal) * maxH : 0.0;
      final canH = maxVal > 0 ? (d.cancelled / maxVal) * maxH : 0.0;
      final actH = maxVal > 0
          ? ((d.total - d.completed - d.cancelled).clamp(0, d.total) / maxVal) *
                maxH
          : 0.0;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - totH, barNet, totH),
          const Radius.circular(5),
        ),
        Paint()..color = _D.indigo.withOpacity(0.06),
      );

      if (cmpH > 0)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - cmpH, barNet, cmpH),
            const Radius.circular(5),
          ),
          Paint()..color = _D.teal,
        );

      if (actH > 0 && totH > cmpH)
        canvas.drawRect(
          Rect.fromLTWH(x, size.height - cmpH - actH, barNet, actH),
          Paint()..color = _D.amber,
        );

      if (canH > 0 && totH > cmpH + actH)
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, size.height - totH, barNet, canH),
            const Radius.circular(5),
          ),
          Paint()..color = _D.coral,
        );
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) => false;
}

class _TypeDonutCard extends StatelessWidget {
  final List<JobTypeReport> types;
  final List<Color> colors;
  const _TypeDonutCard({required this.types, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = types.fold<int>(0, (s, t) => s + t.total);
    return _WhiteCard(
      child: Row(
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: CustomPaint(
              painter: _DonutPainter(
                segments: types
                    .asMap()
                    .entries
                    .map(
                      (e) => _DonutSeg(
                        value: e.value.total.toDouble(),
                        color: colors[e.key % colors.length],
                      ),
                    )
                    .toList(),
                total: total.toDouble(),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$total', style: _D.bigNum.copyWith(fontSize: 28)),
                    const Text(
                      'JOBS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _D.inkLight,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: types.asMap().entries.map((e) {
                final t = e.value;
                final c = colors[e.key % colors.length];
                final pct = total > 0
                    ? (t.total / total * 100).toStringAsFixed(0)
                    : '0';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 34,
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.jobType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: c,
                                letterSpacing: 0.8,
                              ),
                            ),
                            Text(
                              '${t.total} jobs',
                              style: _D.tiny.copyWith(color: _D.inkMid),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: c,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleBarChart extends StatelessWidget {
  final List<VehicleReport> vehicles;
  final int maxJobs;
  const _VehicleBarChart({required this.vehicles, required this.maxJobs});

  @override
  Widget build(BuildContext context) {
    final show = vehicles.take(8).toList();
    const colors = [_D.indigo, _D.violet, _D.amber, _D.teal, _D.sky, _D.coral];

    return _WhiteCard(
      child: Column(
        children: show.asMap().entries.map((e) {
          final v = e.value;
          final pct = maxJobs > 0 ? v.totalJobs / maxJobs : 0.0;
          final c = colors[e.key % colors.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: c,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        v.vehicleName,
                        style: _D.body.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${v.totalJobs}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: c,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('jobs', style: _D.tiny.copyWith(color: _D.inkMid)),
                  ],
                ),
                const SizedBox(height: 7),
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [c, c.withOpacity(0.6)],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: c.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TechLeaderboard extends StatelessWidget {
  final List<TechnicianReport> techs;
  const _TechLeaderboard({required this.techs});

  @override
  Widget build(BuildContext context) {
    final top3 = techs.take(3).toList();
    if (top3.isEmpty) return const SizedBox();
    return _WhiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top3.length > 1)
            Expanded(child: _PodiumItem(tech: top3[1], rank: 2, height: 90)),
          const SizedBox(width: 8),
          Expanded(child: _PodiumItem(tech: top3[0], rank: 1, height: 120)),
          const SizedBox(width: 8),
          if (top3.length > 2)
            Expanded(child: _PodiumItem(tech: top3[2], rank: 3, height: 70)),
        ],
      ),
    );
  }
}

class _PodiumItem extends StatelessWidget {
  final TechnicianReport tech;
  final int rank;
  final double height;
  const _PodiumItem({
    required this.tech,
    required this.rank,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    const podiumColors = [
      Color(0xFFFFAB00),
      Color(0xFF90A4AE),
      Color(0xFFFF7043),
    ];
    const medals = ['🥇', '🥈', '🥉'];
    final gradients = [
      _D.gAmber,
      [const Color(0xFF90A4AE), const Color(0xFFB0BEC5)],
      _D.gCoral,
    ];
    final c = podiumColors[rank - 1];

    return Column(
      children: [
        Text(medals[rank - 1], style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 5),
        Text(
          tech.fullName.split(' ').first,
          style: _D.body.copyWith(fontSize: 13),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${tech.completionRate.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradients[rank - 1],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: c.withOpacity(0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tech.totalJobs}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'jobs',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonBarChart extends StatelessWidget {
  final List<CancellationReason> reasons;
  final int total;
  const _ReasonBarChart({required this.reasons, required this.total});

  @override
  Widget build(BuildContext context) {
    final max = reasons.fold<int>(1, (m, r) => r.count > m ? r.count : m);
    return _WhiteCard(
      child: Column(
        children: reasons.take(6).map((r) {
          final pct = max > 0 ? r.count / max : 0.0;
          final tPct = total > 0
              ? (r.count / total * 100).toStringAsFixed(0)
              : '0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.reason,
                        style: _D.body.copyWith(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$tPct%',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _D.coral,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${r.count})',
                      style: _D.tiny.copyWith(color: _D.inkMid),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: _D.coral.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: _D.gCoral),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: _D.coral.withOpacity(0.35),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CARD COMPONENTS
// ════════════════════════════════════════════════════════════════

class _GradientHeroCard extends StatelessWidget {
  final String value;
  final String label;
  final String sublabel;
  final List<Color> gradientColors;
  final IconData icon;

  const _GradientHeroCard({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.gradientColors,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradientColors.first.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(value, style: _D.heroNum.copyWith(fontSize: 44, height: 1)),
          const SizedBox(height: 6),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final List<Color> colors;
  const _ResourceTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colors.first.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: colors.first.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: colors.first.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: _D.bigNum.copyWith(fontSize: 28, color: colors.first),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: _D.tiny.copyWith(color: _D.inkMid, letterSpacing: 0.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatusCountStrip extends StatelessWidget {
  final ReportSummary summary;
  const _StatusCountStrip({required this.summary});

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'Done', val: summary.completed, color: _D.teal),
      (label: 'Active', val: summary.inProgress, color: _D.amber),
      (label: 'Assigned', val: summary.assigned, color: _D.sky),
      (label: 'Pending', val: summary.pending, color: _D.inkLight),
      (label: 'Cancelled', val: summary.cancelled, color: _D.coral),
    ];
    return _WhiteCard(
      child: Row(
        children: items
            .map(
              (it) => Expanded(
                child: Column(
                  children: [
                    Text(
                      '${it.val}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: it.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      it.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _D.inkLight,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final VehicleReport vehicle;
  final int rank;
  const _VehicleCard({required this.vehicle, required this.rank});

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    const colors = [_D.indigo, _D.violet, _D.amber, _D.teal, _D.sky, _D.coral];
    final c = colors[(rank - 1) % colors.length];
    final utilColor = v.utilisationPct >= 70
        ? _D.teal
        : v.utilisationPct >= 40
        ? _D.amber
        : _D.coral;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: c.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: c.withOpacity(0.12)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: _D.inkMid,
          collapsedIconColor: _D.inkLight,
          title: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, c.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: c.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_shipping_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.vehicleName, style: _D.body),
                    Text(v.licensePlate, style: _D.caption),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${v.totalJobs}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: c,
                    ),
                  ),
                  Text(
                    'JOBS',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: c.withOpacity(0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
          children: [
            Divider(color: _D.divider, height: 1),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'UTILISATION',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _D.inkLight,
                    letterSpacing: 1.2,
                  ),
                ),
                Text(
                  '${v.utilisationPct.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: utilColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: _D.divider,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: (v.utilisationPct / 100).clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [utilColor, utilColor.withOpacity(0.65)],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      boxShadow: [
                        BoxShadow(
                          color: utilColor.withOpacity(0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _MiniStat('${v.completed}', 'Done', _D.teal),
                _MiniStat('${v.cancelled}', 'Cancelled', _D.coral),
                _MiniStat('${v.inProgress}', 'Active', _D.amber),
                _MiniStat('${v.daysUsed}', 'Days Used', _D.sky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TechCard extends StatelessWidget {
  final TechnicianReport tech;
  final int rank;
  const _TechCard({required this.tech, required this.rank});

  @override
  Widget build(BuildContext context) {
    final t = tech;
    final rateColor = t.completionRate >= 70
        ? _D.teal
        : t.completionRate >= 40
        ? _D.amber
        : _D.coral;
    const rankColors = [
      Color(0xFFFFAB00),
      Color(0xFF90A4AE),
      Color(0xFFFF7043),
    ];
    final rankColor = rank <= 3 ? rankColors[rank - 1] : _D.inkLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: _D.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: rankColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: rankColor.withOpacity(0.35)),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: rankColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.fullName, style: _D.body),
                Text(
                  '${t.totalJobs} jobs  ·  ${t.completed} completed',
                  style: _D.caption,
                ),
                const SizedBox(height: 10),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: _D.divider,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: (t.completionRate / 100).clamp(0, 1),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [rateColor, rateColor.withOpacity(0.65)],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: rateColor.withOpacity(0.4),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${t.completionRate.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: rateColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final JobTypeReport type;
  final int grandTotal;
  final Color color;
  const _TypeCard({
    required this.type,
    required this.grandTotal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = type;
    final pct = grandTotal > 0
        ? (t.total / grandTotal * 100).toStringAsFixed(0)
        : '0';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.75)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  t.jobType.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${t.total}\ntotal',
                style: _D.tiny.copyWith(color: _D.inkMid),
                textAlign: TextAlign.right,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat('${t.completed}', 'Done', _D.teal),
              _MiniStat('${t.cancelled}', 'Cancelled', _D.coral),
              _MiniStat('${t.inProgress}', 'Active', _D.amber),
              _MiniStat('${t.pending}', 'Pending', _D.inkLight),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMPLETION RATE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _D.inkLight,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${t.completionRate.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _D.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: _D.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (t.completionRate / 100).clamp(0, 1),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: _D.gTeal),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [
                      BoxShadow(color: _D.teal.withOpacity(0.4), blurRadius: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelledJobCard extends StatelessWidget {
  final CancelledJob job;
  const _CancelledJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    final j = job;
    final priorityColor = j.priority == 'urgent'
        ? _D.coral
        : j.priority == 'high'
        ? _D.amber
        : _D.inkLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: _D.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(j.customerName, style: _D.body)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: priorityColor.withOpacity(0.3)),
                ),
                child: Text(
                  j.priority.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: priorityColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${j.jobType}  ·  ${_displayDate(j.scheduledDate.toString())}',
            style: _D.caption,
          ),
          if (j.cancelReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: _D.coral.withOpacity(0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _D.coral.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: _D.coral,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      j.cancelReason!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: _D.coral,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (j.vehicleName != null || j.technicianNames != null) ...[
            const SizedBox(height: 10),
            Divider(color: _D.divider, height: 1),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              children: [
                if (j.vehicleName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 13,
                        color: _D.inkLight,
                      ),
                      const SizedBox(width: 5),
                      Text(j.vehicleName!, style: _D.caption),
                    ],
                  ),
                if (j.technicianNames != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 13,
                        color: _D.inkLight,
                      ),
                      const SizedBox(width: 5),
                      Text(j.technicianNames!, style: _D.caption),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════

class _WhiteCard extends StatelessWidget {
  final Widget child;
  const _WhiteCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: _D.gIndigo,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: _D.sectionHead),
      ],
    );
  }
}

// Compact chip used inside the AppBar actions row
class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryColor,
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _D.inkLight,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: _D.tiny.copyWith(color: _D.inkMid, letterSpacing: 0.3),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: _D.gIndigo),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _D.indigo.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Loading analytics…',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _D.inkMid,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: _D.gCoral),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: _D.coral.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _D.inkMid, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Retry',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _D.divider,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.inbox_rounded,
                size: 32,
                color: _D.inkLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 15, color: _D.inkMid),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
