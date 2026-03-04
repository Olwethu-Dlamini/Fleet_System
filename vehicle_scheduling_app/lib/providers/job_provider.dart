// ============================================
// FILE: lib/providers/job_provider.dart
// PURPOSE: Job state management
// NO CHANGES from your original — token injection happens at
// the service layer (job_service.dart) not here.
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
  // Calls GET /api/jobs/my-jobs — backend filters by the
  // JWT user id, returning only jobs assigned to this user
  // via the job_technicians table.
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
    List<int> technicianIds = const [], // ← NEW: assign drivers at creation
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

      final index = _jobs.indexWhere((j) => j.id == jobId);
      if (index != -1) _jobs[index] = updatedJob;
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
  // ASSIGN JOB
  // Accepts optional technicianIds list (multi-driver).
  // Falls back to legacy driverId if technicianIds not supplied.
  // ==========================================
  Future<bool> assignJob({
    required int jobId,
    required int vehicleId,
    int? driverId,
    List<int> technicianIds = const [], // ← NEW: multi-driver support
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

      await loadJobs();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // ASSIGN TECHNICIANS  (update driver list only, no vehicle change)
  // Calls PUT /api/job-assignments/:jobId/technicians
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

      // Reload so the technicians list on the job is refreshed
      await loadJobs();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // UPDATE STATUS
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

      final index = _jobs.indexWhere((j) => j.id == jobId);
      if (index != -1) {
        _jobs[index] = _jobs[index].copyWith(currentStatus: newStatus);
      }
      if (_selectedJob?.id == jobId) {
        _selectedJob = _selectedJob?.copyWith(currentStatus: newStatus);
      }

      notifyListeners();
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
}
