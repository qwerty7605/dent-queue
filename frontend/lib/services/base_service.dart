import 'dart:io';

import '../core/api_client.dart';
import '../core/api_exception.dart';

class BaseService {
  BaseService(this._apiClient);

  final ApiClient _apiClient;

  Future<T> getJson<T>(String path, T Function(dynamic json) mapper) async {
    try {
      final json = await _apiClient.get(path);
      return mapper(json);
    } on ApiException {
      rethrow;
    }
  }

  Future<T> postJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    try {
      final json = await _apiClient.post(path, body: body);
      return mapper(json);
    } on ApiException {
      rethrow;
    }
  }

  Future<T> putJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    try {
      final json = await _apiClient.put(path, body: body);
      return mapper(json);
    } on ApiException {
      rethrow;
    }
  }

  Future<T> patchJson<T>(
    String path,
    Object? body,
    T Function(dynamic json) mapper,
  ) async {
    try {
      final json = await _apiClient.patch(path, body: body);
      return mapper(json);
    } on ApiException {
      rethrow;
    }
  }

  Future<T> deleteJson<T>(String path, T Function(dynamic json) mapper) async {
    try {
      final json = await _apiClient.delete(path);
      return mapper(json);
    } on ApiException {
      rethrow;
    }
  }

  Future<T> postMultipartJson<T>(
    String path, {
    required Map<String, String> fields,
    Map<String, File>? files,
    required T Function(dynamic json) mapper,
  }) async {
    try {
      final json = await _apiClient.postMultipart(path, fields: fields, files: files);
      return mapper(json);
    } on ApiException {
      rethrow;
    }
  }
}
