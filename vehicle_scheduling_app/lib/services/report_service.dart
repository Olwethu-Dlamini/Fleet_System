// ============================================
// FILE: lib/services/report_service.dart
// PURPOSE: Fetch all analytics/report data from backend
//
// Every method accepts optional dateFrom / dateTo strings (YYYY-MM-DD).
// If omitted the backend defaults to the last 30 days.
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

// ── Lightweight model classes ────────────────────────────────────────────────

class ReportPeriod {
  final String dateFrom;
  final String dateTo;
  final int daysDiff;

  const ReportPeriod({
    required this.dateFrom,
    required this.dateTo,
    required this.daysDiff,
  });

  factory ReportPeriod.fromJson(Map<String, dynamic> j) => ReportPeriod(
    dateFrom: j['dateFrom'] ?? '',
    dateTo: j['dateTo'] ?? '',
    daysDiff: j['daysDiff'] ?? j['totalDays'] ?? 30,
  );
}

class ReportSummary {
  final int total;
  final int completed;
  final int cancelled;
  final int inProgress;
  final int assigned;
  final int pending;
  final double completionRate;
  final double cancellationRate;
  final int activeVehicles;
  final int activeTechnicians;
  final double avgJobsPerDay;

  const ReportSummary({
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.inProgress,
    required this.assigned,
    required this.pending,
    required this.completionRate,
    required this.cancellationRate,
    required this.activeVehicles,
    required this.activeTechnicians,
    required this.avgJobsPerDay,
  });

  factory ReportSummary.fromJson(Map<String, dynamic> j) => ReportSummary(
    total: (j['total'] ?? 0) as int,
    completed: (j['completed'] ?? 0) as int,
    cancelled: (j['cancelled'] ?? 0) as int,
    inProgress: (j['inProgress'] ?? 0) as int,
    assigned: (j['assigned'] ?? 0) as int,
    pending: (j['pending'] ?? 0) as int,
    completionRate: ((j['completionRate'] ?? 0) as num).toDouble(),
    cancellationRate: ((j['cancellationRate'] ?? 0) as num).toDouble(),
    activeVehicles: (j['activeVehicles'] ?? 0) as int,
    activeTechnicians: (j['activeTechnicians'] ?? 0) as int,
    avgJobsPerDay: ((j['avgJobsPerDay'] ?? 0) as num).toDouble(),
  );
}

class VehicleReport {
  final int vehicleId;
  final String vehicleName;
  final String licensePlate;
  final String vehicleType;
  final int totalJobs;
  final int completed;
  final int cancelled;
  final int inProgress;
  final int assigned;
  final int pending;
  final int installations;
  final int deliveries;
  final int miscellaneous;
  final double completionRate;
  final double utilisationPct;
  final int daysUsed;
  final String? lastJobDate;

  const VehicleReport({
    required this.vehicleId,
    required this.vehicleName,
    required this.licensePlate,
    required this.vehicleType,
    required this.totalJobs,
    required this.completed,
    required this.cancelled,
    required this.inProgress,
    required this.assigned,
    required this.pending,
    required this.installations,
    required this.deliveries,
    required this.miscellaneous,
    required this.completionRate,
    required this.utilisationPct,
    required this.daysUsed,
    this.lastJobDate,
  });

  factory VehicleReport.fromJson(Map<String, dynamic> j) => VehicleReport(
    vehicleId: (j['vehicleId'] ?? 0) as int,
    vehicleName: j['vehicleName'] ?? '',
    licensePlate: j['licensePlate'] ?? '',
    vehicleType: j['vehicleType'] ?? '',
    totalJobs: (j['totalJobs'] ?? 0) as int,
    completed: (j['completed'] ?? 0) as int,
    cancelled: (j['cancelled'] ?? 0) as int,
    inProgress: (j['inProgress'] ?? 0) as int,
    assigned: (j['assigned'] ?? 0) as int,
    pending: (j['pending'] ?? 0) as int,
    installations: (j['installations'] ?? 0) as int,
    deliveries: (j['deliveries'] ?? 0) as int,
    miscellaneous: (j['miscellaneous'] ?? 0) as int,
    completionRate: ((j['completionRate'] ?? 0) as num).toDouble(),
    utilisationPct: ((j['utilisationPct'] ?? 0) as num).toDouble(),
    daysUsed: (j['daysUsed'] ?? 0) as int,
    lastJobDate: j['lastJobDate']?.toString(),
  );
}

class TechnicianReport {
  final int technicianId;
  final String fullName;
  final String username;
  final int totalJobs;
  final int completed;
  final int cancelled;
  final int inProgress;
  final int upcoming;
  final int installations;
  final int deliveries;
  final int miscellaneous;
  final int highPriority;
  final int urgent;
  final double completionRate;
  final double cancellationRate;
  final String? lastActiveDate;

