import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import 'base_service.dart';

class StaffService {
  StaffService(this._baseService);

  static const Duration _cacheTtl = Duration(seconds: 30);
  static const String _staffListCache = 'staff-service-list';

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

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> staffData) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminStaff,
      staffData,
      (data) => data,
    );

    invalidateStaffCache();

    if (response is Map<String, dynamic>) {
      return response;
    }

    return <String, dynamic>{};
  }

  Future<void> removeStaff(int staffId) async {
    await _baseService.deleteJson<dynamic>(
      Endpoints.adminDeleteStaff(staffId),
      (data) => data,
    );

    invalidateStaffCache();
  }

  void invalidateStaffCache() {
    ShortTermCache.invalidateNamespace(_staffListCache);
  }
}
