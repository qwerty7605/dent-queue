import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/views/admin_reports_view.dart';

class _FakeBaseService extends Fake implements BaseService {
  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    if (path.contains('reports/summary')) {
      return mapper(<String, dynamic>{
        'data': <String, dynamic>{
          'total_appointments': 0,
          'pending_count': 0,
          'approved_count': 0,
          'completed_count': 0,
          'cancelled_count': 0,
        },
      });
    }

    if (path.contains('master-list')) {
      return mapper(<String, dynamic>{'data': <Map<String, dynamic>>[]});
    }

    return mapper(<String, dynamic>{});
  }
}

void main() {
  late BaseService baseService;
  late AdminDashboardService adminDashboardService;
  late AppointmentService appointmentService;

  setUp(() {
    baseService = _FakeBaseService();
    adminDashboardService = AdminDashboardService(baseService);
    appointmentService = AppointmentService(baseService);
  });

  testWidgets(
    'renders appointment trends section and switches daily weekly monthly views',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminReportsView(
              adminDashboardService: adminDashboardService,
              appointmentService: appointmentService,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Appointment Trends'), findsOneWidget);
      expect(find.byKey(const Key('appointment-trends-chart')), findsOneWidget);
      expect(find.text('Chart is ready for API integration.'), findsOneWidget);
      expect(find.text('Daily view'), findsOneWidget);

      final Finder weeklyToggle = find.byKey(
        const Key('appointment-trends-weekly'),
      );
      await tester.ensureVisible(weeklyToggle);
      await tester.tap(weeklyToggle);
      await tester.pumpAndSettle();

      expect(find.text('Weekly view'), findsOneWidget);
      expect(find.text('Appointments per week'), findsOneWidget);

      final Finder monthlyToggle = find.byKey(
        const Key('appointment-trends-monthly'),
      );
      await tester.ensureVisible(monthlyToggle);
      await tester.tap(monthlyToggle);
      await tester.pumpAndSettle();

      expect(find.text('Monthly view'), findsOneWidget);
      expect(find.text('Appointments per month'), findsOneWidget);
    },
  );
}
