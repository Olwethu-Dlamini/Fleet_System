// ============================================
// FILE: lib/providers/job_provider.dart
//
// FIXES APPLIED:
//   BUG 1 — createJob() now returns Job? instead of bool.
//            The screen needs the actual job object (specifically its ID)
//            to call assignTechnicians() as a separate step after creation.
//            Returning bool meant the screen had to guess the new job's ID
//            by sorting allJobs — which is a race condition.
//
//   BUG 2 — assignTechnicians() and assignJob() already called
//            _reloadSingleJob() internally, but the screens were ALSO
//            calling loadJobById() again afterwards. That double-reload
//            caused a second loading state + notify which made the UI
//            flash and occasionally race. Fixed in the screens, not here.
//            Provider code below is already correct for these methods.
//
//   BUG 3 — assignTechnicians() now accepts forceOverride: bool param
//            and passes it through to JobService. When true the backend
//            will remove the driver from any conflicting job first.
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/services/job_service.dart';
import 'package:vehicle_scheduling_app/services/offline_cache_service.dart';

enum JobStatus { idle, loading, success, error }

class JobProvider extends ChangeNotifier {
  final JobService _jobService = JobService();
  final OfflineCacheService _cacheService = OfflineCacheService();

  // ==========================================
  // STATE
  // ==========================================
  List<Job> _jobs = [];
  Job? _selectedJob;
  JobStatus _status = JobStatus.idle;
  String? _error;
  bool _isOffline = false;

  String? _statusFilter;
  String? _typeFilter;
  bool _weekendFilter = false;

  // ==========================================
  // GETTERS
  // ==========================================
  List<Job> get jobs => _filteredJobs;
  List<Job> get allJobs => _jobs;
  Job? get selectedJob => _selectedJob;
  JobStatus get status => _status;
  String? get error => _error;
  bool get isLoading => _status == JobStatus.loading;
  bool get isOffline => _isOffline;
  String? get statusFilter => _statusFilter;
  String? get typeFilter => _typeFilter;
  bool get weekendFilter => _weekendFilter;

