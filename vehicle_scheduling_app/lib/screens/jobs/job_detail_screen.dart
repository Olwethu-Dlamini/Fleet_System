// ============================================
// FILE: lib/screens/jobs/job_detail_screen.dart
//
// FIXES APPLIED:
//
// BUG 2 — False error after assigning driver from detail screen:
//   The old code called assignTechnicians() then immediately called
//   loadJobById() again. assignTechnicians() in the provider already
//   calls _reloadSingleJob() internally and updates selectedJob.
//   The redundant loadJobById() set status=loading, notified listeners,
//   set status=success, notified again — causing a double rebuild race.
//   On slower devices this meant the screen read selectedJob BEFORE the
//   second load finished, getting stale data, and the error state from
//   the internal reload was sometimes surfaced incorrectly.
//   FIX: Removed all manual loadJobById() calls after assignTechnicians()
//   and assignJob() succeed. Just read selectedJob directly.
//
// BUG 3 — Admin override does nothing:
//   The "Manage Drivers" dialog let admins check busy drivers, but the
//   call to assignTechnicians() passed no forceOverride flag.
//   The backend rejected it with the same conflict error as a normal user.
//   FIX: The dialog now pops with { ids: [...], force: bool } instead of
//   just a List<int>. When isAdmin is true and the user selected a busy
//   driver, force=true is passed through to assignTechnicians() which
//   sends force_override: true to the backend.
//   The backend (jobs.js) reads req.user.role === 'admin' AND force_override
//   to skip conflict checking and remove the driver from any conflicting
//   job before inserting them into this one.
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/screens/jobs/edit_job_screen.dart';
import 'package:vehicle_scheduling_app/services/user_service.dart';

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
  bool _isCompleting = false;

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
        if (_job.vehicleId == null) return ['cancelled'];
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

    String? cancelReason;
    if (newStatus == 'cancelled') {
      cancelReason = await _showCancelReasonDialog();
      if (cancelReason == null || !mounted) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
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
    }

    final success = await context.read<JobProvider>().updateJobStatus(
      jobId: _job.id,
      newStatus: newStatus,
      changedBy: auth.user?.id ?? AppConfig.defaultUserId,
      reason: cancelReason,
    );

    if (!mounted) return;

    if (success) {
      // Same reasoning as the provider: addPostFrameCallback ensures setState
      // runs after the current frame (including the dialog-close Hero
      // transition) is fully complete. Future.microtask runs BEFORE the
      // frame ends and causes the same cascade of assertion errors.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final updated = context.read<JobProvider>().selectedJob;
        setState(
          () => _job = updated ?? _job.copyWith(currentStatus: newStatus),
        );
        _showSnack('Status updated to ${newStatus.replaceAll('_', ' ')}');
      });
    } else {
      _showSnack(
        context.read<JobProvider>().error ?? 'Failed to update status',
        isError: true,
      );
    }
  }

  Future<String?> _showCancelReasonDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: AppTheme.errorColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Cancel Job',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 15,
                        color: AppTheme.errorColor,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'A cancellation reason is required and will be saved to the job record.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Cancellation Reason *',
                    hintText:
                        'e.g. Customer not available, equipment not ready...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: AppTheme.errorColor,
                        width: 2,
                      ),
                    ),
                    alignLabelWithHint: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a reason for cancelling this job';
                    }
                    if (val.trim().length < 5) {
                      return 'Reason must be at least 5 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Go Back'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: const Text('Confirm Cancel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, controller.text.trim());
                }
              },
            ),
          ],
        ),
      ),
    );

    // Defer disposal until after the current frame completes so the Hero
    // transition cleanup (visitChildElements on the closing dialog tree)
    // finishes before the controller is invalidated.
    SchedulerBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return result;
  }

  // ==========================================
  // UNASSIGN DRIVER
  // ==========================================
  Future<void> _unassignDriver(int driverId, String driverName) async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('Remove Driver'),
        content: Text(
          'Remove "$driverName" from this job?\n\n'
          'They will no longer see this job on their dashboard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final remaining = _job.technicians
        .where((t) => t.id != driverId)
        .map((t) => t.id)
        .toList();

    final auth = context.read<AuthProvider>();
    final success = await context.read<JobProvider>().assignTechnicians(
      jobId: _job.id,
      technicianIds: remaining,
      assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
      // No forceOverride needed for removal
    );

    if (!mounted) return;

    if (success) {
      // FIX (Bug 2): Don't call loadJobById() again here.
      // assignTechnicians() in the provider already called _reloadSingleJob()
      // which updated selectedJob. Just read it directly.
      final updated = context.read<JobProvider>().selectedJob;
      if (updated != null && mounted) setState(() => _job = updated);
      _showSnack('$driverName removed from job');
    } else {
      _showSnack(
        context.read<JobProvider>().error ?? 'Failed to remove driver',
        isError: true,
      );
    }
  }

  // ==========================================
  // UNASSIGN VEHICLE
  // ==========================================
  Future<void> _unassignVehicle() async {
    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (_) => AlertDialog(
        title: const Text('Remove Vehicle'),
        content: Text(
          'Remove ${_job.vehicleName ?? "this vehicle"} from the job?\n\n'
          'The job will revert to Pending status.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove Vehicle'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final success = await context.read<JobProvider>().unassignVehicle(
      jobId: _job.id,
    );

    if (!mounted) return;

    if (success) {
      // FIX (Bug 2): Same pattern — unassignVehicle() already reloads.
      final updated = context.read<JobProvider>().selectedJob;
      if (updated != null && mounted) setState(() => _job = updated);
      _showSnack('Vehicle removed. Job is now Pending.');
    } else {
      _showSnack(
        context.read<JobProvider>().error ?? 'Failed to remove vehicle',
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
      useRootNavigator: false,
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
    if (_job.vehicleId != null) {
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
      // BUGFIX: Pass the currently assigned technicians so the backend
      // preserves them. The POST /api/job-assignments/assign endpoint
      // receives technician_ids and writes job_technicians rows as part
      // of the same transaction. If we omit this (defaulting to []), the
      // backend treats it as "clear all technicians" and the previously
      // assigned drivers are silently removed.
      technicianIds: _job.technicians.map((t) => t.id).toList(),
    );

    if (!mounted) return;

    if (success) {
      // FIX (Bug 2): assignJob() internally calls _reloadSingleJob().
      // No need to call loadJobById() again.
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
    if (_job.vehicleId == null) {
      _showSnack(
        'No vehicle assigned. Use "Assign Vehicle" first.',
        isError: true,
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
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
      // BUGFIX: Same as _assignVehicle — preserve the currently assigned
      // technicians. Swapping a vehicle should only change the vehicle,
      // never touch the driver list.
      technicianIds: _job.technicians.map((t) => t.id).toList(),
    );

    if (!mounted) return;

    if (success) {
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
  //
  // FIX (Bug 3): Dialog now pops with a Map instead of a raw List<int>.
  //
  // OLD:  Navigator.pop(ctx, selected.toList())  →  List<int>
  // NEW:  Navigator.pop(ctx, {'ids': selected.toList(), 'force': isAdmin && selectedBusyDriver})
  //
  // The 'force' flag is true when:
  //   - The logged-in user is an admin, AND
  //   - At least one of the selected drivers was in the busyIds set
  //     (meaning the admin deliberately selected a conflicting driver)
  //
  // This flag flows to jobProvider.assignTechnicians(forceOverride: force)
  // → job_service.assignTechnicians(forceOverride: force)
  // → PUT body includes force_override: true
  // → jobs.js backend route checks req.user.role === 'admin' && force_override
  // → calls Job.assignTechnicians(jobId, techIds, assignedBy, isAdminOverride=true)
  // → backend removes driver from conflicting job, then inserts into this one
  // ==========================================
  Future<void> _showManageDriversDialog() async {
    List<_DriverOption> available = [];
    Set<int> busyIds = {};
    bool loading = true;

    final Set<int> selected = Set.from(_job.technicians.map((t) => t.id));
    final isAdmin = context.read<AuthProvider>().isAdmin;

    // FIX (Bug 3): Use a typed showDialog so the result is Map<String, dynamic>
    // not dynamic. The old code used showDialog (untyped) + .then() which is an
    // anti-pattern when the enclosing function already uses await — .then() runs
    // after the await resolves, but context and mounted checks inside .then() can
    // fire after the widget has been disposed. We now await the typed dialog
    // directly and handle the result inline.
    final dialogResult = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          if (loading && available.isEmpty) {
            Future.microtask(() async {
              try {
                final usersFuture = UserService().getUsers(role: 'technician');
                final busyFuture = _fetchBusyDriverIds(
                  dateStr:
                      '${_job.scheduledDate.year}'
                      '-${_job.scheduledDate.month.toString().padLeft(2, '0')}'
                      '-${_job.scheduledDate.day.toString().padLeft(2, '0')}',
                  startStr: _job.scheduledTimeStart,
                  endStr: _job.scheduledTimeEnd,
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
            title: const Row(
              children: [
                Icon(
                  Icons.group_outlined,
                  color: AppTheme.primaryColor,
                  size: 20,
                ),
                SizedBox(width: 8),
                Text('Manage Drivers'),
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
                        // Admin can select busy drivers (force override).
                        // Non-admins cannot.
                        final canSelect = !isBusy || isAdmin;
                        return Opacity(
                          opacity: (isBusy && !isAdmin) ? 0.45 : 1.0,
                          child: Tooltip(
                            message: isBusy
                                ? isAdmin
                                      ? '⚠️ Has another job — admin override will unassign them from it'
                                      : '${driver.fullName} already has a job at this time'
                                : '',
                            child: CheckboxListTile(
                              value: isSelected,
                              onChanged: canSelect
                                  ? (val) => setDialog(() {
                                      if (val == true)
                                        selected.add(driver.id);
                                      else
                                        selected.remove(driver.id);
                                    })
                                  : null,
                              title: Text(
                                driver.fullName,
                                style: TextStyle(
                                  color: (isBusy && !isAdmin)
                                      ? AppTheme.textHint
                                      : AppTheme.textPrimary,
                                ),
                              ),
                              subtitle: isBusy
                                  ? Text(
                                      isAdmin
                                          ? '⚠️ Has another job — will be unassigned from it'
                                          : 'Already booked at this time',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isAdmin
                                            ? AppTheme.warningColor
                                            : AppTheme.errorColor,
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
                // Cancel — pop with null so dialogResult == null below
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
                // Pop with a typed Map. 'force' is true only when the admin
                // deliberately selected a driver that is in busyIds.
                onPressed: () => Navigator.pop(ctx, <String, dynamic>{
                  'ids': selected.toList(),
                  'force':
                      isAdmin && selected.any((id) => busyIds.contains(id)),
                }),
              ),
            ],
          );
        },
      ),
    );

    // Dialog was cancelled or widget was disposed while dialog was open
    if (dialogResult == null || !mounted) return;

    {
      final ids = List<int>.from(dialogResult['ids'] as List);
      final forceOverride = dialogResult['force'] as bool;

      final auth = context.read<AuthProvider>();

      final success = await context.read<JobProvider>().assignTechnicians(
        jobId: _job.id,
        technicianIds: ids,
        assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
        forceOverride: forceOverride,
      );

      if (!mounted) return;

      if (success) {
        // FIX (Bug 2): Don't call loadJobById() again.
        // assignTechnicians() already reloaded selectedJob internally.
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
    }
  }

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
    } catch (_) {}
    return {};
  }

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
      useRootNavigator: false,
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

  Future<void> _openMap() async {
    if (_job.destinationLat == null || _job.destinationLng == null) return;
    
    final url = 'https://www.google.com/maps/search/?api=1&query=${_job.destinationLat},${_job.destinationLng}';
    final uri = Uri.parse(url);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnack('Could not launch Google Maps', isError: true);
    }
  }

  // ==========================================
  // COMPLETE JOB WITH GPS  (Phase 03 — STAT-02, STAT-03, STAT-04)
  // ==========================================
  Future<void> _completeJobWithGps() async {
    // Step 1: Confirm dialog — must precede GPS capture (per context decision)
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete Job'),
        content: const Text('Are you sure? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2: Capture GPS with fallback
    setState(() => _isCompleting = true);

    Map<String, dynamic> gpsData;
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        gpsData = {
          'lat': null,
          'lng': null,
          'accuracy_m': null,
          'gps_status': 'no_gps',
        };
      } else {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 10),
          ),
        );
        if (position.accuracy <= 50.0) {
          gpsData = {
            'lat': position.latitude,
            'lng': position.longitude,
            'accuracy_m': position.accuracy,
            'gps_status': 'ok',
          };
        } else {
          gpsData = {
            'lat': null,
            'lng': null,
            'accuracy_m': null,
            'gps_status': 'low_accuracy',
          };
        }
      }
    } catch (_) {
      gpsData = {
        'lat': null,
        'lng': null,
        'accuracy_m': null,
        'gps_status': 'no_gps',
      };
    }

    if (!mounted) return;

    // Step 3: Call the completion API via provider
    final provider = context.read<JobProvider>();
    final success = await provider.completeJobWithGps(
      jobId: _job.id,
      lat: gpsData['lat'] as double?,
      lng: gpsData['lng'] as double?,
      accuracyM: gpsData['accuracy_m'] as double?,
      gpsStatus: gpsData['gps_status'] as String,
    );

    if (!mounted) return;
    setState(() => _isCompleting = false);

    if (success) {
      _showSnack('Job completed successfully');
      Navigator.pop(context);
    } else {
      _showSnack(
        provider.error ?? 'Failed to complete job',
        isError: true,
      );
    }
  }

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final statusColor = AppTheme.getStatusColor(_job.currentStatus);
    final nextStatuses = _getNextStatuses(_job.currentStatus, auth);
    final hasVehicle = _job.vehicleId != null;

    final canAssign = auth.hasPermission('assignments:create');
    final canSwap = auth.isAdmin;
    final canManageDrivers = auth.isAdmin;
    final canUpdateStatus = auth.hasPermission('jobs:updateStatus');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(_job.jobNumber),
        actions: [
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

            _buildCard(
              title: 'Customer',
              icon: Icons.person_outline,
              children: [
                _infoRow('Name', _job.customerName),
                if (_job.customerPhone != null)
                  _infoRow('Phone', _job.customerPhone!),
                _infoRow(
                  'Address',
                  _job.customerAddress,
                  trailing: (_job.destinationLat != null &&
                          _job.destinationLng != null)
                      ? IconButton(
                          icon: const Icon(
                            Icons.directions_outlined,
                            color: AppTheme.primaryColor,
                            size: 20,
                          ),
                          onPressed: _openMap,
                          tooltip: 'Navigate',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),

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

            _buildCard(
              title: 'Assignment',
              icon: Icons.local_shipping_outlined,
              children: [
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
                          if (auth.isAdmin && _job.isActive) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () =>
                                  _unassignDriver(tech.id, tech.fullName),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.person_remove_outlined,
                                  size: 14,
                                  color: AppTheme.errorColor,
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

            if (_job.isActive) ...[
              const SizedBox(height: 8),

              if (canAssign && !hasVehicle) ...[
                _actionButton(
                  icon: Icons.local_shipping_outlined,
                  label: 'Assign Vehicle',
                  color: AppTheme.primaryColor,
                  onPressed: () => _showVehicleDialog(isSwap: false),
                ),
                const SizedBox(height: 12),
              ],

              if (canSwap && hasVehicle) ...[
                _actionButton(
                  icon: Icons.swap_horiz_outlined,
                  label: 'Swap Vehicle',
                  color: AppTheme.warningColor,
                  onPressed: () => _showVehicleDialog(isSwap: true),
                ),
                const SizedBox(height: 12),
              ],

              if (auth.isAdmin && hasVehicle) ...[
                _actionButton(
                  icon: Icons.remove_circle_outline,
                  label: 'Remove Vehicle',
                  color: AppTheme.errorColor,
                  onPressed: _unassignVehicle,
                ),
                const SizedBox(height: 12),
              ],

              if (auth.isScheduler && hasVehicle) ...[
                _infoNote(
                  'Vehicle assigned. Only administrators can swap vehicles.',
                ),
                const SizedBox(height: 12),
              ],

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

              if (auth.isTechnician && nextStatuses.isEmpty) ...[
                const SizedBox(height: 8),
                _infoNote(
                  'This job cannot be updated at its current stage.',
                  icon: Icons.lock_outline,
                ),
              ],

              // ── COMPLETE JOB BUTTON (Phase 03 — STAT-02/03/04) ────
              // Visible ONLY to the assigned driver/technician when the job
              // is in_progress. Admins/schedulers use the standard status
              // buttons above. This button enforces STAT-02 gating.
              Builder(
                builder: (context) {
                  final currentUserId = auth.user?.id;
                  final isAssigned = currentUserId != null &&
                      (_job.driverId == currentUserId ||
                          _job.technicians.any((t) => t.id == currentUserId));
                  final isEligible =
                      (auth.isTechnician && isAssigned) ||
                      auth.isAdmin ||
                      auth.hasPermission('jobs:updateStatus');
                  final showCompleteButton =
                      isEligible && _job.currentStatus == 'in_progress';

                  if (!showCompleteButton) return const SizedBox.shrink();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isCompleting ? null : _completeJobWithGps,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.successColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          icon: _isCompleting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: Text(
                            _isCompleting ? 'Completing...' : 'Complete Job',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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
      child: OutlinedButton.icon(
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

  Widget _infoRow(String label, String value, {Color? valueColor, Widget? trailing}) {
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
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
