import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import 'admin_dashboard_service.dart';
import 'base_service.dart';

class AdminStaffService {
  AdminStaffService(this._baseService);

  static const Duration _cacheTtl = Duration(seconds: 30);
  static const String _staffListCache = 'admin-staff-list';

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
    AdminDashboardService.invalidateSharedDashboardStatsCache();
  }
}
