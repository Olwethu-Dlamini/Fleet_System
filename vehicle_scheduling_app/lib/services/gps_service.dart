// ============================================
// FILE: lib/services/gps_service.dart
// PURPOSE: GPS API calls — directions, location updates, consent, driver tracking
// Requirements: GPS-01, GPS-02, GPS-03, GPS-04, GPS-07
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class GpsService {
  static final ApiService _api = ApiService();

  // ==========================================
  // GET DIRECTIONS
  // Fetches route polyline, ETA, and distance via backend proxy.
  // Returns the 'directions' object from the response, or null on error.
  // ==========================================
  static Future<Map<String, dynamic>?> getDirections(
    int jobId, {
    double? originLat,
    double? originLng,
  }) async {
    try {
      String endpoint = '${AppConfig.gpsDirectionsEndpoint}?job_id=$jobId';
      if (originLat != null && originLng != null) {
        endpoint += '&origin_lat=$originLat&origin_lng=$originLng';
      }
      final response = await _api.get(endpoint);
      if (response['success'] == true) {
        return response['directions'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // POST LOCATION
  // Driver posts their current GPS position.
  // Non-fatal — returns false on error without throwing.
  // ==========================================
  static Future<bool> postLocation({
    required double lat,
    required double lng,
    double? accuracyM,
  }) async {
    try {
      final body = <String, dynamic>{
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
      };
      final response = await _api.post(AppConfig.gpsLocationEndpoint, data: body);
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // GET CONSENT
  // Returns the current user's GPS consent record, or null.
  // ==========================================
  static Future<Map<String, dynamic>?> getConsent() async {
    try {
      final response = await _api.get(AppConfig.gpsConsentEndpoint);
      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // ==========================================
  // GRANT CONSENT
  // First-time consent: POST /gps/consent
  // ==========================================
  static Future<bool> grantConsent() async {
    try {
      final response = await _api.post(
        AppConfig.gpsConsentEndpoint,
        data: {'gps_enabled': true},
      );
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // UPDATE CONSENT
  // Toggle GPS consent on/off: PUT /gps/consent
  // ==========================================
  static Future<bool> updateConsent(bool enabled) async {
    try {
      final response = await _api.put(
        AppConfig.gpsConsentEndpoint,
        data: {'gps_enabled': enabled},
      );
      return response['success'] == true;
    } catch (_) {
      return false;
    }
  }

  // ==========================================
  // GET DRIVER LOCATIONS
  // Admin/scheduler only — live driver positions.
  // Returns an empty list on error.
  // ==========================================
  static Future<List<Map<String, dynamic>>> getDriverLocations() async {
    try {
      final response = await _api.get(AppConfig.gpsDriversEndpoint);
      if (response['success'] == true) {
        final data = response['data'];
        if (data is List) {
          return data.whereType<Map<String, dynamic>>().toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
