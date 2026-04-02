import 'package:flutter/material.dart';

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
    final normalizedStatus = _normalizeStatus(appointment['status']);

    String statusText = 'PENDING';
    Color statusColor = const Color(0xFFE8C355);
    Color statusBgColor = const Color(0xFFFFF7EF);

    if (normalizedStatus == 'approved') {
      statusText = 'APPROVED';
      statusColor = Colors.blue;
      statusBgColor = const Color(0xFFF1F7FF);
    } else if (normalizedStatus == 'completed') {
      statusText = 'COMPLETED';
      statusColor = Colors.green;
      statusBgColor = const Color(0xFFF1FFF7);
    } else if (normalizedStatus == 'cancelled') {
      statusText = 'CANCELLED';
      statusColor = Colors.redAccent;
      statusBgColor = const Color(0xFFFFF1F1);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Appointment Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2C3E50),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Service Type
            const Text(
              'SERVICE TYPE',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7E8CA0),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              serviceType,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
            ),
            const SizedBox(height: 24),

            // Date and Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'DATE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7E8CA0),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(date),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIME',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7E8CA0),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time, // It's already basically HH:MM, could format more if needed
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Notes
            const Text(
              'NOTES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Color(0xFF7E8CA0),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              appointment['notes']?.toString().isNotEmpty == true
                  ? appointment['notes'].toString()
                  : 'No notes provided',
              style: const TextStyle(fontSize: 16, color: Color(0xFF2C3E50)),
            ),
            const SizedBox(height: 32),

            // Close Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF679B6A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
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

  String _normalizeStatus(dynamic value) {
    final raw = value?.toString().trim().toLowerCase() ?? '';

    if (raw == 'approved' || raw == 'confirmed') {
      return 'approved';
    }
    if (raw == 'completed') {
      return 'completed';
    }
    if (raw == 'cancelled' || raw == 'canceled') {
      return 'cancelled';
    }

    return 'pending';
  }
}
