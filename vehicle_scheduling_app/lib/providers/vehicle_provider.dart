// ============================================
// FILE: lib/providers/vehicle_provider.dart
// PURPOSE: Vehicle state management
// CHANGE:  vehicleService getter added (public) so dashboard can inject token.
//          Everything else is your original structure.
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/services/vehicle_service.dart';

class VehicleProvider extends ChangeNotifier {
  final VehicleService _vehicleService = VehicleService();

  // ==========================================
  // STATE
  // ==========================================
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;

  // ==========================================
  // GETTERS
  // ==========================================
  List<Vehicle> get vehicles => _vehicles;
  List<Vehicle> get activeVehicles =>
      _vehicles.where((v) => v.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Expose service so AuthProvider can inject token:
  //   auth.injectToken(context.read<VehicleProvider>().vehicleService.apiService)
  VehicleService get vehicleService => _vehicleService;

  // ==========================================
  // LOAD VEHICLES
  // ==========================================
  Future<void> loadVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vehicles = await _vehicleService.getAllVehicles();
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  // ==========================================
  // GET ACTIVE VEHICLES
  // ==========================================
  Future<void> loadActiveVehicles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _vehicles = await _vehicleService.getActiveVehicles();
      _isLoading = false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
