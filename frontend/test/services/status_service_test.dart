import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/status_service.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/models/status_response.dart';

class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;

  @override
  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    return mapper(nextResponse);
  }
}

void main() {
  late StatusService statusService;
  late FakeBaseService fakeBaseService;

  setUp(() {
    fakeBaseService = FakeBaseService();
    statusService = StatusService(fakeBaseService);
  });

  test('getStatus resolves models', () async {
    fakeBaseService.nextResponse = {
      'status': 'success',
      'message': 'API is running'
    };

    final StatusResponse response = await statusService.getStatus();

    expect(response.status, 'success');
  });
}
