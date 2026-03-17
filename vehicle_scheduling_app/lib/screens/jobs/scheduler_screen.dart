// ============================================
// FILE: lib/screens/jobs/scheduler_screen.dart
// PURPOSE: Visual job scheduler — day + week views
// ROLES:
//   admin / scheduler → full access + can create jobs via FAB
//   technician        → read-only calendar view (no FAB, no create)
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/screens/jobs/create_job_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/job_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────
class _P {
  static const inst = Color(0xFF6366F1);
  static const deliv = Color(0xFF14B8A6);
  static const maint = Color(0xFFF59E0B);
  static const unass = Color(0xFF94A3B8);

  static const sPending = Color(0xFFDC2626);
  static const sAssigned = Color(0xFF2563EB);
  static const sInProgress = Color(0xFFEAB308);
  static const sCompleted = Color(0xFF16A34A);
  static const sCancelled = Color(0xFF64748B);

  static const navBar = Color.fromARGB(255, 40, 147, 255);
  static const page = Color(0xFFF1F5F9);
  static const card = Color(0xFFFFFFFF);
  static const header = Color(0xFFF8FAFC);
  static const divider = Color(0xFFE2E8F0);
  static const slotAlt = Color(0xFFFAFBFC);
  static const tMain = Color(0xFF1E293B);
  static const tSub = Color(0xFF64748B);
  static const tHint = Color(0xFF94A3B8);

  static Color jobFill(String t) {
    switch (t) {
      case 'installation':
        return inst;
      case 'delivery':
        return deliv;
      case 'miscellenous':
        return maint;
      default:
        return unass;
    }
  }

  static Color statusFill(String s) {
    switch (s) {
      case 'pending':
        return sPending;
      case 'assigned':
        return sAssigned;
      case 'in_progress':
        return sInProgress;
      case 'completed':
        return sCompleted;
      case 'cancelled':
        return sCancelled;
      default:
        return sPending;
    }
  }

  static Color statusText(String s) =>
      s == 'in_progress' ? const Color(0xFF713F12) : Colors.white;

