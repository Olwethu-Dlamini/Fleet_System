// ============================================
// FILE: lib/providers/vehicle_provider.dart
// PURPOSE: Vehicle state management
// CHANGE:  vehicleService getter added (public) so dashboard can inject token.
//          Everything else is your original structure.
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/models/vehicle.dart';
import 'package:vehicle_scheduling_app/services/vehicle_service.dart';
import 'package:vehicle_scheduling_app/services/offline_cache_service.dart';

class VehicleProvider extends ChangeNotifier {
  final VehicleService _vehicleService = VehicleService();
  final OfflineCacheService _cacheService = OfflineCacheService();

  // ==========================================
  // STATE
  // ==========================================
  List<Vehicle> _vehicles = [];
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;

  // ==========================================
  // GETTERS
  // ==========================================
  List<Vehicle> get vehicles => _vehicles;
  List<Vehicle> get activeVehicles =>
      _vehicles.where((v) => v.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;

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
      _isOffline = false;
      _isLoading = false;

      // Cache for offline use
      _cacheService.cacheVehicles(_vehicles.map((v) => v.toJson()).toList());
    } catch (e) {
      // API failed — try loading from offline cache
      final cached = await _cacheService.getCachedVehicles();
      if (cached.isNotEmpty) {
        _vehicles = cached.map((v) => Vehicle.fromJson(v)).toList();
        _isOffline = true;
        _isLoading = false;
        _error = null;
      } else {
        _error = e.toString();
        _isLoading = false;
      }
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
      _isOffline = false;
      _isLoading = false;

      // Cache for offline use
      _cacheService.cacheVehicles(_vehicles.map((v) => v.toJson()).toList());
    } catch (e) {
      // API failed — try loading from offline cache (filter active only)
      final cached = await _cacheService.getCachedVehicles();
      if (cached.isNotEmpty) {
        _vehicles = cached
            .map((v) => Vehicle.fromJson(v))
            .where((v) => v.isActive)
            .toList();
        _isOffline = true;
        _isLoading = false;
        _error = null;
      } else {
        _error = e.toString();
        _isLoading = false;
      }
    }
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
