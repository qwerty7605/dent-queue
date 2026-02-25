abstract class AuthService {
  Future<void> login(String email, String password);
  Future<void> register(Map<String, dynamic> payload);
  Future<void> logout();
  Future<void> me();
}
