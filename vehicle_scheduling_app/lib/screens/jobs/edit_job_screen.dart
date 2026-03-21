// ============================================
// FILE: lib/screens/jobs/edit_job_screen.dart
// PURPOSE: Edit an existing job — admin + scheduler only
// ACCESS: jobs:create permission (same gate as create)
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/services/job_service.dart';
import 'package:vehicle_scheduling_app/services/user_service.dart';
import 'package:vehicle_scheduling_app/widgets/common/location_picker_popup.dart';
import 'package:vehicle_scheduling_app/widgets/job/driver_load_chip.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class _DriverOption {
  final int id;
  final String fullName;
  const _DriverOption({required this.id, required this.fullName});

  factory _DriverOption.fromJson(Map<String, dynamic> j) => _DriverOption(
    id: j['id'] as int,
    fullName: (j['full_name'] ?? j['fullName'] ?? '').toString(),
  );
}

class EditJobScreen extends StatefulWidget {
  final Job job;
  const EditJobScreen({super.key, required this.job});

  @override
  State<EditJobScreen> createState() => _EditJobScreenState();
}

class _EditJobScreenState extends State<EditJobScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _customerNameController;
  late TextEditingController _customerPhoneController;
  late TextEditingController _customerAddressController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;

  late String _jobType;
  late String _priority;
  late DateTime _scheduledDate;
  late TimeOfDay _scheduledTimeStart;
  late TimeOfDay _scheduledTimeEnd;

  double? _lat; // ← NEW
  double? _lng; // ← NEW

  String? _dateError;
  String? _timeError;
  bool _saving = false;

  // Driver load balancing state (Phase 03)
  String _loadRange = 'weekly';
  List<Map<String, dynamic>> _driverLoadData = [];
  bool _loadingDriverLoad = false;
  int? _selectedDriverId;
  final Set<int> _selectedTechnicianIds = {};
  String _techSearchQuery = '';
  List<_DriverOption> _availableDrivers = [];

  @override
  void initState() {
    super.initState();
    final j = widget.job;

    _customerNameController = TextEditingController(text: j.customerName);
    _customerPhoneController = TextEditingController(
      text: j.customerPhone ?? '',
    );
    _customerAddressController = TextEditingController(text: j.customerAddress);
    _descriptionController = TextEditingController(text: j.description ?? '');
    _durationController = TextEditingController(
      text: j.estimatedDurationMinutes.toString(),
    );

    _lat = j.destinationLat; // ← NEW
    _lng = j.destinationLng; // ← NEW

    // FIX 1: 'miscellaneous' — lowercase, correctly spelled to match DB/backend
    const validJobTypes = ['installation', 'delivery', 'miscellaneous'];
    _jobType = validJobTypes.contains(j.jobType) ? j.jobType : 'installation';

    const validPriorities = ['low', 'normal', 'high', 'urgent'];
    _priority = validPriorities.contains(j.priority) ? j.priority : 'normal';

    _scheduledDate = j.scheduledDate;

    _scheduledTimeStart = _parseTime(j.scheduledTimeStart);
    _scheduledTimeEnd = _parseTime(j.scheduledTimeEnd);

    // Pre-populate selected driver and technicians from existing job data
    _selectedDriverId = j.driverId;
    _selectedTechnicianIds.addAll(j.technicians.map((t) => t.id));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAvailableDrivers();
        _fetchDriverLoad();
      }
    });
  }

  Future<void> _loadAvailableDrivers() async {
    try {
      final users = await UserService().getUsers(role: 'technician');
      if (mounted) {
        setState(() {
          _availableDrivers =
              users.map((u) => _DriverOption(id: u.id, fullName: u.fullName)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchDriverLoad() async {
    if (!mounted) return;
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

  TimeOfDay _parseTime(String? t) {
    if (t == null || t.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    final parts = t.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
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

  String? _validateTimeOrder(TimeOfDay start, TimeOfDay end) {
    final s = start.hour * 60 + start.minute;
    final e = end.hour * 60 + end.minute;
    if (e <= s) return 'End time must be after start time';
    return null;
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    // FIX 2: firstDate allows the job's own existing date so past-dated jobs
    // can still be edited without being forced to pick a future date.
    final earliest = _scheduledDate.isBefore(today) ? _scheduledDate : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: earliest,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _scheduledDate = picked);
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
      });
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    _timeError = _validateTimeOrder(_scheduledTimeStart, _scheduledTimeEnd);
    if (_timeError != null) {
      setState(() {});
      _showSnack(_timeError!, isError: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final jobService = JobService();
      await jobService.updateJob(
        jobId: widget.job.id,
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
      );

      if (!mounted) return;

      final auth = context.read<AuthProvider>();
      final jobProvider = context.read<JobProvider>();
      if (auth.isTechnician) {
        await jobProvider.loadMyJobs();
      } else {
        await jobProvider.loadJobs();
      }

      if (!mounted) return;
      // FIX 3: reset _saving before popping so the button isn't stuck if pop
      // is somehow deferred or the widget stays in the tree.
      setState(() => _saving = false);
      _showSnack('Job updated successfully!');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _handleAssignmentError(e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _handleAssignmentError(String error) {
    final isDriverConflict =
        error.toLowerCase().contains('driver scheduling conflict') ||
        error.toLowerCase().contains('already assigned to');

    if (isDriverConflict) {
      _showConflictDialog(
        title: 'Schedule Change Blocked — Driver Conflict',
        icon: Icons.person_off_outlined,
        rawMessage: error,
        hint:
            'Choose a different time, or remove the conflicting driver '
            'from this job first (via Job Details → Manage Drivers).',
      );
    } else {
      _showSnack(error, isError: true);
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
            // FIX 4: if no structured conflict lines, fall back to showing
            // the raw message so the dialog is never empty/misleading.
            Text(
              conflictLines.isEmpty
                  ? rawMessage
                  : 'The new time window conflicts with an existing assignment '
                        'for the following driver(s):',
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

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
  }

  Widget _buildDriverSelector() {
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

    final techCandidates = _availableDrivers
        .where(
          (d) =>
              d.id != _selectedDriverId &&
              d.fullName.toLowerCase().contains(
                _techSearchQuery.toLowerCase(),
              ),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Primary Driver ────────────────────────────────────
        const Text(
          'Primary Driver',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),

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
                _selectedDriverId = null;
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

        // ── Technicians ───────────────────────────────────────
        const Text(
          'Technicians',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 8),

        if (_selectedTechnicianIds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _selectedTechnicianIds.map((id) {
              final driver =
                  _availableDrivers.where((d) => d.id == id).firstOrNull;
              final name = driver?.fullName ?? 'Driver $id';
              return InputChip(
                label: Text(name, style: const TextStyle(fontSize: 13)),
                onDeleted: () =>
                    setState(() => _selectedTechnicianIds.remove(id)),
                backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                deleteIconColor: AppTheme.primaryColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
        ],

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
                  .where((d) => !_selectedTechnicianIds.contains(d.id))
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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.hasPermission('jobs:create')) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Job')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 60, color: AppTheme.textHint),
              SizedBox(height: 16),
              Text(
                'You do not have permission to edit jobs.',
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
        title: Text('Edit ${widget.job.jobNumber}'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── CUSTOMER ──────────────────────────────────────────
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
              if (_lat != null && _lng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed, size: 14, color: AppTheme.successColor),
                      const SizedBox(width: 6),
                      Text(
                        'Location coordinates captured: ${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() {
                          _lat = null;
                          _lng = null;
                        }),
                        child: const Icon(Icons.cancel, size: 16, color: AppTheme.textHint),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // ── JOB DETAILS ───────────────────────────────────────
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
                  // FIX 1: corrected spelling + lowercase to match backend
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

              // ── SCHEDULE ──────────────────────────────────────────
              _sectionTitle('Schedule'),
              const SizedBox(height: 12),
              _buildTappableField(
                label: 'Date',
                value: _formatDateDisplay(_scheduledDate),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDate,
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

              // ── DRIVER ASSIGNMENT (load-balanced) ─────────────────
              _sectionTitle('Assign Personnel (Optional)'),
              const SizedBox(height: 12),
              _buildDriverSelector(),
              const SizedBox(height: 32),

              // ── SAVE BUTTON ───────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
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
                    _saving ? 'Saving...' : 'Save Changes',
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

  // ── Widget helpers ─────────────────────────────────────────────────────────

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
    Widget? suffixIcon, // ← NEW
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
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
    return GestureDetector(
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
    );
  }
}
