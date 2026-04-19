import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/appointment_status.dart';
import 'package:frontend/widgets/appointment_status_badge.dart';

void main() {
  test('maps supported statuses to the shared icon and color palette', () {
    final pending = appointmentStatusVisual('pending');
    expect(pending.key, 'pending');
    expect(pending.label, 'Pending');
    expect(pending.icon, Icons.schedule_rounded);
    expect(pending.foregroundColor, const Color(0xFFD97706));
    expect(pending.backgroundColor, const Color(0xFFFFF7ED));

    final approved = appointmentStatusVisual('confirmed');
    expect(approved.key, 'approved');
    expect(approved.label, 'Approved');
    expect(approved.icon, Icons.event_available_rounded);
    expect(approved.foregroundColor, const Color(0xFF1D4ED8));
    expect(approved.backgroundColor, const Color(0xFFEFF6FF));

    final completed = appointmentStatusVisual('completed');
    expect(completed.key, 'completed');
    expect(completed.label, 'Completed');
    expect(completed.icon, Icons.check_circle_rounded);
    expect(completed.foregroundColor, const Color(0xFF15803D));
    expect(completed.backgroundColor, const Color(0xFFF0FDF4));

    final cancelled = appointmentStatusVisual('canceled');
    expect(cancelled.key, 'cancelled');
    expect(cancelled.label, 'Cancelled');
    expect(cancelled.icon, Icons.cancel_rounded);
    expect(cancelled.foregroundColor, const Color(0xFFDC2626));
    expect(cancelled.backgroundColor, const Color(0xFFFEF2F2));

    final cancelledByDoctor = appointmentStatusVisual('cancelled_by_doctor');
    expect(cancelledByDoctor.key, 'cancelled_by_doctor');
    expect(cancelledByDoctor.label, 'Cancelled by Doctor');
    expect(cancelledByDoctor.icon, Icons.event_busy_rounded);

    final rescheduleRequired = appointmentStatusVisual('Reschedule Required');
    expect(rescheduleRequired.key, 'reschedule_required');
    expect(rescheduleRequired.label, 'Reschedule Required');
    expect(rescheduleRequired.icon, Icons.update_rounded);
  });

  testWidgets('renders the status icon together with the text label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppointmentStatusBadge(status: 'Pending', compact: true),
              AppointmentStatusBadge(status: 'Approved', compact: true),
              AppointmentStatusBadge(status: 'Completed', compact: true),
              AppointmentStatusBadge(status: 'Cancelled', compact: true),
              AppointmentStatusBadge(
                status: 'Cancelled by Doctor',
                compact: true,
              ),
              AppointmentStatusBadge(
                status: 'Reschedule Required',
                compact: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancelled by Doctor'), findsOneWidget);
    expect(find.text('Reschedule Required'), findsOneWidget);
    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(find.byIcon(Icons.event_available_rounded), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byIcon(Icons.event_busy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.update_rounded), findsOneWidget);
  });
}
