import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/widgets/reschedule_appointment_dialog.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {
  String? lastAvailabilityDate;
  int? lastIgnoredAppointmentId;
  int? lastRescheduledAppointmentId;
  Map<String, dynamic>? lastReschedulePayload;

  @override
  Future<Map<String, dynamic>> getAvailabilitySlots(
    String date, {
    int? ignoreAppointmentId,
  }) async {
    lastAvailabilityDate = date;
    lastIgnoredAppointmentId = ignoreAppointmentId;

    return <String, dynamic>{
      'slots': <Map<String, dynamic>>[
        <String, dynamic>{
          'time': '10:00',
          'time_label': '10:00 AM',
          'status': 'available',
        },
        <String, dynamic>{
          'time': '10:30',
          'time_label': '10:30 AM',
          'status': 'available',
        },
        <String, dynamic>{
          'time': '11:00',
          'time_label': '11:00 AM',
          'status': 'booked',
        },
      ],
      'unavailable_ranges': const <Map<String, dynamic>>[],
    };
  }

  @override
  Future<Map<String, dynamic>> rescheduleAppointment(
    int id,
    Map<String, dynamic> payload,
  ) async {
    lastRescheduledAppointmentId = id;
    lastReschedulePayload = Map<String, dynamic>.from(payload);

    return <String, dynamic>{
      'appointment': <String, dynamic>{
        'id': id,
        'appointment_date': payload['appointment_date'],
        'appointment_time': payload['time_slot'],
        'status': 'Approved',
      },
    };
  }
}

void main() {
  testWidgets(
    'reschedule page loads appointment availability and saves an approved schedule',
    (WidgetTester tester) async {
      final _FakeAppointmentService appointmentService =
          _FakeAppointmentService();

      await tester.pumpWidget(
        MaterialApp(
          home: RescheduleAppointmentDialog(
            asPage: true,
            appointmentService: appointmentService,
            appointment: const <String, dynamic>{
              'id': 55,
              'appointment_date': '2026-05-10',
              'appointment_time': '10:00',
              'notes': 'Bring x-rays',
              'status': 'Reschedule Required',
            },
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(appointmentService.lastAvailabilityDate, '2026-05-10');
      expect(appointmentService.lastIgnoredAppointmentId, 55);
      expect(
        find.byKey(const Key('reschedule-appointment-page')),
        findsOneWidget,
      );
      expect(
        find.text('Current schedule: 2026-05-10 at 10:00 AM'),
        findsOneWidget,
      );

      ElevatedButton submitButton = tester.widget(
        find.widgetWithText(ElevatedButton, 'Confirm New Schedule'),
      );
      expect(submitButton.onPressed, isNull);

      await tester.tap(find.byType(InputDecorator));
      await tester.pumpAndSettle();

      expect(find.text('Set Time'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('SELECTED TIME: 10:30 AM'), findsOneWidget);

      await tester.tap(find.text('Set Time'));
      await tester.pumpAndSettle();

      submitButton = tester.widget(
        find.widgetWithText(ElevatedButton, 'Confirm New Schedule'),
      );
      expect(submitButton.onPressed, isNotNull);

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Confirm New Schedule'),
      );
      await tester.pumpAndSettle();

      expect(appointmentService.lastRescheduledAppointmentId, 55);
      expect(
        appointmentService.lastReschedulePayload?['appointment_date'],
        '2026-05-10',
      );
      expect(appointmentService.lastReschedulePayload?['time_slot'], '10:30');
      expect(
        appointmentService.lastReschedulePayload?['notes'],
        'Bring x-rays',
      );
      expect(
        find.text('Appointment Rescheduled\nSuccessfully!'),
        findsOneWidget,
      );
      expect(find.text('APPOINTMENT STATUS'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
    },
  );
}