  List<Job> get _filteredJobs {
    return _jobs.where((job) {
      final matchesStatus =
          _statusFilter == null || job.currentStatus == _statusFilter;
      final matchesType = _typeFilter == null || job.jobType == _typeFilter;
      final matchesWeekend = !_weekendFilter ||
          job.scheduledDate.weekday == DateTime.saturday ||
          job.scheduledDate.weekday == DateTime.sunday;
      return matchesStatus && matchesType && matchesWeekend;
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
      _isOffline = false;
      _status = JobStatus.success;

      // Cache for offline use
      _cacheService.cacheJobs(_jobs.map((j) => j.toJson()).toList());
    } catch (e) {
      // API failed — try loading from offline cache
      final cached = await _cacheService.getCachedJobs();
      if (cached.isNotEmpty) {
        _jobs = cached.map((j) => Job.fromJson(j)).toList();
        _isOffline = true;
        _status = JobStatus.success;
        _error = null;
      } else {
        _error = e.toString();
        _status = JobStatus.error;
      }
    }

    notifyListeners();
  }

  // ==========================================
  // LOAD MY JOBS  (technician / driver)
  // ==========================================
  Future<void> loadMyJobs() async {
    _status = JobStatus.loading;
    _error = null;
    notifyListeners();

    try {
      _jobs = await _jobService.getMyJobs();
      _isOffline = false;
      _status = JobStatus.success;

      // Cache for offline use
      _cacheService.cacheJobs(_jobs.map((j) => j.toJson()).toList());
    } catch (e) {
      // API failed — try loading from offline cache
      final cached = await _cacheService.getCachedJobs();
      if (cached.isNotEmpty) {
        _jobs = cached.map((j) => Job.fromJson(j)).toList();
        _isOffline = true;
        _status = JobStatus.success;
        _error = null;
      } else {
        _error = e.toString();
        _status = JobStatus.error;
      }
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
  //
  // FIX (Bug 1): Changed return type from bool to Job?.
  //
  // WHY: The create job screen needs the new job's ID immediately after
  // creation so it can call assignTechnicians() as a separate API call.
  // Returning just true/false forced the screen to find the new job by
  // sorting allJobs — a race condition that sometimes found the wrong job.
  //
  // HOW TO USE IN SCREEN:
  //   final newJob = await jobProvider.createJob(...);
  //   if (newJob == null) { /* handle error */ return; }
  //   // now safely use newJob.id
  // ==========================================
  Future<Job?> createJob({
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
    // NOTE: We intentionally do NOT pass technicianIds here anymore.
    // The create screen calls assignTechnicians() separately after getting
    // the new job's ID from this return value. This is safer because the
    // POST /api/jobs endpoint does not guarantee it processes technician_ids.
  }) async {
    _status = JobStatus.loading;
    _error = null;
    notifyListeners();

    try {
      final newJob = await _jobService.createJob(
        customerName: customerName,
        customerPhone: customerPhone,
        customerAddress: customerAddress,
        destinationLat: destinationLat, // ← NEW
        destinationLng: destinationLng, // ← NEW
        jobType: jobType,
        description: description,
        scheduledDate: scheduledDate,
        scheduledTimeStart: scheduledTimeStart,
        scheduledTimeEnd: scheduledTimeEnd,
        estimatedDurationMinutes: estimatedDurationMinutes,
        priority: priority,
        createdBy: createdBy,
        // No technicianIds passed — handled separately after creation
      );

      _jobs.insert(0, newJob);
      _status = JobStatus.success;
      notifyListeners();
      return newJob; // ← Return the actual job, not just true
    } catch (e) {
      _error = e.toString();
      _status = JobStatus.error;
      notifyListeners();
      return null; // ← null means failure, screens check for null
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
  //
  // FIX (Bug 3): Added forceOverride parameter.
  //
  // WHY: Admin users should be able to assign a driver even if that
  // driver has a conflicting job. When forceOverride is true, the backend
  // will first remove the driver from their conflicting job(s), then
  // assign them to the new job. Without this flag, the backend's conflict
  // check rejects the request regardless of who is making it.
  //
  // The flag is only sent to the backend when true to keep the payload
  // clean for normal (non-admin) assignments.
  // ==========================================
  Future<bool> assignTechnicians({
    required int jobId,
    required List<int> technicianIds,
    required int assignedBy,
    bool forceOverride = false, // ← NEW: admin-only force flag
  }) async {
    _error = null;

    try {
      await _jobService.assignTechnicians(
        jobId: jobId,
        technicianIds: technicianIds,
        assignedBy: assignedBy,
        forceOverride: forceOverride,
      );

      // Reload only this job — safe for all roles.
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

      // Optimistic update so the UI responds instantly
      final index = _jobs.indexWhere((j) => j.id == jobId);
      if (index != -1) {
        _jobs[index] = _jobs[index].copyWith(currentStatus: newStatus);
      }
      if (_selectedJob?.id == jobId) {
        _selectedJob = _selectedJob?.copyWith(currentStatus: newStatus);
      }

      // CRITICAL: Use addPostFrameCallback — NOT Future.microtask — to
      // schedule notifyListeners after a status update.
      //
      // WHY microtask is wrong:
      //   Microtasks run in the same event-loop turn, BEFORE the next I/O
      //   callback. Flutter's frame pipeline is driven by the engine calling
      //   into Dart via platform callbacks. When a dialog closes and this
      //   code runs, we are still inside the gesture/event callback that
      //   drove the "Confirm" button tap. The microtask queue drains BEFORE
      //   that callback returns to the engine, which means notifyListeners()
      //   fires while Flutter's build/layout/paint for the dialog-close Hero
      //   transition is still in progress. This causes every error in the
      //   cascade: Hero tag clash, dirty-widget-wrong-scope, RenderFlex ghost.
      //
      // WHY addPostFrameCallback is correct:
      //   SchedulerBinding guarantees this callback runs AFTER the current
      //   frame's build, layout, and paint phases are 100% complete — after
      //   the Hero transition has fully resolved, after the dialog subtree is
      //   fully torn down, after all dirty elements have been rebuilt.
      //   Only then does notifyListeners() schedule the NEXT frame's rebuild.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
        // Terminal statuses (cancelled/completed) never change again.
        // A background refresh would just fire another notifyListeners()
        // into a potentially mid-disposal widget tree.
        const terminalStatuses = {'cancelled', 'completed'};
        if (!terminalStatuses.contains(newStatus)) {
          _refreshJobSilently(jobId);
        }
      });

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ==========================================
  // UNASSIGN VEHICLE  (admin only)
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
  // DRIVER LOAD  (load balancing — Phase 03)
  // ==========================================
  List<Map<String, dynamic>> _driverLoadStats = [];
  List<Map<String, dynamic>> get driverLoadStats => _driverLoadStats;
  String _loadRange = 'weekly';
  String get loadRange => _loadRange;
  bool _loadingDriverStats = false;
  bool get loadingDriverStats => _loadingDriverStats;

  Future<void> fetchDriverLoad({String range = 'weekly'}) async {
    _loadRange = range;
    _loadingDriverStats = true;
    notifyListeners();
    try {
      _driverLoadStats = await _jobService.getDriverLoad(range: range);
    } catch (e) {
      _driverLoadStats = [];
    }
    _loadingDriverStats = false;
    notifyListeners();
  }

  Future<bool> completeJobWithGps({
    required int jobId,
    double? lat,
    double? lng,
    double? accuracyM,
    required String gpsStatus,
  }) async {
    try {
      await _jobService.completeJobWithGps(
        jobId: jobId,
        lat: lat,
        lng: lng,
        accuracyM: accuracyM,
        gpsStatus: gpsStatus,
      );
      await loadJobs(); // Refresh job list
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

  void setWeekendFilter(bool value) {
    _weekendFilter = value;
    notifyListeners();
  }

  void clearFilters() {
    _statusFilter = null;
    _typeFilter = null;
    _weekendFilter = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==========================================
  // PRIVATE HELPERS
  // ==========================================

  void _replaceJobInList(Job updated) {
    final index = _jobs.indexWhere((j) => j.id == updated.id);
    if (index != -1) _jobs[index] = updated;
  }

  Future<void> _reloadSingleJob(int jobId) async {
    try {
      final fresh = await _jobService.getJobById(jobId);
      if (fresh != null) {
        _replaceJobInList(fresh);
        if (_selectedJob?.id == jobId) _selectedJob = fresh;
        notifyListeners();
      }
    } catch (_) {
      // Non-fatal — optimistic update already happened
    }
  }

  void _refreshJobSilently(int jobId) {
    _jobService
        .getJobById(jobId)
        .then((fresh) {
          if (fresh != null) {
            bool changed = false;
            final index = _jobs.indexWhere((j) => j.id == fresh.id);
            if (index != -1 && _jobs[index].updatedAt != fresh.updatedAt) {
              _jobs[index] = fresh;
              changed = true;
            }
            if (_selectedJob?.id == jobId &&
                _selectedJob?.updatedAt != fresh.updatedAt) {
              _selectedJob = fresh;
              changed = true;
            }
            // Only notify if something actually changed to avoid
            // triggering a rebuild mid-frame after status updates.
            if (changed) notifyListeners();
          }
        })
        .catchError((_) {});
  }
}
