import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../models/admin_ui_notification.dart';
import '../services/admin_dashboard_service.dart';
import '../services/admin_settings_service.dart';
import '../services/admin_staff_service.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import '../services/patient_record_service.dart';
import '../widgets/admin_layout.dart';
import '../widgets/appointment_status_badge.dart';
import 'admin_master_list_view.dart';
import 'admin_patients_view.dart';
import 'admin_profile_view.dart';
import 'admin_reports_view.dart';
import 'admin_settings_view.dart';
import 'admin_staff_view.dart';

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
  static const List<_DashboardMetricConfig> _metricConfigs =
      <_DashboardMetricConfig>[
        _DashboardMetricConfig(
          route: 'Patients',
          title: 'PATIENT ACCOUNTS',
          description: 'Registered patient records',
          icon: Icons.groups_outlined,
          badgeText: 'LIVE',
        ),
        _DashboardMetricConfig(
          route: 'Staff',
          title: 'STAFF REGISTRY',
          description: 'Total active practitioners',
          icon: Icons.person_outline_rounded,
          badgeText: 'ACTIVE',
        ),
        _DashboardMetricConfig(
          route: 'Appointments',
          title: 'APPOINTMENTS',
          description: 'Scheduled clinical procedures',
          icon: Icons.assignment_outlined,
          badgeText: 'SYNCED',
        ),
        _DashboardMetricConfig(
          route: 'Reports',
          title: 'REPORTS',
          description: 'Clinical efficiency analytics',
          icon: Icons.bar_chart_outlined,
          badgeText: 'READY',
        ),
      ];

  String _activeRoute = 'Dashboard';
  late final PatientRecordService _patientRecordService;
  late final AdminDashboardService _adminDashboardService;
  late final AdminStaffService _adminStaffService;
  late final AdminSettingsService _adminSettingsService;
  late final AppointmentService _appointmentService;

  bool _isLoadingDashboard = true;
  Map<String, int> _dashboardStats = <String, int>{
    'patients_count': 0,
    'staff_count': 0,
    'intern_count': 0,
    'staff_accounts_count': 0,
    'appointments_count': 0,
  };
  Map<String, int> _reportSummary = <String, int>{
    'report_records': 0,
    'completed': 0,
    'approved': 0,
    'pending': 0,
  };
  List<Map<String, dynamic>> _masterListPreview = <Map<String, dynamic>>[];
  Map<String, dynamic> _clinicSettings = <String, dynamic>{};

  final List<AdminUiNotification> _notifications = <AdminUiNotification>[];
  Map<String, dynamic>? _localUserInfo;
  bool _adminDarkMode = false;
  bool get _isDarkMode => _adminDarkMode;
  Color get _panelColor => _isDarkMode ? const Color(0xFF162033) : Colors.white;
  Color get _panelAltColor =>
      _isDarkMode ? const Color(0xFF1B2740) : const Color(0xFFF7F9FE);
  Color get _panelBorderColor =>
      _isDarkMode ? const Color(0xFF30415F) : const Color(0xFFE4EAF5);
  Color get _headingColor =>
      _isDarkMode ? const Color(0xFFEAF1FF) : const Color(0xFF1D3264);
  Color get _bodyColor =>
      _isDarkMode ? const Color(0xFFD2DCEF) : const Color(0xFF52607C);
  Color get _mutedColor =>
      _isDarkMode ? const Color(0xFFAAB8D4) : const Color(0xFF9AA8C4);
  Color get _lineColor =>
      _isDarkMode ? const Color(0xFF25344E) : const Color(0xFFF0F3FA);

  @override
  void initState() {
    super.initState();
    _localUserInfo = widget.userInfo;
    final ApiClient apiClient = ApiClient(tokenStorage: widget.tokenStorage);
    final BaseService baseService = BaseService(apiClient);
    _patientRecordService = PatientRecordService(baseService);
    _adminDashboardService = AdminDashboardService(baseService);
    _adminStaffService = AdminStaffService(baseService);
    _adminSettingsService = AdminSettingsService(baseService);
    _appointmentService = AppointmentService(baseService);

    final bool showedCachedSnapshot = _applyCachedDashboardSnapshot();
    unawaited(_loadDashboardSnapshot(showLoader: !showedCachedSnapshot));
  }

  bool _applyCachedDashboardSnapshot() {
    final Map<String, int>? cachedStats = _adminDashboardService.getCachedStats(
      allowStale: true,
    );
    final Map<String, int>? cachedReportSummary = _adminDashboardService
        .getCachedReportSummary(const <String, String>{}, true);
    final List<Map<String, dynamic>>? cachedPendingAppointments =
        _appointmentService.getCachedAdminMasterList(const <String, String>{
          'status': 'pending',
        }, allowStale: true);
    final Map<String, dynamic>? cachedClinicSettings = _adminSettingsService
        .getCachedClinicSettings(allowStale: true);

    final bool hasCachedSnapshot =
        cachedStats != null ||
        cachedReportSummary != null ||
        cachedPendingAppointments != null ||
        cachedClinicSettings != null;

    if (!hasCachedSnapshot) {
      return false;
    }

    if (!mounted) {
      return false;
    }

    if (cachedPendingAppointments != null) {
      cachedPendingAppointments.sort(_compareRecentAppointments);
    }

    setState(() {
      if (cachedStats != null) {
        _dashboardStats = cachedStats;
      }
      if (cachedReportSummary != null) {
        _reportSummary = cachedReportSummary;
      }
      if (cachedPendingAppointments != null) {
        _masterListPreview = cachedPendingAppointments.take(10).toList();
      }
      if (cachedClinicSettings != null) {
        _clinicSettings = cachedClinicSettings;
      }
      _isLoadingDashboard = false;
    });

    return true;
  }

  Future<void> _loadDashboardSnapshot({
    bool forceRefresh = false,
    bool showLoader = true,
  }) async {
    if (mounted && showLoader) {
      setState(() {
        _isLoadingDashboard = true;
      });
    }

    try {
      if (forceRefresh) {
        _appointmentService.invalidateAppointmentCaches();
        _adminSettingsService.invalidateClinicSettingsCache();
      }

      final List<dynamic> results = await Future.wait<dynamic>(
        <Future<dynamic>>[
          _adminDashboardService.getStats(forceRefresh: forceRefresh),
          _adminDashboardService.getReportSummary(
            const <String, String>{},
            forceRefresh,
          ),
          _appointmentService.getAdminMasterList(const <String, String>{
            'status': 'pending',
          }),
          _adminSettingsService.getClinicSettings(),
        ],
      );

      if (!mounted) {
        return;
      }

      final List<Map<String, dynamic>> pendingAppointments =
          List<Map<String, dynamic>>.from(
            results[2] as List<Map<String, dynamic>>,
          )..sort(_compareRecentAppointments);

      setState(() {
        _dashboardStats = Map<String, int>.from(results[0] as Map);
        _reportSummary = Map<String, int>.from(results[1] as Map);
        _masterListPreview = pendingAppointments.take(10).toList();
        _clinicSettings = Map<String, dynamic>.from(results[3] as Map);
        _isLoadingDashboard = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingDashboard = false;
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
      isDarkMode: _adminDarkMode,
      onToggleDarkMode: () {
        setState(() {
          _adminDarkMode = !_adminDarkMode;
        });
      },
      sidebarCounts: <String, int>{
        'Patients': _dashboardStats['patients_count'] ?? 0,
        'Staff': _dashboardStats['staff_accounts_count'] ?? 0,
      },
      onNavigate: (String route) {
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
            _loadDashboardSnapshot();
          },
        );
      case 'Appointments':
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
          onNotify: (String title, String message) {
            _addNotification(title, message);
            _loadDashboardSnapshot(forceRefresh: true);
          },
        );
      case 'Profile':
        return AdminProfileView(
          activeUser: _localUserInfo,
          tokenStorage: widget.tokenStorage,
          onProfileUpdated: (updatedUser) {
            setState(() {
              if (_localUserInfo != null) {
                _localUserInfo = Map<String, dynamic>.from(_localUserInfo!)
                  ..addAll(updatedUser);

                final String fName =
                    _localUserInfo!['first_name']?.toString() ?? '';
                final String mName =
                    _localUserInfo!['middle_name']?.toString() ?? '';
                final String lName =
                    _localUserInfo!['last_name']?.toString() ?? '';
                final String newName = ('$fName $mName $lName')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .trim();
                if (newName.isNotEmpty) {
                  _localUserInfo!['name'] = newName;
                }

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
    final Map<String, dynamic>? userInfo = _localUserInfo;
    if (userInfo == null) {
      return false;
    }

    final String directRole = _normalizeRoleValue(userInfo['role']);
    if (directRole == 'admin') {
      return true;
    }

    final String roleName = _normalizeRoleValue(userInfo['role_name']);
    if (roleName == 'admin') {
      return true;
    }

    final dynamic roles = userInfo['roles'];
    if (roles is List) {
      for (final dynamic role in roles) {
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
      final String? roleName = value['name']?.toString().trim().toLowerCase();
      if (roleName != null && roleName.isNotEmpty) {
        return roleName;
      }
    }

    return '';
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: () => _loadDashboardSnapshot(forceRefresh: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          MobileTypography.isPhone(context) ? 14 : 20,
          20,
          MobileTypography.isPhone(context) ? 14 : 20,
          28,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1540),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMetricGrid(),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    if (constraints.maxWidth < 1080) {
                      return Column(
                        children: [
                          _buildMasterListPanel(),
                          const SizedBox(height: 20),
                          _buildRightColumn(),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: _buildMasterListPanel()),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _buildRightColumn()),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricGrid() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double totalSpacing = 16 * (_metricConfigs.length - 1);
        final bool fitsSingleRow = constraints.maxWidth >= 980;

        final List<Widget> cards = _metricConfigs.map((
          _DashboardMetricConfig metric,
        ) {
          return _DashboardMetricCard(
            title: metric.title,
            value: _metricValue(metric.route),
            description: _metricDescription(metric.route, metric.description),
            icon: metric.icon,
            badgeText: metric.badgeText,
            loading: _isLoadingDashboard,
            onTap: () {
              setState(() {
                _activeRoute = metric.route;
              });
            },
          );
        }).toList();

        if (fitsSingleRow) {
          final double cardWidth =
              (constraints.maxWidth - totalSpacing) / _metricConfigs.length;

          return Row(
            children: List<Widget>.generate(cards.length, (int index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == cards.length - 1 ? 0 : 16,
                ),
                child: SizedBox(
                  width: cardWidth,
                  height: 192,
                  child: cards[index],
                ),
              );
            }),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List<Widget>.generate(cards.length, (int index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == cards.length - 1 ? 0 : 16,
                ),
                child: SizedBox(width: 224, height: 192, child: cards[index]),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildMasterListPanel() {
    return Container(
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _panelBorderColor),
        boxShadow: [
          BoxShadow(
            color: (_isDarkMode ? Colors.black : const Color(0xFF0E1A3A))
                .withValues(alpha: _isDarkMode ? 0.24 : 0.03),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Appointments',
                        style: TextStyle(
                          color: _headingColor,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'RECENT PENDING APPOINTMENT REQUESTS',
                        style: TextStyle(
                          color: _mutedColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _activeRoute = 'Appointments';
                    });
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Open'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _lineColor),
          if (_isLoadingDashboard && _masterListPreview.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 76),
              child: Center(
                child: CircularProgressIndicator(
                  color: _isDarkMode
                      ? const Color(0xFFB6C8F5)
                      : const Color(0xFF1F356C),
                ),
              ),
            )
          else if (_masterListPreview.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: _DashboardEmptyState(
                icon: Icons.assignment_outlined,
                title: 'No appointments yet',
                message:
                    'The master list preview will appear here once appointment records are available.',
              ),
            )
          else
            Column(
              children: [
                _buildTableHeader(),
                ..._masterListPreview.map(_buildTableRow),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 10),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'PATIENT NAME',
              style: _DashboardSectionStyles.tableHeading(_isDarkMode),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'TREATMENT',
              style: _DashboardSectionStyles.tableHeading(_isDarkMode),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'DATE/TIME',
              style: _DashboardSectionStyles.tableHeading(_isDarkMode),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'STATUS',
              style: _DashboardSectionStyles.tableHeading(_isDarkMode),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(Map<String, dynamic> appointment) {
    final String secondaryLabel = _dashboardSecondaryLabel(appointment);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _lineColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayText(appointment['patient_name']),
                  style: TextStyle(
                    color: _headingColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (secondaryLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondaryLabel,
                    style: TextStyle(
                      color: _mutedColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _displayText(appointment['service']),
              style: TextStyle(
                color: _bodyColor,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatAppointmentDate(appointment),
                  style: TextStyle(
                    color: _headingColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAppointmentTime(appointment),
                  style: TextStyle(
                    color: _mutedColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.center,
              child: AppointmentStatusBadge(
                status: appointment['status'],
                compact: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Column(
      children: [
        _buildSettingsPanel(),
        const SizedBox(height: 20),
        _buildSystemLogsPanel(),
      ],
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _panelBorderColor),
        boxShadow: [
          BoxShadow(
            color: (_isDarkMode ? Colors.black : const Color(0xFF0E1A3A))
                .withValues(alpha: _isDarkMode ? 0.24 : 0.03),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _panelAltColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _panelBorderColor),
            ),
            child: const Icon(
              Icons.settings_outlined,
              color: Color(0xFF1F356C),
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Clinic Settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _headingColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'STAFF SCHEDULES & OPERATIONAL PARAMETERS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _panelAltColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _panelBorderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoLine(label: 'Hours', value: _formatClinicHours()),
                const SizedBox(height: 10),
                _InfoLine(label: 'Working days', value: _formatWorkingDays()),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  _activeRoute = 'Settings';
                });
              },
              icon: const Icon(Icons.north_east_rounded, size: 18),
              label: const Text('Configuration Suite'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLogsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF223A78),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'System Logs',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'RECENT ADMIN ACTIVITY & REPORT SNAPSHOTS',
                      style: TextStyle(
                        color: Color(0xFFC8D3F1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SystemLogStat(
            label: 'Notifications',
            value: _notifications.length.toString(),
          ),
          const SizedBox(height: 12),
          _SystemLogStat(
            label: 'Reportable appointments',
            value: NumberFormat.compact().format(
              _reportSummary['total'] ?? 0,
            ),
          ),
          const SizedBox(height: 12),
          _SystemLogStat(
            label: 'Completed cases',
            value: (_reportSummary['completed'] ?? 0).toString(),
          ),
          const SizedBox(height: 18),
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                _activeRoute = 'Reports';
              });
            },
            icon: const Icon(Icons.insights_outlined),
            label: const Text('Open Reports'),
          ),
        ],
      ),
    );
  }

  String _metricValue(String route) {
    if (_isLoadingDashboard) {
      return '...';
    }

    switch (route) {
      case 'Patients':
        return _compactNumber(_dashboardStats['patients_count'] ?? 0);
      case 'Staff':
        return _compactNumber(_dashboardStats['staff_accounts_count'] ?? 0);
      case 'Appointments':
        return _compactNumber(_dashboardStats['appointments_count'] ?? 0);
      case 'Reports':
        return _compactNumber(_reportSummary['total'] ?? 0);
      default:
        return '0';
    }
  }

  String _metricDescription(String route, String fallback) {
    if (_isLoadingDashboard) {
      return 'Pulling the latest figures...';
    }

    switch (route) {
      case 'Patients':
        return fallback;
      case 'Staff':
        final int staff = _dashboardStats['staff_count'] ?? 0;
        final int interns = _dashboardStats['intern_count'] ?? 0;
        return '$staff practitioners and $interns interns';
      case 'Appointments':
        return fallback;
      case 'Reports':
        final int completed = _reportSummary['completed'] ?? 0;
        final int pending = _reportSummary['pending'] ?? 0;
        return '$completed completed and $pending pending items';
      default:
        return fallback;
    }
  }

  String _compactNumber(int value) {
    if (value >= 1000) {
      return NumberFormat.compact().format(value).toLowerCase();
    }
    return NumberFormat.decimalPattern().format(value);
  }

  String _displayText(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'No data yet' : text;
  }

  String _dashboardSecondaryLabel(Map<String, dynamic> appointment) {
    final List<String> parts = <String>[
      appointment['patient_id']?.toString() ?? '',
      appointment['contact']?.toString() ?? '',
      appointment['queue_number']?.toString() ?? '',
    ].where((String value) => value.trim().isNotEmpty).toList();

    return parts.isEmpty ? '' : parts.first;
  }

  String _formatAppointmentDate(Map<String, dynamic> appointment) {
    final String raw =
        appointment['date']?.toString() ??
        appointment['appointment_date']?.toString() ??
        '';
    if (raw.isEmpty) {
      return 'No schedule';
    }

    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }

    return DateFormat('MMM d, yyyy').format(parsed);
  }

  String _formatAppointmentTime(Map<String, dynamic> appointment) {
    final String raw =
        appointment['time']?.toString() ??
        appointment['appointment_time']?.toString() ??
        '';
    if (raw.isEmpty) {
      return 'Time pending';
    }

    final String normalized = raw.length == 5 ? '$raw:00' : raw;
    final DateTime? parsed = DateTime.tryParse('2024-01-01 $normalized');
    if (parsed == null) {
      return raw;
    }

    return DateFormat('hh:mm a').format(parsed);
  }

  int _compareRecentAppointments(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    final DateTime leftCreated = _resolveComparableDateTime(
      left['created_at']?.toString(),
      left['appointment_date']?.toString(),
      left['date']?.toString(),
      left['appointment_time']?.toString(),
      left['time']?.toString(),
    );
    final DateTime rightCreated = _resolveComparableDateTime(
      right['created_at']?.toString(),
      right['appointment_date']?.toString(),
      right['date']?.toString(),
      right['appointment_time']?.toString(),
      right['time']?.toString(),
    );

    final int byCreated = rightCreated.compareTo(leftCreated);
    if (byCreated != 0) {
      return byCreated;
    }

    final int leftId =
        int.tryParse(left['appointment_id']?.toString() ?? '') ?? 0;
    final int rightId =
        int.tryParse(right['appointment_id']?.toString() ?? '') ?? 0;
    return rightId.compareTo(leftId);
  }

  DateTime _resolveComparableDateTime(
    String? createdAtRaw,
    String? appointmentDateRaw,
    String? dateRaw,
    String? appointmentTimeRaw,
    String? timeRaw,
  ) {
    final DateTime? createdAt = _tryParseDateTime(createdAtRaw);
    if (createdAt != null) {
      return createdAt;
    }

    final String? dateValue = _firstNonEmpty(<String?>[
      appointmentDateRaw,
      dateRaw,
    ]);
    final String? timeValue = _firstNonEmpty(<String?>[
      appointmentTimeRaw,
      timeRaw,
      '00:00',
    ]);

    final DateTime? scheduledDateTime = _tryParseDateTime(
      '${dateValue ?? '1970-01-01'} ${_normalizeTimeToken(timeValue ?? '00:00')}',
    );

    return scheduledDateTime ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _tryParseDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    final DateTime? direct = DateTime.tryParse(raw.trim());
    if (direct != null) {
      return direct;
    }

    return DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).tryParse(raw.trim(), true)?.toLocal();
  }

  String _normalizeTimeToken(String raw) {
    final String normalized = raw.trim();
    if (RegExp(r'^\d{2}:\d{2}$').hasMatch(normalized)) {
      return '$normalized:00';
    }
    return normalized;
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final String? value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  String _formatClinicHours() {
    final String opening = _formatApiTime(
      _clinicSettings['opening_time']?.toString(),
    );
    final String closing = _formatApiTime(
      _clinicSettings['closing_time']?.toString(),
    );

    if (opening.isEmpty && closing.isEmpty) {
      return _isLoadingDashboard ? 'Loading clinic hours...' : 'Not configured';
    }

    return '$opening - $closing';
  }

  String _formatWorkingDays() {
    final dynamic value = _clinicSettings['working_days'];
    if (value is List && value.isNotEmpty) {
      final List<String> days = value
          .map((dynamic item) => item.toString().trim())
          .where((String item) => item.isNotEmpty)
          .toList();
      if (days.isNotEmpty) {
        if (days.length <= 3) {
          return days.join(', ');
        }
        return '${days.first} - ${days.last}';
      }
    }

    return _isLoadingDashboard ? 'Loading clinic days...' : 'Default weekdays';
  }

  String _formatApiTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '';
    }

    final List<String> parts = value.split(':');
    if (parts.length < 2) {
      return value;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return value;
    }

    final DateTime parsed = DateTime(2024, 1, 1, hour, minute);
    return DateFormat('hh:mm a').format(parsed);
  }
}

class _DashboardMetricConfig {
  const _DashboardMetricConfig({
    required this.route,
    required this.title,
    required this.description,
    required this.icon,
    required this.badgeText,
  });

  final String route;
  final String title;
  final String description;
  final IconData icon;
  final String badgeText;
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.badgeText,
    required this.loading,
    required this.onTap,
  });

  final String title;
  final String value;
  final String description;
  final IconData icon;
  final String badgeText;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color cardBackground = isDarkMode
        ? const Color(0xFF162033)
        : const Color(0xFFF3F7FF);
    final Color cardBorder = isDarkMode
        ? const Color(0xFF30415F)
        : const Color(0xFFDDE6F5);
    final Color iconBadgeBackground = isDarkMode
        ? const Color(0xFF1D2A44)
        : const Color(0xFFE2EBFB);
    final Color metricBadgeBackground = isDarkMode
        ? const Color(0xFF1A253A)
        : const Color(0xFFEAFBF0);
    final Color metricBadgeBorder = isDarkMode
        ? const Color(0xFF2B3956)
        : const Color(0xFFD3F2E2);
    final Color metricBadgeText = isDarkMode
        ? const Color(0xFFD7E4FF)
        : const Color(0xFF1A8D4B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: (isDarkMode ? Colors.black : const Color(0xFF22386F))
                    .withValues(alpha: isDarkMode ? 0.24 : 0.04),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBadgeBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Icon(
                      icon,
                      color: isDarkMode
                          ? const Color(0xFFBCD0FF)
                          : const Color(0xFF1F356C),
                      size: 24,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: metricBadgeBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: metricBadgeBorder),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        color: metricBadgeText,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFAAB8D4)
                      : const Color(0xFF7E8EA9),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Text(
                  value,
                  key: ValueKey<String>(value),
                  style: TextStyle(
                    color: isDarkMode
                        ? const Color(0xFFEAF1FF)
                        : const Color(0xFF1D3264),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFFAAB8D4)
                      : const Color(0xFF95A3BF),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Icon(
          icon,
          color: isDarkMode ? const Color(0xFFAAB8D4) : const Color(0xFF8FA1C5),
          size: 34,
        ),
        const SizedBox(height: 14),
        Text(
          title,
          style: TextStyle(
            color: isDarkMode
                ? const Color(0xFFEAF1FF)
                : const Color(0xFF1D3264),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDarkMode
                ? const Color(0xFFAAB8D4)
                : const Color(0xFF8FA1C5),
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFAAB8D4)
                  : const Color(0xFF8D9DBC),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isDarkMode
                  ? const Color(0xFFEAF1FF)
                  : const Color(0xFF1D3264),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

class _SystemLogStat extends StatelessWidget {
  const _SystemLogStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFD4DCF3),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionStyles {
  static TextStyle tableHeading(bool isDarkMode) => TextStyle(
    color: isDarkMode ? const Color(0xFFAAB8D4) : const Color(0xFF9AA8C4),
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.8,
  );
}
