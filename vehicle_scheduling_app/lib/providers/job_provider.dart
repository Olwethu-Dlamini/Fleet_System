// ============================================
// FILE: lib/providers/job_provider.dart
// PURPOSE: Job state management
//
// FIXES:
//   • assignTechnicians() now reloads the specific job by ID instead of
//     calling loadJobs() — works correctly for all roles and avoids
//     fetching all jobs when a technician is on the job detail screen.
//   • updateJobStatus() same fix — reloads the specific job by ID so
//     the technician detail screen reflects the new status immediately.
//   • loadMyJobs() already existed — used by dashboard for technicians.
// ============================================

import 'package:flutter/material.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/services/job_service.dart';

enum JobStatus { idle, loading, success, error }

class JobProvider extends ChangeNotifier {
  final JobService _jobService = JobService();

  // ==========================================
  // STATE
  // ==========================================
  List<Job> _jobs = [];
  Job? _selectedJob;
  JobStatus _status = JobStatus.idle;
  String? _error;

  // Filters
  String? _statusFilter;
  String? _typeFilter;

  // ==========================================
  // GETTERS
  // ==========================================
  List<Job> get jobs => _filteredJobs;
  List<Job> get allJobs => _jobs;
  Job? get selectedJob => _selectedJob;
  JobStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == JobStatus.loading;
  String? get statusFilter => _statusFilter;
  String? get typeFilter => _typeFilter;

  List<Job> get _filteredJobs {
    return _jobs.where((job) {
      final matchesStatus =
          _statusFilter == null || job.currentStatus == _statusFilter;
      final matchesType = _typeFilter == null || job.jobType == _typeFilter;
      return matchesStatus && matchesType;
    }).toList();
  }

  int get pendingCount =>
      _jobs.where((j) => j.currentStatus == 'pending').length;
  int get assignedCount =>
      _jobs.where((j) => j.currentStatus == 'assigned').length;
  int get inProgressCount =>
      _jobs.where((j) => j.currentStatus == 'in_progress').length;
  int get completedCount =>
      _jobs.where((j) => j.currentStatus == 'completed').length;

  // ==========================================
  // EXPOSE SERVICE so AuthProvider can inject token:
  //   context.read<AuthProvider>().injectToken(
  //     context.read<JobProvider>().jobService.apiService
  //   );
  // ==========================================
  JobService get jobService => _jobService;

  // ==========================================
  // LOAD ALL JOBS  (admin / scheduler)
  // GET /api/jobs  — returns every job in the system.
  // ==========================================
  Future<void> loadJobs() async {
    _status = JobStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _jobs = await _jobService.getAllJobs();
      _status = JobStatus.success;
    } catch (e) {
      _error = e.toString();
      _status = JobStatus.error;
    }

