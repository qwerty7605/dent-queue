import '../core/endpoints.dart';
import '../core/paginated_result.dart';
import '../core/short_term_cache.dart';
import 'admin_dashboard_service.dart';
import 'base_service.dart';

class AdminStaffService {
  AdminStaffService(this._baseService);

  static const Duration _cacheTtl = Duration(minutes: 2);
  static const String _staffListCache = 'admin-staff-list';
  static const String _staffPageCache = 'admin-staff-page';

  final BaseService _baseService;

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final dynamic cached = ShortTermCache.read<dynamic>(_staffListCache, 'all');
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminStaff,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is List<dynamic>) {
      final result = (response['data'] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      ShortTermCache.write(_staffListCache, 'all', result, ttl: _cacheTtl);
      return result;
    }

    const result = <Map<String, dynamic>>[];
    ShortTermCache.write(_staffListCache, 'all', result, ttl: _cacheTtl);
    return result;
  }

  Future<PaginatedResult<Map<String, dynamic>>> getStaffPage({
    int page = 1,
    int perPage = 25,
  }) async {
    final String cacheKey = _pageCacheKey(page: page, perPage: perPage);
    final dynamic cached = ShortTermCache.read<dynamic>(
      _staffPageCache,
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

    return ShortTermCache.runSingleFlight(_staffPageCache, cacheKey, () async {
      final response = await _baseService.getJson<dynamic>(
        Endpoints.adminStaffList(<String, String>{
          'page': page.toString(),
          'per_page': perPage.toString(),
        }),
        (data) => data,
      );

      if (response is Map<String, dynamic>) {
        ShortTermCache.write(
          _staffPageCache,
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
        _staffPageCache,
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
    });
  }

  PaginatedResult<Map<String, dynamic>>? getCachedStaffPage({
    int page = 1,
    int perPage = 25,
    bool allowStale = false,
  }) {
    final String cacheKey = _pageCacheKey(page: page, perPage: perPage);
    final ShortTermCacheHit<dynamic>? cached =
        ShortTermCache.readEntry<dynamic>(
          _staffPageCache,
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

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> data) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminStaff,
      data,
      (data) => data,
    );
    invalidateStaffCache();

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {'message': 'Staff account successfully created.'};
  }

  Future<String> deactivateStaff(int id) async {
    final response = await _baseService.deleteJson<dynamic>(
      Endpoints.adminDeleteStaff(id),
      (data) => data,
    );

    invalidateStaffCache();

    if (response is Map<String, dynamic> && response['message'] is String) {
      return response['message'] as String;
    }

    return 'Staff account successfully removed.';
  }

  void invalidateStaffCache() {
    ShortTermCache.invalidateNamespace(_staffListCache);
    ShortTermCache.invalidateNamespace(_staffPageCache);
    AdminDashboardService.invalidateSharedDashboardStatsCache();
  }

  String _pageCacheKey({required int page, required int perPage}) {
    return 'page=$page&per_page=$perPage';
  }
}
