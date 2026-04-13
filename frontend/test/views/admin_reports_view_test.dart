import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/short_term_cache.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/appointment_service.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/views/admin_reports_view.dart';
import 'package:http/http.dart' as http;

class _FakeBaseService extends Fake implements BaseService {
  _FakeBaseService({List<Map<String, dynamic>>? records})
    : records = records ?? _defaultRecords;

  static const List<Map<String, dynamic>> _defaultRecords =
      <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2026-04-01',
          'status': 'Approved',
          'booking_type': 'Online Booking',
          'patient_name': 'Ava Stone',
          'service': 'Dental Checkup',
          'queue_number': '01',
        },
        <String, dynamic>{
          'date': '2026-04-01',
          'status': 'Pending',
          'booking_type': 'Online Booking',
          'patient_name': 'Noah Lane',
          'service': 'Dental Checkup',
          'queue_number': '02',
        },
        <String, dynamic>{
          'date': '2026-04-02',
          'status': 'Approved',
          'booking_type': 'Online Booking',
          'patient_name': 'Mia Cruz',
          'service': 'Dental Checkup',
          'queue_number': '03',
        },
        <String, dynamic>{
          'date': '2026-04-08',
          'status': 'Completed',
          'booking_type': 'Walk-In Booking',
          'patient_name': 'Uma Reed',
          'service': 'Dental Cleaning',
          'queue_number': '04',
        },
        <String, dynamic>{
          'date': '2026-04-10',
          'status': 'Pending',
          'booking_type': 'Online Booking',
          'patient_name': 'Leo Hart',
          'service': 'Dental Checkup',
          'queue_number': '05',
        },
        <String, dynamic>{
          'date': '2026-05-03',
          'status': 'Cancelled',
          'booking_type': 'Walk-In Booking',
          'patient_name': 'Kai West',
          'service': 'Tooth Extraction',
          'queue_number': '-',
        },
      ];

  final List<Map<String, dynamic>> records;
  final List<String> requestedPaths = <String>[];
  final List<String> rawRequestedPaths = <String>[];
  Map<String, String>? lastRawHeaders;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    requestedPaths.add(path);
    final Uri uri = Uri.parse(path);
    final List<Map<String, dynamic>> filteredRecords = _filterRecords(
      uri.queryParameters,
    );

    if (path.contains('reports/summary')) {
      return mapper(<String, dynamic>{'data': _buildSummary(filteredRecords)});
    }

    if (path.contains('reports/trends')) {
      final String trendType = uri.queryParameters['trend_type'] ?? 'daily';

      return mapper(<String, dynamic>{
        'data': _buildTrends(filteredRecords, trendType),
      });
    }

    if (path.contains('master-list')) {
      final List<Map<String, dynamic>> sortedRecords = filteredRecords.toList()
        ..sort((Map<String, dynamic> a, Map<String, dynamic> b) {
          return (b['date'] as String).compareTo(a['date'] as String);
        });
      final int page = int.tryParse(uri.queryParameters['page'] ?? '') ?? 1;
      final int perPage =
          int.tryParse(uri.queryParameters['per_page'] ?? '') ??
          sortedRecords.length;
      final int startIndex = (page - 1) * perPage;
      final List<Map<String, dynamic>> pagedRecords =
          startIndex >= sortedRecords.length
          ? const <Map<String, dynamic>>[]
          : sortedRecords.skip(startIndex).take(perPage).toList();

      if (uri.queryParameters.containsKey('page') ||
          uri.queryParameters.containsKey('per_page')) {
        return mapper(<String, dynamic>{
          'data': pagedRecords,
          'meta': <String, dynamic>{
            'current_page': page,
            'per_page': perPage,
            'total': sortedRecords.length,
            'has_more_pages': startIndex + perPage < sortedRecords.length,
          },
        });
      }

      return mapper(<String, dynamic>{'data': sortedRecords});
    }

    return mapper(<String, dynamic>{});
  }

  @override
  Future<http.Response> getRaw(
    String path, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    rawRequestedPaths.add(path);
    lastRawHeaders = headers;

    return http.Response.bytes(
      <int>[1, 2, 3],
      200,
      headers: <String, String>{
        'content-disposition': 'attachment; filename=report-records.csv',
        'content-type': 'text/csv',
      },
    );
  }

  List<Map<String, dynamic>> _filterRecords(Map<String, String> query) {
    return records.where((Map<String, dynamic> record) {
      final String date = record['date'] as String;
      final String status = (record['status'] as String).toLowerCase();
      final String bookingType = (record['booking_type'] as String)
          .toLowerCase();
      final String? startDate = query['start_date'];
      final String? endDate = query['end_date'];
      final String? statusFilter = query['status']?.toLowerCase();
      final String? bookingTypeFilter = query['booking_type']?.toLowerCase();

      if (startDate != null && date.compareTo(startDate) < 0) {
        return false;
      }

      if (endDate != null && date.compareTo(endDate) > 0) {
        return false;
      }

      if (statusFilter != null && status != statusFilter) {
        return false;
      }

      if (bookingTypeFilter != null && bookingType != bookingTypeFilter) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<String, dynamic> _buildSummary(
    List<Map<String, dynamic>> filteredRecords,
  ) {
    int countByStatus(String status) {
      return filteredRecords
          .where((Map<String, dynamic> record) => record['status'] == status)
          .length;
    }

    return <String, dynamic>{
      'total_appointments': filteredRecords.length,
      'pending_count': countByStatus('Pending'),
      'approved_count': countByStatus('Approved'),
      'completed_count': countByStatus('Completed'),
      'cancelled_count': countByStatus('Cancelled'),
    };
  }

  List<Map<String, dynamic>> _buildTrends(
    List<Map<String, dynamic>> filteredRecords,
    String trendType,
  ) {
    final Map<String, int> buckets = <String, int>{};

    for (final Map<String, dynamic> record in filteredRecords) {
      final String label = _trendLabel(record['date'] as String, trendType);
      buckets[label] = (buckets[label] ?? 0) + 1;
    }

    final List<String> labels = buckets.keys.toList()..sort();
    return labels
        .map(
          (String label) => <String, dynamic>{
            'trend_type': trendType,
            'label': label,
            'count': buckets[label] ?? 0,
          },
        )
        .toList();
  }

  String _trendLabel(String date, String trendType) {
    switch (trendType) {
      case 'daily':
        return date;
      case 'weekly':
        return _isoWeekLabel(DateTime.parse(date));
      case 'monthly':
        final DateTime parsedDate = DateTime.parse(date);
        final String month = parsedDate.month.toString().padLeft(2, '0');
        return '${parsedDate.year}-$month';
      default:
        return date;
    }
  }

  String _isoWeekLabel(DateTime date) {
    final DateTime target = date.add(Duration(days: 4 - date.weekday));
    final DateTime firstThursday = DateTime(target.year, 1, 4);
    final DateTime firstWeekStart = firstThursday.subtract(
      Duration(days: firstThursday.weekday - 1),
    );
    final int weekNumber = 1 + target.difference(firstWeekStart).inDays ~/ 7;

    return '${target.year}-W${weekNumber.toString().padLeft(2, '0')}';
  }
}

void main() {
  setUp(() {
    ShortTermCache.clear();
  });

  testWidgets(
    'renders report filters with the supported status and booking type options',
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

      expect(find.byKey(const Key('report-filters-section')), findsOneWidget);
      expect(find.byKey(const Key('report-filter-start-date')), findsOneWidget);
      expect(find.byKey(const Key('report-filter-end-date')), findsOneWidget);
      expect(find.byKey(const Key('report-filter-status')), findsOneWidget);
      expect(
        find.byKey(const Key('report-filter-booking-type')),
        findsOneWidget,
      );
      expect(find.text('Filters Live'), findsOneWidget);
      expect(find.text('Prepared For API'), findsNothing);
      expect(find.text('Apply Filters'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);
      expect(find.textContaining('stored locally for now'), findsNothing);

      final Finder statusField = find.byKey(
        const Key('report-filter-status-field'),
      );
      await tester.ensureVisible(statusField);
      await tester.tap(statusField);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('report-filter-status-option-pending')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-filter-status-option-approved')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-filter-status-option-completed')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('report-filter-status-option-cancelled')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('report-filter-status-option-approved')),
      );
      await tester.pumpAndSettle();

      final Finder bookingTypeField = find.byKey(
        const Key('report-filter-booking-type-field'),
      );
      await tester.ensureVisible(bookingTypeField);
      await tester.tap(bookingTypeField);
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const Key('report-filter-booking-type-option-online-booking'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('report-filter-booking-type-option-walk-in-booking'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'applies and resets report filters against backend-backed reports data',
    (WidgetTester tester) async {
      final _FakeBaseService baseService = _FakeBaseService();
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

      expect(find.text('Uma Reed'), findsOneWidget);
      expect(find.text('Kai West'), findsOneWidget);
      expect(
        baseService.requestedPaths,
        contains('/api/v1/admin/reports/summary'),
      );

      final Finder statusField = find.byKey(
        const Key('report-filter-status-field'),
      );
      await tester.ensureVisible(statusField);
      await tester.tap(statusField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('report-filter-status-option-approved')),
      );
      await tester.pumpAndSettle();

      final Finder bookingTypeField = find.byKey(
        const Key('report-filter-booking-type-field'),
      );
      await tester.ensureVisible(bookingTypeField);
      await tester.tap(bookingTypeField);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const Key('report-filter-booking-type-option-online-booking'),
        ),
      );
      await tester.pumpAndSettle();

      final Finder applyButton = find.byKey(const Key('report-filter-apply'));
      await tester.ensureVisible(applyButton);
      await tester.tap(applyButton);
      await tester.pumpAndSettle();

      expect(
        baseService.requestedPaths,
        contains(
          '/api/v1/admin/reports/summary?status=Approved&booking_type=Online+Booking',
        ),
      );
      expect(
        baseService.requestedPaths,
        contains(
          '/api/v1/admin/reports/trends?trend_type=daily&status=Approved&booking_type=Online+Booking',
        ),
      );
      expect(
        baseService.requestedPaths,
        contains(
          '/api/v1/admin/appointments/master-list?status=Approved&booking_type=Online+Booking&page=1&per_page=25',
        ),
      );
      expect(find.text('Ava Stone'), findsOneWidget);
      expect(find.text('Mia Cruz'), findsOneWidget);
      expect(find.text('Uma Reed'), findsNothing);
      expect(find.text('Kai West'), findsNothing);
      expect(find.text('2026-04-10'), findsNothing);

      await tester.tap(find.byKey(const Key('report-filter-reset')));
      await tester.pumpAndSettle();

      expect(
        baseService.requestedPaths.where(
          (String path) => path == '/api/v1/admin/reports/summary',
        ),
        isNotEmpty,
      );
      expect(find.text('Uma Reed'), findsOneWidget);
      expect(find.text('Kai West'), findsOneWidget);
    },
  );

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
      expect(find.text('2026-04-01'), findsWidgets);
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

  testWidgets('exports the same filtered report data currently shown on screen', (
    WidgetTester tester,
  ) async {
    final _FakeBaseService baseService = _FakeBaseService();
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

    final Finder statusField = find.byKey(
      const Key('report-filter-status-field'),
    );
    await tester.ensureVisible(statusField);
    await tester.tap(statusField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('report-filter-status-option-approved')),
    );
    await tester.pumpAndSettle();

    final Finder bookingTypeField = find.byKey(
      const Key('report-filter-booking-type-field'),
    );
    await tester.ensureVisible(bookingTypeField);
    await tester.tap(bookingTypeField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('report-filter-booking-type-option-online-booking')),
    );
    await tester.pumpAndSettle();

    final Finder applyButton = find.byKey(const Key('report-filter-apply'));
    await tester.ensureVisible(applyButton);
    await tester.tap(applyButton);
    await tester.pumpAndSettle();

    final Finder exportButton = find.byKey(const Key('report-export-button'));
    await tester.ensureVisible(exportButton);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(
      find.text('Current report filters will be exported'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Choose the file format. The export will use the same filters applied to the report table.',
      ),
      findsOneWidget,
    );

    final Finder exportDialog = find.byType(AlertDialog);
    await tester.tap(
      find.descendant(
        of: exportDialog,
        matching: find.widgetWithText(FilledButton, 'Export'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      baseService.rawRequestedPaths,
      contains(
        '/api/v1/admin/reports/export?status=Approved&booking_type=Online+Booking&format=csv',
      ),
    );
    expect(baseService.lastRawHeaders, <String, String>{'Accept': 'text/csv'});
  });

  testWidgets('renders empty trends state safely when api returns no points', (
    WidgetTester tester,
  ) async {
    final BaseService baseService = _FakeBaseService(
      records: const <Map<String, dynamic>>[],
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

  testWidgets(
    'skips detailed records requests when the detailed table is hidden',
    (WidgetTester tester) async {
      final _FakeBaseService baseService = _FakeBaseService();
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
              showDetailedRecords: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        baseService.requestedPaths.where(
          (String path) => path.contains('master-list'),
        ),
        isEmpty,
      );
      expect(find.text('Detailed Records'), findsNothing);
    },
  );

  testWidgets('loads more detailed records a page at a time', (
    WidgetTester tester,
  ) async {
    final List<Map<String, dynamic>> records =
        List<Map<String, dynamic>>.generate(
          30,
          (int index) => <String, dynamic>{
            'date': '2026-04-${(index % 28 + 1).toString().padLeft(2, '0')}',
            'status': 'Approved',
            'booking_type': 'Online Booking',
            'patient_name': 'Patient ${index + 1}',
            'service': 'Dental Checkup',
            'queue_number': (index + 1).toString().padLeft(2, '0'),
          },
        );
    final _FakeBaseService baseService = _FakeBaseService(records: records);
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

    expect(find.text('Showing 25 of 30 records'), findsOneWidget);
    expect(find.byKey(const Key('admin-reports-load-more')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('admin-reports-load-more')),
    );
    await tester.tap(find.byKey(const Key('admin-reports-load-more')));
    await tester.pumpAndSettle();

    expect(
      baseService.requestedPaths,
      contains('/api/v1/admin/appointments/master-list?page=2&per_page=25'),
    );
    expect(find.text('Showing all 30 records'), findsOneWidget);
  });
}
