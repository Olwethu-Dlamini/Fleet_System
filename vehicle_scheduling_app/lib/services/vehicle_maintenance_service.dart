// ============================================
// FILE: lib/services/vehicle_maintenance_service.dart
// PURPOSE: CRUD for vehicle maintenance records
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/vehicle_maintenance.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class VehicleMaintenanceService {
  final ApiService apiService = ApiService();
  String get _endpoint => AppConfig.vehicleMaintenanceEndpoint;

  /// Get maintenance history for a specific vehicle
  Future<List<VehicleMaintenance>> getMaintenanceForVehicle(int vehicleId) async {
    final response = await apiService.get('$_endpoint?vehicle_id=$vehicleId');
    if (response['success'] == true) {
      return (response['maintenance'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(VehicleMaintenance.fromJson)
          .toList();
    }
    return [];
  }

  /// Get all currently active maintenance records
  Future<List<VehicleMaintenance>> getActiveMaintenance() async {
    final response = await apiService.get('$_endpoint/active');
    if (response['success'] == true) {
      return (response['maintenance'] as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(VehicleMaintenance.fromJson)
          .toList();
    }
    return [];
  }

  /// Schedule new maintenance
  Future<VehicleMaintenance> createMaintenance({
    required int vehicleId,
    required String maintenanceType,
    String? otherTypeDesc,
    required String startDate,
    required String endDate,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'vehicle_id': vehicleId,
      'maintenance_type': maintenanceType,
      'start_date': startDate,
      'end_date': endDate,
    };
    if (otherTypeDesc != null) data['other_type_desc'] = otherTypeDesc;
    if (notes != null && notes.isNotEmpty) data['notes'] = notes;

    final response = await apiService.post(_endpoint, data: data);
    if (response['success'] == true && response['maintenance'] != null) {
      return VehicleMaintenance.fromJson(
        response['maintenance'] as Map<String, dynamic>,
      );
    }
    throw Exception(response['message'] ?? 'Failed to schedule maintenance');
  }

  /// Update maintenance (status change, date change, etc.)
  Future<VehicleMaintenance> updateMaintenance(
    int id,
    Map<String, dynamic> updates,
  ) async {
    final response = await apiService.put('$_endpoint/$id', data: updates);
    if (response['success'] == true && response['maintenance'] != null) {
      return VehicleMaintenance.fromJson(
        response['maintenance'] as Map<String, dynamic>,
      );
    }
    throw Exception(response['message'] ?? 'Failed to update maintenance');
  }

  /// Cancel/complete maintenance (soft delete — sets status to completed)
  Future<void> deleteMaintenance(int id) async {
    final response = await apiService.delete('$_endpoint/$id');
    if (response['success'] != true) {
      throw Exception(response['message'] ?? 'Failed to cancel maintenance');
    }
  }
}
