import '../core/endpoints.dart';
import '../core/short_term_cache.dart';
import 'base_service.dart';

class AdminSettingsService {
  AdminSettingsService(this._baseService);

  static const Duration _clinicSettingsCacheTtl = Duration(minutes: 10);
  static const Duration _doctorUnavailabilityCacheTtl = Duration(minutes: 2);
  static const String _clinicSettingsCache = 'admin-clinic-settings';
  static const String _doctorUnavailabilityCache =
      'admin-doctor-unavailability';

  final BaseService _baseService;

  Map<String, dynamic>? getCachedClinicSettings({bool allowStale = false}) {
    final ShortTermCacheHit<dynamic>? cached =
        ShortTermCache.readEntry<dynamic>(
          _clinicSettingsCache,
          'current',
          allowStale: allowStale,
        );

    if (cached?.value is Map) {
      return Map<String, dynamic>.from(cached!.value as Map);
    }

    return null;
  }

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
        ttl: _clinicSettingsCacheTtl,
      );
      return result;
    }

    const result = <String, dynamic>{};
    ShortTermCache.write(
      _clinicSettingsCache,
      'current',
      result,
      ttl: _clinicSettingsCacheTtl,
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

  Future<List<Map<String, dynamic>>> getDoctorUnavailability() async {
    final dynamic cached = ShortTermCache.read<dynamic>(
      _doctorUnavailabilityCache,
      'all',
    );
    if (cached is List) {
      return cached
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminDoctorUnavailability,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is List) {
      final result = (response['data'] as List<dynamic>)
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
      ShortTermCache.write(
        _doctorUnavailabilityCache,
        'all',
        result,
        ttl: _doctorUnavailabilityCacheTtl,
      );
      return result;
    }

    const result = <Map<String, dynamic>>[];
    ShortTermCache.write(
      _doctorUnavailabilityCache,
      'all',
      result,
      ttl: _doctorUnavailabilityCacheTtl,
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> createDoctorUnavailability(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminDoctorUnavailability,
      payload,
      (data) => data,
    );

    invalidateDoctorUnavailabilityCache();

    if (response is Map<String, dynamic> && response['data'] is List) {
      return (response['data'] as List<dynamic>)
          .whereType<Map>()
          .map((dynamic item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }

    return <Map<String, dynamic>>[];
  }

  Future<void> deleteDoctorUnavailability(int id) async {
    await _baseService.deleteJson<dynamic>(
      Endpoints.adminDeleteDoctorUnavailability(id),
      (data) => data,
    );

    invalidateDoctorUnavailabilityCache();
  }

  void invalidateClinicSettingsCache() {
    ShortTermCache.invalidateNamespace(_clinicSettingsCache);
  }

  void invalidateDoctorUnavailabilityCache() {
    ShortTermCache.invalidateNamespace(_doctorUnavailabilityCache);
  }
}
