import '../core/endpoints.dart';
import 'base_service.dart';

class PatientRecordService {
  PatientRecordService(this._baseService);

  final BaseService _baseService;

  Future<List<Map<String, dynamic>>> getAllPatients() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminPatients,
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

  Future<List<Map<String, dynamic>>> searchPatients(String query) async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminPatientSearch(query),
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

  Future<Map<String, dynamic>> getPatientDetail(String patientId) async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminPatientDetail(patientId),
      (data) => data,
    );

    if (response is Map<String, dynamic>) {
      return response;
    }

    return <String, dynamic>{};
  }

  Future<String> deactivatePatient(String patientId) async {
    final response = await _baseService.deleteJson<dynamic>(
      Endpoints.adminPatientDetail(patientId),
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['message'] is String) {
      return response['message'] as String;
    }

    return 'Patient record successfully removed or deactivated.';
  }
}
