// ============================================
// FILE: lib/screens/jobs/job_detail_screen.dart
// PURPOSE: View job details + update status + assign/swap vehicle
//
// CHANGES:
//   • Assignment card now lists all technicians from job.technicians
//     (replaces single driverName row).
//   • Drivers see their own job detail without confusion — their name
//     is highlighted in the technicians list.
//   • Admin / Scheduler: new "Manage Drivers" button opens a dialog
//     to replace the technician list, calling assignTechnicians().
//   • Drivers fetched from GET /api/users?role=technician in the
//     Manage Drivers dialog.
//
// Permission matrix:
//   admin      → assign/swap vehicle, manage drivers, update status
//   scheduler  → assign vehicle (no swap), manage drivers, update status
//   technician → update status only (in_progress → completed/cancelled)
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/screens/jobs/edit_job_screen.dart';
import 'package:vehicle_scheduling_app/services/user_service.dart';

// ── Lightweight driver option for the picker dialog ────────────
class _DriverOption {
  final int id;
  final String fullName;
  const _DriverOption({required this.id, required this.fullName});

  factory _DriverOption.fromJson(Map<String, dynamic> j) => _DriverOption(
    id: j['id'] as int,
    fullName: (j['full_name'] ?? j['fullName'] ?? '').toString(),
  );
}

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Job _job;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
  }

  // ==========================================
  // STATUS TRANSITIONS
  // ==========================================
  List<String> _getNextStatuses(String current, AuthProvider auth) {
    if (auth.isTechnician) {
      switch (current) {
        case 'assigned':
          return ['in_progress'];
        case 'in_progress':
          return ['completed', 'cancelled'];
        default:
          return [];
      }
    }
    switch (current) {
      case 'pending':
        return ['assigned', 'cancelled'];
      case 'assigned':
        return ['in_progress', 'cancelled'];
      case 'in_progress':
        return ['completed', 'cancelled'];
      default:
        return [];
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final auth = context.read<AuthProvider>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Status'),
        content: Text(
          'Change status to "${newStatus.replaceAll('_', ' ').toUpperCase()}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context.read<JobProvider>().updateJobStatus(
      jobId: _job.id,
      newStatus: newStatus,
      changedBy: auth.user?.id ?? AppConfig.defaultUserId,
    );

    if (!mounted) return;

    if (success) {
      setState(() => _job = _job.copyWith(currentStatus: newStatus));
      _showSnack('Status updated to ${newStatus.replaceAll('_', ' ')}');
    } else {
      _showSnack(
        context.read<JobProvider>().error ?? 'Failed to update status',
        isError: true,
      );
    }
  }

  // ==========================================
  // VEHICLE DIALOG
  // ==========================================
  Future<void> _showVehicleDialog({required bool isSwap}) async {
    await context.read<VehicleProvider>().loadActiveVehicles();
    if (!mounted) return;

    final vehicles = context.read<VehicleProvider>().activeVehicles;
    final currentVehicleId = _job.vehicleId;
    final available = isSwap
        ? vehicles.where((v) => v.id != currentVehicleId).toList()
        : vehicles;

    if (available.isEmpty) {
      _showSnack(
        isSwap
            ? 'No other active vehicles to swap with'
            : 'No active vehicles available',
      );
      return;
    }

    int? selectedVehicleId;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(isSwap ? 'Swap Vehicle' : 'Assign Vehicle'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: available
                  .map(
                    (v) => RadioListTile<int>(
                      value: v.id,
                      groupValue: selectedVehicleId,
                      title: Text(v.vehicleName),
                      subtitle: Text(v.licensePlate),
                      onChanged: (val) =>
                          setDialogState(() => selectedVehicleId = val),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedVehicleId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      if (isSwap)
                        await _swapVehicle(selectedVehicleId!);
                      else
                        await _assignVehicle(selectedVehicleId!);
                    },
              child: Text(isSwap ? 'Swap' : 'Assign'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _assignVehicle(int vehicleId) async {
    if (_job.isAssigned) {
      _showSnack(
        'Job already has a vehicle. Use "Swap Vehicle" to change.',
        isError: true,
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await context.read<JobProvider>().assignJob(
      jobId: _job.id,
      vehicleId: vehicleId,
      assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
    );

    if (!mounted) return;

    if (success) {
      await context.read<JobProvider>().loadJobById(_job.id);
      final updated = context.read<JobProvider>().selectedJob;
      if (updated != null) setState(() => _job = updated);
      _showSnack('Vehicle assigned successfully!');
    } else {
      _showSnack(
        context.read<JobProvider>().error ?? 'Failed to assign vehicle',
        isError: true,
      );
    }
  }

  Future<void> _swapVehicle(int newVehicleId) async {
    if (!_job.isAssigned) {
      _showSnack(
        'No vehicle assigned. Use "Assign Vehicle" first.',
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Vehicle Swap'),
        content: Text(
          'This will replace ${_job.vehicleName} with the new vehicle. '
          'The current assignment will be removed.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Swap Vehicle'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final auth = context.read<AuthProvider>();
    final success = await context.read<JobProvider>().assignJob(
      jobId: _job.id,
      vehicleId: newVehicleId,
      assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
    );

    if (!mounted) return;

    if (success) {
      await context.read<JobProvider>().loadJobById(_job.id);
      final updated = context.read<JobProvider>().selectedJob;
      if (updated != null) setState(() => _job = updated);
      _showSnack('Vehicle swapped! ${_job.vehicleName} assigned.');
    } else {
      _showSnack(
        context.read<JobProvider>().error ?? 'Failed to swap vehicle',
        isError: true,
      );
    }
  }

  // ==========================================
  // MANAGE DRIVERS DIALOG
  // Opens a multi-select picker; on save calls assignTechnicians().
  // Drivers already booked at this job's time window are shown
  // greyed-out and disabled so the scheduler cannot accidentally
  // double-book them.
  // ==========================================
  Future<void> _showManageDriversDialog() async {
    List<_DriverOption> available = [];
    // Busy driver IDs for this job's time window (excluding the job itself)
    Set<int> busyIds = {};
    bool loading = true;

    final Set<int> selected = Set.from(_job.technicians.map((t) => t.id));

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          // Kick off both loads on first build
          if (loading && available.isEmpty) {
            Future.microtask(() async {
              try {
                // Load driver list and busy IDs in parallel
                final dateStr =
                    _job.formattedDate; // already YYYY-MM-DD-compatible
                final startStr = _job.scheduledTimeStart;
                final endStr = _job.scheduledTimeEnd;

                final usersFuture = UserService().getUsers(role: 'technician');
                final busyFuture = _fetchBusyDriverIds(
                  dateStr:
                      '${_job.scheduledDate.year}'
                      '-${_job.scheduledDate.month.toString().padLeft(2, '0')}'
                      '-${_job.scheduledDate.day.toString().padLeft(2, '0')}',
                  startStr: startStr,
                  endStr: endStr,
                  excludeJobId: _job.id,
                );

                final results = await Future.wait([usersFuture, busyFuture]);
                final users = results[0] as List;
                final busy = results[1] as Set<int>;

                setDialog(() {
                  available = users
                      .map((u) => _DriverOption(id: u.id, fullName: u.fullName))
                      .toList();
                  busyIds = busy;
                  loading = false;
                });
              } catch (_) {
                setDialog(() => loading = false);
              }
            });
          }

          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.group_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text('Manage Drivers'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : available.isEmpty
                  ? const Center(
                      child: Text(
                        'No drivers available.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      children: available.map((driver) {
                        final isSelected = selected.contains(driver.id);
                        final isBusy = busyIds.contains(driver.id);
                        return Opacity(
                          opacity: isBusy ? 0.45 : 1.0,
                          child: Tooltip(
                            message: isBusy
                                ? '${driver.fullName} already has a job at this time'
                                : '',
                            child: CheckboxListTile(
                              value: isSelected && !isBusy,
                              // Disable busy drivers
                              onChanged: isBusy
                                  ? null
                                  : (val) => setDialog(() {
                                      if (val == true)
                                        selected.add(driver.id);
                                      else
                                        selected.remove(driver.id);
                                    }),
                              title: Text(
                                driver.fullName,
                                style: TextStyle(
                                  color: isBusy
                                      ? AppTheme.textHint
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: isBusy
                                  ? const Text(
                                      'Already booked at this time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.errorColor,
                                      ),
                                    )
                                  : null,
                              secondary: CircleAvatar(
                                radius: 16,
                                backgroundColor: isBusy
                                    ? AppTheme.textHint.withOpacity(0.1)
                                    : isSelected
                                    ? AppTheme.primaryColor.withOpacity(0.15)
                                    : AppTheme.textHint.withOpacity(0.15),
                                child: Text(
                                  driver.fullName.isNotEmpty
                                      ? driver.fullName[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isBusy
                                        ? AppTheme.textHint
                                        : isSelected
                                        ? AppTheme.primaryColor
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.save_outlined, size: 16),
                label: Text(
                  selected.isEmpty
                      ? 'Clear Drivers'
                      : 'Save (${selected.length})',
                ),
                onPressed: () => Navigator.pop(ctx, selected.toList()),
              ),
            ],
          );
        },
      ),
    ).then((result) async {
      if (result == null || !mounted) return;

      final ids = result as List<int>;
      final auth = context.read<AuthProvider>();

      final success = await context.read<JobProvider>().assignTechnicians(
        jobId: _job.id,
        technicianIds: ids,
        assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
      );

      if (!mounted) return;

      if (success) {
        await context.read<JobProvider>().loadJobById(_job.id);
        final updated = context.read<JobProvider>().selectedJob;
        if (updated != null && mounted) setState(() => _job = updated);
        _showSnack(
          ids.isEmpty
              ? 'All drivers removed from job'
              : '${ids.length} driver(s) assigned',
        );
      } else {
        final error =
            context.read<JobProvider>().error ?? 'Failed to update drivers';
        _handleDriverConflictError(error);
      }
    });
  }

  // ── Fetch busy driver IDs for this job's time window ─────────────────
  // Falls back to empty set on error — the server-side check in
  // jobAssignmentService.js is the authoritative guard.
  Future<Set<int>> _fetchBusyDriverIds({
    required String dateStr,
    required String startStr,
    required String endStr,
    int? excludeJobId,
  }) async {
    try {
      String url =
          '${AppConfig.availabilityEndpoint}/drivers'
          '?date=$dateStr&start_time=$startStr&end_time=$endStr';
      if (excludeJobId != null) url += '&exclude_job_id=$excludeJobId';

      final response = await UserService().apiService.get(url);
      if (response['success'] == true) {
        final busyList = response['busy'] as List<dynamic>? ?? [];
        return busyList.map<int>((d) => (d['id'] as num).toInt()).toSet();
      }
    } catch (_) {
      // Network error — degrade gracefully
    }
    return {};
  }

  // ── Show conflict dialog when assignTechnicians() rejects ────────────
  void _handleDriverConflictError(String error) {
    final isConflict =
        error.toLowerCase().contains('conflict') ||
        error.toLowerCase().contains('already assigned');

    if (isConflict) {
      _showConflictDialog(
        title: 'Driver Already Booked',
        icon: Icons.person_off_outlined,
        rawMessage: error,
        hint:
            'Deselect the conflicting driver(s) or reschedule this job first.',
      );
    } else {
      _showSnack(error, isError: true, duration: 4);
    }
  }

  // ── Detailed conflict dialog (shared by vehicle swap + driver assign) ─
  void _showConflictDialog({
    required String title,
    required IconData icon,
    required String rawMessage,
    required String hint,
  }) {
    final conflictLines = rawMessage
        .split('\n')
        .where(
          (l) =>
              l.trim().startsWith('•') ||
              l.toLowerCase().contains('assigned to'),
        )
        .toList();

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: AppTheme.errorColor, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conflictLines.isEmpty
                  ? rawMessage
                  : 'The following driver(s) have a conflicting assignment:',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            if (conflictLines.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...conflictLines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.errorColor.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 15,
                          color: AppTheme.errorColor,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            line.trim().replaceFirst('•', '').trim(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK, I'll fix it"),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false, int duration = 3}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: Duration(seconds: duration),
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final statusColor = AppTheme.getStatusColor(_job.currentStatus);
    final nextStatuses = _getNextStatuses(_job.currentStatus, auth);
    final hasVehicle = _job.isAssigned;

    final canAssign = auth.hasPermission('assignments:create');
    final canSwap = auth.isAdmin;
    final canManageDrivers = canAssign; // same gate: admin + scheduler
    final canUpdateStatus = auth.hasPermission('jobs:updateStatus');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_job.jobNumber),
        actions: [
          // Edit button — admin + scheduler only
          if (auth.hasPermission('jobs:create'))
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Job',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => EditJobScreen(job: _job)),
                );
                if (updated == true && mounted) {
                  await context.read<JobProvider>().loadJobById(_job.id);
                  final refreshed = context.read<JobProvider>().selectedJob;
                  if (refreshed != null && mounted) {
                    setState(() => _job = refreshed);
                  }
                }
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── STATUS BANNER ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    AppTheme.getJobTypeIcon(_job.jobType),
                    color: statusColor,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _job.typeDisplayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _job.statusDisplayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.getPriorityColor(
                        _job.priority,
                      ).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _job.priorityDisplayName,
                      style: TextStyle(
                        color: AppTheme.getPriorityColor(_job.priority),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── CUSTOMER ────────────────────────────────────────────
            _buildCard(
              title: 'Customer',
              icon: Icons.person_outline,
              children: [
                _infoRow('Name', _job.customerName),
                if (_job.customerPhone != null)
                  _infoRow('Phone', _job.customerPhone!),
                _infoRow('Address', _job.customerAddress),
              ],
            ),
            const SizedBox(height: 12),

            // ── SCHEDULE ────────────────────────────────────────────
            _buildCard(
              title: 'Schedule',
              icon: Icons.calendar_today_outlined,
              children: [
                _infoRow('Date', _job.formattedDate),
                _infoRow('Time', _job.formattedTimeRange),
                _infoRow(
                  'Duration',
                  '${widget.job.estimatedDurationMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── ASSIGNMENT ──────────────────────────────────────────
            _buildCard(
              title: 'Assignment',
              icon: Icons.local_shipping_outlined,
              children: [
                // Vehicle row
                _infoRow(
                  'Vehicle',
                  _job.vehicleName ?? 'Not assigned',
                  valueColor: _job.vehicleName != null
                      ? AppTheme.primaryColor
                      : AppTheme.textHint,
                ),
                if (_job.licensePlate != null)
                  _infoRow('Plate', _job.licensePlate!),

                const Divider(height: 16),

                // Technician / drivers section
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text(
                          'Drivers',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      // "Manage" button for admin/scheduler
                      if (canManageDrivers && _job.isActive)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _showManageDriversDialog,
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text(
                                'Manage',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                if (_job.technicians.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 80, bottom: 4),
                    child: Text(
                      'No drivers assigned',
                      style: TextStyle(
                        color: canManageDrivers
                            ? AppTheme.warningColor
                            : AppTheme.textHint,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ..._job.technicians.map((tech) {
                    final isMe = auth.user?.id == tech.id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 80, bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isMe
                                ? AppTheme.primaryColor.withOpacity(0.15)
                                : AppTheme.textHint.withOpacity(0.15),
                            child: Text(
                              tech.fullName.isNotEmpty
                                  ? tech.fullName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? AppTheme.primaryColor
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tech.fullName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isMe
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isMe
                                  ? AppTheme.primaryColor
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 12),

            // ── DESCRIPTION ─────────────────────────────────────────
            if (_job.description != null) ...[
              _buildCard(
                title: 'Description',
                icon: Icons.notes_outlined,
                children: [
                  Text(
                    _job.description!,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // ── ACTIONS ─────────────────────────────────────────────
            if (_job.isActive) ...[
              const SizedBox(height: 8),

              // ASSIGN VEHICLE
              if (canAssign && !hasVehicle) ...[
                _actionButton(
                  icon: Icons.local_shipping_outlined,
                  label: 'Assign Vehicle',
                  color: AppTheme.primaryColor,
                  onPressed: () => _showVehicleDialog(isSwap: false),
                ),
                const SizedBox(height: 12),
              ],

              // SWAP VEHICLE
              if (canSwap && hasVehicle) ...[
                _actionButton(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Swap Vehicle',
                  color: AppTheme.warningColor,
                  onPressed: () => _showVehicleDialog(isSwap: true),
                ),
                const SizedBox(height: 12),
              ],

              // Scheduler info when vehicle already assigned
              if (auth.isScheduler && hasVehicle) ...[
                _infoNote(
                  'Vehicle assigned. Only administrators can swap vehicles.',
                ),
                const SizedBox(height: 12),
              ],

              // MANAGE DRIVERS — inline shortcut (admin/scheduler)
              if (canManageDrivers) ...[
                _actionButton(
                  icon: Icons.group_outlined,
                  label: _job.technicians.isEmpty
                      ? 'Assign Drivers'
                      : 'Manage Drivers (${_job.technicians.length})',
                  color: AppTheme.successColor,
                  onPressed: _showManageDriversDialog,
                  outlined: true,
                ),
                const SizedBox(height: 12),
              ],

              // STATUS BUTTONS
              if (canUpdateStatus && nextStatuses.isNotEmpty) ...[
                const Text(
                  'Update Status:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: nextStatuses.map((status) {
                    final color = AppTheme.getStatusColor(status);
                    return ElevatedButton(
                      onPressed: () => _updateStatus(status),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(status.replaceAll('_', ' ').toUpperCase()),
                    );
                  }).toList(),
                ),
              ],

              // Read-only note for technician when no transitions available
              if (auth.isTechnician && nextStatuses.isEmpty) ...[
                const SizedBox(height: 8),
                _infoNote(
                  'This job cannot be updated at its current stage.',
                  icon: Icons.lock_outline,
                ),
              ],
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
    );
  }

  Widget _infoNote(String text, {IconData icon = Icons.info_outline}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.textHint.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textHint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
