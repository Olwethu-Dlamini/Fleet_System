// ============================================
// FILE: lib/models/job.dart
// CHANGES:
//   • Added technicians list (List<JobTechnician>)
//   • driverId / driverName kept for backwards-compat
//   • fromJson handles both old & new API shape
// ============================================

// ── Lightweight model for a technician assigned to a job ───
class JobTechnician {
  final int id;
  final String fullName;

  const JobTechnician({required this.id, required this.fullName});

  factory JobTechnician.fromJson(Map<String, dynamic> json) {
    return JobTechnician(
      id: _parseInt(json['id']),
      fullName: (json['full_name'] ?? json['fullName'] ?? '').toString(),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

// ─────────────────────────────────────────────────────────────
class Job {
  final int id;
  final String jobNumber;
  final String jobType;
  final String customerName;
  final String? customerPhone;
  final String customerAddress;
  final double? destinationLat; // ← NEW
  final double? destinationLng; // ← NEW
  final String? description;
  final DateTime scheduledDate;
  final String scheduledTimeStart;
  final String scheduledTimeEnd;
  final int estimatedDurationMinutes;
  final String currentStatus;
  final String priority;
  final int createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Assignment fields
  final int? vehicleId;
  final String? vehicleName;
  final String? licensePlate;

  // Legacy single-driver (kept for backwards-compat)
  final int? driverId;
  final String? driverName;

  // ── NEW: all technicians assigned to this job ──────────────
  final List<JobTechnician> technicians;

  Job({
    required this.id,
    required this.jobNumber,
    required this.jobType,
    required this.customerName,
    this.customerPhone,
    required this.customerAddress,
    this.destinationLat, // ← NEW
    this.destinationLng, // ← NEW
    this.description,
    required this.scheduledDate,
    required this.scheduledTimeStart,
    required this.scheduledTimeEnd,
    required this.estimatedDurationMinutes,
    required this.currentStatus,
    required this.priority,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.vehicleId,
    this.vehicleName,
    this.licensePlate,
    this.driverId,
    this.driverName,
    this.technicians = const [],
  });

  // ──────────────────────────────────────────
  // SAFE PARSERS
  // ──────────────────────────────────────────
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    final str = value.toString().trim();
    try {
      final datePart = str.length >= 10 ? str.substring(0, 10) : str;
      final parts = datePart.split('-');
      if (parts.length == 3) {
        final y = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        final d = int.tryParse(parts[2]);
        if (y != null && m != null && d != null) return DateTime(y, m, d);
      }
      return DateTime.parse(str);
    } catch (_) {
      return DateTime.now();
    }
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  // ──────────────────────────────────────────
  // FROM JSON
  // ──────────────────────────────────────────
  factory Job.fromJson(Map<String, dynamic> json) {
    // technicians_json can arrive as a JSON string or already decoded list
    List<JobTechnician> techs = [];
    final raw = json['technicians_json'] ?? json['technicians'];
    if (raw != null) {
      if (raw is List) {
        techs = raw
            .whereType<Map<String, dynamic>>()
            .map(JobTechnician.fromJson)
            .toList();
      }
    }

    return Job(
      id: _parseInt(json['id']),
      jobNumber: json['job_number'] as String,
      jobType: json['job_type'] as String,
      customerName: json['customer_name'] as String,
      customerPhone: json['customer_phone'] as String?,
      customerAddress: json['customer_address'] as String,
      destinationLat: _parseDouble(json['destination_lat']), // ← NEW
      destinationLng: _parseDouble(json['destination_lng']), // ← NEW
      description: json['description'] as String?,
      scheduledDate: _parseDate(json['scheduled_date']),
      scheduledTimeStart: json['scheduled_time_start'] as String,
      scheduledTimeEnd: json['scheduled_time_end'] as String,
      estimatedDurationMinutes: _parseInt(json['estimated_duration_minutes']),
      currentStatus: json['current_status'] as String,
      priority: json['priority'] as String,
      createdBy: _parseInt(json['created_by']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      vehicleId: json['vehicle_id'] != null
          ? _parseInt(json['vehicle_id'])
          : null,
      vehicleName: json['vehicle_name'] as String?,
      licensePlate: json['license_plate'] as String?,
      driverId: json['driver_id'] != null ? _parseInt(json['driver_id']) : null,
      driverName: json['driver_name'] as String?,
      technicians: techs,
    );
  }

  // ──────────────────────────────────────────
  // TO JSON
  // Full serialization for offline caching (round-trips through fromJson).
  // Also works for create-job payloads — backend ignores extra fields.
  // ──────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'job_number': jobNumber,
    'job_type': jobType,
    'customer_name': customerName,
    'customer_phone': customerPhone,
    'customer_address': customerAddress,
    'destination_lat': destinationLat,
    'destination_lng': destinationLng,
    'description': description,
    'scheduled_date':
        '${scheduledDate.year}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
    'scheduled_time_start': scheduledTimeStart,
    'scheduled_time_end': scheduledTimeEnd,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'current_status': currentStatus,
    'priority': priority,
    'created_by': createdBy,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'vehicle_id': vehicleId,
    'vehicle_name': vehicleName,
    'license_plate': licensePlate,
    'driver_id': driverId,
    'driver_name': driverName,
    'technicians': technicians
        .map((t) => {'id': t.id, 'full_name': t.fullName})
        .toList(),
  };

  // ──────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────
  String get typeDisplayName {
    switch (jobType) {
      case 'installation':
        return 'Installation';
      case 'delivery':
        return 'Delivery';
      case 'maintenance':
        return 'Maintenance';
      case 'miscellaneous':
        return 'Miscellaneous';
      default:
        return jobType;
    }
  }

  String get statusDisplayName {
    switch (currentStatus) {
      case 'pending':
        return 'Pending';
      case 'assigned':
        return 'Assigned';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return currentStatus;
    }
  }

  String get priorityDisplayName {
    switch (priority) {
      case 'urgent':
        return 'Urgent';
      case 'high':
        return 'High';
      case 'normal':
        return 'Normal';
      case 'low':
        return 'Low';
      default:
        return priority;
    }
  }

  bool get isAssigned => vehicleId != null;
  bool get isActive =>
      currentStatus != 'completed' && currentStatus != 'cancelled';

  /// Returns the display names of all assigned technicians (comma-separated)
  String get technicianNames => technicians.isEmpty
      ? 'None'
      : technicians.map((t) => t.fullName).join(', ');

  /// Whether a given userId is one of this job's technicians
  bool hasTechnician(int userId) => technicians.any((t) => t.id == userId);

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[scheduledDate.month - 1]} ${scheduledDate.day}, ${scheduledDate.year}';
  }

  String get formattedTimeRange {
    final start = scheduledTimeStart.length >= 5
        ? scheduledTimeStart.substring(0, 5)
        : scheduledTimeStart;
    final end = scheduledTimeEnd.length >= 5
        ? scheduledTimeEnd.substring(0, 5)
        : scheduledTimeEnd;
    return '$start - $end';
  }

  Job copyWith({
    int? id,
    String? jobNumber,
    String? jobType,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? description,
    DateTime? scheduledDate,
    String? scheduledTimeStart,
    String? scheduledTimeEnd,
    int? estimatedDurationMinutes,
    String? currentStatus,
    String? priority,
    int? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? vehicleId,
    String? vehicleName,
    String? licensePlate,
    int? driverId,
    String? driverName,
    List<JobTechnician>? technicians,
  }) => Job(
    id: id ?? this.id,
    jobNumber: jobNumber ?? this.jobNumber,
    jobType: jobType ?? this.jobType,
    customerName: customerName ?? this.customerName,
    customerPhone: customerPhone ?? this.customerPhone,
    customerAddress: customerAddress ?? this.customerAddress,
    description: description ?? this.description,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    scheduledTimeStart: scheduledTimeStart ?? this.scheduledTimeStart,
    scheduledTimeEnd: scheduledTimeEnd ?? this.scheduledTimeEnd,
    estimatedDurationMinutes:
        estimatedDurationMinutes ?? this.estimatedDurationMinutes,
    currentStatus: currentStatus ?? this.currentStatus,
    priority: priority ?? this.priority,
    createdBy: createdBy ?? this.createdBy,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    vehicleId: vehicleId ?? this.vehicleId,
    vehicleName: vehicleName ?? this.vehicleName,
    licensePlate: licensePlate ?? this.licensePlate,
    driverId: driverId ?? this.driverId,
    driverName: driverName ?? this.driverName,
    technicians: technicians ?? this.technicians,
  );
}
