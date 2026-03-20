import 'package:flutter/material.dart';
import '../widgets/admin_layout.dart';
import 'admin_patients_view.dart';
import 'admin_master_list_view.dart';
import '../core/token_storage.dart';
import '../core/api_client.dart';
import '../services/base_service.dart';
import '../services/patient_record_service.dart';
import '../services/admin_dashboard_service.dart';

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

  bool _isLoadingStats = true;
  Map<String, int> _dashboardStats = {
    'patients_count': 0,
    'staff_count': 0,
    'appointments_count': 0,
  };

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(tokenStorage: widget.tokenStorage);
    final baseService = BaseService(apiClient);
    _patientRecordService = PatientRecordService(baseService);
    _adminDashboardService = AdminDashboardService(baseService);

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
      userInfo: widget.userInfo,
      onLogout: widget.onLogout,
      loggingOut: widget.loggingOut,
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
        return AdminPatientsView(
          patientRecordService: _patientRecordService,
        );
      case 'Master List':
        return const AdminMasterListView();
      // Other routes to be implemented in subsequent tickets
      default:
        return Center(
          child: Text(
            '$_activeRoute View\n(To be implemented)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, color: Colors.grey),
          ),
        );
    }
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
                value: _isLoadingStats ? '...' : (_dashboardStats['patients_count'] ?? 0).toString(),
                icon: Icons.badge_outlined,
                mainColor: const Color(0xFF6A9A8B), // Slightly grayish green-blue
                darkColor: const Color(0xFF50786A),
              ),
              _buildDashboardCard(
                title: 'Staff',
                value: _isLoadingStats ? '...' : (_dashboardStats['staff_count'] ?? 0).toString(),
                icon: Icons.medical_services_outlined,
                mainColor: const Color(0xFF86B9B0), // Teal
                darkColor: const Color(0xFF6E9A92),
              ),
              _buildDashboardCard(
                title: 'Master List',
                value: _isLoadingStats ? '...' : (_dashboardStats['appointments_count'] ?? 0).toString(),
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
      width: 400,
      height: 200,
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
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
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
                height: 50,
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
