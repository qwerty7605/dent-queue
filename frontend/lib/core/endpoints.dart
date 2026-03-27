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
  static const medicalHistory = '$_base/patient/appointments/history';
  static const patientTodayQueue = '$_base/patient/queues/today';
  static const patientJoinQueue = '$_base/patient/queues/join';
  static String cancelAppointment(int id) =>
      '$_base/patient/appointments/$id/cancel';
  static String updatePatientProfile(int id) => '$_base/patient/profile/$id';
  static String updateStaffProfile(int id) => '$_base/staff/profile/$id';

  static String adminAppointmentsByDate(String date) =>
      '$_base/admin/appointments?date=$date';
  static String adminCalendarAppointments(String date) =>
      '$_base/admin/calendar/appointments?date=$date';
  static String adminCalendarAppointmentDetails(int id) =>
      '$_base/admin/calendar/appointments/$id';
  static const adminDashboardStats = '$_base/admin/dashboard/stats';
  static const adminReportsSummary = '$_base/admin/reports/summary';
  static const adminProfileUpdate = '$_base/admin/profile';
  static const adminAppointments = '$_base/admin/appointments';
  static const adminMasterList = '$_base/admin/appointments/master-list';
  static const adminClinicSettings = '$_base/admin/settings/clinic';
  static String adminTodayQueue([String? date]) => date == null || date.isEmpty
      ? '$_base/admin/queues/today'
      : '$_base/admin/queues/today?date=$date';
  static const adminCallNextQueue = '$_base/admin/queues/call-next';
  static String adminUpdateAppointmentStatus(int id) =>
      '$_base/admin/appointments/$id/status';
  static const adminWalkInAppointment = '$_base/admin/appointments/walk-in';
  static const adminPatients = '$_base/admin/patients';
  static const adminStaff = '$_base/admin/staff';
  static String adminDeleteStaff(int id) => '$_base/admin/staff/$id';
  static String adminPatientSearch(String query) =>
      '$_base/admin/patients/search?query=${Uri.encodeQueryComponent(query)}';
  static String adminPatientDetail(String patientId) =>
      '$_base/admin/patients/${Uri.encodeComponent(patientId)}';
}
