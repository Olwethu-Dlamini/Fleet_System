// ============================================
// FILE: lib/screens/jobs/jobs_list_screen.dart
// PURPOSE: Jobs list — role-aware create/edit access
//   admin / scheduler → can create jobs, see all
//   technician/driver → sees ONLY their assigned jobs (my-jobs), read-only
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/providers/auth_provider.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/screens/jobs/job_detail_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/create_job_screen.dart';
import 'package:vehicle_scheduling_app/screens/jobs/edit_job_screen.dart';

class JobsListScreen extends StatefulWidget {
  const JobsListScreen({super.key});

  @override
  State<JobsListScreen> createState() => _JobsListScreenState();
}

class _JobsListScreenState extends State<JobsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) _loadJobs();
    });
  }

  // Drivers/technicians call loadMyJobs() — only their jobs.
  // Admins and schedulers call loadJobs() — all jobs.
  void _loadJobs() {
    final auth = context.read<AuthProvider>();
    final provider = context.read<JobProvider>();
    if (auth.isTechnician) {
      provider.loadMyJobs();
    } else {
      provider.loadJobs();
    }
  }

  void _refreshJobs() {
    if (mounted) _loadJobs();
  }

  @override
  Widget build(BuildContext context) {
    final jobProvider = context.watch<JobProvider>();
    final auth = context.watch<AuthProvider>();

    // Technicians can only update status — no create permission
    final canCreate = auth.hasPermission('jobs:create');

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(auth.isTechnician ? 'My Jobs' : 'Jobs'),
        automaticallyImplyLeading: false,
        actions: [
          // Filter only relevant for admin/scheduler (full job list)
          if (!auth.isTechnician)
            PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filter by status',
              onSelected: (value) {
                if (mounted) context.read<JobProvider>().setStatusFilter(value);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: null, child: Text('All Jobs')),
                const PopupMenuItem(value: 'pending', child: Text('Pending')),
                const PopupMenuItem(value: 'assigned', child: Text('Assigned')),
                const PopupMenuItem(
                  value: 'in_progress',
                  child: Text('In Progress'),
                ),
                const PopupMenuItem(
                  value: 'completed',
                  child: Text('Completed'),
                ),
                const PopupMenuItem(
                  value: 'cancelled',
                  child: Text('Cancelled'),
                ),
              ],
            ),
          // DASH-02: Weekend filter toggle (admin/scheduler only)
          if (!auth.isTechnician)
            IconButton(
              icon: Icon(
                Icons.weekend_outlined,
                color: jobProvider.weekendFilter
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              tooltip: jobProvider.weekendFilter
                  ? 'Show all jobs'
                  : 'Show weekend jobs only',
              onPressed: () {
                context
                    .read<JobProvider>()
                    .setWeekendFilter(!jobProvider.weekendFilter);
              },
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshJobs),
        ],
      ),
      body: Column(
        children: [
          // Active filter indicator (admin/scheduler only)
          if (!auth.isTechnician && jobProvider.statusFilter != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppTheme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Text(
                    'Filtered: ${jobProvider.statusFilter!.replaceAll('_', ' ').toUpperCase()}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      if (mounted) context.read<JobProvider>().clearFilters();
                    },
                    child: const Icon(
                      Icons.close,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

          // DASH-02: Weekend filter active indicator
          if (!auth.isTechnician && jobProvider.weekendFilter)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  const Icon(Icons.weekend, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Showing weekend jobs only',
                    style: TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () =>
                        context.read<JobProvider>().setWeekendFilter(false),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
            ),

          // Technician info banner
          if (auth.isTechnician)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF0D9488).withOpacity(0.08),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 15,
                    color: Color(0xFF0D9488),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Showing your assigned jobs  •  Tap a job to update status',
                    style: TextStyle(fontSize: 12, color: Color(0xFF0D9488)),
                  ),
                ],
              ),
            ),

          // Job count bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  '${jobProvider.jobs.length} job${jobProvider.jobs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                _statusChip(
                  '${jobProvider.pendingCount} pending',
                  AppTheme.pendingColor,
                ),
                const SizedBox(width: 6),
                _statusChip(
                  '${jobProvider.inProgressCount} active',
                  AppTheme.inProgressColor,
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: jobProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : jobProvider.error != null
                ? _buildError(jobProvider.error!)
                : jobProvider.jobs.isEmpty
                ? _buildEmpty(canCreate, auth.isTechnician)
                : RefreshIndicator(
                    onRefresh: () async {
                      if (mounted) _loadJobs();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: jobProvider.jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobProvider.jobs[index];
                        final color = AppTheme.getStatusColor(
                          job.currentStatus,
                        );

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => JobDetailScreen(job: job),
                                ),
                              );
                              _refreshJobs();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: color.withOpacity(
                                          0.15,
                                        ),
                                        child: Icon(
                                          AppTheme.getJobTypeIcon(job.jobType),
                                          color: color,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              job.jobNumber,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              job.typeDisplayName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          job.statusDisplayName,
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      // Edit button — admin/scheduler only
                                      if (canCreate) ...[
                                        const SizedBox(width: 4),
                                        InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    EditJobScreen(job: job),
                                              ),
                                            );
                                            _refreshJobs();
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(6),
                                            child: Icon(
                                              Icons.edit_outlined,
                                              size: 18,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const Divider(height: 16),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline,
                                        size: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        job.customerName,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: AppTheme.textSecondary,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${job.formattedDate}  •  ${job.formattedTimeRange}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (job.vehicleName != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.local_shipping,
                                          size: 14,
                                          color: AppTheme.primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          job.vehicleName!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  // Show assigned drivers/technicians using
                                  // the Job model's built-in technicianNames getter
                                  if (job.technicians.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.group_outlined,
                                          size: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            job.technicianNames,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.textSecondary,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),

      // Create FAB — only for admin / scheduler
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag:
                  'jobs_list_fab', // ← fix: unique tag prevents heroes conflict
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateJobScreen()),
                );
                _refreshJobs();
              },
              icon: const Icon(Icons.add),
              label: const Text('New Job'),
            )
          : null,
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildError(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 60, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(error, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshJobs,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool canCreate, bool isTechnician) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.work_off_outlined,
            size: 60,
            color: AppTheme.textHint,
          ),
          const SizedBox(height: 16),
          const Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isTechnician
                ? 'You have no jobs assigned to you yet'
                : canCreate
                ? 'Tap + to create a new job'
                : 'No jobs have been assigned yet',
            style: const TextStyle(color: AppTheme.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
