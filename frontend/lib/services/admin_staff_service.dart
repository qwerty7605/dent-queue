import '../core/endpoints.dart';
import 'base_service.dart';

class AdminStaffService {
  AdminStaffService(this._baseService);

  final BaseService _baseService;

  Future<List<Map<String, dynamic>>> getAllStaff() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminStaff,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['data'] is List<dynamic>) {
      return (response['data'] as List<dynamic>)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return [];
  }

  Future<String> deactivateStaff(int id) async {
    final response = await _baseService.deleteJson<dynamic>(
      Endpoints.adminDeleteStaff(id),
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['message'] is String) {
      return response['message'] as String;
    }

    return 'Staff account successfully removed.';
  }
}
