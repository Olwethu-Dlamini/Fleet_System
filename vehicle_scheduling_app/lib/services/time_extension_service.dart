// ============================================
// FILE: lib/services/time_extension_service.dart
// PURPOSE: HTTP client wrapping ApiService for time extension endpoints
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/time_extension.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class TimeExtensionService {
  final ApiService _api = ApiService();

  // ── POST /api/time-extensions ─────────────────────────────────────────────
  /// Creates a new time extension request.
  /// Returns a map with keys: request, affectedJobs, suggestions.
  Future<Map<String, dynamic>> createRequest({
    required int jobId,
    required int durationMinutes,
    required String reason,
  }) async {
    final response = await _api.post(
      AppConfig.timeExtensionsEndpoint,
      data: {
        'job_id': jobId,
        'duration_minutes': durationMinutes,
        'reason': reason,
      },
    );

    final requestData = response['request'];
    final TimeExtensionRequest request = requestData != null
        ? TimeExtensionRequest.fromJson(requestData as Map<String, dynamic>)
        : throw Exception('Invalid response: missing request');

    final rawAffected = response['affectedJobs'] ?? response['affected_jobs'];
    final List<AffectedJob> affectedJobs = [];
    if (rawAffected is List) {
      for (final item in rawAffected) {
        if (item is Map<String, dynamic>) {
          affectedJobs.add(AffectedJob.fromJson(item));
        }
      }
    }

    final rawSuggestions = response['suggestions'];
    final List<RescheduleOption> suggestions = [];
    if (rawSuggestions is List) {
      for (final item in rawSuggestions) {
        if (item is Map<String, dynamic>) {
          suggestions.add(RescheduleOption.fromJson(item));
        }
      }
    }

    return {
      'request': request,
      'affectedJobs': affectedJobs,
      'suggestions': suggestions,
    };
  }

  // ── GET /api/time-extensions/pending ──────────────────────────────────────
  /// Returns all pending time extension requests for the tenant.
  Future<List<TimeExtensionRequest>> getPendingRequests() async {
    final response = await _api.get(
      '${AppConfig.timeExtensionsEndpoint}/pending',
    );

    final rawRequests = response['requests'];
    final List<TimeExtensionRequest> requests = [];
    if (rawRequests is List) {
      for (final item in rawRequests) {
        if (item is Map<String, dynamic>) {
          requests.add(TimeExtensionRequest.fromJson(item));
        }
      }
    }
    return requests;
  }

  // ── GET /api/time-extensions/:jobId ───────────────────────────────────────
  /// Returns the active (pending/approved) request for a job, if any.
  Future<Map<String, dynamic>> getActiveRequest(int jobId) async {
    final response = await _api.get(
      '${AppConfig.timeExtensionsEndpoint}/$jobId',
    );

    final requestData = response['request'];
    final TimeExtensionRequest? request = requestData != null
        ? TimeExtensionRequest.fromJson(requestData as Map<String, dynamic>)
        : null;

    final rawSuggestions = response['suggestions'];
    final List<RescheduleOption> suggestions = [];
    if (rawSuggestions is List) {
      for (final item in rawSuggestions) {
        if (item is Map<String, dynamic>) {
          suggestions.add(RescheduleOption.fromJson(item));
        }
      }
    }

    return {
      'request': request,
      'suggestions': suggestions,
    };
  }

  // ── GET /api/time-extensions/:jobId/day-schedule ──────────────────────────
  /// Returns the full day schedule grouped by personnel for the given job's date.
  /// Response map has keys: 'date' (String) and 'personnel' (List<DaySchedulePersonnel>).
  Future<Map<String, dynamic>> getDaySchedule(int jobId) async {
    final response = await _api.get(
      '${AppConfig.timeExtensionsEndpoint}/$jobId/day-schedule',
    );

    final date = (response['date'] ?? '').toString();
    final rawPersonnel = response['personnel'];
    final List<DaySchedulePersonnel> personnel = [];
    if (rawPersonnel is List) {
      for (final item in rawPersonnel) {
        if (item is Map<String, dynamic>) {
          personnel.add(DaySchedulePersonnel.fromJson(item));
        }
      }
    }

    return {
      'date': date,
      'personnel': personnel,
    };
  }

  // ── PATCH /api/time-extensions/:id/approve ────────────────────────────────
  Future<Map<String, dynamic>> approveRequest(
    int requestId, {
    int? suggestionId,
    List<Map<String, dynamic>>? customChanges,
  }) async {
    return await _api.patch(
      '${AppConfig.timeExtensionsEndpoint}/$requestId/approve',
      data: {
        if (suggestionId != null) 'suggestion_id': suggestionId,
        if (customChanges != null) 'custom_changes': customChanges,
      },
    );
  }

  // ── PATCH /api/time-extensions/:id/deny ───────────────────────────────────
  Future<Map<String, dynamic>> denyRequest(
    int requestId, {
    String? reason,
  }) async {
    return await _api.patch(
      '${AppConfig.timeExtensionsEndpoint}/$requestId/deny',
      data: {
        if (reason != null) 'reason': reason,
      },
    );
  }
}
