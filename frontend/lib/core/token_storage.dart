import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStorage {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<Map<String, dynamic>?> readUserInfo();
  Future<void> writeUserInfo(Map<String, dynamic> userInfo);
  Future<void> clear();
}

class InMemoryTokenStorage implements TokenStorage {
  String? _token;
  Map<String, dynamic>? _userInfo;

  @override
  Future<String?> readToken() async {
    return _token;
  }

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<Map<String, dynamic>?> readUserInfo() async {
    return _userInfo;
  }

  @override
  Future<void> writeUserInfo(Map<String, dynamic> userInfo) async {
    _userInfo = userInfo;
  }

  @override
  Future<void> clear() async {
    _token = null;
    _userInfo = null;
  }
}

class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;
  static const _tokenKey = 'auth_token';
  static const _userInfoKey = 'auth_user_info';

  @override
  Future<String?> readToken() async {
    return _secureStorage.read(key: _tokenKey);
  }

  @override
  Future<void> writeToken(String token) async {
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  @override
  Future<Map<String, dynamic>?> readUserInfo() async {
    final raw = await _secureStorage.read(key: _userInfoKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> writeUserInfo(Map<String, dynamic> userInfo) async {
    await _secureStorage.write(
      key: _userInfoKey,
      value: jsonEncode(userInfo),
    );
  }

  @override
  Future<void> clear() async {
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _userInfoKey);
  }
}