  const TechnicianReport({
    required this.technicianId,
    required this.fullName,
    required this.username,
    required this.totalJobs,
    required this.completed,
    required this.cancelled,
    required this.inProgress,
    required this.upcoming,
    required this.installations,
    required this.deliveries,
    required this.miscellaneous,
    required this.highPriority,
    required this.urgent,
    required this.completionRate,
    required this.cancellationRate,
    this.lastActiveDate,
  });

  factory TechnicianReport.fromJson(Map<String, dynamic> j) => TechnicianReport(
    technicianId: (j['technicianId'] ?? 0) as int,
    fullName: j['fullName'] ?? '',
    username: j['username'] ?? '',
    totalJobs: (j['totalJobs'] ?? 0) as int,
    completed: (j['completed'] ?? 0) as int,
    cancelled: (j['cancelled'] ?? 0) as int,
    inProgress: (j['inProgress'] ?? 0) as int,
    upcoming: (j['upcoming'] ?? 0) as int,
    installations: (j['installations'] ?? 0) as int,
    deliveries: (j['deliveries'] ?? 0) as int,
    miscellaneous: (j['miscellaneous'] ?? 0) as int,
    highPriority: (j['highPriority'] ?? 0) as int,
    urgent: (j['urgent'] ?? 0) as int,
    completionRate: ((j['completionRate'] ?? 0) as num).toDouble(),
    cancellationRate: ((j['cancellationRate'] ?? 0) as num).toDouble(),
    lastActiveDate: j['lastActiveDate']?.toString(),
  );
}

class JobTypeReport {
  final String jobType;
  final int total;
  final int completed;
  final int cancelled;
  final int inProgress;
  final int assigned;
  final int pending;
  final double completionRate;

  const JobTypeReport({
    required this.jobType,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.inProgress,
    required this.assigned,
    required this.pending,
    required this.completionRate,
  });

  factory JobTypeReport.fromJson(Map<String, dynamic> j) => JobTypeReport(
    jobType: j['jobType'] ?? '',
    total: (j['total'] ?? 0) as int,
    completed: (j['completed'] ?? 0) as int,
    cancelled: (j['cancelled'] ?? 0) as int,
    inProgress: (j['inProgress'] ?? 0) as int,
    assigned: (j['assigned'] ?? 0) as int,
    pending: (j['pending'] ?? 0) as int,
    completionRate: ((j['completionRate'] ?? 0) as num).toDouble(),
  );
}

class CancelledJob {
  final int jobId;
  final String customerName;
  final String jobType;
  final String priority;
  final String scheduledDate;
  final String? scheduledTime;
  final String? vehicleName;
  final String? licensePlate;
  final String? technicianNames;
  final String? cancelReason;
  final String? cancelledBy;
  final String? cancelledAt;

  const CancelledJob({
    required this.jobId,
    required this.customerName,
    required this.jobType,
    required this.priority,
    required this.scheduledDate,
    this.scheduledTime,
    this.vehicleName,
    this.licensePlate,
    this.technicianNames,
    this.cancelReason,
    this.cancelledBy,
    this.cancelledAt,
  });

  factory CancelledJob.fromJson(Map<String, dynamic> j) => CancelledJob(
    jobId: (j['jobId'] ?? 0) as int,
    customerName: j['customerName'] ?? '',
    jobType: j['jobType'] ?? '',
    priority: j['priority'] ?? 'normal',
    scheduledDate: j['scheduledDate'] ?? '',
    scheduledTime: j['scheduledTime']?.toString(),
    vehicleName: j['vehicleName']?.toString(),
    licensePlate: j['licensePlate']?.toString(),
    technicianNames: j['technicianNames']?.toString(),
    cancelReason: j['cancelReason']?.toString(),
    cancelledBy: j['cancelledBy']?.toString(),
    cancelledAt: j['cancelledAt']?.toString(),
  );
}

class CancellationReason {
  final String reason;
  final int count;
  const CancellationReason({required this.reason, required this.count});
  factory CancellationReason.fromJson(Map<String, dynamic> j) =>
      CancellationReason(
        reason: j['reason'] ?? '',
        count: (j['count'] ?? 0) as int,
      );
}

class DailyVolume {
  final String date;
  final int total;
  final int completed;
  final int cancelled;
  final int active;

  const DailyVolume({
    required this.date,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.active,
  });

  factory DailyVolume.fromJson(Map<String, dynamic> j) => DailyVolume(
    date: j['date']?.toString() ?? '',
    total: (j['total'] ?? 0) as int,
    completed: (j['completed'] ?? 0) as int,
    cancelled: (j['cancelled'] ?? 0) as int,
    active: (j['active'] ?? 0) as int,
  );
}

