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
