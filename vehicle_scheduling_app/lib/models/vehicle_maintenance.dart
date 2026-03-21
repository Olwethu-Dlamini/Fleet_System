// ============================================
// FILE: lib/models/vehicle_maintenance.dart
// PURPOSE: Vehicle maintenance data model
// ============================================

class VehicleMaintenance {
  final int id;
  final int vehicleId;
  final String maintenanceType;
  final String? otherTypeDesc;
  final String status;
  final DateTime startDate;
  final DateTime endDate;
  final String? notes;
  final int createdBy;
  final String? vehicleName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VehicleMaintenance({
    required this.id,
    required this.vehicleId,
    required this.maintenanceType,
    this.otherTypeDesc,
    required this.status,
    required this.startDate,
    required this.endDate,
    this.notes,
    required this.createdBy,
    this.vehicleName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleMaintenance.fromJson(Map<String, dynamic> json) {
    return VehicleMaintenance(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      maintenanceType: json['maintenance_type'] as String,
      otherTypeDesc: json['other_type_desc'] as String?,
      status: json['status'] as String,
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as int,
      vehicleName: json['vehicle_name'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  /// Human-readable maintenance type
  String get typeDisplayName {
    switch (maintenanceType) {
      case 'service':
        return 'Service';
      case 'repair':
        return 'Repair';
      case 'inspection':
        return 'Inspection';
      case 'tyre_change':
        return 'Tyre Change';
      case 'other':
        return otherTypeDesc ?? 'Other';
      default:
        return maintenanceType;
    }
  }

  /// Human-readable status
  String get statusDisplayName {
    switch (status) {
      case 'scheduled':
        return 'Scheduled';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  /// Is the maintenance currently active (not completed)
  bool get isActive => status != 'completed';
}
