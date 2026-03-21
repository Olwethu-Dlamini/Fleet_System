// ============================================
// FILE: lib/services/vehicle_service.dart
// CHANGES:
//   • Added createVehicle()  — POST /api/vehicles
//   • Added updateVehicle()  — PUT /api/vehicles/:id
//   • Added deleteVehicle()  — DELETE /api/vehicles/:id
//   All write methods are admin-only; backend enforces the role guard.
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class VehicleService {
  final ApiService apiService = ApiService();

  // ══════════════════════════════════════════
  // GET ALL VEHICLES
  // ══════════════════════════════════════════
  Future<List<Vehicle>> getAllVehicles({bool? activeOnly}) async {
    try {
      String endpoint = AppConfig.vehiclesEndpoint;
      if (activeOnly == true) endpoint += '?activeOnly=true';
      final response = await apiService.get(endpoint);
      if (response['success'] == true && response['data'] != null) {
        return (response['data'] as List<dynamic>)
            .map((j) => Vehicle.fromJson(j))
            .toList();
      }
      return [];
    } catch (e) {
      print('VehicleService.getAllVehicles error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════
  // GET VEHICLE BY ID
  // ══════════════════════════════════════════
  Future<Vehicle?> getVehicleById(int id) async {
    try {
      final response = await apiService.get(
        '${AppConfig.vehiclesEndpoint}/$id',
      );
      if (response['success'] == true && response['data'] != null) {
        return Vehicle.fromJson(response['data']);
      }
      return null;
    } catch (e) {
      print('VehicleService.getVehicleById error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════
  // GET ACTIVE VEHICLES
  // ══════════════════════════════════════════
  Future<List<Vehicle>> getActiveVehicles() => getAllVehicles(activeOnly: true);

  // ══════════════════════════════════════════
  // CREATE VEHICLE  ← ADMIN ONLY
  // POST /api/vehicles
  // ══════════════════════════════════════════
  Future<Vehicle> createVehicle({
    required String vehicleName,
    required String licensePlate,
    required String vehicleType, // 'van' | 'truck' | 'car'
    double? capacityKg,
    String? notes,
  }) async {
    try {
      final data = <String, dynamic>{
        'vehicle_name': vehicleName,
        'license_plate': licensePlate,
        'vehicle_type': vehicleType,
        if (capacityKg != null) 'capacity_kg': capacityKg,
        if (notes != null) 'notes': notes,
      };
      final response = await apiService.post(
        AppConfig.vehiclesEndpoint,
        data: data,
      );
      if (response['success'] == true && response['data'] != null) {
        return Vehicle.fromJson(response['data']);
      }
      throw Exception(
        response['message'] ?? response['error'] ?? 'Create vehicle failed',
      );
    } catch (e) {
      print('VehicleService.createVehicle error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════
  // UPDATE VEHICLE  ← ADMIN ONLY
  // PUT /api/vehicles/:id
  // Pass any subset of Vehicle fields.
  // ══════════════════════════════════════════
  Future<Vehicle> updateVehicle({
    required int id,
    required Map<String, dynamic> updates,
  }) async {
    try {
      final response = await apiService.put(
        '${AppConfig.vehiclesEndpoint}/$id',
        data: updates,
      );
      if (response['success'] == true && response['data'] != null) {
        return Vehicle.fromJson(response['data']);
      }
      throw Exception(
        response['message'] ?? response['error'] ?? 'Update vehicle failed',
      );
    } catch (e) {
      print('VehicleService.updateVehicle error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════
  // DELETE VEHICLE  ← ADMIN ONLY
  // DELETE /api/vehicles/:id
  // (backend soft-deletes if assignments exist)
  // ══════════════════════════════════════════
  Future<void> deleteVehicle(int id) async {
    try {
      await apiService.delete('${AppConfig.vehiclesEndpoint}/$id');
    } catch (e) {
      print('VehicleService.deleteVehicle error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════
  // SWAP VEHICLE ON JOB  ← SCHED-02
  // PUT /api/jobs/:jobId/swap-vehicle
  // ══════════════════════════════════════════
  Future<Map<String, dynamic>> swapVehicle(
    int jobId,
    int newVehicleId, {
    String? note,
  }) async {
    try {
      final data = <String, dynamic>{'new_vehicle_id': newVehicleId};
      if (note != null && note.isNotEmpty) data['note'] = note;
      // AppConfig.jobsEndpoint is a pre-existing getter ('/jobs')
      final response = await apiService.put(
        '${AppConfig.jobsEndpoint}/$jobId/swap-vehicle',
        data: data,
      );
      if (response['success'] == true) return response;
      throw Exception(response['message'] ?? 'Failed to swap vehicle');
    } catch (e) {
      print('VehicleService.swapVehicle error: $e');
      rethrow;
    }
  }
}
