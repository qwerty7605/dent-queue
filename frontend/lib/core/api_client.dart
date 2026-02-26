import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'config.dart';
import 'endpoints.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({http.Client? client, required TokenStorage tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage;

  final http.Client _client;
  final TokenStorage _tokenStorage;

  static const Duration _timeout = Duration(seconds: 10);

  Future<dynamic> get(String path) async {
    if (_isMockMode) {
      return _handleMock('GET', path);
    }
    return _send('GET', path);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    if (_isMockMode) {
      return _handleMock('POST', path);
    }
    return _send('POST', path, body: body);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    if (_isMockMode) {
      return _handleMock('PUT', path);
    }
    return _send('PUT', path, body: body);
  }

  Future<dynamic> delete(String path) async {
    if (_isMockMode) {
      return _handleMock('DELETE', path);
    }
    return _send('DELETE', path);
  }

  bool get _isMockMode => AppConfig.env == AppEnvironment.mock;

  Future<dynamic> _handleMock(String method, String path) async {
    if (method == 'GET' && path == Endpoints.status) {
      return {
        'status': 'ok',
        'message': 'mock status - backend not connected',
      };
    }
    if (method == 'POST' && path == Endpoints.login) {
      return {
        'message': 'mock login success',
        'token': 'mock-token-login',
        'user': {
          'id': 1,
          'name': 'Mock User',
          'email': 'mock@example.com',
          'role': 'patient',
        },
      };
    }
    if (method == 'POST' && path == Endpoints.register) {
      return {
        'message': 'mock register success',
        'token': 'mock-token-register',
        'user': {
          'id': 2,
          'name': 'New Mock User',
          'email': 'newmock@example.com',
          'role': 'patient',
        },
      };
    }
    if (method == 'POST' && path == Endpoints.logout) {
      return {
        'message': 'mock logout success',
      };
    }
    if (method == 'GET' && path == Endpoints.me) {
      return {
        'message': 'mock me success',
        'user': {
          'id': 1,
          'name': 'Mock User',
          'email': 'mock@example.com',
          'role': 'patient',
        },
      };
    }
    throw ApiException(message: 'Mock mode: endpoint not available');
  }

  Future<Map<String, String>> _buildHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> _send(String method, String path, {Object? body}) async {
    final url = '${AppConfig.baseUrl}$path';
    final uri = Uri.parse(url);

    try {
      final headers = await _buildHeaders();
      http.Response response;

      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(_timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: jsonEncode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(_timeout);
          break;
        default:
          throw ApiException(message: 'Unsupported method: $method');
      }

      // ignore: avoid_print
      print('API $method $url -> ${response.statusCode}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) {
          return null;
        }
        return jsonDecode(response.body) as dynamic;
      }

      String message = 'Request failed';
      Map<String, dynamic>? errors;
      if (response.body.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) {
            if (decoded['message'] is String) {
              message = decoded['message'] as String;
            }
            if (decoded['errors'] is Map<String, dynamic>) {
              errors = decoded['errors'] as Map<String, dynamic>;
            }
          }
        } on FormatException {
          message = response.body;
        }
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: message,
        errors: errors,
      );
    } on TimeoutException {
      throw ApiException(message: 'Request timed out');
    } on SocketException {
      throw ApiException(message: 'No internet / cannot reach server');
    } on FormatException {
      throw ApiException(message: 'Invalid server response');
    }
  }
}
