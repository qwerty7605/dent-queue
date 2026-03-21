import '../core/endpoints.dart';
import 'base_service.dart';

class AdminProfileService {
  AdminProfileService(this._baseService);
  final BaseService _baseService;

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _baseService.putJson<dynamic>(
      Endpoints.adminProfileUpdate,
      data,
      (data) => data,
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {};
  }
}
