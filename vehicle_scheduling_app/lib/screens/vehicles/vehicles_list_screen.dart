// ============================================
// FILE: lib/screens/vehicles/vehicles_list_screen.dart
// PURPOSE: Vehicles list — role-aware
//   admin      → full CRUD: add / edit / delete / toggle active
//   scheduler  → read-only (vehicle overview for job assignment context)
//   technician → read-only (basic info only)
//
// CHANGES:
//   • FAB opens _AddEditVehicleSheet (bottom-sheet form) for create
//   • Edit button on each card also opens _AddEditVehicleSheet (pre-filled)
//   • Long-press / delete icon on card: confirms then calls deleteVehicle
//   • Toggle active button on card: PUT is_active flip
//   • VehicleProvider gets inline createVehicle / updateVehicle / deleteVehicle
//     calls (no provider changes needed — all go through VehicleService)
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/vehicle_provider.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/services/vehicle_service.dart';

class VehiclesListScreen extends StatefulWidget {
  const VehiclesListScreen({super.key});

  @override
  State<VehiclesListScreen> createState() => _VehiclesListScreenState();
}

class _VehiclesListScreenState extends State<VehiclesListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) context.read<VehicleProvider>().loadVehicles();
    });
  }

  // ── Open the Add / Edit bottom sheet ──────────────────────────────────────
  Future<void> _openForm({Vehicle? vehicle}) async {
    final refreshed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddEditVehicleSheet(vehicle: vehicle),
    );
    if (refreshed == true && mounted) {
      context.read<VehicleProvider>().loadVehicles();
    }
  }

  // ── Delete with confirmation ───────────────────────────────────────────────
  Future<void> _confirmDelete(Vehicle vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Vehicle'),
        content: Text(
          'Remove "${vehicle.vehicleName}"?\n\n'
          'If the vehicle has existing job assignments it will be '
          'deactivated instead of deleted.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final service = context.read<VehicleProvider>().vehicleService;
      await service.deleteVehicle(vehicle.id);
      if (mounted) {
        context.read<VehicleProvider>().loadVehicles();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${vehicle.vehicleName} removed'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // ── Toggle active/inactive ────────────────────────────────────────────────
  Future<void> _toggleActive(Vehicle vehicle) async {
    final action = vehicle.isActive ? 'deactivate' : 'reactivate';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${action[0].toUpperCase()}${action.substring(1)} Vehicle'),
        content: Text(
          '${action[0].toUpperCase()}${action.substring(1)} "${vehicle.vehicleName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action[0].toUpperCase() + action.substring(1)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final service = context.read<VehicleProvider>().vehicleService;
      await service.updateVehicle(
        id: vehicle.id,
        updates: {'is_active': vehicle.isActive ? 0 : 1},
      );
      if (mounted) context.read<VehicleProvider>().loadVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleProvider = context.watch<VehicleProvider>();
    final auth = context.watch<AuthProvider>();
    final canManage = auth.hasPermission('vehicles:create');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Vehicles'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<VehicleProvider>().loadVehicles(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Role info banner
          if (!canManage)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.06),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    auth.isTechnician
                        ? 'Assigned vehicle information'
                        : 'Vehicle overview — contact admin to add or edit vehicles',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

          // Vehicle list
          Expanded(
            child: vehicleProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vehicleProvider.error != null
                ? _buildError(vehicleProvider.error!, context)
                : vehicleProvider.vehicles.isEmpty
                ? _buildEmpty(canManage)
                : RefreshIndicator(
                    onRefresh: () =>
                        context.read<VehicleProvider>().loadVehicles(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: vehicleProvider.vehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = vehicleProvider.vehicles[index];
                        final isActive = vehicle.isActive;
                        final iconColor = isActive
                            ? AppTheme.successColor
                            : AppTheme.errorColor;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Icon
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: iconColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Icon(
                                        Icons.local_shipping,
                                        color: iconColor,
                                        size: 28,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  vehicle.vehicleName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                              ),
                                              // Status pill
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: iconColor.withOpacity(
                                                    0.12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  vehicle.statusText,
                                                  style: TextStyle(
                                                    color: iconColor,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),

                                          // Plate + type
                                          Row(
                                            children: [
                                              _detailChip(
                                                Icons.badge_outlined,
                                                vehicle.licensePlate,
                                              ),
                                              const SizedBox(width: 12),
                                              _detailChip(
                                                Icons.category_outlined,
                                                vehicle.typeDisplayName,
                                              ),
                                            ],
                                          ),

                                          if (vehicle.capacityKg != null) ...[
                                            const SizedBox(height: 4),
                                            _detailChip(
                                              Icons.scale_outlined,
                                              '${vehicle.capacityKg!.toStringAsFixed(0)} kg capacity',
                                            ),
                                          ],

                                          if (vehicle.lastMaintenanceDate !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            _detailChip(
                                              Icons.build_outlined,
                                              'Last service: ${_fmtDate(vehicle.lastMaintenanceDate!)}',
                                            ),
                                          ],

                                          if (vehicle.notes != null &&
                                              vehicle.notes!.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            _detailChip(
                                              Icons.notes_outlined,
                                              vehicle.notes!,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                // Admin action row
                                if (canManage) ...[
                                  const SizedBox(height: 10),
                                  const Divider(height: 1),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      // Toggle active/inactive
                                      TextButton.icon(
                                        onPressed: () => _toggleActive(vehicle),
                                        icon: Icon(
                                          isActive
                                              ? Icons.pause_circle_outline
                                              : Icons.play_circle_outline,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isActive
                                              ? 'Deactivate'
                                              : 'Reactivate',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: isActive
                                              ? AppTheme.warningColor
                                              : AppTheme.successColor,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),

                                      // Edit
                                      TextButton.icon(
                                        onPressed: () =>
                                            _openForm(vehicle: vehicle),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Edit',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              AppTheme.primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                        ),
                                      ),

                                      // Delete
                                      TextButton.icon(
                                        onPressed: () =>
                                            _confirmDelete(vehicle),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Delete',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppTheme.errorColor,
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
                      },
                    ),
                  ),
          ),
        ],
      ),

      // FAB — admin only
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Vehicle'),
            )
          : null,
    );
  }

  String _fmtDate(DateTime d) {
    const m = [
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
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _detailChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildError(String error, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.read<VehicleProvider>().loadVehicles(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool canManage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 60,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'No vehicles found',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            canManage
                ? 'Tap + to add your first vehicle'
                : 'No vehicles have been added yet',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// _AddEditVehicleSheet  —  modal bottom sheet for create / edit
// ============================================================
class _AddEditVehicleSheet extends StatefulWidget {
  final Vehicle? vehicle;
  const _AddEditVehicleSheet({this.vehicle});

  @override
  State<_AddEditVehicleSheet> createState() => _AddEditVehicleSheetState();
}

class _AddEditVehicleSheetState extends State<_AddEditVehicleSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _capCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _vehicleType = 'van';
  bool _isSaving = false;
  String? _saveError;

  bool get _isEditing => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final v = widget.vehicle!;
      _nameCtrl.text = v.vehicleName;
      _plateCtrl.text = v.licensePlate;
      _vehicleType = v.vehicleType;
      _capCtrl.text = v.capacityKg != null
          ? v.capacityKg!.toStringAsFixed(0)
          : '';
      _notesCtrl.text = v.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _capCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final service = context.read<VehicleProvider>().vehicleService;
    final cap = _capCtrl.text.trim().isNotEmpty
        ? double.tryParse(_capCtrl.text.trim())
        : null;
    final notes = _notesCtrl.text.trim().isNotEmpty
        ? _notesCtrl.text.trim()
        : null;

    try {
      if (_isEditing) {
        await service.updateVehicle(
          id: widget.vehicle!.id,
          updates: {
            'vehicle_name': _nameCtrl.text.trim(),
            'license_plate': _plateCtrl.text.trim().toUpperCase(),
            'vehicle_type': _vehicleType,
            if (cap != null) 'capacity_kg': cap,
            'notes': notes,
          },
        );
      } else {
        await service.createVehicle(
          vehicleName: _nameCtrl.text.trim(),
          licensePlate: _plateCtrl.text.trim().toUpperCase(),
          vehicleType: _vehicleType,
          capacityKg: cap,
          notes: notes,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _saveError = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle + title
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                _isEditing ? 'Edit Vehicle' : 'Add New Vehicle',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Vehicle name
              _field(
                controller: _nameCtrl,
                label: 'Vehicle Name',
                icon: Icons.local_shipping_outlined,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              // License plate
              _field(
                controller: _plateCtrl,
                label: 'License Plate',
                icon: Icons.badge_outlined,
                inputType: TextInputType.text,
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'License plate is required'
                    : null,
              ),
              const SizedBox(height: 12),

              // Vehicle type dropdown
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _vehicleType,
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: 'van', child: Text('Van')),
                            DropdownMenuItem(
                              value: 'truck',
                              child: Text('Truck'),
                            ),
                            DropdownMenuItem(value: 'car', child: Text('Car')),
                          ],
                          onChanged: (v) => setState(() => _vehicleType = v!),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Capacity
              _field(
                controller: _capCtrl,
                label: 'Capacity (kg) — optional',
                icon: Icons.scale_outlined,
                inputType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (double.tryParse(v.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Notes
              _field(
                controller: _notesCtrl,
                label: 'Notes — optional',
                icon: Icons.notes_outlined,
                maxLines: 2,
              ),

              if (_saveError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
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
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _saveError!,
                          style: const TextStyle(
                            color: AppTheme.errorColor,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : (_isEditing ? 'Save Changes' : 'Add Vehicle'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      maxLines: maxLines,
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
      ),
    );
  }
}
