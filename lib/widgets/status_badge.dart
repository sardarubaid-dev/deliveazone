// lib/widgets/status_badge.dart
import 'package:flutter/material.dart';
import 'package:deliveazone_driver_app/utils/helpers.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool isRescheduled;
  final DateTime? rescheduledDate;
  final bool small;

  const StatusBadge({
    super.key,
    required this.status,
    this.isRescheduled = false,
    this.rescheduledDate,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = Helpers.getStatusColor(status);
    String label = Helpers.getStatusLabel(status);
    
    if (status == 'failed' && isRescheduled) {
      if (rescheduledDate != null) {
        label = 'Rescheduled: ${Helpers.formatDate(rescheduledDate!)}';
      } else {
        label = 'Failed (Rescheduled)';
      }
    }

    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
