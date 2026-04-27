import 'package:flutter/material.dart';

class AppointmentStatusVisual {
  const AppointmentStatusVisual({
    required this.key,
    required this.label,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
}

String normalizeAppointmentStatus(dynamic value) {
  final raw = value?.toString().trim().toLowerCase() ?? '';

  return switch (raw) {
    'approved' || 'confirmed' => 'approved',
    'completed' => 'completed',
    'cancelled' || 'canceled' => 'cancelled',
    'cancelled by doctor' || 'cancelled_by_doctor' => 'cancelled_by_doctor',
    'reschedule required' || 'reschedule_required' => 'reschedule_required',
    _ => 'pending',
  };
}

String appointmentStatusLabel(dynamic value) {
  return appointmentStatusVisual(value).label;
}

AppointmentStatusVisual appointmentStatusVisual(dynamic value) {
  final normalized = normalizeAppointmentStatus(value);

  return switch (normalized) {
    'approved' => const AppointmentStatusVisual(
      key: 'approved',
      label: 'Approved',
      icon: Icons.event_available_rounded,
      foregroundColor: Color(0xFF1D4ED8),
      backgroundColor: Color(0xFFEFF6FF),
      borderColor: Color(0xFFBFDBFE),
    ),
    'completed' => const AppointmentStatusVisual(
      key: 'completed',
      label: 'Completed',
      icon: Icons.check_circle_rounded,
      foregroundColor: Color(0xFF15803D),
      backgroundColor: Color(0xFFF0FDF4),
      borderColor: Color(0xFFBBF7D0),
    ),
    'cancelled' => const AppointmentStatusVisual(
      key: 'cancelled',
      label: 'Cancelled',
      icon: Icons.cancel_rounded,
      foregroundColor: Color(0xFFDC2626),
      backgroundColor: Color(0xFFFEF2F2),
      borderColor: Color(0xFFFECACA),
    ),
    'cancelled_by_doctor' => const AppointmentStatusVisual(
      key: 'cancelled_by_doctor',
      label: 'Cancelled by Doctor',
      icon: Icons.event_busy_rounded,
      foregroundColor: Color(0xFFB91C1C),
      backgroundColor: Color(0xFFFFE4E6),
      borderColor: Color(0xFFFDA4AF),
    ),
    'reschedule_required' => const AppointmentStatusVisual(
      key: 'reschedule_required',
      label: 'Reschedule Required',
      icon: Icons.update_rounded,
      foregroundColor: Color(0xFF92400E),
      backgroundColor: Color(0xFFFFF7ED),
      borderColor: Color(0xFFFCD34D),
    ),
    _ => const AppointmentStatusVisual(
      key: 'pending',
      label: 'Pending',
      icon: Icons.schedule_rounded,
      foregroundColor: Color(0xFFD97706),
      backgroundColor: Color(0xFFFFF7ED),
      borderColor: Color(0xFFFED7AA),
    ),
  };
}
