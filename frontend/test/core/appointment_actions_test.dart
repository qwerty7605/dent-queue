import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/appointment_actions.dart';

void main() {
  group('resolveAppointmentActions', () {
    test('admin gets status-based fallback actions', () {
      final List<AppointmentAction> actions = resolveAppointmentActions(
        <String, dynamic>{'status': 'Pending'},
        actorRole: 'admin',
      );

      expect(actions, <AppointmentAction>[
        AppointmentAction.approve,
        AppointmentAction.cancel,
      ]);
    });

    test('staff gets status-based fallback actions', () {
      final List<AppointmentAction> actions = resolveAppointmentActions(
        <String, dynamic>{'status': 'Approved'},
        actorRole: 'staff',
      );

      expect(actions, <AppointmentAction>[
        AppointmentAction.complete,
        AppointmentAction.cancel,
      ]);
    });

    test('api allowed_actions overrides fallback when present', () {
      final List<AppointmentAction> actions = resolveAppointmentActions(
        <String, dynamic>{
          'status': 'Pending',
          'allowed_actions': <String>['cancel'],
        },
        actorRole: 'admin',
      );

      expect(actions, <AppointmentAction>[AppointmentAction.cancel]);
    });

    test('non-admin/staff gets no actions', () {
      final List<AppointmentAction> actions = resolveAppointmentActions(
        <String, dynamic>{'status': 'Pending'},
        actorRole: 'patient',
      );

      expect(actions, isEmpty);
    });
  });
}
