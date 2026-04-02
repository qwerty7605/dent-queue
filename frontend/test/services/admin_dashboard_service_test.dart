import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/base_service.dart';
import 'package:http/http.dart' as http;

class _FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  http.Response? nextRawResponse;
  String? lastPath;
  Map<String, String>? lastHeaders;
  int getJsonCallCount = 0;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    getJsonCallCount += 1;
    lastPath = path;
    return mapper(nextResponse);
  }

  @override
  Future<http.Response> getRaw(
    String path, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    lastPath = path;
    lastHeaders = headers;
    return nextRawResponse ??
        http.Response('', 200, headers: <String, String>{});
  }
}

void main() {
  late _FakeBaseService fakeBaseService;
  late AdminDashboardService adminDashboardService;

  setUp(() {
    fakeBaseService = _FakeBaseService();
    adminDashboardService = AdminDashboardService(fakeBaseService);
    adminDashboardService.invalidateReportCaches();
  });

  test('getReportSummary requests the summary endpoint with filters', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'data': <String, dynamic>{
        'total_appointments': 2,
        'pending_count': 0,
        'approved_count': 2,
        'completed_count': 0,
        'cancelled_count': 0,
      },
    };

    final Map<String, int> result = await adminDashboardService
        .getReportSummary(<String, String>{
          'status': 'Approved',
          'booking_type': 'Online Booking',
        });

    expect(
      fakeBaseService.lastPath,
      '/api/v1/admin/reports/summary?status=Approved&booking_type=Online+Booking',
    );
    expect(result['total'], 2);
    expect(result['approved'], 2);
  });

  test('getReportSummary uses a short-term cache until invalidated', () async {
    fakeBaseService.nextResponse = <String, dynamic>{
      'data': <String, dynamic>{
        'total_appointments': 4,
        'pending_count': 1,
        'approved_count': 2,
        'completed_count': 1,
        'cancelled_count': 0,
      },
    };

    final Map<String, int> first = await adminDashboardService
        .getReportSummary(<String, String>{'status': 'Approved'});
    final Map<String, int> second = await adminDashboardService
        .getReportSummary(<String, String>{'status': 'Approved'});

    expect(first, second);
    expect(fakeBaseService.getJsonCallCount, 1);

    adminDashboardService.invalidateReportCaches();

    await adminDashboardService.getReportSummary(<String, String>{
      'status': 'Approved',
    });

    expect(fakeBaseService.getJsonCallCount, 2);
  });

  test(
    'getAppointmentTrends requests the trends endpoint and maps rows',
    () async {
      fakeBaseService.nextResponse = <String, dynamic>{
        'data': <Map<String, dynamic>>[
          <String, dynamic>{
            'trend_type': 'weekly',
            'label': '2026-W14',
            'count': 3,
          },
          <String, dynamic>{
            'trend_type': 'weekly',
            'label': '2026-W15',
            'count': 5,
          },
        ],
      };

      final List<Map<String, dynamic>> result = await adminDashboardService
          .getAppointmentTrends('weekly', <String, String>{
            'start_date': '2026-04-01',
            'end_date': '2026-04-30',
          });

      expect(
        fakeBaseService.lastPath,
        '/api/v1/admin/reports/trends?trend_type=weekly&start_date=2026-04-01&end_date=2026-04-30',
      );
      expect(result, hasLength(2));
      expect(result.first['label'], '2026-W14');
      expect(result.last['count'], 5);
    },
  );

  test(
    'getAppointmentTrends returns an empty list when payload is missing',
    () async {
      fakeBaseService.nextResponse = <String, dynamic>{'data': null};

      final List<Map<String, dynamic>> result = await adminDashboardService
          .getAppointmentTrends('monthly');

      expect(result, isEmpty);
    },
  );

  test(
    'exportDetailedRecords requests the export endpoint with the format',
    () async {
      fakeBaseService.nextRawResponse = http.Response.bytes(
        <int>[1, 2, 3],
        200,
        headers: <String, String>{
          'content-disposition': 'attachment; filename=report-records.pdf',
          'content-type': 'application/pdf',
        },
      );

      final ReportExportFile result = await adminDashboardService
          .exportDetailedRecords(ReportExportFormat.pdf, <String, String>{
            'status': 'Approved',
          });

      expect(
        fakeBaseService.lastPath,
        '/api/v1/admin/reports/export?status=Approved&format=pdf',
      );
      expect(fakeBaseService.lastHeaders, <String, String>{
        'Accept': 'application/pdf',
      });
      expect(result.filename, 'report-records.pdf');
      expect(result.contentType, 'application/pdf');
      expect(result.bytes, <int>[1, 2, 3]);
    },
  );
}
