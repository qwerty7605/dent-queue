import 'package:flutter/material.dart';

import 'app_dialog_scaffold.dart';
import 'appointment_status_badge.dart';

class AppointmentDetailsDialog extends StatelessWidget {
  final Map<String, dynamic> appointment;

  const AppointmentDetailsDialog({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final serviceType = appointment['service_type']?.toString() ?? 'Service';
    final date = appointment['appointment_date']?.toString() ?? 'YYYY-MM-DD';
    String formattedTime = '--:--';
    final rawTime = appointment['appointment_time']?.toString() ?? '--:--';
    if (rawTime != '--:--') {
      try {
        final parts = rawTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts.length > 1 ? parts[1] : '00';
        final amPm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        formattedTime = '$displayHour:$minute $amPm';
      } catch (e) {
        formattedTime = rawTime;
      }
    }
    final time = formattedTime;
    return AppDialogScaffold(
      title: 'Appointment Details',
      onClose: () => Navigator.of(context).pop(),
      headerTrailing: AppointmentStatusBadge(
        status: appointment['status'],
        compact: true,
      ),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A769E),
            elevation: 0,
          ),
          child: const Text('Close'),
        ),
      ),
      showFooterDivider: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailBlock(label: 'SERVICE TYPE', value: serviceType, large: true),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DetailBlock(label: 'DATE', value: _formatDate(date)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailBlock(label: 'TIME', value: time),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _DetailBlock(
            label: 'NOTES',
            value: appointment['notes']?.toString().isNotEmpty == true
                ? appointment['notes'].toString()
                : 'No notes provided',
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    // Example input: 2026-03-19 -> Feb 28, 2026 (based on design, we format it nicely)
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final year = parts[0];
        final monthIdx = int.parse(parts[1]) - 1;
        final day = int.parse(
          parts[2],
        ).toString(); // remove leading zero if any

        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        final monthStr = (monthIdx >= 0 && monthIdx < 12)
            ? months[monthIdx]
            : parts[1];

        return '$monthStr $day, $year';
      }
    } catch (e) {
      // ignore
    }
    return dateStr;
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({
    required this.label,
    required this.value,
    this.large = false,
  });

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7E8CA0),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 18 : 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF2C3E50),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
