import '../core/endpoints.dart';
import 'base_service.dart';

class AppointmentService {
  AppointmentService(this._baseService);
  final BaseService _baseService;

  Future<List<Map<String, dynamic>>> getServices() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.services,
      (data) => data,
    );
    if (response is Map<String, dynamic> && response.containsKey('services')) {
      final servicesList = response['services'] as List<dynamic>;
      return servicesList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.appointments,
      payload,
      (data) => data,
    );
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAdminAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminAppointments,
      payload,
      (data) => data,
    );
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAdminMasterList() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminMasterList,
      (data) => data,
    );

    if (response is Map<String, dynamic> && response.containsKey('data')) {
      final appointmentsList = response['data'] as List<dynamic>;
      return appointmentsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getPatientAppointments() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.appointments,
      (data) => data,
    );
    if (response is Map<String, dynamic> &&
        response.containsKey('appointments')) {
      final appointmentsList = response['appointments'] as List<dynamic>;
      return appointmentsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getMedicalHistory() async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.medicalHistory,
      (data) => data,
    );
    if (response is Map<String, dynamic> &&
        response.containsKey('appointments')) {
      final appointmentsList = response['appointments'] as List<dynamic>;
      return appointmentsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> cancelAppointment(int id) async {
    final response = await _baseService.patchJson<dynamic>(
      Endpoints.cancelAppointment(id),
      {},
      (data) => data,
    );
    return response as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getAdminAppointmentsByDate(
    String date,
  ) async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminAppointmentsByDate(date),
      (data) => data,
    );

    if (response is Map<String, dynamic> &&
        response.containsKey('appointments')) {
      final appointmentsList = response['appointments'] as List<dynamic>;
      return appointmentsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> getAdminCalendarAppointments(
    String date,
  ) async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminCalendarAppointments(date),
      (data) => data,
    );

    if (response is Map<String, dynamic> &&
        response.containsKey('appointments')) {
      final appointmentsList = response['appointments'] as List<dynamic>;
      return appointmentsList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  Future<Map<String, dynamic>> getAdminCalendarAppointmentDetails(
    int id,
  ) async {
    final response = await _baseService.getJson<dynamic>(
      Endpoints.adminCalendarAppointmentDetails(id),
      (data) => data,
    );

    if (response is Map<String, dynamic> && response['appointment'] is Map) {
      return Map<String, dynamic>.from(response['appointment'] as Map);
    }

    return {};
  }

  Future<Map<String, dynamic>> updateAdminAppointmentStatus(
    int id,
    String status,
  ) async {
    final response = await _baseService.patchJson<dynamic>(
      Endpoints.adminUpdateAppointmentStatus(id),
      {'status': status},
      (data) => data,
    );

    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWalkInAppointment(
    Map<String, dynamic> payload,
  ) async {
    final response = await _baseService.postJson<dynamic>(
      Endpoints.adminWalkInAppointment,
      payload,
      (data) => data,
    );
    return response as Map<String, dynamic>;
  }
}
