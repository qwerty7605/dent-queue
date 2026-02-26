import 'package:frontend/core/token_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('InMemoryTokenStorage saves token and user info', () async {
    final tokenStorage = InMemoryTokenStorage();
    await tokenStorage.writeToken('abc123');
    await tokenStorage.writeUserInfo({
      'id': 1,
      'name': 'Mock User',
      'email': 'mock@example.com',
      'role': 'patient',
    });

    expect(await tokenStorage.readToken(), 'abc123');
    expect(await tokenStorage.readUserInfo(), isNotNull);
    expect((await tokenStorage.readUserInfo())?['role'], 'patient');

    await tokenStorage.clear();
    expect(await tokenStorage.readToken(), isNull);
    expect(await tokenStorage.readUserInfo(), isNull);
  });
}
