// ============================================
// FILE: lib/widgets/job/driver_load_chip.dart
// PURPOSE: Reusable driver load indicator card for the assignment picker.
//          Shows job count, green glow on below-average drivers, and
//          a "Suggested" chip on the rank-1 (lowest load) driver.
// ============================================

import 'package:flutter/material.dart';

class DriverLoadCard extends StatelessWidget {
  /// Driver map from the /api/job-assignments/driver-load endpoint.
  /// Keys: id (int), full_name (String), job_count (int), rank (int),
  ///       below_average (bool)
  final Map<String, dynamic> driver;

  /// Whether this driver is currently selected as the primary driver.
  final bool isSelected;

  /// Called when the card is tapped.
  final VoidCallback onTap;

  /// Human-readable label for the current time range, e.g. "this week".
  final String rangeLabel;

  const DriverLoadCard({
    super.key,
    required this.driver,
    required this.isSelected,
    required this.onTap,
    required this.rangeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final bool belowAverage = driver['below_average'] == true;
    final bool isSuggested = (driver['rank'] as int?) == 1;
    final String fullName =
        (driver['full_name'] ?? driver['fullName'] ?? '').toString();
    final int jobCount = (driver['job_count'] as num?)?.toInt() ?? 0;

    // Determine border + shadow based on load status and selection state
    Color borderColor;
    Color? shadowColor;
    Color cardColor;

    if (isSelected) {
      borderColor = Theme.of(context).colorScheme.primary;
      shadowColor = null;
      cardColor = Theme.of(context).colorScheme.primary.withOpacity(0.08);
    } else if (belowAverage) {
      borderColor = Colors.green;
      shadowColor = Colors.green.withOpacity(0.3);
      cardColor = Colors.white;
    } else {
      borderColor = Colors.grey.shade300;
      shadowColor = null;
      cardColor = Colors.white;
    }

    // Initials from full name
    final initials = fullName.isNotEmpty
        ? fullName
            .split(' ')
            .where((w) => w.isNotEmpty)
            .take(2)
            .map((w) => w[0].toUpperCase())
            .join()
        : '?';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: (isSelected || belowAverage) ? 2 : 1,
          ),
          boxShadow: shadowColor != null
              ? [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: belowAverage
                ? Colors.green.withOpacity(0.15)
                : isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                    : Colors.grey.shade200,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: belowAverage
                    ? Colors.green.shade700
                    : isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade600,
              ),
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSuggested) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text(
                    'Suggested',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.green.shade100,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
          subtitle: Text(
            '$jobCount job${jobCount == 1 ? '' : 's'} ($rangeLabel)',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          trailing: isSelected
              ? Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 22,
                )
              : null,
        ),
      ),
    );
  }
}
