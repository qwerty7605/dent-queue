import '../core/endpoints.dart';
import 'base_service.dart';

class StaffService {
  StaffService(this._baseService);

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

  Future<Map<String, dynamic>> createStaff(Map<String, dynamic> staffData) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminStaff,
      staffData,
      (data) => data,
    );

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
  }
}
