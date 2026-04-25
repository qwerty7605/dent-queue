import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/appointment_clock_picker.dart';

void main() {
  testWidgets('time picker modal only cycles through available slots', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    final BuildContext context = tester.element(find.byType(SizedBox));

    final Future<String?> result = showAppointmentTimePickerModal(
      context: context,
      slots: const <Map<String, dynamic>>[
        <String, dynamic>{
          'time': '08:00',
          'time_label': '8:00 AM',
          'status': 'available',
        },
        <String, dynamic>{
          'time': '08:30',
          'time_label': '8:30 AM',
          'status': 'booked',
        },
        <String, dynamic>{
          'time': '09:00',
          'time_label': '9:00 AM',
          'status': 'available',
        },
      ],
      selectedTimeSlot: null,
      isSlotDisabled: (Map<String, dynamic> slot) =>
          slot['status']?.toString() != 'available',
      unavailableRanges: const <Map<String, dynamic>>[],
      title: 'Choose Appointment Time',
    );

    await tester.pumpAndSettle();

    expect(find.text('Choose Appointment Time'), findsOneWidget);
    expect(find.text('SELECTED TIME: 8:00 AM'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    await tester.pumpAndSettle();

    expect(find.text('SELECTED TIME: 9:00 AM'), findsOneWidget);

    await tester.tap(find.text('Set Time'));
    await tester.pumpAndSettle();

    expect(await result, '09:00');
  });

  testWidgets('time picker modal explains afternoon-only doctor availability', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
    );

    final BuildContext context = tester.element(find.byType(SizedBox));

    showAppointmentTimePickerModal(
      context: context,
      slots: const <Map<String, dynamic>>[
        <String, dynamic>{
          'time': '08:00',
          'time_label': '8:00 AM',
          'status': 'doctor_unavailable',
        },
        <String, dynamic>{
          'time': '08:30',
          'time_label': '8:30 AM',
          'status': 'doctor_unavailable',
        },
        <String, dynamic>{
          'time': '13:00',
          'time_label': '1:00 PM',
          'status': 'available',
        },
      ],
      selectedTimeSlot: null,
      isSlotDisabled: (Map<String, dynamic> slot) =>
          slot['status']?.toString() != 'available',
      unavailableRanges: const <Map<String, dynamic>>[
        <String, dynamic>{
          'start_time': '08:00',
          'end_time': '12:00',
          'reason': 'Morning only unavailable',
        },
      ],
      title: 'Choose Appointment Time',
    );

    await tester.pumpAndSettle();

    expect(
      find.text('Doctor is only available this afternoon.'),
      findsOneWidget,
    );
  });
}
