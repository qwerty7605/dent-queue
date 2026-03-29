import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/base_service.dart';

class _FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    lastPath = path;
    return mapper(nextResponse);
  }
}

void main() {
  late _FakeBaseService fakeBaseService;
  late AdminDashboardService adminDashboardService;

  setUp(() {
    fakeBaseService = _FakeBaseService();
    adminDashboardService = AdminDashboardService(fakeBaseService);
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
          .getAppointmentTrends('weekly');

      expect(
        fakeBaseService.lastPath,
        '/api/v1/admin/reports/trends?trend_type=weekly',
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
}
