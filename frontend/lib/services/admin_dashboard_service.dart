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

    if (response is Map && response.containsKey('data')) {
      final dataMap = response['data'];
      if (dataMap is Map) {
        final data = Map<String, dynamic>.from(dataMap);
        return {
          'patients_count': data['patients_count'] as int? ?? 0,
          'staff_count': data['staff_count'] as int? ?? 0,
          'appointments_count': data['appointments_count'] as int? ?? 0,
        };
      }
    }

    return {
      'patients_count': 0,
      'staff_count': 0,
      'appointments_count': 0,
    };
  }

  Future<Map<String, int>> getReportSummary() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminReportsSummary,
      (data) => data,
    );

    if (response is Map && response.containsKey('data')) {
      final dataMap = response['data'];
      if (dataMap is Map) {
        final data = Map<String, dynamic>.from(dataMap);
        return {
          'total': data['total_appointments'] as int? ?? 0,
          'pending': data['pending_count'] as int? ?? 0,
          'approved': data['approved_count'] as int? ?? 0,
          'completed': data['completed_count'] as int? ?? 0,
          'cancelled': data['cancelled_count'] as int? ?? 0,
        };
      }
    }

    return {
      'total': 0,
      'pending': 0,
      'approved': 0,
      'completed': 0,
      'cancelled': 0,
    };
  }
}
