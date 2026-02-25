class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? errors;

  ApiException({this.statusCode, required this.message, this.errors});

  @override
  String toString() {
    final code = statusCode != null ? ' ($statusCode)' : '';
    return 'ApiException$code: $message';
  }
}
