import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/staff_appointment_details_dialog.dart';

void main() {
  testWidgets(
    'uses action-specific confirmation labels for appointment status updates',
    (WidgetTester tester) async {
      bool updaterCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffAppointmentDetailsDialog(
              appointment: <String, dynamic>{
                'patient_name': 'Ava Stone',
                'service_type': 'Dental Cleaning',
                'appointment_date': '2026-04-20',
                'time': '09:00',
                'status': 'Pending',
                'queue_number': 1,
                'notes': '',
              },
              onStatusUpdate: (String nextStatus) async {
                updaterCalled = nextStatus == 'approved';
                return true;
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('APPROVE'), findsOneWidget);

      await tester.tap(find.text('APPROVE'));
      await tester.pumpAndSettle();

      expect(find.text('Keep Status'), findsOneWidget);
      expect(
        find.text('Are you sure you want to approve this appointment?'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(FilledButton, 'Approve Appointment'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(FilledButton, 'Approve Appointment'),
      );
      await tester.pumpAndSettle();

      expect(updaterCalled, isTrue);
    },
  );
}
