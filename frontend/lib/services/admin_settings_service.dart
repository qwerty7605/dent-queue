import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import 'base_service.dart';

class AdminSettingsService {
  AdminSettingsService(this._baseService);

  static const Duration _cacheTtl = Duration(seconds: 30);
  static const String _clinicSettingsCache = 'admin-clinic-settings';

  final BaseService _baseService;

  Future<Map<String, dynamic>> getClinicSettings() async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _clinicSettingsCache,
      'current',
    );
    if (cached is Map) {
      return Map<String, dynamic>.from(cached);
    }

    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminClinicSettings,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is Map) {
      final result = Map<String, dynamic>.from(response['data'] as Map);
      ShortTermCache.write(
        _clinicSettingsCache,
        'current',
        result,
        ttl: _cacheTtl,
      );
      return result;
    }

    const result = <String, dynamic>{};
    ShortTermCache.write(
      _clinicSettingsCache,
      'current',
      result,
      ttl: _cacheTtl,
    );
    return result;
  }

  Future<Map<String, dynamic>> saveClinicSettings(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.putJson<dynamic>(
      Endpoints.adminClinicSettings,
      payload,
      (data) => data,
    );

    invalidateClinicSettingsCache();

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {};
  }

  void invalidateClinicSettingsCache() {
    ShortTermCache.invalidateNamespace(_clinicSettingsCache);
  }
}
