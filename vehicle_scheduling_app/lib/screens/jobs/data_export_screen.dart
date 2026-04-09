// ============================================
// FILE: lib/screens/jobs/data_export_screen.dart
// PURPOSE: Preview and export jobs data as CSV
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/job.dart';
import 'package:vehicle_scheduling_app/providers/job_provider.dart';
import 'package:vehicle_scheduling_app/services/csv_download.dart' as csv_dl;

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  String _statusFilter = 'All';

  static const _filterOptions = [
    'All',
    'Pending',
    'In Progress',
    'Completed',
    'Cancelled',
  ];

  /// Map display label to the backend status value
  static const _statusMap = {
    'All': null,
    'Pending': 'pending',
    'In Progress': 'in_progress',
    'Completed': 'completed',
    'Cancelled': 'cancelled',
  };

  List<Job> _filteredJobs(List<Job> allJobs) {
    final status = _statusMap[_statusFilter];
    if (status == null) return allJobs;
    return allJobs.where((j) => j.currentStatus == status).toList();
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _exportCsv(List<Job> jobs) {
    if (jobs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to export'),
          backgroundColor: AppTheme.warningColor,
        ),
      );
      return;
    }

    final buf = StringBuffer();
    buf.writeln('Job Number,Customer Name,Job Type,Scheduled Date,Status');
    for (final j in jobs) {
      buf.writeln(
        '"${j.jobNumber}","${j.customerName}","${j.jobType}","${_formatDate(j.scheduledDate)}","${j.currentStatus}"',
      );
    }

    final filterLabel = _statusFilter.toLowerCase().replaceAll(' ', '_');
    final filename = 'jobs_export_${filterLabel}_${_formatDate(DateTime.now())}.csv';

    try {
      csv_dl.downloadCsvFile(buf.toString(), filename);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported $filename'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.completedColor;
      case 'in_progress':
        return AppTheme.inProgressColor;
      case 'cancelled':
        return AppTheme.cancelledColor;
      case 'assigned':
        return AppTheme.assignedColor;
      case 'pending':
      default:
        return AppTheme.pendingColor;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'assigned':
        return 'Assigned';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allJobs = context.watch<JobProvider>().allJobs;
    final jobs = _filteredJobs(allJobs);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Export Data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: () => _exportCsv(jobs),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filter chips ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _filterOptions.map((label) {
                final selected = _statusFilter == label;
                return FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) => setState(() => _statusFilter = label),
                  selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  checkmarkColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? AppTheme.primaryColor
                        : AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Summary row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              '${jobs.length} job${jobs.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
          ),

          // ── Data table ────────────────────────────────────────
          Expanded(
            child: jobs.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined,
                            size: 48, color: AppTheme.textHint),
                        SizedBox(height: 12),
                        Text(
                          'No jobs match this filter',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppTheme.primaryColor.withValues(alpha: 0.08),
                        ),
                        columnSpacing: 20,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Job Number',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Customer',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Job Type',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Scheduled Date',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                        rows: jobs
                            .take(200) // cap preview to 200 rows
                            .map(
                              (j) => DataRow(cells: [
                                DataCell(Text(
                                  j.jobNumber,
                                  style: const TextStyle(fontSize: 13),
                                )),
                                DataCell(Text(
                                  j.customerName,
                                  style: const TextStyle(fontSize: 13),
                                )),
                                DataCell(Text(
                                  j.jobType,
                                  style: const TextStyle(fontSize: 13),
                                )),
                                DataCell(Text(
                                  _formatDate(j.scheduledDate),
                                  style: const TextStyle(fontSize: 13),
                                )),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _statusColor(j.currentStatus)
                                          .withValues(alpha: 0.12),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _statusLabel(j.currentStatus),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            _statusColor(j.currentStatus),
                                      ),
                                    ),
                                  ),
                                ),
                              ]),
                            )
                            .toList(),
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _exportCsv(jobs),
        icon: const Icon(Icons.download),
        label: const Text('Export CSV'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}
