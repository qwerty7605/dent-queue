import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_dashboard_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    lastPath = path;
    return mapper(nextResponse);
  }
}

void main() {
  late AdminDashboardService adminDashboardService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    adminDashboardService = AdminDashboardService(fakeBaseService);
  });

  test('getStats should fetch and parse dashboard statistics', () async {
    fakeBaseService.nextResponse = {
      'data': {
        'patients_count': 100,
        'staff_count': 5,
        'appointments_count': 25,
      }
    };

    final stats = await adminDashboardService.getStats();

    expect(stats['patients_count'], 100);
    expect(stats['staff_count'], 5);
    expect(stats['appointments_count'], 25);
    expect(fakeBaseService.lastPath, contains('stats'));
  });
}
