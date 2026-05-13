import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/paginated_result.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/views/admin_master_list_view.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {
  int? updatedAppointmentId;
  String? updatedStatus;
  int pageCalls = 0;

  @override
  PaginatedResult<Map<String, dynamic>>? getCachedAdminMasterListPage({
    Map<String, String> filters = const <String, String>{},
    int page = 1,
    int perPage = 25,
    bool allowStale = false,
  }) {
    return null;
  }

  @override
  Future<PaginatedResult<Map<String, dynamic>>> getAdminMasterListPage({
    Map<String, String> filters = const <String, String>{},
    int page = 1,
    int perPage = 25,
  }) async {
    pageCalls += 1;
    return const PaginatedResult<Map<String, dynamic>>(
      items: <Map<String, dynamic>>[
        <String, dynamic>{
          'appointment_id': 42,
          'patient_name': 'Mia Cruz',
          'service': 'Teeth Cleaning',
          'date': '2026-05-13',
          'appointment_date': '2026-05-13',
          'appointment_time': '09:00',
          'contact': '09123456789',
          'status': 'Pending',
          'booking_type': 'Online Booking',
          'queue_number': '-',
        },
      ],
      currentPage: 1,
      perPage: 25,
      totalItems: 1,
      hasMorePages: false,
    );
  }

  @override
  Future<Map<String, dynamic>> updateAdminAppointmentStatus(
    int id,
    String status,
  ) async {
    updatedAppointmentId = id;
    updatedStatus = status;
    return <String, dynamic>{'message': 'Appointment status updated'};
  }
}

void main() {
  testWidgets('admin approval uses appointment_id from master list rows', (
    WidgetTester tester,
  ) async {
    final _FakeAppointmentService appointmentService =
        _FakeAppointmentService();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminMasterListView(appointmentService: appointmentService),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage appointment'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('APPROVE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Yes, Approve'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(appointmentService.updatedAppointmentId, 42);
    expect(appointmentService.updatedStatus, 'approved');
    expect(
      find.text('Unable to update status: invalid appointment ID.'),
      findsNothing,
    );

    await tester.tap(find.text('Return to Appointments'));
    await tester.pumpAndSettle();
  });
}
