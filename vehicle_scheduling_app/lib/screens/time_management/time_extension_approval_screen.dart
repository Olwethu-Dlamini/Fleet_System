// ============================================
// FILE: lib/screens/time_management/time_extension_approval_screen.dart
// PURPOSE: Scheduler-facing approval/denial screen for time extension requests
// Requirements: TIME-03, TIME-04, TIME-05, TIME-06, TIME-07
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/config/theme.dart';
import 'package:vehicle_scheduling_app/models/time_extension.dart';
import 'package:vehicle_scheduling_app/providers/time_extension_provider.dart';

class TimeExtensionApprovalScreen extends StatefulWidget {
  final int jobId;
  final int? requestId;

  const TimeExtensionApprovalScreen({
    super.key,
    required this.jobId,
    this.requestId,
  });

  @override
  State<TimeExtensionApprovalScreen> createState() =>
      _TimeExtensionApprovalScreenState();
}

class _TimeExtensionApprovalScreenState
    extends State<TimeExtensionApprovalScreen> {
  int? _selectedSuggestionId;
  // For custom suggestion: jobId -> {newStart, newEnd}
  List<Map<String, dynamic>> _customChanges = [];

  // Controllers for custom time inputs keyed by affected job ID
  final Map<int, TextEditingController> _startControllers = {};
  final Map<int, TextEditingController> _endControllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context
          .read<TimeExtensionProvider>()
          .loadActiveRequest(widget.jobId),
    );
    Future.microtask(
      () => context
          .read<TimeExtensionProvider>()
          .loadDaySchedule(widget.jobId),
    );
  }

  @override
  void dispose() {
    for (final c in _startControllers.values) {
      c.dispose();
    }
    for (final c in _endControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'denied':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  Color _suggestionTypeColor(String type) {
    switch (type) {
      case 'none':
        return Colors.green;
      case 'push':
        return Colors.blue;
      case 'reassign':
        return Colors.teal;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  // Build custom changes list from text field controllers for the custom suggestion
  void _rebuildCustomChanges(List<AffectedJob> affectedJobs) {
    _customChanges = affectedJobs.map((job) {
      return {
        'job_id': job.id,
        'new_start': _startControllers[job.id]?.text ?? '',
        'new_end': _endControllers[job.id]?.text ?? '',
      };
    }).toList();
  }

  // ── Deny dialog ───────────────────────────────────────────────────────────

  Future<void> _showDenyDialog(TimeExtensionRequest request) async {
    final reasonController = TextEditingController();
    final provider = context.read<TimeExtensionProvider>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deny Extension Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to deny this request?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Explain why the request was denied...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deny'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final reason = reasonController.text.trim();
    final success = await provider.denyRequest(
      request.id,
      reason: reason.isNotEmpty ? reason : null,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request denied')),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to deny request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Approve action ────────────────────────────────────────────────────────

  Future<void> _approve(
    TimeExtensionRequest request,
    List<AffectedJob> affectedJobs,
  ) async {
    final provider = context.read<TimeExtensionProvider>();

    // For custom suggestion, collect the changes from text fields
    final selectedSuggestion = provider.suggestions.firstWhere(
      (s) => s.id == _selectedSuggestionId,
      orElse: () => RescheduleOption(
        id: 0,
        requestId: 0,
        type: '',
        label: '',
        changes: [],
      ),
    );

    List<Map<String, dynamic>>? customChanges;
    if (selectedSuggestion.type == 'custom') {
      _rebuildCustomChanges(affectedJobs);
      customChanges = _customChanges;
    }

    final success = await provider.approveRequest(
      request.id,
      suggestionId: selectedSuggestion.type != 'custom'
          ? _selectedSuggestionId
          : null,
      customChanges: customChanges,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extension approved — schedule updated'),
        ),
      );
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to approve request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Extension Request'),
      ),
      body: Consumer<TimeExtensionProvider>(
        builder: (context, provider, _) {
          // Loading with no data yet
          if (provider.isLoading && provider.activeRequest == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // Error state
          if (provider.error != null && provider.activeRequest == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadActiveRequest(widget.jobId),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Empty state
          if (provider.activeRequest == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pending extension request for this job',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final request = provider.activeRequest!;
          final suggestions = provider.suggestions;
          final affectedJobs = provider.affectedJobs;

          // Auto-select recommended suggestion on first load
          if (_selectedSuggestionId == null && suggestions.isNotEmpty) {
            final recommended = suggestions.where((s) => s.recommended).toList();
            if (recommended.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _selectedSuggestionId = recommended.first.id);
              });
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── a. Request Info Card ──────────────────────────────────
                _RequestInfoCard(
                  request: request,
                  statusColor: _statusColor(request.status),
                ),
                const SizedBox(height: 16),

                // ── b. Impact Timeline Section ────────────────────────────
                _AffectedJobsSection(
                  affectedJobs: affectedJobs,
                  formatDateTime: _formatDateTime,
                ),
                const SizedBox(height: 16),

                // ── b2. Day Schedule Section ──────────────────────────────
                _DayScheduleSection(
                  personnel: provider.daySchedule,
                  date: provider.dayScheduleDate,
                  sourceJobId: widget.jobId,
                ),
                const SizedBox(height: 16),

                // ── c. Suggestion Cards ───────────────────────────────────
                _SuggestionCardsSection(
                  suggestions: suggestions,
                  selectedSuggestionId: _selectedSuggestionId,
                  onSuggestionSelected: (id) {
                    setState(() => _selectedSuggestionId = id);
                  },
                  suggestionTypeColor: _suggestionTypeColor,
                  formatDateTime: _formatDateTime,
                ),

                // ── Custom time inputs (shown when custom is selected) ────
                if (_selectedSuggestionId != null &&
                    suggestions
                            .firstWhere(
                              (s) => s.id == _selectedSuggestionId,
                              orElse: () => RescheduleOption(
                                id: 0,
                                requestId: 0,
                                type: '',
                                label: '',
                                changes: [],
                              ),
                            )
                            .type ==
                        'custom') ...[
                  const SizedBox(height: 16),
                  _CustomTimeInputsSection(
                    affectedJobs: affectedJobs,
                    startControllers: _startControllers,
                    endControllers: _endControllers,
                  ),
                ],
                const SizedBox(height: 24),

                // ── d. Action Buttons ─────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: provider.isLoading
                            ? null
                            : () => _showDenyDialog(request),
                        child: provider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.red,
                                ),
                              )
                            : const Text('Deny'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: provider.isLoading ||
                                _selectedSuggestionId == null
                            ? null
                            : () => _approve(request, affectedJobs.toList()),
                        child: provider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Approve'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Request Info Card ─────────────────────────────────────────────────────────

class _RequestInfoCard extends StatelessWidget {
  final TimeExtensionRequest request;
  final Color statusColor;

  const _RequestInfoCard({
    required this.request,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Extension of ${request.durationMinutes} min requested',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              request.reason,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Requested: ${_formatCreatedAt(request.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCreatedAt(DateTime dt) {
    final local = dt.toLocal();
    return '${local.day}/${local.month}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}

// ── Affected Jobs Section ─────────────────────────────────────────────────────

class _AffectedJobsSection extends StatelessWidget {
  final Iterable<AffectedJob> affectedJobs;
  final String Function(String?) formatDateTime;

  const _AffectedJobsSection({
    required this.affectedJobs,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final jobs = affectedJobs.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Affected Jobs',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${jobs.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (jobs.isEmpty)
          const Text(
            'No other jobs affected',
            style: TextStyle(color: Colors.grey),
          )
        else
          Card(
            elevation: 1,
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.work_outline, size: 20),
                  title: Text(
                    'Job #${job.jobNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        formatDateTime(job.currentStart),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        formatDateTime(job.currentEnd),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Suggestion Cards Section ──────────────────────────────────────────────────

class _SuggestionCardsSection extends StatelessWidget {
  final List<RescheduleOption> suggestions;
  final int? selectedSuggestionId;
  final ValueChanged<int?> onSuggestionSelected;
  final Color Function(String) suggestionTypeColor;
  final String Function(String?) formatDateTime;

  const _SuggestionCardsSection({
    required this.suggestions,
    required this.selectedSuggestionId,
    required this.onSuggestionSelected,
    required this.suggestionTypeColor,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rescheduling Options',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (suggestions.isEmpty)
          const Text(
            'No rescheduling options available',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...suggestions.map(
            (suggestion) => _SuggestionCard(
              suggestion: suggestion,
              isSelected: selectedSuggestionId == suggestion.id,
              onTap: () => onSuggestionSelected(suggestion.id),
              typeColor: suggestionTypeColor(suggestion.type),
              formatDateTime: formatDateTime,
            ),
          ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final RescheduleOption suggestion;
  final bool isSelected;
  final VoidCallback onTap;
  final Color typeColor;
  final String Function(String?) formatDateTime;

  const _SuggestionCard({
    required this.suggestion,
    required this.isSelected,
    required this.onTap,
    required this.typeColor,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 3 : 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: isSelected
            ? BorderSide(color: typeColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Radio<int>(
                    value: suggestion.id,
                    groupValue: isSelected ? suggestion.id : null,
                    onChanged: (_) => onTap(),
                    activeColor: typeColor,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          suggestion.label,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (suggestion.recommended)
                          Text(
                            'Recommended',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      suggestion.type.toUpperCase(),
                      style: TextStyle(
                        color: typeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (suggestion.type == 'custom') ...[
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 36),
                  child: Text(
                    'You will enter custom times below',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ] else if (suggestion.changes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: suggestion.changes.map((change) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              'Job #${change.jobNumber}:',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              formatDateTime(change.newStart),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              size: 12,
                              color: Colors.grey,
                            ),
                            Text(
                              formatDateTime(change.newEnd),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Day Schedule Section ──────────────────────────────────────────────────────

class _DayScheduleSection extends StatelessWidget {
  final List<DaySchedulePersonnel> personnel;
  final String? date;
  final int sourceJobId;

  const _DayScheduleSection({
    required this.personnel,
    required this.date,
    required this.sourceJobId,
  });

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    // raw is HH:MM:SS — display as HH:MM
    final parts = raw.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return raw;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = date != null && date!.isNotEmpty ? ' ($date)' : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Day Schedule$dateLabel',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        if (personnel.isEmpty)
          const Text(
            'No schedule data available',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...personnel.map((person) {
            final roleColor =
                person.role == 'driver' ? Colors.blue : Colors.green;

            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row: name + role badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: roleColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: roleColor.withOpacity(0.4),
                            ),
                          ),
                          child: Text(
                            person.role.toUpperCase(),
                            style: TextStyle(
                              color: roleColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Job list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: person.jobs.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final job = person.jobs[index];
                        final isSourceJob = job.id == sourceJobId;

                        return Container(
                          color: isSourceJob
                              ? Colors.yellow.withOpacity(0.15)
                              : null,
                          child: ListTile(
                            dense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            title: Row(
                              children: [
                                Text(
                                  'Job #${job.jobNumber}',
                                  style: TextStyle(
                                    fontWeight: isSourceJob
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                if (isSourceJob) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.amber.withOpacity(0.3),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'this job',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            subtitle: Row(
                              children: [
                                Text(
                                  '${_formatTime(job.scheduledTimeStart)} - ${_formatTime(job.scheduledTimeEnd)}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _statusColor(job.currentStatus)
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    job.currentStatus.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _statusColor(job.currentStatus),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ── Custom Time Inputs Section ────────────────────────────────────────────────

class _CustomTimeInputsSection extends StatelessWidget {
  final Iterable<AffectedJob> affectedJobs;
  final Map<int, TextEditingController> startControllers;
  final Map<int, TextEditingController> endControllers;

  const _CustomTimeInputsSection({
    required this.affectedJobs,
    required this.startControllers,
    required this.endControllers,
  });

  @override
  Widget build(BuildContext context) {
    final jobs = affectedJobs.toList();
    // Initialize controllers for any job that doesn't have them yet
    for (final job in jobs) {
      startControllers.putIfAbsent(job.id, () => TextEditingController());
      endControllers.putIfAbsent(job.id, () => TextEditingController());
    }

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter Custom Times',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Enter new times in HH:MM format (24-hour)',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ...jobs.map((job) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Job #${job.jobNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: startControllers[job.id],
                            decoration: const InputDecoration(
                              labelText: 'New Start',
                              hintText: 'HH:MM',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: endControllers[job.id],
                            decoration: const InputDecoration(
                              labelText: 'New End',
                              hintText: 'HH:MM',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
