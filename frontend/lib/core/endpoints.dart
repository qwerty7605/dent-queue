class Endpoints {
  // versioning and auth path to match Laravel routes
  static const _base = '/api/v1';

  static const status = '$_base/status';

  static const login = '$_base/auth/login';
  static const register = '$_base/auth/register';
  static const logout = '$_base/auth/logout';
  static const me = '$_base/user';

  static const services = '$_base/patient/services';
  static const appointments = '$_base/patient/appointments';
  static String patientAppointment(int id) => '$_base/patient/appointments/$id';
  static const medicalHistory = '$_base/patient/appointments/history';
  static String availabilitySlots(String date, {int? ignoreAppointmentId}) =>
      _withQueryParameters('$_base/availability/slots', <String, String>{
        'date': date,
        if (ignoreAppointmentId != null)
          'ignore_appointment_id': ignoreAppointmentId.toString(),
      });
  static String patientNotifications([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/patient/notifications', queryParameters);
  static const patientNotificationsMarkAllRead =
      '$_base/patient/notifications/read-all';
  static String patientTodayQueue([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/patient/queues/today', queryParameters);
  static const patientJoinQueue = '$_base/patient/queues/join';
  static String cancelAppointment(int id) =>
      '$_base/patient/appointments/$id/cancel';
  static String rescheduleAppointment(int id) =>
      '$_base/patient/appointments/$id';
  static String restoreAppointment(int id) =>
      '$_base/patient/appointments/$id/restore';
  static const patientRecycleBin = '$_base/patient/appointments/recycle-bin';

  static String patientNotificationMarkRead(int id) =>
      '$_base/patient/notifications/$id/read';
  static String updatePatientProfile(int id) => '$_base/patient/profile/$id';
  static String staffNotifications([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/staff/notifications', queryParameters);
  static const staffNotificationsMarkAllRead =
      '$_base/staff/notifications/read-all';
  static String staffNotificationMarkRead(int id) =>
      '$_base/staff/notifications/$id/read';
  static String updateStaffProfile(int id) => '$_base/staff/profile/$id';

  static String adminAppointmentsByDate(String date) =>
      _withQueryParameters('$_base/admin/appointments', <String, String>{
        'date': date,
      });
  static String adminCalendarAppointments(String date) => _withQueryParameters(
    '$_base/admin/calendar/appointments',
    <String, String>{'date': date},
  );
  static String adminCalendarAppointmentDetails(int id) =>
      '$_base/admin/calendar/appointments/$id';
  static String adminDashboardStats([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/admin/dashboard/stats', queryParameters);
  static String adminReportsSummary([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/admin/reports/summary', queryParameters);
  static String adminReportsTrends(
    String trendType, [
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/admin/reports/trends', <String, String>{
    'trend_type': trendType,
    ...queryParameters,
  });
  static String adminReportsExport([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/admin/reports/export', queryParameters);
  static const adminProfileUpdate = '$_base/admin/profile';
  static const adminAppointments = '$_base/admin/appointments';
  static String adminMasterList([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters(
    '$_base/admin/appointments/master-list',
    queryParameters,
  );
  static const staffRecycleBin = '$_base/admin/appointments/recycle-bin';
  static const adminClinicSettings = '$_base/admin/settings/clinic';
  static const adminDoctorUnavailability =
      '$_base/admin/settings/doctor-unavailability';
  static String adminDeleteDoctorUnavailability(int id) =>
      '$_base/admin/settings/doctor-unavailability/$id';
  static String adminTodayQueue(
    String? date, {
    Map<String, String> queryParameters = const <String, String>{},
  }) => _withQueryParameters('$_base/admin/queues/today', <String, String>{
    if (date != null && date.isNotEmpty) 'date': date,
    ...queryParameters,
  });
  static const adminCallNextQueue = '$_base/admin/queues/call-next';
  static String adminUpdateAppointmentStatus(int id) =>
      '$_base/admin/appointments/$id/status';
  static const adminWalkInAppointment = '$_base/admin/appointments/walk-in';
  static const adminPatients = '$_base/admin/patients';
  static String adminPatientsList([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/admin/patients', queryParameters);
  static const adminStaff = '$_base/admin/staff';
  static String adminStaffList([
    Map<String, String> queryParameters = const <String, String>{},
  ]) => _withQueryParameters('$_base/admin/staff', queryParameters);
  static String adminDeleteStaff(int id) => '$_base/admin/staff/$id';
  static String adminPatientSearch(String query) =>
      '$_base/admin/patients/search?query=${Uri.encodeQueryComponent(query)}';
  static String adminPatientDetail(String patientId) =>
      '$_base/admin/patients/${Uri.encodeComponent(patientId)}';

  static String _withQueryParameters(
    String path,
    Map<String, String> queryParameters,
  ) {
    if (queryParameters.isEmpty) {
      return path;
    }

    return Uri(path: path, queryParameters: queryParameters).toString();
  }
}
