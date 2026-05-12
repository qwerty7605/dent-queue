import 'appointment_status.dart';

enum AppointmentAction { approve, cancel, complete }

String appointmentActionStatusValue(AppointmentAction action) {
  return switch (action) {
    AppointmentAction.approve => 'approved',
    AppointmentAction.cancel => 'cancelled',
    AppointmentAction.complete => 'completed',
  };
}

List<AppointmentAction> resolveAppointmentActions(
  Map<String, dynamic> appointment, {
  required String actorRole,
}) {
  final String role = actorRole.trim().toLowerCase();
  final bool canManageStatuses = role == 'admin' || role == 'staff';
  if (!canManageStatuses) {
    return const <AppointmentAction>[];
  }

  final dynamic allowedRaw = appointment['allowed_actions'];
  if (allowedRaw is List) {
    final List<AppointmentAction> fromApi = allowedRaw
        .map((dynamic value) => _actionFromRaw(value?.toString()))
        .whereType<AppointmentAction>()
        .toList();
    if (fromApi.isNotEmpty) {
      return fromApi;
    }
  }

  final String status = normalizeAppointmentStatus(appointment['status']);
  return switch (status) {
    'pending' => const <AppointmentAction>[
      AppointmentAction.approve,
      AppointmentAction.cancel,
    ],
    'approved' => const <AppointmentAction>[
      AppointmentAction.complete,
      AppointmentAction.cancel,
    ],
    _ => const <AppointmentAction>[],
  };
}

AppointmentAction? _actionFromRaw(String? raw) {
  if (raw == null) {
    return null;
  }

  final String value = raw.trim().toLowerCase();
  return switch (value) {
    'approve' || 'approved' => AppointmentAction.approve,
    'cancel' || 'cancelled' || 'canceled' => AppointmentAction.cancel,
    'complete' || 'completed' => AppointmentAction.complete,
    _ => null,
  };
}
