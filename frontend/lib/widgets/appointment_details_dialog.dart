import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/appointment_status.dart';
import 'app_dialog_scaffold.dart';

class AppointmentDetailsDialog extends StatelessWidget {
  const AppointmentDetailsDialog({super.key, required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final String serviceType = appointment['service_type']?.toString() ?? 'Service';
    final String date = appointment['appointment_date']?.toString() ?? 'YYYY-MM-DD';
    final String time = _formatTime(appointment['appointment_time']?.toString());
    final AppointmentStatusVisual statusVisual = appointmentStatusVisual(
      appointment['status'],
    );
    final String queueNumber = _formatQueueNumber(
      _patientVisibleQueueNumber(),
    );

    return AppDialogScaffold(
      maxWidth: 420,
      alignment: Alignment.bottomCenter,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.fromLTRB(16, 80, 16, 10),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      bodyPadding: EdgeInsets.zero,
      headerContent: const SizedBox.shrink(),
      onClose: () => Navigator.of(context).pop(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(height: 4),
          Container(
            width: 46,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE8ECF5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FD),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.medical_services_rounded,
                  color: Color(0xFF223C7A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      serviceType,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF223C7A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: statusVisual.backgroundColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: statusVisual.borderColor),
                      ),
                      child: Text(
                        statusVisual.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                          color: statusVisual.foregroundColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: _InfoCard(
                  icon: Icons.calendar_today_outlined,
                  label: 'DATE',
                  value: _formatDate(date),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  icon: Icons.access_time_rounded,
                  label: 'TIME',
                  value: time,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            decoration: BoxDecoration(
              color: const Color(0xFF223C7A),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33223C7A),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'QUEUE NUMBER',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.2,
                          color: Color(0xFFC4D0F1),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '#$queueNumber',
                          maxLines: 1,
                          softWrap: false,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: Color(0xFF7187C5),
                    size: 34,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F6FB),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _statusSummary(statusVisual.label),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9AA4B6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? rawTime) {
    if (rawTime == null || rawTime.isEmpty) {
      return '--:--';
    }

    for (final String pattern in <String>['HH:mm:ss', 'HH:mm', 'h:mm a']) {
      try {
        return DateFormat('h:mm a').format(DateFormat(pattern).parse(rawTime));
      } catch (_) {
        continue;
      }
    }

    return rawTime;
  }

  String _formatDate(String dateStr) {
    final DateTime? parsed = DateTime.tryParse(dateStr);

    if (parsed == null) {
      return dateStr;
    }

    return DateFormat('MMM d, yyyy').format(parsed);
  }

  String _formatQueueNumber(String? queue) {
    if (queue == null || queue.trim().isEmpty) {
      return '--';
    }

    final int? parsed = int.tryParse(queue.trim());
    if (parsed == null) {
      return queue;
    }

    return parsed.toString().padLeft(2, '0');
  }

  String? _patientVisibleQueueNumber() {
    final String normalizedStatus = normalizeAppointmentStatus(appointment['status']);
    if (normalizedStatus != 'approved' && normalizedStatus != 'completed') {
      return null;
    }

    final String queue = appointment['queue_number']?.toString().trim() ?? '';
    return queue.isEmpty ? null : queue;
  }

  String _statusSummary(String statusLabel) {
    return switch (statusLabel) {
      'Cancelled' => 'Appointment Cancelled',
      'Completed' => 'Appointment Completed',
      'Approved' => 'Appointment Approved',
      'Cancelled by Doctor' => 'Appointment Cancelled by Doctor',
      'Reschedule Required' => 'Action Required for Appointment',
      _ => 'Appointment Pending',
    };
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FE),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: const Color(0xFF98A5BA)),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A97AD),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF223C7A),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
