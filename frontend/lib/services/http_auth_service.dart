import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import '../core/token_storage.dart';
import 'auth_service.dart';
import 'base_service.dart';

class HttpAuthService implements AuthService {
  HttpAuthService(this._baseService, this._tokenStorage);

  final BaseService _baseService;
  final TokenStorage _tokenStorage;

  @override
  Future<void> login(String identifier, String password) async {
    ShortTermCache.clear();

    // send the identifier under both possible keys, backend will pick one
    final payload = {
      'password': password,
    };
    if (identifier.contains('@')) {
      payload['email'] = identifier;
    } else {
      payload['username'] = identifier;
    }

    final json = await _baseService.postJson<dynamic>(
      Endpoints.login,
      payload,
      (data) => data,
    );

    final token = _extractToken(json);
    if (token != null && token.isNotEmpty) {
      await _tokenStorage.writeToken(token);
    }
    final userInfo = _extractUserInfo(json);
    if (userInfo != null && userInfo['role'] != null) {
      await _tokenStorage.writeUserInfo(userInfo);
    } else {
      await me(); // Fetch complete user info including roles
    }
  }

  @override
  Future<void> register(Map<String, dynamic> payload) async {
    ShortTermCache.clear();

    // ensure email and username are present; frontend should provide both now
    final json = await _baseService.postJson<dynamic>(
      Endpoints.register,
      payload,
      (data) => data,
    );

    final token = _extractToken(json);
    if (token != null && token.isNotEmpty) {
      await _tokenStorage.writeToken(token);
    }
    final userInfo = _extractUserInfo(json);
    if (userInfo != null && userInfo['role'] != null) {
      await _tokenStorage.writeUserInfo(userInfo);
    } else {
      await me(); // Fetch complete user info including roles
    }
  }

  @override
  Future<void> logout() async {
    ShortTermCache.clear();

    await _baseService.postJson<dynamic>(
      Endpoints.logout,
      null,
      (data) => data,
    );
    await _tokenStorage.clear();
  }

  @override
  Future<Map<String, dynamic>?> me() async {
    final json = await _baseService.getJson<dynamic>(Endpoints.me, (data) => data);
    final userInfo = _extractUserInfo(json);
    if (userInfo != null) {
      await _tokenStorage.writeUserInfo(userInfo);
    }
    return userInfo;
  }

  String? _extractToken(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final direct = json['token'];
    if (direct is String) return direct;

    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final nested = data['token'];
      if (nested is String) return nested;
      final accessToken = data['access_token'];
      if (accessToken is String) return accessToken;
    }

    final accessToken = json['access_token'];
    if (accessToken is String) return accessToken;
    return null;
  }

  Map<String, dynamic>? _extractUserInfo(dynamic json) {
    if (json is! Map<String, dynamic>) return null;

    dynamic user = json['user'];
    if (user is! Map<String, dynamic>) {
      final data = json['data'];
      if (data is Map<String, dynamic>) {
        user = data['user'];
      }
    }
    if (user is! Map<String, dynamic>) return null;

    String? role;
    final directRole = user['role'];
    if (directRole is String && directRole.isNotEmpty) {
      role = directRole;
    } else if (directRole is Map<String, dynamic> && directRole['name'] is String) {
      role = directRole['name'] as String;
    } else {
      final roles = user['roles'];
      if (roles is List && roles.isNotEmpty) {
        final first = roles.first;
        if (first is String) {
          role = first;
        } else if (first is Map<String, dynamic> && first['name'] is String) {
          role = first['name'] as String;
        }
      }
    }

    final String defaultName = user['name'] ?? user['full_name'] ?? '';
    final String parsedFirstName = user['first_name']?.toString() ?? '';
    final String parsedLastName = user['last_name']?.toString() ?? '';
    final String constructedName = ('$parsedFirstName $parsedLastName').trim();

    return {
      'id': user['id'],
      'name': constructedName.isNotEmpty ? constructedName : (defaultName.isNotEmpty ? defaultName : 'User'),
      'email': user['email'],
      'role': role,
      'first_name': user['first_name'],
      'middle_name': user['middle_name'],
      'last_name': user['last_name'],
      'username': user['username'],
      'location': user['location'],
      'gender': user['gender'],
      'phone_number': user['phone_number'],
      'profile_picture': user['profile_picture'],
    };
  }
}
