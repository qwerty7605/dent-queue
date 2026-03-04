abstract class AuthService {
  /// `identifier` may be email or username depending on backend configuration.
  Future<void> login(String identifier, String password);
  Future<void> register(Map<String, dynamic> payload);
  Future<void> logout();
  Future<Map<String, dynamic>?> me();
}
