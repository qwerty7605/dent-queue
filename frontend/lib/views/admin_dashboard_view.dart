import 'package:flutter/material.dart';
import '../models/admin_ui_notification.dart';
import '../widgets/admin_layout.dart';
import 'admin_patients_view.dart';
import 'admin_staff_view.dart';
import 'admin_master_list_view.dart';
import 'admin_profile_view.dart';
import 'admin_reports_view.dart';
import 'admin_settings_view.dart';
import '../core/token_storage.dart';
import '../core/api_client.dart';
import '../services/base_service.dart';
import '../services/patient_record_service.dart';
import '../services/admin_dashboard_service.dart';
import '../services/admin_staff_service.dart';
import '../services/admin_settings_service.dart';
import '../services/appointment_service.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({
    super.key,
    required this.userInfo,
    required this.tokenStorage,
    required this.onLogout,
    required this.loggingOut,
  });

  final Map<String, dynamic>? userInfo;
  final TokenStorage tokenStorage;
  final VoidCallback onLogout;
  final bool loggingOut;

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  String _activeRoute = 'Dashboard';
  late final PatientRecordService _patientRecordService;
  late final AdminDashboardService _adminDashboardService;
  late final AdminStaffService _adminStaffService;
  late final AdminSettingsService _adminSettingsService;
  late final AppointmentService _appointmentService;

  bool _isLoadingStats = true;
  Map<String, int> _dashboardStats = {
    'patients_count': 0,
    'staff_count': 0,
    'intern_count': 0,
    'staff_accounts_count': 0,
    'appointments_count': 0,
  };

  final List<AdminUiNotification> _notifications = <AdminUiNotification>[];
  Map<String, dynamic>? _localUserInfo;

  @override
  void initState() {
    super.initState();
    _localUserInfo = widget.userInfo;
    final apiClient = ApiClient(tokenStorage: widget.tokenStorage);
    final baseService = BaseService(apiClient);
    _patientRecordService = PatientRecordService(baseService);
    _adminDashboardService = AdminDashboardService(baseService);
    _adminStaffService = AdminStaffService(baseService);
    _adminSettingsService = AdminSettingsService(baseService);
    _appointmentService = AppointmentService(baseService);

    _loadDashboardStats();
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await _adminDashboardService.getStats();
      if (!mounted) return;
      setState(() {
        _dashboardStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingStats = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      activeRoute: _activeRoute,
      userInfo: _localUserInfo,
      onLogout: widget.onLogout,
      loggingOut: widget.loggingOut,
      notifications: _notifications,
      sidebarCounts: <String, int>{
        'Patients': _dashboardStats['patients_count'] ?? 0,
        'Staff': _dashboardStats['staff_accounts_count'] ?? 0,
      },
      onNavigate: (route) {
        setState(() {
          _activeRoute = route;
        });
      },
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_activeRoute) {
      case 'Dashboard':
        return _buildDashboardContent();
      case 'Patients':
        return AdminPatientsView(patientRecordService: _patientRecordService);
      case 'Staff':
        return AdminStaffView(
          adminStaffService: _adminStaffService,
          onStaffChanged: () {
            _loadDashboardStats();
          },
        );
      case 'Master List':
        return AdminMasterListView(appointmentService: _appointmentService);
      case 'Reports':
        return AdminReportsView(
          adminDashboardService: _adminDashboardService,
          appointmentService: _appointmentService,
          showDetailedRecords: false,
        );
      case 'Settings':
        return AdminSettingsView(
          adminSettingsService: _adminSettingsService,
          canManageSettings: _canManageClinicSettings(),
          onNotify: _addNotification,
        );
      case 'Profile':
        return AdminProfileView(
          activeUser: _localUserInfo,
          tokenStorage: widget.tokenStorage,
          onProfileUpdated: (updatedUser) {
            setState(() {
              if (_localUserInfo != null) {
                // Completely merge top-level keys
                _localUserInfo = Map<String, dynamic>.from(_localUserInfo!)
                  ..addAll(updatedUser);

                // Reconstruct the synthetic 'name' field
                final fName = _localUserInfo!['first_name']?.toString() ?? '';
                final mName = _localUserInfo!['middle_name']?.toString() ?? '';
                final lName = _localUserInfo!['last_name']?.toString() ?? '';
                final newName = ('$fName $mName $lName')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
                if (newName.isNotEmpty) {
                  _localUserInfo!['name'] = newName;
                }

                // Save safely backwards to TokenStorage to survive cold app reloads
                widget.tokenStorage.writeUserInfo(_localUserInfo!);
              }
            });
          },
        );
      default:
        return _buildDashboardContent();
    }
  }

  void _addNotification(String title, String message) {
    setState(() {
      _notifications.insert(
        0,
        AdminUiNotification(
          title: title,
          message: message,
          createdAt: DateTime.now(),
        ),
      );

      if (_notifications.length > 8) {
        _notifications.removeRange(8, _notifications.length);
      }
    });
  }

  bool _canManageClinicSettings() {
    final userInfo = _localUserInfo;
    if (userInfo == null) {
      return false;
    }

    final directRole = _normalizeRoleValue(userInfo['role']);
    if (directRole == 'admin') {
      return true;
    }

    final roleName = _normalizeRoleValue(userInfo['role_name']);
    if (roleName == 'admin') {
      return true;
    }

    final roles = userInfo['roles'];
    if (roles is List) {
      for (final role in roles) {
        if (_normalizeRoleValue(role) == 'admin') {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizeRoleValue(dynamic value) {
    if (value is String) {
      return value.trim().toLowerCase();
    }

    if (value is Map) {
      final roleName = value['name']?.toString().trim().toLowerCase();
      if (roleName != null && roleName.isNotEmpty) {
        return roleName;
      }
    }

    return '';
  }

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 48),

          Wrap(
            spacing: 32,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: [
              _buildDashboardCard(
                title: 'Patients',
                value: _isLoadingStats
                    ? '...'
                    : (_dashboardStats['patients_count'] ?? 0).toString(),
                icon: Icons.badge_outlined,
                mainColor: const Color(
                  0xFF6A9A8B,
                ), // Slightly grayish green-blue
                darkColor: const Color(0xFF50786A),
              ),
              _buildDashboardCard(
                title: 'Staff & Interns',
                value: _isLoadingStats
                    ? '...'
                    : (_dashboardStats['staff_accounts_count'] ?? 0).toString(),
                icon: Icons.medical_services_outlined,
                mainColor: const Color(0xFF86B9B0), // Teal
                darkColor: const Color(0xFF6E9A92),
              ),
              _buildDashboardCard(
                title: 'Master List',
                value: _isLoadingStats
                    ? '...'
                    : (_dashboardStats['appointments_count'] ?? 0).toString(),
                icon: Icons.list_alt,
                mainColor: const Color(0xFFE5CC82), // Sand Yellow
                darkColor: const Color(0xFFBCA663),
              ),
              _buildDashboardCard(
                title: 'Settings',
                value: '', // No number from design
                icon: Icons.settings,
                mainColor: const Color(0xFFE28B71), // Orange Red
                darkColor: const Color(0xFFBA6952),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required IconData icon,
    required Color mainColor,
    required Color darkColor,
  }) {
    return Container(
      width: 480,
      height: 198,
      decoration: BoxDecoration(
        color: mainColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 36.0,
                vertical: 24.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (value.isNotEmpty)
                        Text(
                          value,
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      if (value.isEmpty) const SizedBox(height: 24),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    icon,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Navigate to the respective page when clicking More Info
                setState(() {
                  _activeRoute = title;
                });
              },
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: Ink(
                height: 46,
                decoration: BoxDecoration(
                  color: darkColor,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'More Info',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.arrow_circle_right,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
