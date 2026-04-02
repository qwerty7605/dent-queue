import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import 'base_service.dart';

class PatientRecordService {
  PatientRecordService(this._baseService);

  static const Duration _cacheTtl = Duration(seconds: 30);
  static const String _allPatientsCache = 'patient-records-all';
  static const String _searchPatientsCache = 'patient-records-search';
  static const String _patientDetailCache = 'patient-record-detail';

  final BaseService _baseService;

  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _allPatientsCache,
      'all',
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminPatients,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is List<dynamic>) {
      final result = (response['data'] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      ShortTermCache.write(
        _allPatientsCache,
        'all',
        result,
        ttl: _cacheTtl,
      );
      return result;
    }

    const result = <Map<String, dynamic>>[];
    ShortTermCache.write(_allPatientsCache, 'all', result, ttl: _cacheTtl);
    return result;
  }

  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final String cacheKey = query.trim().toLowerCase();
    final dynamic cached = ShortTermCache.read<dynamic>(
      _searchPatientsCache,
      cacheKey,
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminPatientSearch(query),
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is List<dynamic>) {
      final result = (response['data'] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      ShortTermCache.write(
        _searchPatientsCache,
        cacheKey,
        result,
        ttl: _cacheTtl,
      );
      return result;
    }

    const result = <Map<String, dynamic>>[];
    ShortTermCache.write(
      _searchPatientsCache,
      cacheKey,
      result,
      ttl: _cacheTtl,
    );
    return result;
  }

  Future<Map<String, dynamic>> getPatientDetail(String patientId) async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _patientDetailCache,
      patientId,
    );
    if (cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminPatientDetail(patientId),
      (data) => data,
    );

    if (response is Map<String, dynamic>) {
      final result = Map<String, dynamic>.from(response);
      ShortTermCache.write(
        _patientDetailCache,
        patientId,
        result,
        ttl: _cacheTtl,
      );
      return result;
    }

    const result = <String, dynamic>{};
    ShortTermCache.write(_patientDetailCache, patientId, result, ttl: _cacheTtl);
    return result;
  }

  Future<String> deactivatePatient(String patientId) async {
    final response = await _baseService.deleteJson<dynamic>(
      Endpoints.adminPatientDetail(patientId),
      (data) => data,
    );

    invalidatePatientCaches(patientId: patientId);

    if (response is Map<String, dynamic> && response['message'] is String) {
      return response['message'] as String;
    }

    return 'Patient record successfully removed or deactivated.';
  }

  void invalidatePatientCaches({String? patientId}) {
    ShortTermCache.invalidateNamespace(_allPatientsCache);
    ShortTermCache.invalidateNamespace(_searchPatientsCache);
    if (patientId != null) {
      ShortTermCache.invalidate(_patientDetailCache, patientId);
    } else {
      ShortTermCache.invalidateNamespace(_patientDetailCache);
    }
  }
}