// ── Dashboard aggregate ──────────────────────────────────────────────────────

class ExecutiveDashboardData {
  final ReportPeriod period;
  final ReportSummary summary;
  final List<VehicleReport> vehicles;
  final List<TechnicianReport> technicians;
  final List<JobTypeReport> byType;
  final List<DailyVolume> dailyVolume;

  const ExecutiveDashboardData({
    required this.period,
    required this.summary,
    required this.vehicles,
    required this.technicians,
    required this.byType,
    required this.dailyVolume,
  });
}

// ── Service ──────────────────────────────────────────────────────────────────

class ReportService {
  final ApiService _api = ApiService();

  static const String _base = '/reports';

  String _dateParams({String? dateFrom, String? dateTo}) {
    final parts = <String>[];
    if (dateFrom != null) parts.add('date_from=$dateFrom');
    if (dateTo != null) parts.add('date_to=$dateTo');
    return parts.isEmpty ? '' : '?${parts.join('&')}';
  }

  // ── Summary KPIs ─────────────────────────────────────────────────────────
  Future<ReportSummary> getSummary({String? dateFrom, String? dateTo}) async {
    final res = await _api.get(
      '$_base/summary${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    return ReportSummary.fromJson(res['summary'] as Map<String, dynamic>);
  }

  // ── Per-vehicle ───────────────────────────────────────────────────────────
  Future<List<VehicleReport>> getJobsByVehicle({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/jobs-by-vehicle${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    final list = res['vehicles'] as List<dynamic>? ?? [];
    return list
        .map((e) => VehicleReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Per-technician basic ─────────────────────────────────────────────────
  Future<List<TechnicianReport>> getJobsByTechnician({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/jobs-by-technician${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    final list = res['technicians'] as List<dynamic>? ?? [];
    return list
        .map((e) => TechnicianReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Technician performance (richer) ──────────────────────────────────────
  Future<List<TechnicianReport>> getTechnicianPerformance({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/technician-performance${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    final list = res['technicians'] as List<dynamic>? ?? [];
    return list
        .map((e) => TechnicianReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── By job type ──────────────────────────────────────────────────────────
  Future<List<JobTypeReport>> getJobsByType({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/jobs-by-type${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    final list = res['byType'] as List<dynamic>? ?? [];
    return list
        .map((e) => JobTypeReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Cancellations ────────────────────────────────────────────────────────
  Future<
    ({int total, List<CancellationReason> byReason, List<CancelledJob> jobs})
  >
  getCancellations({String? dateFrom, String? dateTo}) async {
    final res = await _api.get(
      '$_base/cancellations${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );

    final reasons = (res['byReason'] as List<dynamic>? ?? [])
        .map((e) => CancellationReason.fromJson(e as Map<String, dynamic>))
        .toList();

    final jobs = (res['jobs'] as List<dynamic>? ?? [])
        .map((e) => CancelledJob.fromJson(e as Map<String, dynamic>))
        .toList();

    return (total: (res['total'] ?? 0) as int, byReason: reasons, jobs: jobs);
  }

  // ── Daily volume ─────────────────────────────────────────────────────────
  Future<List<DailyVolume>> getDailyVolume({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/daily-volume${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    final list = res['days'] as List<dynamic>? ?? [];
    return list
        .map((e) => DailyVolume.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Vehicle utilisation ──────────────────────────────────────────────────
  Future<List<VehicleReport>> getVehicleUtilisation({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/vehicle-utilisation${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );
    final list = res['vehicles'] as List<dynamic>? ?? [];
    return list
        .map((e) => VehicleReport.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Executive dashboard (single call, parallel backend queries) ──────────
  Future<ExecutiveDashboardData> getExecutiveDashboard({
    String? dateFrom,
    String? dateTo,
  }) async {
    final res = await _api.get(
      '$_base/executive-dashboard${_dateParams(dateFrom: dateFrom, dateTo: dateTo)}',
    );

    return ExecutiveDashboardData(
      period: ReportPeriod.fromJson(res['period'] as Map<String, dynamic>),
      summary: ReportSummary.fromJson(res['summary'] as Map<String, dynamic>),
      vehicles: (res['vehicles'] as List<dynamic>? ?? [])
          .map((e) => VehicleReport.fromJson(e as Map<String, dynamic>))
          .toList(),
      technicians: (res['technicians'] as List<dynamic>? ?? [])
          .map((e) => TechnicianReport.fromJson(e as Map<String, dynamic>))
          .toList(),
      byType: (res['byType'] as List<dynamic>? ?? [])
          .map((e) => JobTypeReport.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyVolume: (res['dailyVolume'] as List<dynamic>? ?? [])
          .map((e) => DailyVolume.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
