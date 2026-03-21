// ============================================
// FILE: lib/providers/time_extension_provider.dart
// PURPOSE: ChangeNotifier state for time extension request + approval flow
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/models/time_extension.dart';
import 'package:vehicle_scheduling_app/services/time_extension_service.dart';

class TimeExtensionProvider extends ChangeNotifier {
  final TimeExtensionService _service = TimeExtensionService();

  TimeExtensionRequest? _activeRequest;
  List<RescheduleOption> _suggestions = [];
  List<AffectedJob> _affectedJobs = [];
  bool _loading = false;
  String? _error;

  // ── Getters ───────────────────────────────────────────────────────────────
  TimeExtensionRequest? get activeRequest => _activeRequest;
  List<RescheduleOption> get suggestions => List.unmodifiable(_suggestions);
  List<AffectedJob> get affectedJobs => List.unmodifiable(_affectedJobs);
  bool get isLoading => _loading;
  String? get error => _error;

  // ── submitRequest ─────────────────────────────────────────────────────────
  /// Submits a new time extension request for a job.
  /// Returns true on success, false on failure (error set via [error]).
  Future<bool> submitRequest({
    required int jobId,
    required int durationMinutes,
    required String reason,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.createRequest(
        jobId: jobId,
        durationMinutes: durationMinutes,
        reason: reason,
      );

      _activeRequest = result['request'] as TimeExtensionRequest;
      _affectedJobs = result['affectedJobs'] as List<AffectedJob>;
      _suggestions = result['suggestions'] as List<RescheduleOption>;
      return true;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('TimeExtensionProvider.submitRequest error: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── loadActiveRequest ─────────────────────────────────────────────────────
  /// Loads the active request and suggestions for a given job.
  Future<void> loadActiveRequest(int jobId) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _service.getActiveRequest(jobId);
      _activeRequest = result['request'] as TimeExtensionRequest?;
      _suggestions = result['suggestions'] as List<RescheduleOption>;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('TimeExtensionProvider.loadActiveRequest error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── approveRequest ────────────────────────────────────────────────────────
  Future<bool> approveRequest(
    int requestId, {
    int? suggestionId,
    List<Map<String, dynamic>>? customChanges,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.approveRequest(
        requestId,
        suggestionId: suggestionId,
        customChanges: customChanges,
      );
      _activeRequest = null;
      return true;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('TimeExtensionProvider.approveRequest error: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── denyRequest ───────────────────────────────────────────────────────────
  Future<bool> denyRequest(int requestId, {String? reason}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.denyRequest(requestId, reason: reason);
      _activeRequest = null;
      return true;
    } catch (e) {
      _error = e.toString();
      // ignore: avoid_print
      print('TimeExtensionProvider.denyRequest error: $e');
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── clearState ────────────────────────────────────────────────────────────
  void clearState() {
    _activeRequest = null;
    _suggestions = [];
    _affectedJobs = [];
    _loading = false;
    _error = null;
    notifyListeners();
  }
}
