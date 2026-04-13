import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_staff_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  int getJsonCallCount = 0;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    getJsonCallCount += 1;
    lastPath = path;
    return mapper(nextResponse);
  }
}

void main() {
  late AdminStaffService adminStaffService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    adminStaffService = AdminStaffService(fakeBaseService);
    adminStaffService.invalidateStaffCache();
  });

  test('getStaffPage should request a bounded page and map metadata', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {'id': 8, 'first_name': 'Jamie', 'last_name': 'Stone'},
      ],
      'meta': {
        'current_page': 1,
        'per_page': 25,
        'total': 40,
        'has_more_pages': true,
      },
    };

    final page = await adminStaffService.getStaffPage();

    expect(page.items, hasLength(1));
    expect(page.items.first['id'], 8);
    expect(page.currentPage, 1);
    expect(page.perPage, 25);
    expect(page.totalItems, 40);
    expect(page.hasMorePages, isTrue);
    expect(fakeBaseService.lastPath, '/api/v1/admin/staff?page=1&per_page=25');
  });

  test('getStaffPage uses cache until invalidated', () async {
    fakeBaseService.nextResponse = {
      'data': [
        {'id': 3, 'first_name': 'Taylor'},
      ],
      'meta': {
        'current_page': 1,
        'per_page': 25,
        'total': 25,
        'has_more_pages': false,
      },
    };

    final first = await adminStaffService.getStaffPage();
    final second = await adminStaffService.getStaffPage();

    expect(first.items, hasLength(1));
    expect(second.items, hasLength(1));
    expect(fakeBaseService.getJsonCallCount, 1);

    adminStaffService.invalidateStaffCache();
    await adminStaffService.getStaffPage();

    expect(fakeBaseService.getJsonCallCount, 2);
  });
}
