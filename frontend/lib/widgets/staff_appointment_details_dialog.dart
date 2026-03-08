import 'package:flutter/material.dart';

class StaffAppointmentDetailsDialog extends StatelessWidget {
  const StaffAppointmentDetailsDialog({super.key, required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final patientName = _readValue('patient_name', fallback: 'Patient');
    final serviceType = _readValue('service_type', fallback: 'Service');
    final formattedDate = _formatDate(
      appointment['appointment_date']?.toString() ?? '',
    );
    final formattedTime = _formatTime(
      appointment['time']?.toString() ??
          appointment['appointment_time']?.toString() ??
          '',
    );
    final status = _normalizeStatus(appointment['status']);
    final queueNumber = _formatQueueNumber(appointment['queue_number']);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Appointment Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: const Color(0xFF64748B),
                    tooltip: 'Close',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusBackground(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _DetailBlock(label: 'PATIENT NAME', value: patientName),
              const SizedBox(height: 14),
              _DetailBlock(label: 'SERVICE TYPE', value: serviceType),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DetailBlock(label: 'DATE', value: formattedDate),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailBlock(label: 'TIME', value: formattedTime),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _DetailBlock(
                      label: 'STATUS',
                      value: _statusLabel(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DetailBlock(
                      label: 'QUEUE NUMBER',
                      value: '#$queueNumber',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _readValue(String key, {required String fallback}) {
    final value = appointment[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _normalizeStatus(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? '';
    if (raw == 'approved' || raw == 'confirmed') {
      return 'approved';
    }
    if (raw == 'completed') {
      return 'completed';
    }
    if (raw == 'cancelled') {
      return 'cancelled';
    }
    return 'pending';
  }

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => 'APPROVED',
      'completed' => 'COMPLETED',
      'cancelled' => 'CANCELLED',
      _ => 'PENDING',
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => const Color(0xFF1D4ED8),
      'completed' => const Color(0xFF16A34A),
      'cancelled' => const Color(0xFFDC2626),
      _ => const Color(0xFFF59E0B),
    };
  }

  Color _statusBackground(String status) {
    return switch (status) {
      'approved' => const Color(0xFFEFF5FF),
      'completed' => const Color(0xFFEFFCF3),
      'cancelled' => const Color(0xFFFFF0F0),
      _ => const Color(0xFFFFF7DF),
    };
  }

  String _formatQueueNumber(dynamic value) {
    final queue = _parseQueueNumber(value);
    if (queue >= 9999) {
      return '--';
    }
    return queue.toString().padLeft(2, '0');
  }

  int _parseQueueNumber(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return 9999;
    }
    return int.tryParse(value.toString()) ?? 9999;
  }

  String _formatTime(String rawTime) {
    final trimmed = rawTime.trim();
    if (trimmed.isEmpty) {
      return '--:--';
    }
    final parts = trimmed.split(':');
    if (parts.length < 2) {
      return trimmed;
    }
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) {
      return 'N/A';
    }

    final parts = trimmed.split('-');
    if (parts.length == 3) {
      final year = parts[0];
      final monthIndex = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (monthIndex != null &&
          day != null &&
          monthIndex >= 1 &&
          monthIndex <= 12) {
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
        return '${months[monthIndex - 1]} $day, $year';
      }
    }

    return trimmed;
  }
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
