// ============================================
// FILE: lib/services/job_service.dart
//
// FIXES APPLIED:
//   BUG 1 — createJob no longer sends technician_ids.
//            Driver assignment is now always done as a separate
//            assignTechnicians() call from the screen, using the
//            job ID returned by createJob(). This is more reliable
//            because the POST /api/jobs endpoint may silently ignore
//            technician_ids if the backend hasn't implemented it.
//
//   BUG 3 — assignTechnicians() now accepts forceOverride: bool.
//            When true, force_override: true is included in the PUT body.
//            The backend reads this flag and skips the conflict check,
//            instead removing the driver from any conflicting job first.
// ============================================

import 'package:vehicle_scheduling_app/config/app_config.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/services/api_service.dart';

class JobService {
  final ApiService apiService = ApiService();

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  List<Job> _parseJobList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>).map((j) => Job.fromJson(j)).toList();
  }

  // ══════════════════════════════════════════════════════════
  // GET ALL JOBS
  // ══════════════════════════════════════════════════════════
  Future<List<Job>> getAllJobs() async {
    try {
      final response = await apiService.get('${AppConfig.jobsEndpoint}?limit=1000');
      if (response['success'] == true) {
        return _parseJobList(response['jobs']);
      }
      return [];
    } catch (e) {
      print('JobService.getAllJobs error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // GET MY JOBS  (technician)
  // ══════════════════════════════════════════════════════════
  Future<List<Job>> getMyJobs() async {
    try {
      final response = await apiService.get(
        '${AppConfig.jobsEndpoint}/my-jobs',
      );
      if (response['success'] == true) {
        return _parseJobList(response['jobs']);
      }
      return [];
    } catch (e) {
      print('JobService.getMyJobs error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // GET JOB BY ID
  // ══════════════════════════════════════════════════════════
  Future<Job?> getJobById(int id) async {
    try {
      final response = await apiService.get('${AppConfig.jobsEndpoint}/$id');
      if (response['success'] == true && response['job'] != null) {
        return Job.fromJson(response['job']);
      }
      return null;
    } catch (e) {
      print('JobService.getJobById error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // CREATE JOB
  //
  // FIX (Bug 1): technician_ids is intentionally NOT sent here.
  //
  // The caller (create_job_screen.dart) receives the new Job object back
  // from JobProvider.createJob() and then calls assignTechnicians()
  // separately using the real job ID. This is the reliable approach
  // because:
  //   a) The POST /api/jobs endpoint may not process technician_ids.
  //   b) If it does, it doesn't report back which drivers were actually
  //      saved, so the UI can't confirm success.
  //   c) A dedicated PUT call gives us a clear success/failure signal.
  // ══════════════════════════════════════════════════════════
  Future<Job> createJob({
    required String customerName,
    String? customerPhone,
    required String customerAddress,
    double? destinationLat, // ← NEW
    double? destinationLng, // ← NEW
    required String jobType,
    String? description,
    required DateTime scheduledDate,
    required String scheduledTimeStart,
    required String scheduledTimeEnd,
    required int estimatedDurationMinutes,
    String priority = 'normal',
    required int createdBy,
  }) async {
    try {
      final data = <String, dynamic>{
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'destination_lat': destinationLat, // ← NEW
        'destination_lng': destinationLng, // ← NEW
        'job_type': jobType,
        'description': description,
        'scheduled_date': _formatDate(scheduledDate),
        'scheduled_time_start': scheduledTimeStart,
        'scheduled_time_end': scheduledTimeEnd,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'priority': priority,
        'created_by': createdBy,
        // NOTE: No technician_ids here. Assigned separately after creation.
      };
      final response = await apiService.post(
        AppConfig.jobsEndpoint,
        data: data,
      );
      if (response['success'] == true && response['job'] != null) {
        return Job.fromJson(response['job']);
      }
      throw Exception('Create job failed');
    } catch (e) {
      print('JobService.createJob error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // UPDATE JOB
  // ══════════════════════════════════════════════════════════
  Future<Job> updateJob({
    required int jobId,
    required String customerName,
    String? customerPhone,
    required String customerAddress,
    double? destinationLat, // ← NEW
    double? destinationLng, // ← NEW
    required String jobType,
    String? description,
    required DateTime scheduledDate,
    required String scheduledTimeStart,
    required String scheduledTimeEnd,
    required int estimatedDurationMinutes,
    String priority = 'normal',
  }) async {
    try {
      final data = <String, dynamic>{
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'destination_lat': destinationLat, // ← NEW
        'destination_lng': destinationLng, // ← NEW
        'job_type': jobType,
        'description': description,
        'scheduled_date': _formatDate(scheduledDate),
        'scheduled_time_start': scheduledTimeStart,
        'scheduled_time_end': scheduledTimeEnd,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'priority': priority,
      };
      final response = await apiService.put(
        '${AppConfig.jobsEndpoint}/$jobId',
        data: data,
      );
      if (response['success'] == true && response['job'] != null) {
        return Job.fromJson(response['job']);
      }
      throw Exception(
        response['message'] ?? response['error'] ?? 'Update job failed',
      );
    } catch (e) {
      print('JobService.updateJob error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // UPDATE JOB SCHEDULE
  // ══════════════════════════════════════════════════════════
  Future<Job> updateJobSchedule({
    required int jobId,
    required DateTime scheduledDate,
    required String scheduledTimeStart,
    required String scheduledTimeEnd,
    required int estimatedDurationMinutes,
  }) async {
    try {
      final data = {
        'scheduled_date': _formatDate(scheduledDate),
        'scheduled_time_start': scheduledTimeStart,
        'scheduled_time_end': scheduledTimeEnd,
        'estimated_duration_minutes': estimatedDurationMinutes,
      };
      final response = await apiService.put(
        '${AppConfig.jobsEndpoint}/$jobId/schedule',
        data: data,
      );
      if (response['success'] == true && response['job'] != null) {
        return Job.fromJson(response['job']);
      }
      throw Exception('Update schedule failed');
    } catch (e) {
      print('JobService.updateJobSchedule error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // ASSIGN JOB  (vehicle + optional technicians)
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> assignJob({
    required int jobId,
    required int vehicleId,
    int? driverId,
    List<int> technicianIds = const [],
    String? notes,
    required int assignedBy,
  }) async {
    try {
      final data = <String, dynamic>{
        'job_id': jobId,
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'notes': notes,
        'assigned_by': assignedBy,
        // BUGFIX: Only include technician_ids when the list is non-empty.
        // The backend treats an explicit empty array as "clear all technicians".
        // Omitting the key entirely tells the backend "no change to technicians".
        // This prevents the scenario where assigning/swapping a vehicle with no
        // technicians passed in silently wipes drivers that were already saved.
        if (technicianIds.isNotEmpty) 'technician_ids': technicianIds,
      };
      return await apiService.post(
        '${AppConfig.assignmentsEndpoint}/assign',
        data: data,
      );
    } catch (e) {
      print('JobService.assignJob error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // ASSIGN TECHNICIANS
  //
  // FIX (Bug 3): Added forceOverride parameter.
  //
  // WHY: Without this, the backend's conflict check blocks the request
  // even for admins. The admin's intent (override the conflict) never
  // reached the server — the frontend allowed the checkbox but sent
  // the same payload as a non-admin user.
  //
  // WHAT force_override DOES ON THE BACKEND:
  //   When true, jobs.js route sees req.user.role === 'admin' AND
  //   force_override === true, so it calls Job.assignTechnicians() with
  //   isAdminOverride = true, which skips conflict detection and instead
  //   removes the driver from any conflicting job before inserting.
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> assignTechnicians({
    required int jobId,
    required List<int> technicianIds,
    required int assignedBy,
    bool forceOverride = false, // ← NEW
  }) async {
    try {
      final data = <String, dynamic>{
        'technician_ids': technicianIds,
        'assigned_by': assignedBy,
        // Only include the flag when it's actually true to keep the
        // payload clean for normal assignments.
        if (forceOverride) 'force_override': true,
      };
      return await apiService.put(
        '${AppConfig.assignmentsEndpoint}/$jobId/technicians',
        data: data,
      );
    } catch (e) {
      print('JobService.assignTechnicians error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // UNASSIGN VEHICLE
  // ══════════════════════════════════════════════════════════
  Future<void> unassignVehicle({required int jobId}) async {
    try {
      final response = await apiService.delete(
        '${AppConfig.jobsEndpoint}/$jobId/vehicle',
      );
      if (response['success'] != true) {
        throw Exception(
          response['message'] ??
              response['error'] ??
              'Failed to remove vehicle',
        );
      }
    } catch (e) {
      print('JobService.unassignVehicle error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // GET DRIVER LOAD  (load balancing — Phase 03)
  // ══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getDriverLoad({
    String range = 'weekly',
  }) async {
    try {
      final response = await apiService.get(
        '/job-assignments/driver-load?range=$range',
      );
      if (response['success'] == true) {
        return List<Map<String, dynamic>>.from(response['data'] as List);
      }
      throw Exception('Failed to load driver stats');
    } catch (e) {
      print('JobService.getDriverLoad error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // COMPLETE JOB WITH GPS  (Phase 03)
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> completeJobWithGps({
    required int jobId,
    double? lat,
    double? lng,
    double? accuracyM,
    required String gpsStatus,
  }) async {
    try {
      final data = <String, dynamic>{
        'job_id': jobId,
        'lat': lat,
        'lng': lng,
        'accuracy_m': accuracyM,
        'gps_status': gpsStatus,
      };
      final response = await apiService.post(
        '/job-status/complete',
        data: data,
      );
      if (response['success'] == true) {
        return response['data'] as Map<String, dynamic>? ?? response;
      }
      throw Exception(response['message'] ?? 'Failed to complete job');
    } catch (e) {
      print('JobService.completeJobWithGps error: $e');
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════
  // UPDATE JOB STATUS
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> updateJobStatus({
    required int jobId,
    required String newStatus,
    required int changedBy,
    String? reason,
  }) async {
    try {
      final data = <String, dynamic>{
        'job_id': jobId,
        'new_status': newStatus,
        'changed_by': changedBy,
        'reason': reason,
      };
      return await apiService.post(
        '${AppConfig.statusEndpoint}/update',
        data: data,
      );
    } catch (e) {
      print('JobService.updateJobStatus error: $e');
      rethrow;
    }
  }
}
