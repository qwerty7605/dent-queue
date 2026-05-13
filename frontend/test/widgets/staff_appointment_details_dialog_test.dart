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

      final Dialog confirmationDialog = tester.widget<Dialog>(
        find.byType(Dialog).last,
      );

      expect(find.text('Approve Appointment?'), findsOneWidget);
      expect(confirmationDialog.constraints?.maxWidth, 380);
      expect(
        find.text(
          'Are you sure you want to approve this appointment for '
          'Dental Cleaning on Apr 20, 2026?',
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'No, Keep it'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Yes, Approve'),
        findsOneWidget,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Yes, Approve'));
      await tester.pumpAndSettle();

      expect(updaterCalled, isTrue);
    },
  );

  testWidgets('uses api allowed_actions when provided', (
    WidgetTester tester,
  ) async {
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
              'allowed_actions': <String>['cancel'],
            },
            actorRole: 'admin',
            onStatusUpdate: (_) async => true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('APPROVE'), findsNothing);
  });

  testWidgets('uses patient-style confirmation modal for cancellation', (
    WidgetTester tester,
  ) async {
    String? submittedStatus;

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
              'allowed_actions': <String>['cancel'],
            },
            actorRole: 'admin',
            onStatusUpdate: (String nextStatus) async {
              submittedStatus = nextStatus;
              return true;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    final Dialog confirmationDialog = tester.widget<Dialog>(
      find.byType(Dialog).last,
    );

    expect(find.text('Cancel Appointment?'), findsOneWidget);
    expect(confirmationDialog.constraints?.maxWidth, 380);
    expect(
      find.text(
        'Are you sure you want to cancel this appointment for '
        'Dental Cleaning on Apr 20, 2026?',
      ),
      findsOneWidget,
    );
    expect(find.widgetWithText(ElevatedButton, 'No, Keep it'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Yes, Cancel'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Yes, Cancel'));
    await tester.pumpAndSettle();

    expect(submittedStatus, 'cancelled');
  });
}
