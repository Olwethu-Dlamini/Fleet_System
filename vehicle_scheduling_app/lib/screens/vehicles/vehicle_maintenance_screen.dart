// ============================================
// FILE: lib/screens/vehicles/vehicle_maintenance_screen.dart
// PURPOSE: Schedule maintenance + view maintenance history
// ============================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/models/vehicle_maintenance.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/services/vehicle_maintenance_service.dart';

class VehicleMaintenanceScreen extends StatefulWidget {
  final Vehicle vehicle;

  const VehicleMaintenanceScreen({super.key, required this.vehicle});

  @override
  State<VehicleMaintenanceScreen> createState() =>
      _VehicleMaintenanceScreenState();
}

class _VehicleMaintenanceScreenState extends State<VehicleMaintenanceScreen> {
  final VehicleMaintenanceService _service = VehicleMaintenanceService();
  final _formKey = GlobalKey<FormState>();

  // Form state
  String _maintenanceType = 'service';
  final _otherDescCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _submitError;

  // History state
  List<VehicleMaintenance> _history = [];
  bool _loadingHistory = true;
  String? _historyError;

  static const List<Map<String, String>> _maintenanceTypes = [
    {'value': 'service', 'label': 'Service'},
    {'value': 'repair', 'label': 'Repair'},
    {'value': 'inspection', 'label': 'Inspection'},
    {'value': 'tyre_change', 'label': 'Tyre Change'},
    {'value': 'other', 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _otherDescCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final records =
          await _service.getMaintenanceForVehicle(widget.vehicle.id);
      setState(() {
        _history = records;
        _loadingHistory = false;
      });
    } catch (e) {
      setState(() {
        _historyError = e.toString();
        _loadingHistory = false;
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Reset end date if it's before the new start date
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final firstDate = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? firstDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null) {
      setState(() => _submitError = 'Please select a start date');
      return;
    }
    if (_endDate == null) {
      setState(() => _submitError = 'Please select an end date');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final fmt = DateFormat('yyyy-MM-dd');
      await _service.createMaintenance(
        vehicleId: widget.vehicle.id,
        maintenanceType: _maintenanceType,
        otherTypeDesc: _maintenanceType == 'other' &&
                _otherDescCtrl.text.trim().isNotEmpty
            ? _otherDescCtrl.text.trim()
            : null,
        startDate: fmt.format(_startDate!),
        endDate: fmt.format(_endDate!),
        notes: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Maintenance scheduled successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        // Reset form
        setState(() {
          _maintenanceType = 'service';
          _startDate = null;
          _endDate = null;
          _isSubmitting = false;
        });
        _otherDescCtrl.clear();
        _notesCtrl.clear();
        _formKey.currentState?.reset();
        _loadHistory();
      }
    } catch (e) {
      final message = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _submitError = message;
      });
    }
  }

  Future<void> _updateStatus(VehicleMaintenance record, String newStatus) async {
    try {
      await _service.updateMaintenance(record.id, {'status': newStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${newStatus.replaceAll('_', ' ')}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canCreate = auth.hasPermission('maintenance:create');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text('${widget.vehicle.vehicleName} — Maintenance'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Schedule New section ──────────────────────
            if (canCreate) ...[
              _sectionHeader('Schedule New Maintenance'),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Maintenance type dropdown
                        DropdownButtonFormField<String>(
                          value: _maintenanceType,
                          decoration: _inputDecoration(
                            'Maintenance Type',
                            Icons.build_outlined,
                          ),
                          items: _maintenanceTypes
                              .map(
                                (t) => DropdownMenuItem<String>(
                                  value: t['value']!,
                                  child: Text(t['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _maintenanceType = v!),
                          validator: (v) =>
                              v == null ? 'Select a type' : null,
                        ),
                        const SizedBox(height: 12),

                        // Other description (shown only for 'other')
                        if (_maintenanceType == 'other') ...[
                          TextFormField(
                            controller: _otherDescCtrl,
                            decoration: _inputDecoration(
                              'Describe maintenance type',
                              Icons.notes_outlined,
                            ),
                            validator: (v) =>
                                _maintenanceType == 'other' &&
                                        (v == null || v.trim().isEmpty)
                                    ? 'Please describe the maintenance type'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Start date picker
                        _DatePickerField(
                          label: 'Start Date',
                          date: _startDate,
                          onTap: _pickStartDate,
                        ),
                        const SizedBox(height: 12),

                        // End date picker
                        _DatePickerField(
                          label: 'End Date',
                          date: _endDate,
                          onTap: _pickEndDate,
                          enabled: _startDate != null,
                        ),
                        const SizedBox(height: 12),

                        // Notes
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: _inputDecoration(
                            'Notes (optional)',
                            Icons.comment_outlined,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Error message
                        if (_submitError != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.errorColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: AppTheme.errorColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _submitError!,
                                    style: const TextStyle(
                                      color: AppTheme.errorColor,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Submit button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitForm,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.schedule),
                            label: Text(
                              _isSubmitting ? 'Scheduling...' : 'Schedule Maintenance',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── History section ──────────────────────────
            _sectionHeader('Maintenance History'),
            const SizedBox(height: 12),
            _buildHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (_loadingHistory) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_historyError != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
            const SizedBox(height: 8),
            Text(_historyError!),
            TextButton.icon(
              onPressed: _loadHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.build_circle_outlined,
                  size: 48, color: AppTheme.textHint),
              const SizedBox(height: 12),
              const Text(
                'No maintenance records',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _MaintenanceCard(
        record: _history[i],
        onStatusChange: _updateStatus,
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
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
    );
  }
}

// ============================================================
// _DatePickerField — tappable date display field
// ============================================================
class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final bool enabled;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AbsorbPointer(
        child: TextFormField(
          readOnly: true,
          enabled: enabled,
          controller: TextEditingController(
            text: date != null ? fmt.format(date!) : '',
          ),
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            hintText: enabled ? 'Tap to select date' : 'Select start date first',
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
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
          ),
          validator: (_) => date == null && enabled ? 'Please select a date' : null,
        ),
      ),
    );
  }
}

// ============================================================
// _MaintenanceCard — displays a single maintenance record
// ============================================================
class _MaintenanceCard extends StatelessWidget {
  final VehicleMaintenance record;
  final Future<void> Function(VehicleMaintenance, String) onStatusChange;

  const _MaintenanceCard({
    required this.record,
    required this.onStatusChange,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'scheduled':
        return Colors.green.shade600;
      case 'in_progress':
        return Colors.orange.shade700;
      case 'completed':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final statusColor = _statusColor(record.status);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.typeDisplayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record.statusDisplayName,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.date_range_outlined,
                  size: 14,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${fmt.format(record.startDate)} - ${fmt.format(record.endDate)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_outlined,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      record.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            // Status change action
            if (record.status == 'scheduled' || record.status == 'in_progress') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (record.status == 'scheduled')
                    TextButton.icon(
                      onPressed: () => onStatusChange(record, 'in_progress'),
                      icon: const Icon(Icons.play_arrow_outlined, size: 15),
                      label: const Text(
                        'Start',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                  if (record.status == 'in_progress')
                    TextButton.icon(
                      onPressed: () => onStatusChange(record, 'completed'),
                      icon: const Icon(Icons.check_circle_outline, size: 15),
                      label: const Text(
                        'Complete',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.successColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
