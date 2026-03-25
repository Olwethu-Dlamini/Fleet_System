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
  final String type; // none | push | reassign | cancel | custom
  final String label;
  final bool recommended;
  final List<JobTimeChange> changes;

  const RescheduleOption({
    required this.id,
    required this.requestId,
    required this.type,
    required this.label,
    this.recommended = false,
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
      recommended: json['recommended'] == true,
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

// ── A single job entry in the day schedule ───────────────────────────────────
class DayScheduleJob {
  final int id;
  final String jobNumber;
  final String scheduledTimeStart;
  final String scheduledTimeEnd;
  final String currentStatus;
  final String? customerName;
  final int? driverId;
  final int? vehicleId;
  final String? driverName;
  final String? technicianNames;

  const DayScheduleJob({
    required this.id,
    required this.jobNumber,
    required this.scheduledTimeStart,
    required this.scheduledTimeEnd,
    required this.currentStatus,
    this.customerName,
    this.driverId,
    this.vehicleId,
    this.driverName,
    this.technicianNames,
  });

  factory DayScheduleJob.fromJson(Map<String, dynamic> json) {
    return DayScheduleJob(
      id: _parseInt(json['id']),
      jobNumber: (json['job_number'] ?? json['jobNumber'] ?? '').toString(),
      scheduledTimeStart:
          (json['scheduled_time_start'] ?? '').toString(),
      scheduledTimeEnd:
          (json['scheduled_time_end'] ?? '').toString(),
      currentStatus: (json['current_status'] ?? '').toString(),
      customerName: json['customer_name'] as String?,
      driverId: json['driver_id'] == null ? null : _parseInt(json['driver_id']),
      vehicleId: json['vehicle_id'] == null ? null : _parseInt(json['vehicle_id']),
      driverName: json['driver_name'] as String?,
      technicianNames: json['technician_names'] as String?,
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ── A personnel entry grouping jobs in the day schedule ─────────────────────
class DaySchedulePersonnel {
  final int id;
  final String name;
  final String role; // 'driver' or 'technician'
  final List<DayScheduleJob> jobs;

  const DaySchedulePersonnel({
    required this.id,
    required this.name,
    required this.role,
    required this.jobs,
  });

  factory DaySchedulePersonnel.fromJson(Map<String, dynamic> json) {
    final rawJobs = json['jobs'];
    final List<DayScheduleJob> parsedJobs = [];
    if (rawJobs is List) {
      for (final item in rawJobs) {
        if (item is Map<String, dynamic>) {
          parsedJobs.add(DayScheduleJob.fromJson(item));
        }
      }
    }

    return DaySchedulePersonnel(
      id: _parseInt(json['id']),
      name: (json['name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      jobs: parsedJobs,
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
  final String? jobNumber;
  final String? requesterName;
  final String? customerName;

  const TimeExtensionRequest({
    required this.id,
    required this.jobId,
    required this.requestedBy,
    required this.durationMinutes,
    required this.reason,
    required this.status,
    this.denialReason,
    required this.createdAt,
    this.jobNumber,
    this.requesterName,
    this.customerName,
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
      jobNumber: json['job_number'] as String?,
      requesterName: json['requester_name'] as String?,
      customerName: json['customer_name'] as String?,
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
