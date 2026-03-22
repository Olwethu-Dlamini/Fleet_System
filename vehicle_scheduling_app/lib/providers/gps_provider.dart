// ============================================
// FILE: lib/providers/gps_provider.dart
// PURPOSE: GPS consent state management and 30-second location timer
// Requirements: GPS-02, GPS-06
// ============================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_scheduling_app/services/gps_service.dart';

class GpsProvider extends ChangeNotifier {
  // ── State ────────────────────────────────
  bool _consentChecked = false;
  bool _consentGranted = false;
  bool _gpsEnabled = false;
  bool _loading = false;
  Timer? _locationTimer;

  // ── Getters ──────────────────────────────
  bool get consentChecked => _consentChecked;
  bool get consentGranted => _consentGranted;
  bool get gpsEnabled => _gpsEnabled;
  bool get isLoading => _loading;
  bool get isTimerRunning => _locationTimer != null;

  /// True when we've finished checking and the user has not yet consented.
  bool get needsConsent => _consentChecked && !_consentGranted;

  // ==========================================
  // CHECK CONSENT
  // Reads SharedPreferences first as a fast cache, then refreshes
  // from the API. Sets _consentChecked = true after resolution.
  // ==========================================
  Future<void> checkConsent() async {
    if (_consentChecked) return;

    _loading = true;
    notifyListeners();

    try {
      // Fast path — SharedPreferences cache
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getBool('gps_consent_given') ?? false;

      if (cached) {
        // Optimistically mark as granted while we verify with API
        _consentGranted = true;
        _consentChecked = true;
        _loading = false;
        notifyListeners();
      }

      // Always verify with backend in background / foreground
      final record = await GpsService.getConsent();

      if (record == null) {
        // No consent record in DB — user has never consented
        _consentGranted = false;
        _gpsEnabled = false;
        _consentChecked = true;
        await prefs.setBool('gps_consent_given', false);
      } else {
        // Consent record exists — read gps_enabled flag
        _consentGranted = true;
        _gpsEnabled = record['gps_enabled'] == true ||
            record['gps_enabled'] == 1;
        _consentChecked = true;
        await prefs.setBool('gps_consent_given', true);

        if (_gpsEnabled && _locationTimer == null) {
          startLocationTimer();
        }
      }
    } catch (e) {
      // Network error — fall back to cache only
      _consentChecked = true;
      // ignore: avoid_print
      print('GpsProvider.checkConsent error: $e');
    }

    _loading = false;
    notifyListeners();
  }

  // ==========================================
  // GRANT CONSENT
  // First-time consent: POST /gps/consent with gps_enabled=true.
  // On success, starts the location timer.
  // ==========================================
  Future<bool> grantConsent() async {
    _loading = true;
    notifyListeners();

    try {
      final success = await GpsService.grantConsent();
      if (success) {
        _consentGranted = true;
        _gpsEnabled = true;
        _consentChecked = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('gps_consent_given', true);

        startLocationTimer();
        _loading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('GpsProvider.grantConsent error: $e');
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  // ==========================================
  // TOGGLE GPS
  // Turns GPS tracking on or off after initial consent is granted.
  // Calls GpsService.updateConsent() (PUT /gps/consent).
  // ==========================================
  Future<bool> toggleGps(bool enabled) async {
    _loading = true;
    notifyListeners();

    try {
      final success = await GpsService.updateConsent(enabled);
      if (success) {
        _gpsEnabled = enabled;
        if (enabled) {
          startLocationTimer();
        } else {
          stopLocationTimer();
        }
        _loading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // ignore: avoid_print
      print('GpsProvider.toggleGps error: $e');
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  // ==========================================
  // START LOCATION TIMER
  // Starts a 30-second periodic timer only when GPS is enabled and
  // no timer is already running. On each tick, checks working hours
  // (6AM-8PM), requests current position, and posts to the backend.
  // All errors are caught and logged — this is non-fatal background work.
  // ==========================================
  void startLocationTimer() {
    if (!_gpsEnabled) return;
    if (_locationTimer != null) return; // already running

    _locationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isWithinWorkingHours()) return;

      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        await GpsService.postLocation(
          lat: position.latitude,
          lng: position.longitude,
          accuracyM: position.accuracy,
        );
      } catch (e) {
        // Non-fatal — location errors should not surface to the user
        // ignore: avoid_print
        print('GpsProvider location timer error: $e');
      }
    });
  }

  // ==========================================
  // STOP LOCATION TIMER
  // Cancels the periodic timer and clears the reference.
  // ==========================================
  void stopLocationTimer() {
    _locationTimer?.cancel();
    _locationTimer = null;
  }

  // ==========================================
  // WORKING HOURS CHECK
  // Returns true if the current local time is between 6:00 AM and 8:00 PM.
  // Location updates outside working hours are suppressed to protect privacy.
  // ==========================================
  bool _isWithinWorkingHours() {
    final now = DateTime.now();
    return now.hour >= 6 && now.hour < 20;
  }

  // ==========================================
  // DISPOSE
  // Always stop the timer when the provider is removed from the tree.
  // ==========================================
  @override
  void dispose() {
    stopLocationTimer();
    super.dispose();
  }
}
