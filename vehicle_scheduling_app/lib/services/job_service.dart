// ============================================
// FILE: lib/services/job_service.dart
// CHANGES:
//   • createJob now accepts technicianIds list
//   • assignJob now accepts technicianIds list
//   • getMyJobs — returns only jobs for the logged-in technician
//   • assignTechnicians — set/replace technicians on a job
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

  // ── Helpers to parse job list from response ─────────────────
  List<Job> _parseJobList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List<dynamic>).map((j) => Job.fromJson(j)).toList();
  }

  // ══════════════════════════════════════════════════════════
  // GET ALL JOBS  (admin / scheduler — sees every job)
  // ══════════════════════════════════════════════════════════
  Future<List<Job>> getAllJobs() async {
    try {
      final response = await apiService.get(AppConfig.jobsEndpoint);
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
  // GET MY JOBS  (technician — only sees their assigned jobs)
  // GET /api/jobs/my-jobs   (backend filters by JWT user id)
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
  // CREATE JOB  — now accepts optional technicianIds
  // ══════════════════════════════════════════════════════════
  Future<Job> createJob({
    required String customerName,
    String? customerPhone,
    required String customerAddress,
    required String jobType,
    String? description,
    required DateTime scheduledDate,
    required String scheduledTimeStart,
    required String scheduledTimeEnd,
    required int estimatedDurationMinutes,
    String priority = 'normal',
    required int createdBy,
    List<int> technicianIds = const [], // ← NEW
  }) async {
    try {
      final data = <String, dynamic>{
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'customer_address': customerAddress,
        'job_type': jobType,
        'description': description,
        'scheduled_date': _formatDate(scheduledDate),
        'scheduled_time_start': scheduledTimeStart,
        'scheduled_time_end': scheduledTimeEnd,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'priority': priority,
        'created_by': createdBy,
        if (technicianIds.isNotEmpty) 'technician_ids': technicianIds,
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
  // UPDATE JOB  (admin / scheduler — full field edit)
  // PUT /api/jobs/:id
  // ══════════════════════════════════════════════════════════
  Future<Job> updateJob({
    required int jobId,
    required String customerName,
    String? customerPhone,
    required String customerAddress,
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
  // ASSIGN JOB — vehicle + optional technicianIds list
  // POST /api/job-assignments/assign
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> assignJob({
    required int jobId,
    required int vehicleId,
    int? driverId, // legacy single driver
    List<int> technicianIds = const [], // ← NEW multi-technician
    String? notes,
    required int assignedBy,
  }) async {
    try {
      final data = <String, dynamic>{
        'job_id': jobId,
        'vehicle_id': vehicleId,
        'driver_id': driverId,
        'technician_ids': technicianIds,
        'notes': notes,
        'assigned_by': assignedBy,
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
  // ASSIGN TECHNICIANS  — update technician list on existing job
  // PUT /api/job-assignments/:jobId/technicians
  // ══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> assignTechnicians({
    required int jobId,
    required List<int> technicianIds,
    required int assignedBy,
  }) async {
    try {
      return await apiService.put(
        '${AppConfig.assignmentsEndpoint}/$jobId/technicians',
        data: {'technician_ids': technicianIds, 'assigned_by': assignedBy},
      );
    } catch (e) {
      print('JobService.assignTechnicians error: $e');
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
