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
  static String cancelAppointment(int id) =>
      '$_base/patient/appointments/$id/cancel';
  static String updateProfile(int id) => '$_base/patient/profile/$id';

  static String adminAppointmentsByDate(String date) =>
      '$_base/admin/appointments?date=$date';
  static String adminUpdateAppointmentStatus(int id) =>
      '$_base/admin/appointments/$id/status';
  static const adminWalkInAppointment = '$_base/admin/appointments/walk-in';
}
