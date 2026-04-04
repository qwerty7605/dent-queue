import 'package:flutter/material.dart';

import '../core/appointment_status.dart';

class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final dynamic status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = appointmentStatusVisual(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: visual.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            visual.icon,
            size: compact ? 14 : 16,
            color: visual.foregroundColor,
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            visual.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: visual.foregroundColor,
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
