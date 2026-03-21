import '../core/endpoints.dart';
import 'base_service.dart';

class AdminSettingsService {
  AdminSettingsService(this._baseService);

  final BaseService _baseService;

  Future<Map<String, dynamic>> getClinicSettings() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminClinicSettings,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is Map) {
      return Map<String, dynamic>.from(response['data'] as Map);
    }

    return {};
  }

  Future<Map<String, dynamic>> saveClinicSettings(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.putJson<dynamic>(
      Endpoints.adminClinicSettings,
      payload,
      (data) => data,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    return {};
  }
}
