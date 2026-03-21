// ============================================
// FILE: lib/screens/jobs/create_job_screen.dart
//
// FIX (Bug 1): Driver assignment now works correctly after job creation.
//
// THE PROBLEM:
//   The old code passed technicianIds into jobProvider.createJob(), which
//   sent them in the POST /api/jobs body. The backend ignores that field —
//   it only creates the job record. So drivers were "selected" in the UI
//   but never actually written to the job_technicians DB table.
//   The success dialog said "2 drivers assigned" just because techIds.length
//   was > 0, without any confirmation from the server.
//
// THE FIX:
//   1. jobProvider.createJob() now returns Job? instead of bool.
//      We get the real new job object (with its database ID) back.
//   2. After the job is created, we call jobProvider.assignTechnicians()
//      separately with the confirmed job ID. This hits the dedicated
//      PUT /api/job-assignments/:jobId/technicians endpoint which
//      actually writes to job_technicians.
//   3. The summary dialog now only shows "drivers assigned" if the
//      assignTechnicians() call ACTUALLY SUCCEEDED (not just because
//      the user selected some chips).
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/services/user_service.dart';
import 'package:vehicle_scheduling_app/widgets/common/location_picker_popup.dart';
import 'package:vehicle_scheduling_app/widgets/job/driver_load_chip.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  double? _lat; // ← NEW
  double? _lng; // ← NEW

  String _jobType = 'installation';
  String _priority = 'normal';
  int? _selectedVehicleId;

  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTimeStart;
  late TimeOfDay _scheduledTimeEnd;

  String? _dateError;
  String? _timeError;
  String? _vehicleError;

  List<_DriverOption> _availableDrivers = [];
  final Set<int> _selectedDriverIds = {};
  Set<int> _busyDriverIds = {};
  bool _driversLoading = false;
  String? _driversError;

  // Driver load balancing state (Phase 03)
  String _loadRange = 'weekly';
  List<Map<String, dynamic>> _driverLoadData = [];
  bool _loadingDriverLoad = false;

  // Primary driver selection (single) and technician multi-select
  int? _selectedDriverId;
  final Set<int> _selectedTechnicianIds = {};
  String _techSearchQuery = '';

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
        _fetchDriverLoad();
      }
    });
  }

  Future<void> _fetchDriverLoad() async {
    setState(() => _loadingDriverLoad = true);
    try {
      final provider = Provider.of<JobProvider>(context, listen: false);
      await provider.fetchDriverLoad(range: _loadRange);
      if (mounted) {
        setState(() => _driverLoadData = provider.driverLoadStats);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDriverLoad = false);
  }

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
          _selectedDriverIds.removeAll(busyIds);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _driversError = 'Could not load drivers';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _driversLoading = false;
        });
      }
    }
  }

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
    } catch (_) {}
    return {};
  }

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
      _fetchBusyDriverIds().then((busyIds) {
        if (mounted) {
          setState(() {
            _busyDriverIds = busyIds;
            _selectedDriverIds.removeAll(busyIds);
          });
        }
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
      });
      _onTimeChanged();
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push<LocationPickerResult>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPopup(
          initialPosition: _lat != null && _lng != null 
              ? LatLng(_lat!, _lng!) 
              : null,
          initialAddress: _customerAddressController.text,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _customerAddressController.text = result.address;
        _lat = result.position.latitude;
        _lng = result.position.longitude;
      });
    }
  }

  // ══════════════════════════════════════════════════════════
  // SUBMIT
  //
  // FIX (Bug 1): The critical change is in this method.
  //
  // OLD flow:
  //   createJob(technicianIds: techIds) → bool
  //   // techIds were passed to the job creation POST — silently ignored
  //   // by backend, drivers never actually saved.
  //
  // NEW flow:
  //   1. createJob() → Job?  (no technicianIds in the POST)
  //   2. if newJob != null && vehicleId selected → assignJob(newJob.id)
  //   3. if newJob != null && techIds selected  → assignTechnicians(newJob.id)
  //      This is the DEDICATED PUT endpoint that actually writes to DB.
  //   4. Show summary dialog reflecting actual outcomes.
  // ══════════════════════════════════════════════════════════
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

    // Combine primary driver + technicians. Primary driver is sent via
    // assignJob() driverId. Technicians (excluding selected primary) go
    // through assignTechnicians().
    final techIds = _selectedTechnicianIds.toList();

    // ── STEP 1: Create the job ─────────────────────────────────────
    // createJob() now returns Job? — null means it failed.
    final newJob = await jobProvider.createJob(
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim().isEmpty
          ? null
          : _customerPhoneController.text.trim(),
      customerAddress: _customerAddressController.text.trim(),
      destinationLat: _lat, // ← NEW
      destinationLng: _lng, // ← NEW
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
      // NOTE: No technicianIds here. We handle it in step 3 below.
    );

    if (!mounted) return;

    if (newJob == null) {
      _handleAssignmentError(
        jobProvider.error ?? 'Failed to create job',
        errorContext: 'create',
      );
      return;
    }

    // ── STEP 2: Assign vehicle (optional) ──────────────────────────
    String? vehicleResult;
    String? vehicleError;

    if (_selectedVehicleId != null) {
      final assigned = await jobProvider.assignJob(
        jobId: newJob.id, // ← Safe: we have the real ID from the DB
        vehicleId: _selectedVehicleId!,
        driverId: _selectedDriverId,
        assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
      );

      if (!mounted) return;

      if (assigned) {
        vehicleResult = 'ok';
      } else {
        vehicleResult = 'fail';
        vehicleError = jobProvider.error ?? 'Vehicle assignment failed';

        final isConflict =
            vehicleError!.contains('409') ||
            vehicleError.toLowerCase().contains('conflict') ||
            vehicleError.toLowerCase().contains('already booked');
        if (isConflict) {
          _handleAssignmentError(vehicleError, errorContext: 'assign');
          return;
        }
      }
    }

    if (!mounted) return;

    // ── STEP 3: Assign drivers via the dedicated endpoint ──────────
    // This is the fix. We call assignTechnicians() with the real job ID.
    // The old code sent technicianIds in the createJob POST body which
    // the backend silently ignored. Now we use the correct PUT endpoint.
    int actualDriversAssigned = 0;
    String? driversError;

    if (techIds.isNotEmpty) {
      final driversAssigned = await jobProvider.assignTechnicians(
        jobId: newJob.id,
        technicianIds: techIds,
        assignedBy: auth.user?.id ?? AppConfig.defaultUserId,
        // No forceOverride on create — drivers were pre-filtered as available
      );

      if (!mounted) return;

      if (driversAssigned) {
        actualDriversAssigned = techIds.length;
      } else {
        driversError = jobProvider.error ?? 'Driver assignment failed';
        // Don't abort — job was created successfully, just show the warning
      }
    }

    if (!mounted) return;

    await _showCreationSummaryDialog(
      techCount: actualDriversAssigned, // ← Now reflects actual server result
      vehicleResult: vehicleResult,
      vehicleError: vehicleError,
      driversError: driversError,
    );

    if (mounted) Navigator.pop(context);
  }

  Future<void> _showCreationSummaryDialog({
    required int techCount,
    required String? vehicleResult,
    required String? vehicleError,
    String? driversError,
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

    if (driversError != null) {
      rows.add(
        _SummaryRow(
          icon: Icons.warning_amber_rounded,
          color: AppTheme.warningColor,
          text: 'Driver assignment failed — assign from Job Details',
        ),
      );
    } else if (techCount > 0) {
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

  void _handleAssignmentError(String error, {required String errorContext}) {
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
        () => _vehicleError = errorContext == 'assign'
            ? 'Vehicle has a conflicting job at this time'
            : 'This time slot is already booked for the selected vehicle',
      );
      _showSnack(
        errorContext == 'assign'
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
                  : 'The following drivers are already assigned to another job '
                        'during this time window:',
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.map_outlined, color: AppTheme.primaryColor),
                  onPressed: _pickLocation,
                  tooltip: 'Select on Map',
                ),
              ),
              const SizedBox(height: 24),

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

              Row(
                children: [
                  Expanded(child: _sectionTitle('Assign Personnel (Optional)')),
                  if (_loadingDriverLoad || _driversLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      tooltip: 'Reload drivers',
                      onPressed: () {
                        _loadDrivers();
                        _fetchDriverLoad();
                      },
                      color: AppTheme.textSecondary,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _buildDriverSelector(),
              const SizedBox(height: 32),

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

  Widget _buildDriverSelector() {
    // ── Range label helper ──────────────────────────────────────
    String rangeLabel() {
      switch (_loadRange) {
        case 'monthly':
          return 'this month';
        case 'yearly':
          return 'this year';
        default:
          return 'this week';
      }
    }

    // ── Technician search results ───────────────────────────────
    // Available technicians: all drivers minus the selected primary driver
    final techCandidates = _availableDrivers
        .where(
          (d) =>
              d.id != _selectedDriverId &&
              d.fullName.toLowerCase().contains(
                _techSearchQuery.toLowerCase(),
              ),
        )
        .toList();

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION: Primary Driver ────────────────────────────────
        const Text(
          'Primary Driver',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

        // Time range toggle (weekly / monthly / yearly)
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ButtonSegment(value: 'yearly', label: Text('Yearly')),
          ],
          selected: {_loadRange},
          onSelectionChanged: (newSet) {
            if (newSet.isNotEmpty) {
              setState(() {
                _loadRange = newSet.first;
                _selectedDriverId = null; // reset selection on range change
              });
              _fetchDriverLoad();
            }
          },
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12),
            ),
          ),
        ),
        const SizedBox(height: 8),

        if (_loadingDriverLoad)
          const Center(child: CircularProgressIndicator())
        else if (_driverLoadData.isEmpty)
          const Text(
            'No driver load data available.',
            style: TextStyle(color: AppTheme.textHint, fontSize: 13),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _driverLoadData.length,
            itemBuilder: (context, index) {
              final driver = _driverLoadData[index];
              return DriverLoadCard(
                driver: driver,
                isSelected: _selectedDriverId == (driver['id'] as int?),
                onTap: () {
                  setState(() {
                    final tappedId = driver['id'] as int?;
                    _selectedDriverId =
                        _selectedDriverId == tappedId ? null : tappedId;
                    // Remove from technicians if selected as primary
                    if (_selectedDriverId != null) {
                      _selectedTechnicianIds.remove(_selectedDriverId);
                    }
                  });
                },
                rangeLabel: rangeLabel(),
              );
            },
          ),

        const SizedBox(height: 20),

        // ── SECTION: Technicians ───────────────────────────────────
        const Text(
          'Technicians',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        // Selected technician chips with X to remove
        if (_selectedTechnicianIds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _selectedTechnicianIds.map((id) {
              final driver = _availableDrivers
                  .where((d) => d.id == id)
                  .firstOrNull;
              final name = driver?.fullName ?? 'Driver $id';
              return InputChip(
                label: Text(
                  name,
                  style: const TextStyle(fontSize: 13),
                ),
                onDeleted: () =>
                    setState(() => _selectedTechnicianIds.remove(id)),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                deleteIconColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

        // Technician search field
        TextFormField(
          decoration: InputDecoration(
            hintText: 'Search technicians...',
            prefixIcon: const Icon(Icons.search, size: 18),
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
              borderSide:
                  const BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (val) => setState(() => _techSearchQuery = val),
        ),

        // Technician search results
        if (_techSearchQuery.isNotEmpty && techCandidates.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Column(
              children: techCandidates
                  .where(
                    (d) => !_selectedTechnicianIds.contains(d.id),
                  )
                  .map(
                    (driver) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            AppTheme.primaryColor.withOpacity(0.15),
                        child: Text(
                          driver.fullName.isNotEmpty
                              ? driver.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      title: Text(
                        driver.fullName,
                        style: const TextStyle(fontSize: 13),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedTechnicianIds.add(driver.id);
                          _techSearchQuery = '';
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }

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
    Widget? suffixIcon, // ← NEW
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
        suffixIcon: suffixIcon, // ← NEW
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
