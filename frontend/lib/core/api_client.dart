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

  String _networkHint(String url) {
    if (url.contains('10.0.2.2')) {
      return '10.0.2.2 is Android emulator-only; use API_BASE_URL with your PC LAN IP on a physical phone';
    }
    return 'check backend and API_BASE_URL';
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
    final url = '${AppConfig.baseUrl}$path';
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

          // Determine mime type basic check, or default to generic image
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

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (response.body.isEmpty) return null;
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
      throw ApiException(
        message: 'Request timed out: $url (${_networkHint(url)})',
      );
    } on SocketException {
      throw ApiException(
        message: 'Cannot reach server: $url (${_networkHint(url)})',
      );
    } on FormatException {
      throw ApiException(message: 'Invalid server response');
    }
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
          response = await _client.get(uri, headers: headers).timeout(_timeout);
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
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: jsonEncode(body))
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
      throw ApiException(
        message: 'Request timed out: $url (${_networkHint(url)})',
      );
    } on SocketException {
      throw ApiException(
        message: 'Cannot reach server: $url (${_networkHint(url)})',
      );
    } on FormatException {
      throw ApiException(message: 'Invalid server response');
    }
  }
}
