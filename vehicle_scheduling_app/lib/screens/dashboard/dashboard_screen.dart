// ============================================
// FILE: lib/screens/dashboard/dashboard_screen.dart
// PURPOSE: Role-aware dashboard
//
// FIXES:
//   • _loadDashboard() calls loadMyJobs() for technicians instead of
//     loadJobs() so only their assigned jobs are fetched from the server.
//   • _buildTechnicianDashboard() filters using hasTechnician(userId)
//     OR driverId == userId — covers both assignment paths.
// ============================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';
import 'package:vehicle_scheduling_app/screens/jobs/job_detail_screen.dart';
import 'package:vehicle_scheduling_app/screens/users/users_screen.dart';

// ── Pattern types for stat card decorative art ─────────────────
enum _PatternType { circles, dots, waves, diagonal }

class _StatCardData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final _PatternType patternType;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.patternType,
  });
}

class _StatCardPainter extends CustomPainter {
  final Color color;
  final _PatternType patternType;

  _StatCardPainter({required this.color, required this.patternType});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final fill = Paint()
      ..color = color.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    switch (patternType) {
      case _PatternType.circles:
        for (int i = 1; i <= 5; i++) {
          final r = size.shortestSide * 0.28 * i;
          canvas.drawCircle(
            Offset(size.width, size.height),
            r,
            i == 1 ? fill : stroke,
          );
        }
        break;
      case _PatternType.dots:
        final dotPaint = Paint()
          ..color = color.withOpacity(0.13)
          ..style = PaintingStyle.fill;
        const spacing = 16.0;
        for (double x = spacing; x < size.width; x += spacing) {
          for (double y = spacing; y < size.height; y += spacing) {
            canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
          }
        }
        break;
      case _PatternType.waves:
        final wavePaint = Paint()
          ..color = color.withOpacity(0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        for (int w = 0; w < 5; w++) {
          final path = Path();
          final yBase = size.height * 0.15 + w * (size.height * 0.18);
          path.moveTo(0, yBase);
          for (double x = 0; x <= size.width; x += 2) {
            final y = yBase + math.sin((x / size.width) * math.pi * 2.5) * 9;
            path.lineTo(x, y);
          }
          canvas.drawPath(path, wavePaint);
        }
        break;
      case _PatternType.diagonal:
        const step = 16.0;
        final total = (size.width + size.height) ~/ step + 4;
        for (int i = -4; i < total; i++) {
          final offset = i * step;
          canvas.drawLine(
            Offset(offset, 0),
            Offset(offset + size.height, size.height),
            stroke,
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_StatCardPainter old) =>
      old.color != color || old.patternType != patternType;
}

// ================================================================
// DASHBOARD SCREEN
// ================================================================
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _apiService = ApiService();
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _summary = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) _loadDashboard();
    });
  }

  void _injectTokens() {
    final auth = context.read<AuthProvider>();
    auth.injectToken(_apiService);
    auth.injectToken(context.read<JobProvider>().jobService.apiService);
    auth.injectToken(context.read<VehicleProvider>().vehicleService.apiService);
  }

  // ============================================================
  // FIX: Technicians call loadMyJobs() so the server filters by
  //      their user ID via job_technicians. Admin/Scheduler call
  //      loadJobs() to get everything.
  // ============================================================
  Future<void> _loadDashboard() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _injectTokens();

    final auth = context.read<AuthProvider>();

    if (auth.isTechnician) {
      // Technicians only load their own assigned jobs from /api/jobs/my-jobs
      await context.read<JobProvider>().loadMyJobs();
    } else {
      // Admin / Scheduler load all jobs and vehicles
      await Future.wait([
        context.read<JobProvider>().loadJobs(),
        context.read<VehicleProvider>().loadVehicles(),
      ]);

      if (!mounted) return;

      try {
        final res = await _apiService.get(
          '${AppConfig.dashboardEndpoint}/summary',
        );
        if (res.containsKey('summary') && res['summary'] is Map) {
          final s = res['summary'] as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _summary = {
                'totalJobsToday': s['jobsToday'] ?? 0,
                'pendingJobs': _countStatus(res['jobsToday'], 'pending'),
                'inProgressJobs': s['vehiclesBusy'] ?? 0,
                'completedJobs': _countStatus(res['jobsToday'], 'completed'),
                'totalVehicles': s['totalVehicles'] ?? 0,
                'activeVehicles': s['vehiclesAvailable'] ?? 0,
              };
              _loading = false;
            });
            return;
          }
        }
      } catch (_) {}

      _computeSummaryLocally();
      return;
    }

    // Technician path — compute their personal summary locally
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  int _countStatus(dynamic jobsList, String status) {
    if (jobsList is! List) return 0;
    return jobsList.where((j) => j['status'] == status).length;
  }

  void _computeSummaryLocally() {
    if (!mounted) return;
    final jobs = context.read<JobProvider>().allJobs;
    final vehicles = context.read<VehicleProvider>().vehicles;
    final today = DateTime.now();
    final todaysJobs = jobs
        .where(
          (j) =>
              j.scheduledDate.year == today.year &&
              j.scheduledDate.month == today.month &&
              j.scheduledDate.day == today.day,
        )
        .toList();

    setState(() {
      _summary = {
        'totalJobsToday': todaysJobs.length,
        'pendingJobs': todaysJobs
            .where((j) => j.currentStatus == 'pending')
            .length,
        'inProgressJobs': todaysJobs
            .where((j) => j.currentStatus == 'in_progress')
            .length,
        'completedJobs': todaysJobs
            .where((j) => j.currentStatus == 'completed')
            .length,
        'totalVehicles': vehicles.length,
        'activeVehicles': vehicles.where((v) => v.isActive).length,
      };
      _loading = false;
    });
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final jobProvider = context.watch<JobProvider>();
    final vehProvider = context.watch<VehicleProvider>();
    final isLoading =
        _loading || jobProvider.isLoading || vehProvider.isLoading;
    final error = _error ?? jobProvider.error ?? vehProvider.error;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.people_outlined),
              tooltip: 'Manage Users',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UsersScreen()),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadDashboard,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async => await context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? _buildError(error)
          : auth.isTechnician
          ? _buildTechnicianDashboard(auth, jobProvider)
          : _buildManagerDashboard(auth, jobProvider, vehProvider),
    );
  }

  // ==============================================================
  // TECHNICIAN DASHBOARD
  // ==============================================================
  Widget _buildTechnicianDashboard(AuthProvider auth, JobProvider jobProvider) {
    final today = DateTime.now();
    final userId = auth.user?.id;

    // ── FIX: match by job_technicians list OR legacy driver_id ──
    // Because jobs can be assigned via "Manage Drivers" (writes to
    // job_technicians) or via the old driver_id field in job_assignments.
    // hasTechnician() checks job.technicians — populated from
    // technicians_json returned by /api/jobs/my-jobs.
    final myJobs = jobProvider.allJobs.where((j) {
      if (userId == null) return false;
      return j.hasTechnician(userId) || j.driverId == userId;
    }).toList();

    final todayJobs =
        myJobs
            .where(
              (j) =>
                  j.scheduledDate.year == today.year &&
                  j.scheduledDate.month == today.month &&
                  j.scheduledDate.day == today.day,
            )
            .toList()
          ..sort(
            (a, b) => a.scheduledTimeStart.compareTo(b.scheduledTimeStart),
          );

    final upcomingJobs =
        myJobs
            .where(
              (j) => j.scheduledDate.isAfter(
                DateTime(today.year, today.month, today.day),
              ),
            )
            .toList()
          ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final inProgress = todayJobs
        .where((j) => j.currentStatus == 'in_progress')
        .length;
    final pending = todayJobs
        .where(
          (j) => j.currentStatus == 'pending' || j.currentStatus == 'assigned',
        )
        .length;
    final completed = todayJobs
        .where((j) => j.currentStatus == 'completed')
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final content = RefreshIndicator(
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(auth),
                const SizedBox(height: 20),
                _buildTechnicianStatCards(
                  inProgress,
                  pending,
                  completed,
                  todayJobs.length,
                ),
                const SizedBox(height: 24),
                _buildSectionTitle("Today's Jobs  (${todayJobs.length})"),
                const SizedBox(height: 12),
                todayJobs.isEmpty
                    ? _buildTechEmptyCard(
                        icon: Icons.event_available_outlined,
                        title: 'No jobs scheduled today',
                        subtitle: 'You have no assigned jobs for today.',
                      )
                    : Column(
                        children: todayJobs
                            .map(_buildTechnicianJobCard)
                            .toList(),
                      ),
                const SizedBox(height: 24),
                if (upcomingJobs.isNotEmpty) ...[
                  _buildSectionTitle('Upcoming Jobs  (${upcomingJobs.length})'),
                  const SizedBox(height: 12),
                  Column(
                    children: upcomingJobs
                        .take(5)
                        .map(
                          (j) => _buildTechnicianJobCard(j, isUpcoming: true),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        );

        if (!isWide) return content;
        return Container(
          color: AppTheme.backgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTechnicianStatCards(
    int inProgress,
    int pending,
    int completed,
    int total,
  ) {
    final cardData = [
      _StatCardData(
        label: 'Jobs Today',
        value: '$total',
        icon: Icons.work_outline,
        color: AppTheme.primaryColor,
        patternType: _PatternType.circles,
      ),
      _StatCardData(
        label: 'In Progress',
        value: '$inProgress',
        icon: Icons.directions_car_outlined,
        color: AppTheme.inProgressColor,
        patternType: _PatternType.waves,
      ),
      _StatCardData(
        label: 'Pending',
        value: '$pending',
        icon: Icons.pending_outlined,
        color: const Color(0xFFEF4444),
        patternType: _PatternType.dots,
      ),
      _StatCardData(
        label: 'Completed',
        value: '$completed',
        icon: Icons.check_circle_outline,
        color: AppTheme.completedColor,
        patternType: _PatternType.diagonal,
      ),
    ];
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStatCard(cardData[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(cardData[1])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStatCard(cardData[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(cardData[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicianJobCard(dynamic job, {bool isUpcoming = false}) {
    final status = job.currentStatus as String;
    final color = AppTheme.getStatusColor(status);
    final isActiveJob = status == 'in_progress';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isActiveJob
            ? BorderSide(color: AppTheme.inProgressColor, width: 2)
            : BorderSide.none,
      ),
      elevation: isActiveJob ? 4 : 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        ).then((_) => _loadDashboard()),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      AppTheme.getJobTypeIcon(job.jobType),
                      color: color,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.jobNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        Text(
                          job.customerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      job.statusDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  _techDetailChip(
                    Icons.calendar_today_outlined,
                    isUpcoming ? job.formattedDate : 'Today',
                  ),
                  const SizedBox(width: 12),
                  _techDetailChip(Icons.access_time, job.formattedTimeRange),
                  if (job.vehicleName != null) ...[
                    const SizedBox(width: 12),
                    _techDetailChip(Icons.local_shipping, job.vehicleName!),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.customerAddress,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (isActiveJob) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(job: job),
                      ),
                    ).then((_) => _loadDashboard()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.inProgressColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text(
                      'Update Status',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _techDetailChip(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppTheme.textSecondary),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
      ),
    ],
  );

  Widget _buildTechEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 52, color: AppTheme.textHint),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // ADMIN / SCHEDULER DASHBOARD
  // ==============================================================
  Widget _buildManagerDashboard(
    AuthProvider auth,
    JobProvider jobProvider,
    VehicleProvider vehProvider,
  ) {
    final today = DateTime.now();
    final todaysJobs = jobProvider.allJobs
        .where(
          (j) =>
              j.scheduledDate.year == today.year &&
              j.scheduledDate.month == today.month &&
              j.scheduledDate.day == today.day,
        )
        .toList();

    final vehicleStatus = vehProvider.vehicles.map((v) {
      final count = todaysJobs.where((j) => j.vehicleId == v.id).length;
      return {
        'vehicle_name': v.vehicleName,
        'license_plate': v.licensePlate,
        'is_active': v.isActive,
        'jobsToday': count,
      };
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;
        final content = RefreshIndicator(
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeHeader(auth),
                const SizedBox(height: 20),
                _buildStatCards(_summary),
                const SizedBox(height: 24),
                if (auth.isAdmin) ...[
                  _buildUsersQuickCard(),
                  const SizedBox(height: 24),
                ],
                if (vehicleStatus.isNotEmpty) ...[
                  _buildSectionTitle('Vehicle Status'),
                  const SizedBox(height: 12),
                  _buildVehicleStatusList(vehicleStatus),
                  const SizedBox(height: 24),
                ],
                _buildSectionTitle("Today's Jobs"),
                const SizedBox(height: 12),
                todaysJobs.isEmpty
                    ? _buildEmptyJobs()
                    : _buildJobsList(todaysJobs),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );

        if (!isWide) return content;
        return Container(
          color: AppTheme.backgroundColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUsersQuickCard() {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UsersScreen()),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF7C3AED).withOpacity(0.12),
              const Color(0xFF7C3AED).withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_outlined,
                color: Color(0xFF7C3AED),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'System Users',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Manage drivers, schedulers and admins',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF7C3AED)),
          ],
        ),
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(AuthProvider auth) {
    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
        ? 'Good Afternoon'
        : 'Good Evening';

    final headerColors = auth.isTechnician
        ? [const Color(0xFF0D9488), const Color(0xFF0F766E)]
        : auth.isScheduler
        ? [const Color(0xFFEA580C), const Color(0xFFC2410C)]
        : [AppTheme.primaryColor, AppTheme.primaryDark];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: headerColors),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Colors.white24,
            radius: 28,
            child: Icon(Icons.person, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting,',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  auth.user?.fullName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    auth.user?.roleDisplayName ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${now.day}/${now.month}/${now.year}',
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              Text(
                '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(Map<String, dynamic> summary) {
    final cardData = [
      _StatCardData(
        label: 'Jobs Today',
        value: '${summary['totalJobsToday'] ?? 0}',
        icon: Icons.work_outline,
        color: AppTheme.primaryColor,
        patternType: _PatternType.circles,
      ),
      _StatCardData(
        label: 'Pending',
        value: '${summary['pendingJobs'] ?? 0}',
        icon: Icons.pending_outlined,
        color: const Color(0xFFEF4444),
        patternType: _PatternType.dots,
      ),
      _StatCardData(
        label: 'In Progress',
        value: '${summary['inProgressJobs'] ?? 0}',
        icon: Icons.directions_car_outlined,
        color: AppTheme.inProgressColor,
        patternType: _PatternType.waves,
      ),
      _StatCardData(
        label: 'Completed',
        value: '${summary['completedJobs'] ?? 0}',
        icon: Icons.check_circle_outline,
        color: AppTheme.completedColor,
        patternType: _PatternType.diagonal,
      ),
    ];
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStatCard(cardData[0])),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(cardData[1])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildStatCard(cardData[2])),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard(cardData[3])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(_StatCardData data) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              data.color.withOpacity(0.09),
              data.color.withOpacity(0.02),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _StatCardPainter(
                  color: data.color,
                  patternType: data.patternType,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: data.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(data.icon, color: data.color, size: 26),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: data.color,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary,
    ),
  );

  Widget _buildVehicleStatusList(List<Map<String, dynamic>> vehicles) {
    return Column(
      children: vehicles.map((vehicle) {
        final jobsToday = vehicle['jobsToday'] as int? ?? 0;
        final isActive = vehicle['is_active'] == true;
        final iconColor = isActive
            ? AppTheme.successColor
            : AppTheme.errorColor;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(Icons.local_shipping, color: iconColor, size: 22),
            ),
            title: Text(
              vehicle['vehicle_name'] ?? 'Unknown Vehicle',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(vehicle['license_plate'] ?? ''),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$jobsToday job${jobsToday == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyJobs() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.work_off_outlined, size: 48, color: AppTheme.textHint),
              SizedBox(height: 12),
              Text(
                'No jobs scheduled for today',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobsList(List<dynamic> jobs) {
    return Column(
      children: jobs.map((job) {
        final status = job.currentStatus as String;
        final color = AppTheme.getStatusColor(status);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(
                AppTheme.getJobTypeIcon(job.jobType),
                color: color,
                size: 22,
              ),
            ),
            title: Text(
              job.jobNumber,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.customerName, style: const TextStyle(fontSize: 13)),
                Text(
                  '${job.scheduledTimeStart} - ${job.scheduledTimeEnd}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }
}
