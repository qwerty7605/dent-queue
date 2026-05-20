import 'package:flutter/material.dart';

import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';
import 'admin_reports_view.dart';

class StaffReportsView extends StatelessWidget {
  const StaffReportsView({
    super.key,
    required this.adminDashboardService,
    required this.appointmentService,
  });

  final AdminDashboardService adminDashboardService;
  final AppointmentService appointmentService;

  @override
  Widget build(BuildContext context) {
    return AdminReportsView(
      adminDashboardService: adminDashboardService,
      appointmentService: appointmentService,
      canExport: false,
      showDetailedRecords: false,
    );
  }
}
