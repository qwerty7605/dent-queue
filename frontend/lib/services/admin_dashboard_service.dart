import '../core/endpoints.dart';
import 'base_service.dart';

class AdminDashboardService {
  AdminDashboardService(this._baseService);
  final BaseService _baseService;

  Future<Map<String, int>> getStats() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminDashboardStats,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final data = response['data'] as Map<String, dynamic>;
      return {
        'patients_count': data['patients_count'] as int? ?? 0,
        'staff_count': data['staff_count'] as int? ?? 0,
        'appointments_count': data['appointments_count'] as int? ?? 0,
      };
    }

    return {
      'patients_count': 0,
      'staff_count': 0,
      'appointments_count': 0,
    };
  }
}
