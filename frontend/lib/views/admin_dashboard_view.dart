import 'package:flutter/material.dart';
import '../core/mobile_typography.dart';
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
import '../widgets/dashboard_stat_card.dart';

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

  Future<void> _loadDashboardStats({bool forceRefresh = false}) async {
    if (mounted) {
      setState(() {
        _isLoadingStats = true;
      });
    }

    try {
      final stats = await _adminDashboardService.getStats(
        forceRefresh: forceRefresh,
      );
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
    final List<Map<String, dynamic>> cards = <Map<String, dynamic>>[
      <String, dynamic>{
        'route': 'Patients',
        'title': 'Patients',
        'value': _isLoadingStats
            ? '...'
            : (_dashboardStats['patients_count'] ?? 0).toString(),
        'icon': Icons.badge_outlined,
        'accentColor': const Color(0xFF50786A),
        'backgroundColor': const Color(0xFFEAF3F0),
      },
      <String, dynamic>{
        'route': 'Staff',
        'title': 'Staff & Interns',
        'value': _isLoadingStats
            ? '...'
            : (_dashboardStats['staff_accounts_count'] ?? 0).toString(),
        'icon': Icons.medical_services_outlined,
        'accentColor': const Color(0xFF6E9A92),
        'backgroundColor': const Color(0xFFE9F5F3),
      },
      <String, dynamic>{
        'route': 'Master List',
        'title': 'Master List',
        'value': _isLoadingStats
            ? '...'
            : (_dashboardStats['appointments_count'] ?? 0).toString(),
        'icon': Icons.list_alt,
        'accentColor': const Color(0xFFBCA663),
        'backgroundColor': const Color(0xFFFBF6E8),
      },
      <String, dynamic>{
        'route': 'Settings',
        'title': 'Settings',
        'value': '',
        'icon': Icons.settings,
        'accentColor': const Color(0xFFBA6952),
        'backgroundColor': const Color(0xFFFCEEE9),
      },
    ];

    return SingleChildScrollView(
      padding: MobileTypography.screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Dashboard',
            style: TextStyle(
              fontSize: MobileTypography.pageTitle(context),
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _isLoadingStats
                ? null
                : () => _loadDashboardStats(forceRefresh: true),
            icon: const Icon(Icons.refresh),
            label: Text(_isLoadingStats ? 'Refreshing...' : 'Refresh'),
          ),
          SizedBox(height: MobileTypography.isPhone(context) ? 24 : 48),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double contentWidth = constraints.maxWidth > 1120
                  ? 1120
                  : constraints.maxWidth;
              final int crossAxisCount = contentWidth >= 1040
                  ? 4
                  : contentWidth >= 720
                  ? 2
                  : 1;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      mainAxisExtent: 204,
                    ),
                    itemBuilder: (BuildContext context, int index) {
                      final Map<String, dynamic> card = cards[index];
                      final Color accentColor = card['accentColor']! as Color;

                      return DashboardStatCard(
                        title: card['title']! as String,
                        value: card['value']! as String,
                        icon: card['icon']! as IconData,
                        accentColor: accentColor,
                        backgroundColor: card['backgroundColor']! as Color,
                        contentAlignment: DashboardCardContentAlignment.start,
                        contentColor: const Color(0xFF243746),
                        iconColor: accentColor,
                        footerLabel: 'More Info',
                        footerBackgroundColor: accentColor,
                        footerTextColor: Colors.white,
                        onTap: () {
                          setState(() {
                            _activeRoute = card['route']! as String;
                          });
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
