import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/admin_profile_service.dart';
import 'package:frontend/services/base_service.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  Object? lastBody;

  @override
  Future<T> putJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    lastPath = path;
    lastBody = body;
    return mapper(nextResponse);
  }
}

void main() {
  late AdminProfileService adminProfileService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    adminProfileService = AdminProfileService(fakeBaseService);
  });

  test('updateProfile sends PUT request and maps response', () async {
    fakeBaseService.nextResponse = {
      'message': 'Admin profile updated'
    };

    final payload = {'first_name': 'Wayne'};
    final response = await adminProfileService.updateProfile(payload);

    expect(response['message'], 'Admin profile updated');
    expect(fakeBaseService.lastPath, contains('admin/profile'));
    expect((fakeBaseService.lastBody as Map)['first_name'], 'Wayne');
  });
}
