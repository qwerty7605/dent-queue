class Endpoints {
  // versioning and auth path to match Laravel routes
  static const _base = '/api/v1';

  static const status = '$_base/status';

  static const login = '$_base/auth/login';
  static const register = '$_base/auth/register';
  static const logout = '$_base/auth/logout';
  static const me = '$_base/user';
}
