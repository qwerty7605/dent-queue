import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/core/paginated_result.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/notification_service.dart';
import 'package:frontend/models/app_notification.dart';
import 'package:frontend/views/staff_dashboard_view.dart';
import 'package:frontend/widgets/navigation_chrome.dart';

class _FakeAppointmentService extends Fake implements AppointmentService {
  int adminMasterListCalls = 0;
  int adminMasterListPageCalls = 0;
  int adminAppointmentsCalls = 0;
  int adminQueueCalls = 0;
  int recycleBinCalls = 0;

  @override
  void invalidateAppointmentCaches() {}

  @override
  Future<List<Map<String, dynamic>>> getAdminMasterList([
    Map<String, String> filters = const <String, String>{},
  ]) async {
    adminMasterListCalls += 1;
    return <Map<String, dynamic>>[];
  }

  @override
  Future<PaginatedResult<Map<String, dynamic>>> getAdminMasterListPage({
    Map<String, String> filters = const <String, String>{},
    int page = 1,
    int perPage = 25,
  }) async {
    adminMasterListPageCalls += 1;
    return const PaginatedResult<Map<String, dynamic>>(
      items: <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-05-10',
          'status': 'Approved',
          'booking_type': 'Online Booking',
          'patient_name': 'Casey Patient',
          'service': 'Dental Checkup',
          'queue_number': '04',
        },
      ],
      currentPage: 1,
      perPage: 25,
      totalItems: 1,
      hasMorePages: false,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAdminAppointmentsByDate(
    String date,
  ) async {
    adminAppointmentsCalls += 1;
    return <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> getAdminTodayQueue([
    String? date,
    bool forceRefresh = false,
  ]) async {
    adminQueueCalls += 1;
    return <String, dynamic>{};
  }

  @override
  Future<List<Map<String, dynamic>>> getRecycleBinAppointments(
    bool isStaff,
  ) async {
    recycleBinCalls += 1;
    return <Map<String, dynamic>>[];
  }
}

class _FakeAdminDashboardService extends Fake implements AdminDashboardService {
  int reportSummaryCalls = 0;
  final List<String> trendTypes = <String>[];

  @override
  void invalidateReportCaches() {}

  @override
  Future<Map<String, int>> getReportSummary([
    Map<String, String> filters = const <String, String>{},
    bool forceRefresh = false,
  ]) async {
    reportSummaryCalls += 1;
    return <String, int>{
      'total': 6,
      'report_records': 6,
      'pending': 2,
      'approved': 2,
      'completed': 1,
      'cancelled': 1,
      'cancelled_by_doctor': 0,
      'reschedule_required': 0,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getAppointmentTrends(
    String trendType, [
    Map<String, String> filters = const <String, String>{},
    bool forceRefresh = false,
  ]) async {
    trendTypes.add(trendType);
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'trend_type': trendType,
        'label': '2026-05-10',
        'count': 6,
      },
    ];
  }
}

class _FakeNotificationService extends Fake implements NotificationService {
  @override
  Future<NotificationListResult> getNotifications(
    String role, {
    bool forceRefresh = false,
  }) async {
    return const NotificationListResult(
      notifications: <AppNotification>[],
      unreadCount: 0,
    );
  }
}

void main() {
  testWidgets('staff navigation opens reports page with staff-safe data', (
    WidgetTester tester,
  ) async {
    final InMemoryTokenStorage tokenStorage = InMemoryTokenStorage();
    final _FakeAppointmentService appointmentService =
        _FakeAppointmentService();
    final _FakeAdminDashboardService adminDashboardService =
        _FakeAdminDashboardService();

    await tester.pumpWidget(
      MaterialApp(
        home: StaffDashboardView(
          userInfo: const <String, dynamic>{
            'first_name': 'Casey',
            'last_name': 'Staff',
            'role': <String, dynamic>{'name': 'Staff'},
          },
          tokenStorage: tokenStorage,
          onLogout: () {},
          loggingOut: false,
          appointmentService: appointmentService,
          adminDashboardService: adminDashboardService,
          notificationService: _FakeNotificationService(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('staff-nav-reports')), findsOneWidget);
    expect(
      tester
          .widget<AppNavigationDrawerItem>(
            find.byKey(const Key('staff-nav-reports')),
          )
          .selected,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('staff-nav-reports')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('staff-reports-tab')), findsOneWidget);
    expect(find.text('Clinic operations analytics'), findsOneWidget);
    expect(adminDashboardService.reportSummaryCalls, 1);
    expect(adminDashboardService.trendTypes, contains('monthly'));
    expect(appointmentService.adminMasterListPageCalls, 0);
    expect(find.text('Detailed Records'), findsNothing);
    expect(find.text('Casey Patient'), findsNothing);
    expect(find.text('Online Booking'), findsNothing);
    expect(find.byKey(const Key('report-export-button')), findsNothing);
  });
}
