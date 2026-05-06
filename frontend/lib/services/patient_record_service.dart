import '../core/endpoints.dart';
import '../core/paginated_result.dart';
import '../core/short_term_cache.dart';
import 'admin_dashboard_service.dart';
import 'base_service.dart';

class PatientRecordService {
  PatientRecordService(this._baseService);

  static const Duration _cacheTtl = Duration(minutes: 1);
  static const String _allPatientsCache = 'patient-records-all';
  static const String _patientsPageCache = 'patient-records-page';
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
      ShortTermCache.write(_allPatientsCache, 'all', result, ttl: _cacheTtl);
      return result;
    }

    const result = <Map<String, dynamic>>[];
    ShortTermCache.write(_allPatientsCache, 'all', result, ttl: _cacheTtl);
    return result;
  }

  Future<PaginatedResult<Map<String, dynamic>>> getPatientsPage({
    int page = 1,
    int perPage = 25,
  }) async {
    final String cacheKey = _pageCacheKey(page: page, perPage: perPage);
    final dynamic cached = ShortTermCache.read<dynamic>(
      _patientsPageCache,
      cacheKey,
    );
    if (cached is Map<String, dynamic>) {
      return PaginatedResult<Map<String, dynamic>>.fromResponse(
        cached,
        (dynamic item) => Map<String, dynamic>.from(item as Map),
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    }

    return ShortTermCache.runSingleFlight(
      _patientsPageCache,
      cacheKey,
      () async {
        final response = await _baseService.getJson<dynamic>(
          Endpoints.adminPatientsList(<String, String>{
            'page': page.toString(),
            'per_page': perPage.toString(),
          }),
          (data) => data,
        );

        if (response is Map<String, dynamic>) {
          ShortTermCache.write(
            _patientsPageCache,
            cacheKey,
            response,
            ttl: _cacheTtl,
          );

          return PaginatedResult<Map<String, dynamic>>.fromResponse(
            response,
            (dynamic item) => Map<String, dynamic>.from(item as Map),
            fallbackPage: page,
            fallbackPerPage: perPage,
          );
        }

        const Map<String, dynamic> emptyResponse = <String, dynamic>{
          'data': <Map<String, dynamic>>[],
          'meta': <String, dynamic>{},
        };
        ShortTermCache.write(
          _patientsPageCache,
          cacheKey,
          emptyResponse,
          ttl: _cacheTtl,
        );
        return const PaginatedResult<Map<String, dynamic>>(
          items: <Map<String, dynamic>>[],
          currentPage: 1,
          perPage: 25,
          totalItems: 0,
          hasMorePages: false,
        );
      },
    );
  }

  PaginatedResult<Map<String, dynamic>>? getCachedPatientsPage({
    int page = 1,
    int perPage = 25,
    bool allowStale = false,
  }) {
    final String cacheKey = _pageCacheKey(page: page, perPage: perPage);
    final ShortTermCacheHit<dynamic>? cached =
        ShortTermCache.readEntry<dynamic>(
          _patientsPageCache,
          cacheKey,
          allowStale: allowStale,
        );

    if (cached?.value is Map<String, dynamic>) {
      return PaginatedResult<Map<String, dynamic>>.fromResponse(
        cached!.value as Map<String, dynamic>,
        (dynamic item) => Map<String, dynamic>.from(item as Map),
        fallbackPage: page,
        fallbackPerPage: perPage,
      );
    }

    return null;
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
    ShortTermCache.write(
      _patientDetailCache,
      patientId,
      result,
      ttl: _cacheTtl,
    );
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
    ShortTermCache.invalidateNamespace(_patientsPageCache);
    ShortTermCache.invalidateNamespace(_searchPatientsCache);
    AdminDashboardService.invalidateSharedDashboardStatsCache();
    if (patientId != null) {
      ShortTermCache.invalidate(_patientDetailCache, patientId);
    } else {
      ShortTermCache.invalidateNamespace(_patientDetailCache);
    }
  }

  String _pageCacheKey({required int page, required int perPage}) {
    return 'page=$page&per_page=$perPage';
  }
}
