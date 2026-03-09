import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_exception.dart';
import 'config.dart';
import 'token_storage.dart';

class ApiClient {
  ApiClient({http.Client? client, required TokenStorage tokenStorage})
    : _client = client ?? http.Client(),
      _tokenStorage = tokenStorage;

  final http.Client _client;
  final TokenStorage _tokenStorage;

  static const Duration _timeout = Duration(seconds: 10);
  String? _activeBaseUrl;

  String _networkHint(String url) {
    if (url.contains('10.0.2.2')) {
      return '10.0.2.2 is Android emulator-only; for phones use API_BASE_URL/API_HOST or adb reverse tcp:8080 tcp:8080';
    }
    if (url.contains('localhost') || url.contains('127.0.0.1')) {
      return 'localhost on physical phones points to the phone itself; use API_BASE_URL/API_HOST with your PC LAN IP';
    }
    return 'check backend and API_BASE_URL/API_HOST';
  }

  String _normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.endsWith('/') ? trimmed.substring(0, trimmed.length - 1) : trimmed;
  }

  List<String> _baseUrlCandidates() {
    final ordered = <String>[];
    final seen = <String>{};

    void add(String? value) {
      if (value == null || value.isEmpty) return;
      final normalized = _normalizeBaseUrl(value);
      if (normalized.isEmpty) return;
      if (seen.add(normalized)) {
        ordered.add(normalized);
      }
    }

    add(_activeBaseUrl);

    final shouldPreferAndroidLocalhost =
        !AppConfig.hasManualBaseUrl &&
        defaultTargetPlatform == TargetPlatform.android &&
        AppConfig.env == AppEnvironment.auto;

    // In Android auto mode, prefer localhost first (works with adb reverse).
    if (shouldPreferAndroidLocalhost) {
      add(AppConfig.localhostBaseUrl);
      add('http://127.0.0.1:${AppConfig.port}');
      add(AppConfig.androidEmulatorBaseUrl);
      add(AppConfig.baseUrl);
      return ordered;
    }

    add(AppConfig.baseUrl);

    if (!AppConfig.hasManualBaseUrl && defaultTargetPlatform != TargetPlatform.android) {
      add(AppConfig.localhostBaseUrl);
    }

    return ordered;
  }

  Future<dynamic> get(String path) async {
    return _send('GET', path);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send('POST', path, body: body);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _send('PATCH', path, body: body);
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send('PUT', path, body: body);
  }

  Future<dynamic> delete(String path) async {
    return _send('DELETE', path);
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, File>? files,
  }) async {
    final baseUrls = _baseUrlCandidates();
    ApiException? lastNetworkError;

    for (var i = 0; i < baseUrls.length; i++) {
      final baseUrl = baseUrls[i];
      final url = '$baseUrl$path';
      final uri = Uri.parse(url);

      try {
        final request = http.MultipartRequest('POST', uri);

        final token = await _tokenStorage.readToken();
        if (token != null && token.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $token';
        }
        request.headers['Accept'] = 'application/json';

        request.fields.addAll(fields);

        if (files != null) {
          for (final entry in files.entries) {
            final file = entry.value;
            final fileName = file.path.split('/').last;

            // Determine mime type basic check, or default to generic image.
            MediaType mediaType = MediaType('image', 'jpeg');
            if (fileName.toLowerCase().endsWith('.png')) {
              mediaType = MediaType('image', 'png');
            } else if (fileName.toLowerCase().endsWith('.gif')) {
              mediaType = MediaType('image', 'gif');
            }

            request.files.add(
              await http.MultipartFile.fromPath(
                entry.key,
                file.path,
                contentType: mediaType,
              ),
            );
          }
        }

        debugPrint('API MULTIPART POST $url');
        final streamedResponse = await _client.send(request).timeout(_timeout);
        final response = await http.Response.fromStream(streamedResponse);
        debugPrint('API MULTIPART POST $url -> ${response.statusCode}');

        final parsed = _parseResponse(response);
        _activeBaseUrl = baseUrl;
        return parsed;
      } on TimeoutException {
        lastNetworkError = ApiException(
          message: 'Request timed out: $url (${_networkHint(url)})',
        );
      } on SocketException {
        lastNetworkError = ApiException(
          message: 'Cannot reach server: $url (${_networkHint(url)})',
        );
      } on FormatException {
        throw ApiException(message: 'Invalid server response');
      } on ApiException {
        rethrow;
      }

      if (i < baseUrls.length - 1) {
        debugPrint('API MULTIPART fallback -> ${baseUrls[i + 1]}$path');
      }
    }

    throw lastNetworkError ?? ApiException(message: 'Cannot reach server');
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
    final headers = await _buildHeaders();
    final baseUrls = _baseUrlCandidates();
    ApiException? lastNetworkError;

    for (var i = 0; i < baseUrls.length; i++) {
      final baseUrl = baseUrls[i];
      final url = '$baseUrl$path';
      final uri = Uri.parse(url);

      try {
        final response = await _performRequest(
          method: method,
          uri: uri,
          headers: headers,
          body: body,
        );

        // ignore: avoid_print
        print('API $method $url -> ${response.statusCode}');

        final parsed = _parseResponse(response);
        _activeBaseUrl = baseUrl;
        return parsed;
      } on TimeoutException {
        lastNetworkError = ApiException(
          message: 'Request timed out: $url (${_networkHint(url)})',
        );
      } on SocketException {
        lastNetworkError = ApiException(
          message: 'Cannot reach server: $url (${_networkHint(url)})',
        );
      } on FormatException {
        throw ApiException(message: 'Invalid server response');
      } on ApiException {
        rethrow;
      }

      if (i < baseUrls.length - 1) {
        debugPrint('API $method fallback -> ${baseUrls[i + 1]}$path');
      }
    }

    throw lastNetworkError ?? ApiException(message: 'Cannot reach server');
  }

  Future<http.Response> _performRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Object? body,
  }) async {
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers).timeout(_timeout);
      case 'POST':
        return _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(_timeout);
      case 'PUT':
        return _client
            .put(uri, headers: headers, body: jsonEncode(body))
            .timeout(_timeout);
      case 'PATCH':
        return _client
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(_timeout);
      case 'DELETE':
        return _client.delete(uri, headers: headers).timeout(_timeout);
      default:
        throw ApiException(message: 'Unsupported method: $method');
    }
  }

  dynamic _parseResponse(http.Response response) {
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
  }
}