    notifyListeners();
  }

  // ==========================================
  // LOAD MY JOBS  (technician / driver)
  // GET /api/jobs/my-jobs — backend filters by the JWT user id,
  // returning only jobs assigned to this technician via the
  // job_technicians table OR as the legacy driver_id.
  // ==========================================
  Future<void> loadMyJobs() async {
    _status = JobStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _jobs = await _jobService.getMyJobs();
      _status = JobStatus.success;
    } catch (e) {
      _error = e.toString();
      _status = JobStatus.error;
    }

    notifyListeners();
  }

  // ==========================================
  // LOAD JOB BY ID
  // ==========================================
  Future<void> loadJobById(int id) async {
    _status = JobStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _selectedJob = await _jobService.getJobById(id);
      _status = JobStatus.success;
    } catch (e) {
      _error = e.toString();
      _status = JobStatus.error;
    }

    notifyListeners();
  }

  // ==========================================
  // CREATE JOB
  // Accepts optional technicianIds so drivers can be assigned
  // at creation time (written to job_technicians on the backend).
  // ==========================================
  Future<bool> createJob({
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
    List<int> technicianIds = const [],
  }) async {
    _status = JobStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final newJob = await _jobService.createJob(
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        jobType: jobType,
        description: description,
        scheduledDate: scheduledDate,
        scheduledTimeStart: scheduledTimeStart,
        scheduledTimeEnd: scheduledTimeEnd,
        estimatedDurationMinutes: estimatedDurationMinutes,
        priority: priority,
        createdBy: createdBy,
        technicianIds: technicianIds,
      );

      _jobs.insert(0, newJob);
      _status = JobStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _status = JobStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // UPDATE JOB SCHEDULE
  // ==========================================
  Future<bool> updateJobSchedule({
    required int jobId,
    required DateTime scheduledDate,
    required String scheduledTimeStart,
    required String scheduledTimeEnd,
    required int estimatedDurationMinutes,
  }) async {
    _error = null;

    try {
      final updatedJob = await _jobService.updateJobSchedule(
        jobId: jobId,
        scheduledDate: scheduledDate,
        scheduledTimeStart: scheduledTimeStart,
        scheduledTimeEnd: scheduledTimeEnd,
        estimatedDurationMinutes: estimatedDurationMinutes,
      );

      _replaceJobInList(updatedJob);
      if (_selectedJob?.id == jobId) _selectedJob = updatedJob;

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // ASSIGN JOB  (vehicle + optional drivers)
  // ==========================================
  Future<bool> assignJob({
    required int jobId,
    required int vehicleId,
    int? driverId,
    List<int> technicianIds = const [],
    String? notes,
    required int assignedBy,
  }) async {
    _error = null;

    try {
      await _jobService.assignJob(
        jobId: jobId,
        vehicleId: vehicleId,
        driverId: driverId,
        technicianIds: technicianIds,
        notes: notes,
        assignedBy: assignedBy,
      );

      // Reload just this job so the detail screen gets fresh assignment data
      // without forcing a full list reload (important for technician context).
      await _reloadSingleJob(jobId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // ASSIGN TECHNICIANS
  // Replaces the driver list on a job without changing its vehicle.
  // Calls PUT /api/jobs/:id/technicians  (or the job-assignments route).
  //
  // FIX: previously called loadJobs() which broke technician context
  // because technicians are not allowed to fetch all jobs.
  // Now reloads only the specific job by ID.
  // ==========================================
  Future<bool> assignTechnicians({
    required int jobId,
    required List<int> technicianIds,
    required int assignedBy,
  }) async {
    _error = null;

    try {
      await _jobService.assignTechnicians(
        jobId: jobId,
        technicianIds: technicianIds,
        assignedBy: assignedBy,
      );

      // Reload only this job — safe for all roles (admin, scheduler, technician).
      await _reloadSingleJob(jobId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // UPDATE STATUS
  //
  // FIX: after optimistically updating the in-memory list, also fetch
  // the full job from the server so technicians_json (driver list) and
  // any other server-side changes are reflected in the detail screen.
  // ==========================================
  Future<bool> updateJobStatus({
    required int jobId,
    required String newStatus,
    required int changedBy,
    String? reason,
  }) async {
    _error = null;

    try {
      await _jobService.updateJobStatus(
        jobId: jobId,
        newStatus: newStatus,
        changedBy: changedBy,
        reason: reason,
      );

      // Optimistic update in the list
      final index = _jobs.indexWhere((j) => j.id == jobId);
      if (index != -1) {
        _jobs[index] = _jobs[index].copyWith(currentStatus: newStatus);
      }
      if (_selectedJob?.id == jobId) {
        _selectedJob = _selectedJob?.copyWith(currentStatus: newStatus);
      }

      notifyListeners();

      // Background refresh of the full job object (includes technicians_json)
      _refreshJobSilently(jobId);

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // UNASSIGN VEHICLE  (admin only)
  // Removes the vehicle assignment from a job.
  // Job reverts to 'pending' on the backend if it was 'assigned'.
  // ==========================================
  Future<bool> unassignVehicle({required int jobId}) async {
    _error = null;

    try {
      await _jobService.unassignVehicle(jobId: jobId);
      await _reloadSingleJob(jobId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // FILTERS
  // ==========================================
  void setStatusFilter(String? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setTypeFilter(String? type) {
    _typeFilter = type;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _typeFilter = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================
  // PRIVATE HELPERS
  // ==========================================

  /// Replace a job in the in-memory list by ID.
  void _replaceJobInList(Job updated) {
    final index = _jobs.indexWhere((j) => j.id == updated.id);
    if (index != -1) _jobs[index] = updated;
  }

  /// Fetch the latest version of a single job from the server,
  /// update the in-memory list and selectedJob, then notify listeners.
  /// Used after mutations (assign, update status, manage drivers).
  Future<void> _reloadSingleJob(int jobId) async {
    try {
      final fresh = await _jobService.getJobById(jobId);
      if (fresh != null) {
        _replaceJobInList(fresh);
        if (_selectedJob?.id == jobId) _selectedJob = fresh;
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal — the optimistic update already happened.
    }
  }

  /// Same as _reloadSingleJob but does NOT propagate errors and does not
  /// change loading state — safe to fire-and-forget after updateJobStatus.
  void _refreshJobSilently(int jobId) {
    _jobService
        .getJobById(jobId)
        .then((fresh) {
          if (fresh != null) {
            _replaceJobInList(fresh);
            if (_selectedJob?.id == jobId) _selectedJob = fresh;
            notifyListeners();
          }
        })
        .catchError((_) {});
  }
}
