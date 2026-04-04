import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/widgets/book_appointment_dialog.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {}

void main() {
  testWidgets('shows inline required errors when booking fields are empty', (
    WidgetTester tester,
  ) async {
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

    await tester.ensureVisible(find.text('Confirm Booking'));
    await tester.tap(find.text('Confirm Booking'));
    await tester.pump();

    expect(find.text('Required'), findsNWidgets(3));
  });
}
