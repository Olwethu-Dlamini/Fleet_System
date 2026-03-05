// ============================================
// FILE: lib/screens/jobs/create_job_screen.dart
// PURPOSE: Form to create a new job
// CHANGES:
//   • Added "Assign Drivers" section — fetches technician/driver users
//     from GET /api/users?role=technician and renders a multi-select
//     chip list so one or more drivers can be assigned at creation time.
//   • technicianIds list is passed through to jobProvider.createJob()
//     which already supports it (no provider changes needed).
// ACCESS: admin + scheduler only (jobs:create permission)
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/services/user_service.dart';

// ── Lightweight row model for the job-creation summary dialog ──────
class _SummaryRow {
  final IconData icon;
  final Color color;
  final String text;
  const _SummaryRow({
    required this.icon,
    required this.color,
    required this.text,
  });
}

// ── Lightweight model for a selectable driver/technician ──
class _DriverOption {
  final int id;
  final String fullName;
  const _DriverOption({required this.id, required this.fullName});

  factory _DriverOption.fromJson(Map<String, dynamic> j) => _DriverOption(
    id: j['id'] as int,
    fullName: (j['full_name'] ?? j['fullName'] ?? '').toString(),
  );
}

class CreateJobScreen extends StatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialStartTime;
  final TimeOfDay? initialEndTime;

  const CreateJobScreen({
    super.key,
    this.initialDate,
    this.initialStartTime,
    this.initialEndTime,
  });

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController(text: '60');

  String _jobType = 'installation';
  String _priority = 'normal';
  int? _selectedVehicleId;

  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTimeStart;
  late TimeOfDay _scheduledTimeEnd;

  String? _dateError;
  String? _timeError;
  String? _vehicleError;

  // ── Driver selection state ──────────────────────────────
  List<_DriverOption> _availableDrivers = [];
  final Set<int> _selectedDriverIds = {};
  // Drivers already booked during the selected time window.
  // Rendered greyed-out/disabled so the scheduler cannot pick them.
  Set<int> _busyDriverIds = {};
  bool _driversLoading = false;
  String? _driversError;

  @override
  void initState() {
    super.initState();
    _scheduledDate = DateTime.now().add(const Duration(days: 1));
    _scheduledTimeStart = const TimeOfDay(hour: 9, minute: 0);
    _scheduledTimeEnd = const TimeOfDay(hour: 12, minute: 0);

    if (widget.initialDate != null) _scheduledDate = widget.initialDate!;
    if (widget.initialStartTime != null) {
      _scheduledTimeStart = widget.initialStartTime!;
      _scheduledTimeEnd =
          widget.initialEndTime ??
          TimeOfDay(
            hour: (_scheduledTimeStart.hour + 1) % 24,
            minute: _scheduledTimeStart.minute,
          );
    } else if (widget.initialEndTime != null) {
      _scheduledTimeEnd = widget.initialEndTime!;
    }

    _updateDurationFromTimes();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<VehicleProvider>().loadVehicles();
        _loadDrivers();
      }
    });
  }

  // ── Load all drivers, then mark which are busy for the chosen time ──
  Future<void> _loadDrivers() async {
    setState(() {
      _driversLoading = true;
      _driversError = null;
    });
    try {
      final users = await UserService().getUsers(role: 'technician');
      if (!mounted) return;
      final allDrivers = users
          .map((u) => _DriverOption(id: u.id, fullName: u.fullName))
          .toList();
      final busyIds = await _fetchBusyDriverIds();
      if (mounted) {
        setState(() {
          _availableDrivers = allDrivers;
          _busyDriverIds = busyIds;
          _selectedDriverIds.removeAll(busyIds); // deselect any now-busy driver
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _driversError = 'Could not load drivers';
        });
    } finally {
      if (mounted)
        setState(() {
          _driversLoading = false;
        });
    }
  }

  // ── Query GET /api/availability/drivers for the current time window ──
  // Falls back to empty set on any network error — the server-side
  // checkDriversAvailability() guard is still the authoritative check.
  Future<Set<int>> _fetchBusyDriverIds({int? excludeJobId}) async {
    try {
      final dateStr = _formatDate(_scheduledDate);
      final startStr = _formatTime(_scheduledTimeStart);
      final endStr = _formatTime(_scheduledTimeEnd);

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
      // Network error — degrade gracefully, server will still enforce
    }
    return {};
  }

  // ── Re-check driver availability whenever date/time changes ──────────
  // Called from _pickTime so the chip picker always reflects the
  // currently selected window before the user submits.
  void _onTimeChanged() {
    _updateDurationFromTimes();
    _fetchBusyDriverIds().then((busyIds) {
      if (mounted) {
        setState(() {
          _busyDriverIds = busyIds;
          _selectedDriverIds.removeAll(busyIds);
        });
      }
    });
  }

  void _updateDurationFromTimes() {
    final startM = _scheduledTimeStart.hour * 60 + _scheduledTimeStart.minute;
    final endM = _scheduledTimeEnd.hour * 60 + _scheduledTimeEnd.minute;
    final dur = endM - startM;
    if (dur > 0) _durationController.text = dur.toString();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  String? _validateDate(DateTime date) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final sel = DateTime(date.year, date.month, date.day);
    if (sel.isBefore(today)) return 'Cannot schedule jobs in the past';
    return null;
  }

  String? _validateTimeOrder(TimeOfDay start, TimeOfDay end) {
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    if (e <= s) return 'End time must be after start time';
    return null;
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  String _formatTimeDisplay(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _formatDateDisplay(DateTime d) {
    const months = [
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
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _scheduledDate = picked;
        _dateError = _validateDate(picked);
      });
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _scheduledTimeStart : _scheduledTimeEnd,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _scheduledTimeStart = picked;
          _scheduledTimeEnd = TimeOfDay(
            hour: (picked.hour + 1) % 24,
            minute: picked.minute,
          );
        } else {
          _scheduledTimeEnd = picked;
        }
        _timeError = _validateTimeOrder(_scheduledTimeStart, _scheduledTimeEnd);
        _vehicleError = null;
        _onTimeChanged(); // recalculate duration + refresh driver availability
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    _dateError = _validateDate(_scheduledDate);
    if (_dateError != null) {
      _showSnack(_dateError!, isError: true);
      setState(() {});
      return;
    }

    _timeError = _validateTimeOrder(_scheduledTimeStart, _scheduledTimeEnd);
    if (_timeError != null) {
      _showSnack(_timeError!, isError: true);
      setState(() {});
      return;
    }

    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final jobProvider = context.read<JobProvider>();

    if (!auth.hasPermission('jobs:create')) {
      _showSnack('You do not have permission to create jobs.', isError: true);
      return;
    }

    final techIds = _selectedDriverIds.toList();

    final created = await jobProvider.createJob(
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim(),
      customerAddress: _customerAddressController.text.trim(),
      jobType: _jobType,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      scheduledDate: _scheduledDate,
      scheduledTimeStart: _formatTime(_scheduledTimeStart),
      scheduledTimeEnd: _formatTime(_scheduledTimeEnd),
      estimatedDurationMinutes: int.tryParse(_durationController.text) ?? 60,
      priority: _priority,
      createdBy: auth.user?.id ?? AppConfig.defaultUserId,
      technicianIds: techIds, // ← pass selected drivers
    );

    if (!mounted) return;

    if (!created) {
      _handleAssignmentError(
        jobProvider.error ?? 'Failed to create job',
        context: 'create',
      );
      return;
    }

    // ── Job was created — now handle optional vehicle + driver assignment ──
    String? vehicleResult; // null = no vehicle chosen, 'ok', 'fail'
    String? vehicleError;

    if (_selectedVehicleId != null) {
      final newJob = jobProvider.allJobs.isNotEmpty
          ? jobProvider.allJobs.first
          : null;

      if (newJob == null) {
        vehicleResult = 'fail';
        vehicleError =
            'Could not find the new job to assign vehicle. Assign from Job Details.';
      } else {
        final assigned = await jobProvider.assignJob(
          jobId: newJob.id,
          vehicleId: _selectedVehicleId!,
          assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
        );

        if (!mounted) return;

        if (assigned) {
          vehicleResult = 'ok';
        } else {
          vehicleResult = 'fail';
          vehicleError = jobProvider.error ?? 'Vehicle assignment failed';

          // If it's a conflict error, show the detailed dialog and stay on screen
          final isConflict =
              vehicleError!.contains('409') ||
              vehicleError.toLowerCase().contains('conflict') ||
              vehicleError.toLowerCase().contains('already booked');
          if (isConflict) {
            _handleAssignmentError(vehicleError, context: 'assign');
            return; // stay on screen so user can pick a different vehicle
          }
        }
      }
    }

    if (!mounted) return;

    // ── Show creation summary dialog then pop ────────────────────────────
    await _showCreationSummaryDialog(
      techCount: techIds.length,
      vehicleResult: vehicleResult,
      vehicleError: vehicleError,
    );

    if (mounted) Navigator.pop(context);
  }

  // ── Summary dialog shown after successful job creation ────────────────
  // Clearly tells the scheduler:
  //   ✅ Job created
  //   ✅ / ⚠️  Vehicle status
  //   ✅ / —   Drivers status
  // If vehicle assignment failed (non-conflict), the dialog explains
  // the user can reassign from Job Details.
  Future<void> _showCreationSummaryDialog({
    required int techCount,
    required String? vehicleResult, // null | 'ok' | 'fail'
    required String? vehicleError,
  }) async {
    final rows = <_SummaryRow>[
      const _SummaryRow(
        icon: Icons.check_circle,
        color: AppTheme.successColor,
        text: 'Job created successfully',
      ),
    ];

    if (vehicleResult == 'ok') {
      rows.add(
        const _SummaryRow(
          icon: Icons.local_shipping,
          color: AppTheme.successColor,
          text: 'Vehicle assigned',
        ),
      );
    } else if (vehicleResult == 'fail') {
      rows.add(
        _SummaryRow(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warningColor,
          text:
              vehicleError ??
              'Vehicle assignment failed — assign from Job Details',
        ),
      );
    }

    if (techCount > 0) {
      rows.add(
        _SummaryRow(
          icon: Icons.group,
          color: AppTheme.successColor,
          text: '$techCount driver${techCount == 1 ? '' : 's'} assigned',
        ),
      );
    } else {
      rows.add(
        const _SummaryRow(
          icon: Icons.group_off_outlined,
          color: AppTheme.textHint,
          text: 'No drivers assigned — add from Job Details',
        ),
      );
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.task_alt, color: AppTheme.successColor, size: 22),
            SizedBox(width: 8),
            Text(
              'Job Created',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(row.icon, color: row.color, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          row.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: row.color == AppTheme.textHint
                                ? AppTheme.textSecondary
                                : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Parse backend conflict errors into the right UI feedback ────────
  //
  // The backend throws structured messages such as:
  //   "Driver scheduling conflict:\n   • John already assigned to: JOB-001 (09:00 - 11:00)"
  //
  // Three cases:
  //   1. Driver conflict  → refresh busy chips + show detail dialog
  //   2. Vehicle conflict → highlight vehicle field + snackbar hint
  //   3. Everything else  → plain snackbar
  void _handleAssignmentError(String error, {required String context}) {
    final isDriverConflict =
        error.toLowerCase().contains('driver scheduling conflict') ||
        error.toLowerCase().contains('already assigned to');

    final isVehicleConflict =
        error.contains('409') ||
        (error.toLowerCase().contains('vehicle') &&
            error.toLowerCase().contains('conflict')) ||
        error.toLowerCase().contains('already booked') ||
        error.toLowerCase().contains('time conflict detected');

    if (isDriverConflict) {
      // Refresh chip picker so newly-busy drivers are greyed out
      _fetchBusyDriverIds().then((busyIds) {
        if (mounted) {
          setState(() {
            _busyDriverIds = busyIds;
            _selectedDriverIds.removeAll(busyIds);
          });
        }
      });
      _showConflictDialog(
        title: 'Driver Already Booked',
        icon: Icons.person_off_outlined,
        rawMessage: error,
        hint: 'Deselect the conflicting driver(s) or choose a different time.',
      );
    } else if (isVehicleConflict) {
      setState(
        () => _vehicleError = context == 'assign'
            ? 'Vehicle has a conflicting job at this time'
            : 'This time slot is already booked for the selected vehicle',
      );
      _showSnack(
        context == 'assign'
            ? '⚠️ Job created but vehicle is booked at this time. Assign from job details.'
            : '⚠️ Vehicle is booked at this time. Choose a different vehicle or reschedule.',
        isError: true,
        duration: 6,
      );
    } else {
      _showSnack(
        error.replaceFirst('Exception: ', ''),
        isError: true,
        duration: 5,
      );
    }
  }

  // ── Detailed conflict dialog ──────────────────────────────────────────
  // Parses bullet-point lines from the backend error message and renders
  // each one as a card so the scheduler can see exactly what to fix.
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
            const Text(
              'The following drivers are already assigned to another job '
              'during this time window:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final jobProvider = context.watch<JobProvider>();
    final vehicleProvider = context.watch<VehicleProvider>();
    final vehicles = vehicleProvider.activeVehicles;

    if (!auth.hasPermission('jobs:create')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Create Job')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: AppTheme.textHint),
              SizedBox(height: 16),
              Text(
                'You do not have permission to create jobs.',
                style: TextStyle(color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.initialDate != null ? 'Schedule Job' : 'Create New Job',
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CUSTOMER ────────────────────────────────────────────
              _sectionTitle('Customer Details'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerNameController,
                label: 'Customer Name',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Customer name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerPhoneController,
                label: 'Phone Number (optional)',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _customerAddressController,
                label: 'Address',
                icon: Icons.location_on_outlined,
                maxLines: 2,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Address is required'
                    : null,
              ),
              const SizedBox(height: 24),

              // ── JOB DETAILS ─────────────────────────────────────────
              _sectionTitle('Job Details'),
              const SizedBox(height: 12),
              _buildDropdown<String>(
                label: 'Job Type',
                icon: Icons.work_outline,
                value: _jobType,
                items: const [
                  DropdownMenuItem(
                    value: 'installation',
                    child: Text('Installation'),
                  ),
                  DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                  DropdownMenuItem(
                    value: 'miscellaneous',
                    child: Text('Miscellaneous'),
                  ),
                ],
                onChanged: (v) => setState(() => _jobType = v!),
              ),
              const SizedBox(height: 12),
              _buildDropdown<String>(
                label: 'Priority',
                icon: Icons.flag_outlined,
                value: _priority,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (v) => setState(() => _priority = v!),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description (optional)',
                icon: Icons.notes_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // ── SCHEDULE ────────────────────────────────────────────
              _sectionTitle('Schedule'),
              const SizedBox(height: 12),
              _buildTappableField(
                label: 'Date',
                value: _formatDateDisplay(_scheduledDate),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
                errorText: _dateError,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTappableField(
                      label: 'Start Time',
                      value: _formatTimeDisplay(_scheduledTimeStart),
                      icon: Icons.access_time,
                      onTap: () => _pickTime(true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTappableField(
                      label: 'End Time',
                      value: _formatTimeDisplay(_scheduledTimeEnd),
                      icon: Icons.access_time_filled,
                      onTap: () => _pickTime(false),
                      errorText: _timeError,
                    ),
                  ),
                ],
              ),
              if (_timeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    _timeError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _durationController,
                label: 'Duration (minutes)',
                icon: Icons.timer_outlined,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Duration is required';
                  if (int.tryParse(v) == null) return 'Enter a valid number';
                  final d = int.parse(v);
                  if (d <= 0) return 'Duration must be positive';
                  if (d > 1440) return 'Duration cannot exceed 24 hours';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // ── VEHICLE ─────────────────────────────────────────────
              _sectionTitle('Vehicle (Optional)'),
              const SizedBox(height: 12),
              if (vehicleProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (vehicleProvider.error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'Error loading vehicles: ${vehicleProvider.error}',
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                )
              else if (vehicles.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No active vehicles available.',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                )
              else
                _buildVehicleDropdown(vehicles),
              if (_vehicleError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Text(
                    _vehicleError!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // ── ASSIGN DRIVERS ──────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _sectionTitle('Assign Drivers (Optional)')),
                  if (_driversLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Reload drivers',
                      onPressed: _loadDrivers,
                      color: AppTheme.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDriverSelector(),
              const SizedBox(height: 32),

              // ── SUBMIT ──────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: jobProvider.isLoading ? null : _submit,
                  icon: jobProvider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    jobProvider.isLoading ? 'Creating...' : 'Create Job',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Driver multi-select chip list ──────────────────────────────────────────
  Widget _buildDriverSelector() {
    if (_driversLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_driversError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_outlined,
              color: AppTheme.errorColor,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _driversError!,
                style: const TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(onPressed: _loadDrivers, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_availableDrivers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.textHint.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.person_off_outlined,
              color: AppTheme.textHint,
              size: 18,
            ),
            const SizedBox(width: 10),
            const Text(
              'No drivers available.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary line
          if (_selectedDriverIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 15,
                    color: AppTheme.successColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_selectedDriverIds.length} driver(s) selected',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() => _selectedDriverIds.clear()),
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Tap a driver to assign them to this job',
                style: TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
            ),

          // Driver chips — busy drivers are shown greyed-out and disabled.
          // The "Already booked" label and 0.45 opacity make it instantly
          // obvious why a driver cannot be selected.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableDrivers.map((driver) {
              final selected = _selectedDriverIds.contains(driver.id);
              final isBusy = _busyDriverIds.contains(driver.id);
              return Opacity(
                opacity: isBusy ? 0.45 : 1.0,
                child: Tooltip(
                  message: isBusy
                      ? '${driver.fullName} already has a job at this time'
                      : '',
                  child: FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: isBusy
                              ? AppTheme.textHint.withOpacity(0.3)
                              : selected
                              ? AppTheme.primaryColor
                              : AppTheme.textHint.withOpacity(0.2),
                          child: Text(
                            driver.fullName.isNotEmpty
                                ? driver.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 9,
                              color: selected && !isBusy
                                  ? Colors.white
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              driver.fullName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected && !isBusy
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isBusy
                                    ? AppTheme.textHint
                                    : selected
                                    ? AppTheme.primaryColor
                                    : AppTheme.textPrimary,
                              ),
                            ),
                            if (isBusy)
                              const Text(
                                'Already booked',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.errorColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    selected: selected && !isBusy,
                    showCheckmark: false,
                    onSelected: isBusy
                        ? null // disabled — cannot select a busy driver
                        : (val) => setState(() {
                            if (val) {
                              _selectedDriverIds.add(driver.id);
                            } else {
                              _selectedDriverIds.remove(driver.id);
                            }
                          }),
                    selectedColor: AppTheme.primaryColor.withOpacity(0.15),
                    backgroundColor: isBusy
                        ? AppTheme.textHint.withOpacity(0.05)
                        : AppTheme.backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isBusy
                            ? AppTheme.dividerColor
                            : selected
                            ? AppTheme.primaryColor
                            : AppTheme.dividerColor,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _buildVehicleDropdown(List<Vehicle> vehicles) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _vehicleError != null
              ? AppTheme.errorColor
              : AppTheme.dividerColor,
          width: _vehicleError != null ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedVehicleId,
                hint: const Text('Select vehicle (optional)'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None (assign later)'),
                  ),
                  ...vehicles.map(
                    (v) => DropdownMenuItem(
                      value: v.id,
                      child: Text('${v.vehicleName} (${v.licensePlate})'),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _selectedVehicleId = value;
                  _vehicleError = null;
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: AppTheme.textPrimary,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                items: items,
                onChanged: onChanged,
                isExpanded: true,
                hint: Text(label),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTappableField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: errorText != null
                    ? AppTheme.errorColor
                    : AppTheme.dividerColor,
                width: errorText != null ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: errorText != null
                              ? AppTheme.errorColor
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}
