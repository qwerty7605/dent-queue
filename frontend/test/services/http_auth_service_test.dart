import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/services/http_auth_service.dart';
import 'package:frontend/services/base_service.dart';
import 'package:frontend/core/token_storage.dart';

// Use a Fake class for a more reliable mock without code generation
class FakeBaseService extends Fake implements BaseService {
  dynamic nextResponse;
  String? lastPath;
  Object? lastBody;

  @override
  Future<T> postJson<T>(String path, Object? body, T Function(dynamic json) mapper) async {
    lastPath = path;
    lastBody = body;
    return mapper(nextResponse);
  }
}

class FakeTokenStorage extends Fake implements TokenStorage {
  String? lastWrittenToken;
  Map<String, dynamic>? lastWrittenUserInfo;

  @override
  Future<void> writeToken(String token) async {
    lastWrittenToken = token;
  }
  
  @override
  Future<void> writeUserInfo(Map<String, dynamic> userInfo) async {
    lastWrittenUserInfo = userInfo;
  }
}

void main() {
  late HttpAuthService authService;
  late FakeBaseService fakeBaseService;
  late FakeTokenStorage fakeTokenStorage;

  setUp(() {
    fakeBaseService = FakeBaseService();
    fakeTokenStorage = FakeTokenStorage();
    authService = HttpAuthService(fakeBaseService, fakeTokenStorage);
  });

  test('login should write token and user info on success', () async {
    fakeBaseService.nextResponse = {
      'data': {
        'token': 'test_token',
        'user': {
          'id': 1,
          'email': 'test@example.com',
          'role': 'admin',
          'first_name': 'Test',
          'last_name': 'Admin',
        }
      }
    };

    await authService.login('test@example.com', 'password');

    expect(fakeTokenStorage.lastWrittenToken, 'test_token');
    expect(fakeTokenStorage.lastWrittenUserInfo?['role'], 'admin');
    expect(fakeBaseService.lastPath, contains('login'));
  });
}
