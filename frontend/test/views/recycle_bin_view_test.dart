import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/recycle_bin_entry.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/views/recycle_bin_view.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {
  final List<int> restoreCalls = <int>[];

  @override
  Future<Map<String, dynamic>> restoreAppointment(int id) async {
    restoreCalls.add(id);
    return <String, dynamic>{'message': 'restored'};
  }

  @override
  Future<List<Map<String, dynamic>>> getRecycleBinAppointments(
    bool isStaff,
  ) async {
    return <Map<String, dynamic>>[];
  }
}

void main() {
  testWidgets('renders recycle bin entries with restore and expired states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RecycleBinView(
          role: RecycleBinRole.staff,
          entries: [
            RecycleBinEntry(
              id: 10,
              service: 'Dental Cleaning',
              appointmentAt: DateTime(2026, 4, 20, 9, 30),
              deletedAt: DateTime(2026, 3, 30, 10, 0),
              statusLabel: 'Cancelled',
              isRestorable: true,
              expiresAt: DateTime(2026, 4, 5),
              patientName: 'Ava Stone',
              notes: 'Still inside the restore window.',
            ),
            RecycleBinEntry(
              id: 11,
              service: 'Root Canal Consultation',
              appointmentAt: DateTime(2026, 3, 28, 14, 0),
              deletedAt: DateTime(2026, 3, 20, 8, 45),
              statusLabel: 'Cancelled',
              isRestorable: false,
              expiresAt: DateTime(2026, 3, 26),
              patientName: 'Noah Lane',
              notes: 'Expired from restore eligibility.',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Recycle Bin'), findsOneWidget);
    expect(find.byKey(const Key('recycle-bin-list')), findsOneWidget);
    expect(find.text('Dental Cleaning'), findsOneWidget);
    expect(find.text('Ava Stone'), findsOneWidget);
    expect(
      find.byKey(const Key('recycle-bin-chip-available-10')),
      findsOneWidget,
    );
    await tester.drag(
      find.byKey(const Key('recycle-bin-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();

    expect(find.text('Root Canal Consultation'), findsOneWidget);
    expect(find.text('Noah Lane'), findsOneWidget);
    expect(
      find.byKey(const Key('recycle-bin-chip-expired-11')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recycle-bin-restore-area-10')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('recycle-bin-restore-area-11')),
      findsOneWidget,
    );
    expect(find.text('Restore Appointment'), findsOneWidget);
    expect(find.text('Restore expired'), findsOneWidget);
  });

  testWidgets('renders a clear recycle bin empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: RecycleBinView(
          role: RecycleBinRole.patient,
          entries: <RecycleBinEntry>[],
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('recycle-bin-empty-state')), findsOneWidget);
    expect(find.text('Recycle Bin is empty'), findsOneWidget);
    expect(
      find.textContaining('Cancelled appointments will appear here'),
      findsOneWidget,
    );
  });

  testWidgets('requires confirmation before restoring an appointment', (
    WidgetTester tester,
  ) async {
    final _FakeAppointmentService appointmentService =
        _FakeAppointmentService();

    await tester.pumpWidget(
      MaterialApp(
        home: RecycleBinView(
          role: RecycleBinRole.staff,
          appointmentService: appointmentService,
          entries: [
            RecycleBinEntry(
              id: 12,
              service: 'Dental Cleaning',
              appointmentAt: DateTime(2026, 4, 20, 9, 30),
              deletedAt: DateTime(2026, 3, 30, 10, 0),
              statusLabel: 'Cancelled',
              isRestorable: true,
              expiresAt: DateTime(2026, 4, 5),
              patientName: 'Ava Stone',
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('recycle-bin-list')),
      const Offset(0, -250),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore Appointment'));
    await tester.pumpAndSettle();

    expect(find.text('Restore Appointment?'), findsOneWidget);
    expect(find.text('Keep in Recycle Bin'), findsOneWidget);
    expect(appointmentService.restoreCalls, isEmpty);

    await tester.tap(find.byKey(const Key('recycle-bin-restore-confirm')));
    await tester.pumpAndSettle();

    expect(appointmentService.restoreCalls, <int>[12]);
  });
}