  static String statusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});
  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  String _view = 'day';
  DateTime _date = DateTime.now();

  static const _startH = 8;
  static const _endH = 18;
  static const _slotH = 60.0;
  static const _timeW = 68.0;
  static const _labelW = 130.0;
  static const _mobileColW = 150.0;
  static const _weekColW = 160.0;

  final _dayV = ScrollController();
  final _dayH = ScrollController();
  final _dayHH = ScrollController();
  final _dayHB = ScrollController();
  final _weekV = ScrollController();
  final _weekH = ScrollController();
  final _weekHH = ScrollController();
  final _weekHB = ScrollController();

  bool _syncingDay = false;
  bool _syncingWeek = false;

  void _syncDay(ScrollController source) {
    if (_syncingDay) return;
    _syncingDay = true;
    final o = source.offset;
    for (final c in [_dayH, _dayHH, _dayHB]) {
      if (c != source && c.hasClients && c.offset != o)
        c.jumpTo(o.clamp(0.0, c.position.maxScrollExtent));
    }
    _syncingDay = false;
  }

  void _syncWeek(ScrollController source) {
    if (_syncingWeek) return;
    _syncingWeek = true;
    final o = source.offset;
    for (final c in [_weekH, _weekHH, _weekHB]) {
      if (c != source && c.hasClients && c.offset != o)
        c.jumpTo(o.clamp(0.0, c.position.maxScrollExtent));
    }
    _syncingWeek = false;
  }

  @override
  void initState() {
    super.initState();
    _dayH.addListener(() => _syncDay(_dayH));
    _dayHH.addListener(() => _syncDay(_dayHH));
    _dayHB.addListener(() => _syncDay(_dayHB));
    _weekH.addListener(() => _syncWeek(_weekH));
    _weekHH.addListener(() => _syncWeek(_weekHH));
    _weekHB.addListener(() => _syncWeek(_weekHB));
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _dayV.dispose();
    _dayH.dispose();
    _dayHH.dispose();
    _dayHB.dispose();
    _weekV.dispose();
    _weekH.dispose();
    _weekHH.dispose();
    _weekHB.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    await Future.wait([
      context.read<JobProvider>().loadJobs(),
      context.read<VehicleProvider>().loadVehicles(),
    ]);
  }

  void _today() => setState(() => _date = DateTime.now());
  void _next() =>
      setState(() => _date = _date.add(Duration(days: _view == 'day' ? 1 : 7)));
  void _prev() => setState(
    () => _date = _date.subtract(Duration(days: _view == 'day' ? 1 : 7)),
  );

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<Job> _onDay(List<Job> all, DateTime d) =>
      all.where((j) => _same(j.scheduledDate, d)).toList();
  List<Job> _onDayV(List<Job> all, DateTime d, int? v) =>
      _onDay(all, d).where((j) => j.vehicleId == v).toList();
  DateTime _weekStart(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  double _top(String t) {
    final p = t.split(':');
    final h = int.tryParse(p[0]) ?? _startH;
    final m = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
    return ((h * 60 + m) - _startH * 60) / 30 * _slotH;
  }

  double _cardH(String s, String e) {
    final sp = s.split(':');
    final ep = e.split(':');
    final sm =
        (int.tryParse(sp[0]) ?? 0) * 60 +
        (int.tryParse(sp.length > 1 ? sp[1] : '0') ?? 0);
    final em =
        (int.tryParse(ep[0]) ?? 0) * 60 +
        (int.tryParse(ep.length > 1 ? ep[1] : '0') ?? 0);
    return (em - sm) / 30 * _slotH;
  }

  String _fmtDate(DateTime d) {
    const mo = [
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
    return '${mo[d.month - 1]} ${d.day}, ${d.year}';
  }

  String _fmtHr(int h) {
    final p = h >= 12 ? 'PM' : 'AM';
    final v = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$v $p';
  }

  String _dayName(DateTime d) {
    const n = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return n[d.weekday - 1];
  }

  Future<void> _openDetail(Job job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
    );
    if (mounted) _load();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>().activeVehicles;
    final allJobs = context.watch<JobProvider>().allJobs;
    final vLoad = context.watch<VehicleProvider>().isLoading;
    final jLoad = context.watch<JobProvider>().isLoading;
    final auth = context.watch<AuthProvider>();

    // Only admin / scheduler can create jobs
    final canCreate = auth.hasPermission('jobs:create');

    final sw = MediaQuery.of(context).size.width;
    final isMobile = sw < 600;
    final ws = _weekStart(_date);
    final title = _view == 'day'
        ? _fmtDate(_date)
        : '${_fmtDate(ws)} – ${_fmtDate(ws.add(const Duration(days: 4)))}';

    return Scaffold(
      backgroundColor: _P.page,
      appBar: AppBar(
        backgroundColor: _P.navBar,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            fontSize: isMobile ? 14 : 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            color: _P.navBar,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _viewToggle(isMobile),
                  const SizedBox(width: 8),
                  _navBtn(Icons.chevron_left, _prev, 'Previous'),
                  _navBtn(Icons.today, _today, 'Today'),
                  _navBtn(Icons.chevron_right, _next, 'Next'),
                  _navBtn(Icons.refresh, _load, 'Refresh'),
                  // Role badge in nav bar for technician
                  if (auth.isTechnician) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'View Only',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),

      // FAB only for admin / scheduler
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'scheduler_screen_fab',
              backgroundColor: _P.inst,
              foregroundColor: Colors.white,
              elevation: 3,
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateJobScreen(initialDate: _date),
                  ),
                );
                if (mounted) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'New Job',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,

      body: Column(
        children: [
          _legend(isMobile),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 8 : 14),
              child: vLoad || jLoad
                  ? const Center(child: CircularProgressIndicator())
                  : vehicles.isEmpty
                  ? _emptyState()
                  : _view == 'day'
                  ? _dayView(allJobs, vehicles, isMobile)
                  : _weekView(allJobs, vehicles, isMobile),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DAY VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _dayView(List<Job> all, List<Vehicle> vehicles, bool mob) {
    final dayJobs = _onDay(all, _date);
    final hasUna = dayJobs.any((j) => j.vehicleId == null);
    final nCols = vehicles.length + (hasUna ? 1 : 0);
    final colW = _mobileColW;
    final gridW = _timeW + colW * nCols;

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      color: _P.card,
      child: Column(
        children: [
          SingleChildScrollView(
            controller: _dayHH,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(
              width: gridW,
              child: _dayHeader(vehicles, colW, mob, hasUna),
            ),
          ),
          const Divider(height: 1, color: _P.divider),
          Expanded(
            child: Scrollbar(
              controller: _dayV,
              thumbVisibility: true,
              trackVisibility: !mob,
              child: SingleChildScrollView(
                controller: _dayV,
                child: SingleChildScrollView(
                  controller: _dayH,
                  scrollDirection: Axis.horizontal,
                  physics: mob
                      ? const BouncingScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: gridW,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _timeColumn(),
                        ...vehicles.map(
                          (v) => SizedBox(
                            width: colW,
                            child: _slotStack(
                              dayJobs
                                  .where((j) => j.vehicleId == v.id)
                                  .toList(),
                              mob,
                            ),
                          ),
                        ),
                        if (hasUna)
                          _unassignedChipColumn(
                            dayJobs.where((j) => j.vehicleId == null).toList(),
                            mob,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _bottomScrollbar(_dayHB, gridW, mob),
        ],
      ),
    );
  }

  Widget _dayHeader(
    List<Vehicle> vehicles,
    double colW,
    bool mob,
    bool hasUna,
  ) {
    return Container(
      decoration: const BoxDecoration(color: _P.header),
      child: Row(
        children: [
          SizedBox(
            width: _timeW,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Text(
                'Time',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: mob ? 13 : 14,
                  color: const Color.fromARGB(255, 101, 139, 100),
                ),
              ),
            ),
          ),
          ...vehicles.map(
            (v) =>
                _vehicleCell(v.vehicleName, v.licensePlate, colW, mob, _P.inst),
          ),
          if (hasUna)
            _vehicleCell('Unassigned', 'No vehicle', colW, mob, _P.unass),
        ],
      ),
    );
  }

  Widget _vehicleCell(
    String name,
    String plate,
    double w,
    bool mob,
    Color accent,
  ) {
    return Container(
      width: w,
      padding: EdgeInsets.symmetric(vertical: mob ? 8 : 12, horizontal: 10),
      decoration: const BoxDecoration(
        color: _P.header,
        border: Border(left: BorderSide(color: _P.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.directions_car_rounded, size: 18, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: mob ? 13 : 14,
                    color: _P.tMain,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  plate,
                  style: TextStyle(fontSize: mob ? 11 : 12, color: _P.tHint),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotStack(List<Job> jobs, bool mob) {
    final slots = (_endH - _startH) * 2;
    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _P.divider)),
      ),
      child: Stack(
        children: [
          Column(
            children: List.generate(
              slots,
              (i) => Container(
                height: _slotH,
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : _P.slotAlt,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
              ),
            ),
          ),
          ...jobs.map((j) => _dayCard(j, mob)),
        ],
      ),
    );
  }

  Widget _unassignedChipColumn(List<Job> jobs, bool mob) {
    final slots = (_endH - _startH) * 2;
    return Container(
      width: _mobileColW,
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: _P.divider)),
      ),
      child: Stack(
        children: [
          Column(
            children: List.generate(
              slots,
              (i) => Container(
                height: _slotH,
                decoration: BoxDecoration(
                  color: i.isEven ? Colors.white : _P.slotAlt,
                  border: const Border(
                    bottom: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: jobs.map((j) => _unassignedDayChip(j, mob)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unassignedDayChip(Job job, bool mob) {
    final fill = _P.jobFill(job.jobType);
    final sFill = _P.statusFill(job.currentStatus);
    final sTxt = _P.statusText(job.currentStatus);
    final sLabel = _P.statusLabel(job.currentStatus);

    return GestureDetector(
      onTap: () => _openDetail(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(7, 5, 5, 6),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: fill.withOpacity(0.28),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.jobNumber,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: mob ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusBadge(sLabel, sFill, sTxt, mob),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              job.customerName,
              style: TextStyle(
                fontSize: mob ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 10,
                  color: Colors.white.withOpacity(0.70),
                ),
                const SizedBox(width: 2),
                Text(
                  job.formattedTimeRange,
                  style: TextStyle(
                    fontSize: mob ? 11 : 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(Job job, bool mob) {
    final top = _top(job.scheduledTimeStart);
    final h = _cardH(job.scheduledTimeStart, job.scheduledTimeEnd);
    if (h < 20 || top < 0) return const SizedBox.shrink();

    final fill = _P.jobFill(job.jobType);
    final sFill = _P.statusFill(job.currentStatus);
    final sTxt = _P.statusText(job.currentStatus);
    final sLabel = _P.statusLabel(job.currentStatus);

    return Positioned(
      top: top + 2,
      left: 4,
      right: 4,
      height: h.clamp(24.0, double.infinity) - 4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openDetail(job),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: fill.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: mob ? 6 : 8, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        job.jobNumber,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: mob ? 11 : 12,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (h > 28) ...[
                      const SizedBox(width: 4),
                      _statusBadge(sLabel, sFill, sTxt, mob),
                    ],
                  ],
                ),
                if (h > 36) ...[
                  const SizedBox(height: 2),
                  Text(
                    job.customerName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: mob ? 13 : 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (h > 54) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 10,
                        color: Colors.white.withOpacity(0.75),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        job.formattedTimeRange,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: mob ? 11 : 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // WEEK VIEW
  // ══════════════════════════════════════════════════════════════════════════
  Widget _weekView(List<Job> all, List<Vehicle> vehicles, bool mob) {
    final ws = _weekStart(_date);
    final days = List.generate(5, (i) => ws.add(Duration(days: i)));
    final gridW = _labelW + _weekColW * days.length;
    final hasUna = days.any((d) => _onDayV(all, d, null).isNotEmpty);

    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      color: _P.card,
      child: Column(
        children: [
          SingleChildScrollView(
            controller: _weekHH,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: SizedBox(width: gridW, child: _weekHeader(days, mob)),
          ),
          const Divider(height: 1, color: _P.divider),
          Expanded(
            child: Scrollbar(
              controller: _weekV,
              thumbVisibility: true,
              trackVisibility: !mob,
              child: SingleChildScrollView(
                controller: _weekV,
                child: SingleChildScrollView(
                  controller: _weekH,
                  scrollDirection: Axis.horizontal,
                  physics: mob
                      ? const BouncingScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: gridW,
                    child: Column(
                      children: [
                        ...vehicles.map(
                          (v) => _weekRow(
                            all,
                            v.vehicleName,
                            v.licensePlate,
                            v.id,
                            days,
                            mob,
                          ),
                        ),
                        if (hasUna)
                          _weekRow(all, 'Unassigned', '—', null, days, mob),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          _bottomScrollbar(_weekHB, gridW, mob),
        ],
      ),
    );
  }

  Widget _weekHeader(List<DateTime> days, bool mob) {
    return Container(
      decoration: const BoxDecoration(color: _P.header),
      child: Row(
        children: [
          Container(
            width: _labelW,
            height: 52,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: _P.header,
              border: Border(
                right: BorderSide(color: _P.divider),
                bottom: BorderSide(color: _P.divider),
              ),
            ),
            child: Text(
              'Vehicle',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: mob ? 13 : 15,
                color: _P.tSub,
              ),
            ),
          ),
          ...days.map((d) {
            final isToday = _same(d, DateTime.now());
            return Container(
              width: _weekColW,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isToday ? _P.inst.withOpacity(0.07) : _P.header,
                border: const Border(
                  left: BorderSide(color: _P.divider),
                  bottom: BorderSide(color: _P.divider),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _dayName(d),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: mob ? 14 : 16,
                      color: isToday ? _P.inst : _P.tSub,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: isToday ? _P.inst : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: TextStyle(
                        fontSize: mob ? 12 : 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                        color: isToday ? Colors.white : _P.tHint,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _weekRow(
    List<Job> all,
    String name,
    String plate,
    int? vid,
    List<DateTime> days,
    bool mob,
  ) {
    final isUna = vid == null;
    final accent = isUna ? _P.unass : _P.inst;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: _labelW,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              color: _P.header,
              border: Border(
                right: BorderSide(color: _P.divider),
                bottom: BorderSide(color: _P.divider),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(
                    isUna
                        ? Icons.help_outline_rounded
                        : Icons.directions_car_rounded,
                    size: 15,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: mob ? 12 : 13,
                          color: _P.tMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        plate,
                        style: TextStyle(
                          fontSize: mob ? 10 : 11,
                          color: _P.tHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...days.map((d) => _weekCell(_onDayV(all, d, vid), mob, d)),
        ],
      ),
    );
  }

  Widget _weekCell(List<Job> jobs, bool mob, DateTime day) {
    final isToday = _same(day, DateTime.now());
    return Container(
      width: _weekColW,
      constraints: const BoxConstraints(minHeight: 72),
      decoration: BoxDecoration(
        color: isToday ? _P.inst.withOpacity(0.02) : Colors.white,
        border: const Border(
          left: BorderSide(color: _P.divider),
          bottom: BorderSide(color: _P.divider),
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: jobs.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: jobs.map((j) => _weekChip(j, mob)).toList(),
            ),
    );
  }

  Widget _weekChip(Job job, bool mob) {
    final fill = _P.jobFill(job.jobType);
    final sFill = _P.statusFill(job.currentStatus);
    final sTxt = _P.statusText(job.currentStatus);
    final sLabel = _P.statusLabel(job.currentStatus);

    return GestureDetector(
      onTap: () => _openDetail(job),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.fromLTRB(7, 4, 5, 5),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
              color: fill.withOpacity(0.28),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    job.jobNumber,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: mob ? 10 : 11,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _statusBadge(sLabel, sFill, sTxt, mob),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              job.customerName,
              style: TextStyle(
                fontSize: mob ? 12 : 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 9,
                  color: Colors.white.withOpacity(0.70),
                ),
                const SizedBox(width: 2),
                Text(
                  job.formattedTimeRange,
                  style: TextStyle(
                    fontSize: mob ? 11 : 12,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _statusBadge(String label, Color bg, Color fg, bool mob) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: mob ? 10 : 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _timeColumn() {
    return Container(
      width: _timeW,
      decoration: const BoxDecoration(
        color: _P.header,
        border: Border(right: BorderSide(color: _P.divider)),
      ),
      child: Column(
        children: List.generate(
          _endH - _startH + 1,
          (i) => Container(
            height: _slotH * 2,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(top: 5, right: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 0.5),
              ),
            ),
            child: Text(
              _fmtHr(_startH + i),
              style: const TextStyle(
                fontSize: 13,
                color: _P.tHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomScrollbar(ScrollController ctrl, double contentW, bool mob) {
    return Container(
      height: mob ? 22 : 18,
      decoration: const BoxDecoration(
        color: _P.header,
        border: Border(top: BorderSide(color: _P.divider)),
      ),
      child: RawScrollbar(
        controller: ctrl,
        thumbVisibility: true,
        trackVisibility: true,
        thickness: mob ? 12 : 10,
        radius: const Radius.circular(5),
        thumbColor: _P.inst.withOpacity(0.50),
        trackColor: _P.divider,
        trackBorderColor: _P.divider,
        child: SingleChildScrollView(
          controller: ctrl,
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: contentW, height: 1),
        ),
      ),
    );
  }

  Widget _viewToggle(bool mob) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'day', label: Text('Day')),
        ButtonSegment(value: 'week', label: Text('Week')),
      ],
      selected: {_view},
      onSelectionChanged: (s) => setState(() => _view = s.first),
      style: ButtonStyle(
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected)
              ? Colors.white
              : Colors.white.withOpacity(0.15),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (st) => st.contains(WidgetState.selected) ? _P.navBar : Colors.white,
        ),
      ),
    );
  }

  Widget _navBtn(IconData icon, VoidCallback fn, String tip) {
    return IconButton(
      icon: Icon(icon, color: Colors.white, size: 20),
      onPressed: fn,
      tooltip: tip,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      splashRadius: 18,
    );
  }

  Widget _legend(bool mob) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: mob ? 6 : 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _lLabel('Type:', mob),
            _lDot('Installation', _P.inst, mob),
            _lDot('Delivery', _P.deliv, mob),
            _lDot('Miscellenous',  const Color.fromARGB(255, 100, 116, 139), mob),
            Container(
              width: 1,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: _P.divider,
            ),
            _lLabel('Status:', mob),
            _lDot('Pending', _P.sPending, mob),
            _lDot('Assigned', _P.sAssigned, mob),
            _lDot('In Progress', _P.sInProgress, mob),
            _lDot('Completed', _P.sCompleted, mob),
            _lDot('Cancelled', const Color.fromARGB(255, 100, 116, 139), mob),
          ],
        ),
      ),
    );
  }

  Widget _lLabel(String t, bool mob) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: Text(
      t,
      style: TextStyle(
        fontSize: mob ? 12 : 13,
        fontWeight: FontWeight.w700,
        color: _P.tSub,
      ),
    ),
  );

  Widget _lDot(String label, Color color, bool mob) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: mob ? 10 : 12,
            height: mob ? 10 : 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: mob ? 12 : 13, color: _P.tSub),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.local_shipping_outlined,
                size: 36,
                color: Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No active vehicles',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _P.tSub,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add vehicles in the Vehicles tab',
              style: TextStyle(fontSize: 15, color: _P.tHint),
            ),
          ],
        ),
      ),
    );
  }
}
