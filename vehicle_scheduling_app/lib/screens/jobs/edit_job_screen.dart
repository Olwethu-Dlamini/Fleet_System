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

  String? _dateError;
  String? _timeError;
  bool _saving = false;

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

    // FIX 1: 'miscellaneous' — lowercase, correctly spelled to match DB/backend
    const validJobTypes = ['installation', 'delivery', 'miscellaneous'];
    _jobType = validJobTypes.contains(j.jobType) ? j.jobType : 'installation';

    const validPriorities = ['low', 'normal', 'high', 'urgent'];
    _priority = validPriorities.contains(j.priority) ? j.priority : 'normal';

    _scheduledDate = j.scheduledDate;

    _scheduledTimeStart = _parseTime(j.scheduledTimeStart);
    _scheduledTimeEnd = _parseTime(j.scheduledTimeEnd);
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
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
