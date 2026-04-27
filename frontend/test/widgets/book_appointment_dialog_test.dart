import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/widgets/book_appointment_dialog.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {}

void main() {
  testWidgets(
    'shows the current step action and prevents moving forward without a service',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BookAppointmentDialog(
              appointmentService: _FakeAppointmentService(),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Continue to Date'), findsOneWidget);
      expect(find.text('Confirm Booking'), findsNothing);

      final ElevatedButton button = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );
      expect(button.onPressed, isNull);
      expect(find.text('Required'), findsNothing);
    },
  );
}
