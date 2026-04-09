// ============================================
// FILE: lib/services/offline_cache_service.dart
// PURPOSE: Offline caching for jobs and vehicles data
//          using SharedPreferences and JSON serialization.
//
// USAGE:
//   await OfflineCacheService().cacheJobs(jobsList);
//   final cached = await OfflineCacheService().getCachedJobs();
// ============================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineCacheService {
  // Singleton — one instance for the whole app
  static final OfflineCacheService _instance = OfflineCacheService._internal();
  factory OfflineCacheService() => _instance;
  OfflineCacheService._internal();

  // SharedPreferences keys
  static const String _cachedJobsKey = 'cached_jobs';
  static const String _cachedVehiclesKey = 'cached_vehicles';
  static const String _cacheTimestampKey = 'cache_timestamp';

  // ==========================================
  // CACHE JOBS
  // ==========================================
  /// Serializes a list of job maps to JSON and stores them.
  /// Call after a successful API fetch:
  ///   OfflineCacheService().cacheJobs(allJobs.map((j) => j.toJson()).toList())
  Future<void> cacheJobs(List<dynamic> jobs) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(jobs);
    await prefs.setString(_cachedJobsKey, encoded);
    await _updateTimestamp(prefs);
  }

  // ==========================================
  // GET CACHED JOBS
  // ==========================================
  /// Returns the cached jobs list, or an empty list if nothing is cached.
  Future<List<Map<String, dynamic>>> getCachedJobs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedJobsKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('OfflineCacheService: failed to decode cached jobs: $e');
      return [];
    }
  }

  // ==========================================
  // CACHE VEHICLES
  // ==========================================
  /// Serializes a list of vehicle maps to JSON and stores them.
  Future<void> cacheVehicles(List<dynamic> vehicles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(vehicles);
    await prefs.setString(_cachedVehiclesKey, encoded);
    await _updateTimestamp(prefs);
  }

  // ==========================================
  // GET CACHED VEHICLES
  // ==========================================
  /// Returns the cached vehicles list, or an empty list if nothing is cached.
  Future<List<Map<String, dynamic>>> getCachedVehicles() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cachedVehiclesKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      print('OfflineCacheService: failed to decode cached vehicles: $e');
      return [];
    }
  }

  // ==========================================
  // GET LAST SYNC TIME
  // ==========================================
  /// Returns the DateTime of the last successful cache write,
  /// or null if no data has been cached yet.
  Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_cacheTimestampKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  // ==========================================
  // CLEAR CACHE
  // ==========================================
  /// Removes all cached data (jobs, vehicles, timestamp).
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cachedJobsKey);
    await prefs.remove(_cachedVehiclesKey);
    await prefs.remove(_cacheTimestampKey);
  }

  // ==========================================
  // PRIVATE: update timestamp
  // ==========================================
  Future<void> _updateTimestamp(SharedPreferences prefs) async {
    await prefs.setInt(
      _cacheTimestampKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
