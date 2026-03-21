// ============================================
// FILE: lib/models/time_extension.dart
// PURPOSE: Models for time extension requests and scheduling impact
// ============================================

// ── Change applied to a single job during rescheduling ───────────────────────
class JobTimeChange {
  final int jobId;
  final String jobNumber;
  final String? currentStart;
  final String? currentEnd;
  final String newStart;
  final String newEnd;

  const JobTimeChange({
    required this.jobId,
    required this.jobNumber,
    this.currentStart,
    this.currentEnd,
    required this.newStart,
    required this.newEnd,
  });

  factory JobTimeChange.fromJson(Map<String, dynamic> json) {
    return JobTimeChange(
      jobId: _parseInt(json['job_id'] ?? json['jobId']),
      jobNumber: (json['job_number'] ?? json['jobNumber'] ?? '').toString(),
      currentStart: json['current_start'] as String?,
      currentEnd: json['current_end'] as String?,
      newStart: (json['new_start'] ?? json['newStart'] ?? '').toString(),
      newEnd: (json['new_end'] ?? json['newEnd'] ?? '').toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ── A rescheduling option returned when a time extension is created ───────────
class RescheduleOption {
  final int id;
  final int requestId;
  final String type; // push | swap | custom
  final String label;
  final List<JobTimeChange> changes;

  const RescheduleOption({
    required this.id,
    required this.requestId,
    required this.type,
    required this.label,
    required this.changes,
  });

  factory RescheduleOption.fromJson(Map<String, dynamic> json) {
    final rawChanges = json['changes'];
    final List<JobTimeChange> parsed = [];
    if (rawChanges is List) {
      for (final item in rawChanges) {
        if (item is Map<String, dynamic>) {
          parsed.add(JobTimeChange.fromJson(item));
        }
      }
    }

    return RescheduleOption(
      id: _parseInt(json['id']),
      requestId: _parseInt(json['request_id'] ?? json['requestId']),
      type: (json['type'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      changes: parsed,
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ── A job affected by the time extension ─────────────────────────────────────
class AffectedJob {
  final int id;
  final String jobNumber;
  final String currentStart;
  final String currentEnd;

  const AffectedJob({
    required this.id,
    required this.jobNumber,
    required this.currentStart,
    required this.currentEnd,
  });

  factory AffectedJob.fromJson(Map<String, dynamic> json) {
    return AffectedJob(
      id: _parseInt(json['id']),
      jobNumber: (json['job_number'] ?? json['jobNumber'] ?? '').toString(),
      currentStart:
          (json['current_start'] ?? json['scheduled_time_start'] ?? '')
              .toString(),
      currentEnd:
          (json['current_end'] ?? json['scheduled_time_end'] ?? '').toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ── A time extension request (the main model) ─────────────────────────────────
class TimeExtensionRequest {
  final int id;
  final int jobId;
  final int requestedBy;
  final int durationMinutes;
  final String reason;
  final String status; // pending | approved | denied
  final String? denialReason;
  final DateTime createdAt;

  const TimeExtensionRequest({
    required this.id,
    required this.jobId,
    required this.requestedBy,
    required this.durationMinutes,
    required this.reason,
    required this.status,
    this.denialReason,
    required this.createdAt,
  });

  factory TimeExtensionRequest.fromJson(Map<String, dynamic> json) {
    return TimeExtensionRequest(
      id: _parseInt(json['id']),
      jobId: _parseInt(json['job_id'] ?? json['jobId']),
      requestedBy: _parseInt(json['requested_by'] ?? json['requestedBy']),
      durationMinutes:
          _parseInt(json['duration_minutes'] ?? json['durationMinutes']),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      denialReason: json['denial_reason'] as String?,
      createdAt: _parseDateTime(json['created_at'] ?? json['createdAt']),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime _parseDateTime(dynamic v) {
    if (v == null) return DateTime.now();
    try {
      return DateTime.parse(v.toString());
    } catch (_) {
      return DateTime.now();
    }
  }
}
