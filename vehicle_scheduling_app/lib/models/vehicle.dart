// ============================================
// FILE: lib/models/vehicle.dart
// PURPOSE: Vehicle data model
// ============================================

class Vehicle {
  final int id;
  final String vehicleName;
  final String licensePlate;
  final String vehicleType;
  final double? capacityKg;
  final bool isActive;
  final bool isInMaintenance;
  final DateTime? lastMaintenanceDate;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.vehicleName,
    required this.licensePlate,
    required this.vehicleType,
    this.capacityKg,
    required this.isActive,
    this.isInMaintenance = false,
    this.lastMaintenanceDate,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  // ==========================================
  // FROM JSON - Convert API response to Vehicle object
  // ==========================================
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      vehicleName: json['vehicle_name'] as String,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String,
      capacityKg: json['capacity_kg'] != null
          ? double.parse(json['capacity_kg'].toString())
          : null,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isInMaintenance: json['is_in_maintenance'] == 1 || json['is_in_maintenance'] == true,
      lastMaintenanceDate: json['last_maintenance_date'] != null
          ? DateTime.parse(json['last_maintenance_date'])
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // ==========================================
  // TO JSON - Convert Vehicle object to API format
  // ==========================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_name': vehicleName,
      'license_plate': licensePlate,
      'vehicle_type': vehicleType,
      'capacity_kg': capacityKg,
      'is_active': isActive ? 1 : 0,
      'is_in_maintenance': isInMaintenance ? 1 : 0,
      'last_maintenance_date': lastMaintenanceDate?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // ==========================================
  // HELPER METHODS
  // ==========================================

  /// Get status text
  String get statusText => isActive ? 'Active' : 'Inactive';

  /// Get vehicle type display name
  String get typeDisplayName {
    switch (vehicleType.toLowerCase()) {
      case 'van':
        return 'Van';
      case 'truck':
        return 'Truck';
      case 'car':
        return 'Car';
      default:
        return vehicleType;
    }
  }

  /// Copy with method for updates
  Vehicle copyWith({
    int? id,
    String? vehicleName,
    String? licensePlate,
    String? vehicleType,
    double? capacityKg,
    bool? isActive,
    bool? isInMaintenance,
    DateTime? lastMaintenanceDate,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Vehicle(
      id: id ?? this.id,
      vehicleName: vehicleName ?? this.vehicleName,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      capacityKg: capacityKg ?? this.capacityKg,
      isActive: isActive ?? this.isActive,
      isInMaintenance: isInMaintenance ?? this.isInMaintenance,
      lastMaintenanceDate: lastMaintenanceDate ?? this.lastMaintenanceDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, name: $vehicleName, plate: $licensePlate, type: $vehicleType, active: $isActive)';
  }
}
