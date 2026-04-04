import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/appointment_queue_order.dart';

void main() {
  test('orders appointments by date and time before queue number', () {
    final List<Map<String, dynamic>> appointments = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 3,
        'appointment_date': '2026-04-08',
        'time': '09:00',
        'queue_number': 1,
      },
      <String, dynamic>{
        'id': 1,
        'appointment_date': '2026-04-07',
        'time': '10:00',
        'queue_number': 9,
      },
      <String, dynamic>{
        'id': 2,
        'appointment_date': '2026-04-07',
        'time': '08:30',
        'queue_number': 5,
      },
    ];

    appointments.sort(compareAppointmentQueueDisplayOrder);

    expect(
      appointments.map((Map<String, dynamic> item) => item['id']).toList(),
      <dynamic>[2, 1, 3],
    );
  });

  test('uses timestamp_created to break same-time ties', () {
    final List<Map<String, dynamic>> appointments = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'appointment_date': '2026-04-07',
        'time': '09:00',
        'timestamp_created': '2026-04-01T07:45:00Z',
      },
      <String, dynamic>{
        'id': 1,
        'appointment_date': '2026-04-07',
        'time': '09:00',
        'timestamp_created': '2026-04-01T07:30:00Z',
      },
    ];

    appointments.sort(compareAppointmentQueueDisplayOrder);

    expect(
      appointments.map((Map<String, dynamic> item) => item['id']).toList(),
      <dynamic>[1, 2],
    );
  });

  test('normalizes 12-hour and 24-hour time formats consistently', () {
    final List<Map<String, dynamic>> appointments = <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 2,
        'appointment_date': '2026-04-07',
        'appointment_time': '10:00 AM',
      },
      <String, dynamic>{
        'id': 1,
        'appointment_date': '2026-04-07',
        'time': '09:30:00',
      },
    ];

    appointments.sort(compareAppointmentQueueDisplayOrder);

    expect(
      appointments.map((Map<String, dynamic> item) => item['id']).toList(),
      <dynamic>[1, 2],
    );
  });
}
