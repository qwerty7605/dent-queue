import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/views/admin_reports_view.dart';

class _FakeBaseService extends Fake implements BaseService {
  _FakeBaseService({Map<String, List<Map<String, dynamic>>>? trendsByType})
    : trendsByType = trendsByType ?? _defaultTrendsByType;

  static const Map<String, List<Map<String, dynamic>>> _defaultTrendsByType =
      <String, List<Map<String, dynamic>>>{
        'daily': <Map<String, dynamic>>[
          <String, dynamic>{
            'trend_type': 'daily',
            'label': '2026-04-01',
            'count': 4,
          },
          <String, dynamic>{
            'trend_type': 'daily',
            'label': '2026-04-02',
            'count': 2,
          },
        ],
        'weekly': <Map<String, dynamic>>[
          <String, dynamic>{
            'trend_type': 'weekly',
            'label': '2026-W14',
            'count': 9,
          },
          <String, dynamic>{
            'trend_type': 'weekly',
            'label': '2026-W15',
            'count': 7,
          },
        ],
        'monthly': <Map<String, dynamic>>[
          <String, dynamic>{
            'trend_type': 'monthly',
            'label': '2026-04',
            'count': 16,
          },
        ],
      };

  final Map<String, List<Map<String, dynamic>>> trendsByType;

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

    if (path.contains('reports/trends')) {
      final String trendType =
          Uri.parse(path).queryParameters['trend_type'] ?? 'daily';

      return mapper(<String, dynamic>{
        'data': trendsByType[trendType] ?? const <Map<String, dynamic>>[],
      });
    }

    if (path.contains('master-list')) {
      return mapper(<String, dynamic>{'data': <Map<String, dynamic>>[]});
    }

    return mapper(<String, dynamic>{});
  }
}

void main() {
  testWidgets(
    'loads appointment trends from the api and switches daily weekly monthly views',
    (WidgetTester tester) async {
      final BaseService baseService = _FakeBaseService();
      final AdminDashboardService adminDashboardService = AdminDashboardService(
        baseService,
      );
      final AppointmentService appointmentService = AppointmentService(
        baseService,
      );

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
      expect(find.text('Daily view'), findsOneWidget);
      expect(find.text('2026-04-01'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      final Finder weeklyToggle = find.byKey(
        const Key('appointment-trends-weekly'),
      );
      await tester.ensureVisible(weeklyToggle);
      await tester.tap(weeklyToggle);
      await tester.pumpAndSettle();

      expect(find.text('Weekly view'), findsOneWidget);
      expect(find.text('Appointments per week'), findsOneWidget);
      expect(find.text('2026-W14'), findsOneWidget);

      final Finder monthlyToggle = find.byKey(
        const Key('appointment-trends-monthly'),
      );
      await tester.ensureVisible(monthlyToggle);
      await tester.tap(monthlyToggle);
      await tester.pumpAndSettle();

      expect(find.text('Monthly view'), findsOneWidget);
      expect(find.text('Appointments per month'), findsOneWidget);
      expect(find.text('2026-04'), findsOneWidget);
    },
  );

  testWidgets('renders empty trends state safely when api returns no points', (
    WidgetTester tester,
  ) async {
    final BaseService baseService = _FakeBaseService(
      trendsByType: const <String, List<Map<String, dynamic>>>{
        'daily': <Map<String, dynamic>>[],
      },
    );
    final AdminDashboardService adminDashboardService = AdminDashboardService(
      baseService,
    );
    final AppointmentService appointmentService = AppointmentService(
      baseService,
    );

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

    expect(
      find.text('No appointment trend data available yet.'),
      findsOneWidget,
    );
    expect(find.text('No data'), findsOneWidget);
    expect(find.byKey(const Key('appointment-trends-chart')), findsOneWidget);
  });
}
