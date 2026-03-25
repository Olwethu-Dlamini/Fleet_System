// ============================================
// FILE: lib/screens/time_management/time_extension_request_screen.dart
// PURPOSE: Driver/technician screen to request additional time on a job
// ============================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:vehicle_scheduling_app/providers/time_extension_provider.dart';

class TimeExtensionRequestScreen extends StatefulWidget {
  final int jobId;
  final String jobNumber;

  const TimeExtensionRequestScreen({
    super.key,
    required this.jobId,
    required this.jobNumber,
  });

  @override
  State<TimeExtensionRequestScreen> createState() =>
      _TimeExtensionRequestScreenState();
}

class _TimeExtensionRequestScreenState
    extends State<TimeExtensionRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _customMinutesController = TextEditingController();

  // Duration selection: 30 | 60 | 120 | -1 (custom)
  int _selectedMinutes = 30;
  bool _isCustom = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _customMinutesController.dispose();
    super.dispose();
  }

  // ── Duration presets ──────────────────────────────────────────────────────
  static const List<_DurationPreset> _presets = [
    _DurationPreset(label: '30 min', minutes: 30),
    _DurationPreset(label: '1 hour', minutes: 60),
    _DurationPreset(label: '2 hours', minutes: 120),
    _DurationPreset(label: 'Custom', minutes: -1),
  ];

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider =
        context.read<TimeExtensionProvider>();

    final success = await provider.submitRequest(
      jobId: widget.jobId,
      durationMinutes: _selectedMinutes,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Extension request submitted'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.error ?? 'Failed to submit request. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TimeExtensionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Request Time Extension',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.jobNumber,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .appBarTheme
                    .foregroundColor
                    ?.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Duration selector ─────────────────────────────────────────
            _SectionLabel(label: 'How much extra time do you need?'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _presets.map((preset) {
                final isSelected = preset.minutes == -1
                    ? _isCustom
                    : (!_isCustom && _selectedMinutes == preset.minutes);

                return ChoiceChip(
                  label: Text(preset.label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      if (preset.minutes == -1) {
                        _isCustom = true;
                        // Reset minutes until user enters a valid value
                        final parsed =
                            int.tryParse(_customMinutesController.text) ?? 0;
                        _selectedMinutes = parsed > 0 ? parsed : 0;
                      } else {
                        _isCustom = false;
                        _selectedMinutes = preset.minutes;
                      }
                    });
                  },
                );
              }).toList(),
            ),

            // ── Custom minutes input ──────────────────────────────────────
            if (_isCustom) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _customMinutesController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Custom duration',
                  suffixText: 'minutes',
                  hintText: 'Enter minutes (max 480)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) {
                  final parsed = int.tryParse(v) ?? 0;
                  setState(() => _selectedMinutes = parsed);
                },
                validator: (v) {
                  final mins = int.tryParse(v ?? '') ?? 0;
                  if (mins <= 0) return 'Enter a duration greater than 0';
                  if (mins > 480) return 'Maximum 480 minutes (8 hours)';
                  return null;
                },
              ),
            ],

            const SizedBox(height: 24),

            // ── Reason field ──────────────────────────────────────────────
            _SectionLabel(label: 'Reason for extension'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for extension',
                hintText: 'Explain why more time is needed...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (v) {
                if ((v ?? '').trim().length < 10) {
                  return 'Reason must be at least 10 characters';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ── Impact preview info card ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 16,
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Impact Preview: This request will be checked against all jobs for the same day involving your driver, technician team, and vehicle. The scheduler will see any conflicts before approving.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Submit button ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (provider.isLoading || _selectedMinutes <= 0)
                    ? null
                    : _submit,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Info note ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your request will be sent to the scheduler for approval. '
                      'They will review the impact on other jobs and decide.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Internal helpers ──────────────────────────────────────────────────────────

class _DurationPreset {
  final String label;
  final int minutes;
  const _DurationPreset({required this.label, required this.minutes});
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
