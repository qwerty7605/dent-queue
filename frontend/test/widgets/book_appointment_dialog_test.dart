import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/widgets/book_appointment_dialog.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {}

void main() {
  testWidgets(
    'requires a service selection before advancing to the date step',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BookAppointmentDialog(
            appointmentService: _FakeAppointmentService(),
            asPage: true,
          ),
        ),
      );

      expect(find.text('Select Service'), findsOneWidget);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);

      final ElevatedButton continueButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continue to Date'),
      );
      expect(continueButton.onPressed, isNull);

      await tester.tap(find.text('Dental Check-up'));
      await tester.pumpAndSettle();

      final ElevatedButton enabledContinueButton = tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Continue to Date'),
          );
      expect(enabledContinueButton.onPressed, isNotNull);

      await tester.tap(find.text('Continue to Date'));
      await tester.pumpAndSettle();

      expect(find.text('Select Date'), findsOneWidget);
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
    },
  );
}
