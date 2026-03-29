import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../services/base_service.dart';
import '../services/appointment_service.dart';
import '../core/config.dart';

import '../widgets/book_appointment_dialog.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/appointment_details_dialog.dart';
import 'notifications_view.dart';
import 'recycle_bin_view.dart';

class PatientDashboardView extends StatefulWidget {
  const PatientDashboardView({
    super.key,
    required this.userInfo,
    required this.onLogout,
    required this.loggingOut,
  });

  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;
  final bool loggingOut;

  @override
  State<PatientDashboardView> createState() => _PatientDashboardViewState();
}

enum _PatientAppointmentFilter { all, pending, approved, completed, cancelled }

class _PatientDashboardViewState extends State<PatientDashboardView> {
  int _selectedIndex = 0; // 0 for Appointments, 1 for Profile

  late final AppointmentService _appointmentService;
  List<Map<String, dynamic>> _appointments = [];
  Map<String, dynamic>? _todayQueueStatus;
  _PatientAppointmentFilter _selectedFilter = _PatientAppointmentFilter.all;
  bool _isLoadingAppointments = true;
  bool _isJoiningQueue = false;
  String? _successMessage;
  String _messageType = 'success'; // 'success' or 'error'
  late Map<String, dynamic> _localUserInfo;

  @override
  void initState() {
    super.initState();
    _localUserInfo = widget.userInfo ?? {};
    _appointmentService = AppointmentService(
      BaseService(ApiClient(tokenStorage: SecureTokenStorage())),
    );
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final list = await _appointmentService.getPatientAppointments();
      Map<String, dynamic>? queueStatus;
      try {
        queueStatus = await _appointmentService.getPatientTodayQueue();
      } catch (_) {
        queueStatus = null;
      }
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _todayQueueStatus = queueStatus;
        _isLoadingAppointments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAppointments = false;
        _todayQueueStatus = null;
      });
    }
  }

  Future<void> _joinTodayQueue() async {
    if (_isJoiningQueue) return;

    setState(() {
      _isJoiningQueue = true;
    });

    try {
      final response = await _appointmentService.joinPatientTodayQueue();
      if (!mounted) return;

      setState(() {
        _todayQueueStatus = Map<String, dynamic>.from(response);
        _successMessage =
            response['message']?.toString() ?? 'Queue joined successfully.';
        _messageType = 'success';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _successMessage = 'Unable to join today\'s queue right now.';
        _messageType = 'error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isJoiningQueue = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> userInfo = _localUserInfo;
    String fullName = userInfo['name']?.toString() ?? '';
    if (fullName.isEmpty) {
      fullName =
          '${userInfo['first_name'] ?? ''} ${userInfo['middle_name'] ?? ''} ${userInfo['last_name'] ?? ''}'
              .trim();
    }
    if (fullName.isEmpty) fullName = 'User';
    final name = fullName;

    String? profilePicture = userInfo['profile_picture']?.toString();
    if (profilePicture != null &&
        (profilePicture.isEmpty ||
            profilePicture == 'null' ||
            profilePicture == '/storage/')) {
      profilePicture = null;
    }
    final String paddedId =
        userInfo['id']?.toString().padLeft(4, '0') ?? '0002';

    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F5ED,
      ), // Faint greyish green for the background
      appBar: _buildAppBar(name, profilePicture),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFF679B6A),
                      backgroundImage: profilePicture != null
                          ? NetworkImage('${AppConfig.baseUrl}$profilePicture')
                          : null,
                      child: profilePicture == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'ID: SDQ-$paddedId',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF679B6A),
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Color(0xFF679B6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedIndex = 1);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF679B6A),
                ),
                title: const Text(
                  'My Appointments',
                  style: TextStyle(
                    color: Color(0xFF679B6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedIndex = 0);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: const Icon(
                  Icons.access_time_outlined,
                  color: Color(0xFF679B6A),
                ),
                title: const Text(
                  'Medical History',
                  style: TextStyle(
                    color: Color(0xFF679B6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  setState(() => _selectedIndex = 2);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: const Icon(
                  Icons.notifications_none,
                  color: Color(0xFF679B6A),
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Color(0xFF679B6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsView(),
                    ),
                  );
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: const Icon(
                  Icons.restore_from_trash_outlined,
                  color: Color(0xFF679B6A),
                ),
                title: const Text(
                  'Recycle Bin',
                  style: TextStyle(
                    color: Color(0xFF679B6A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const RecycleBinView(role: RecycleBinRole.patient),
                    ),
                  );
                },
              ),
              const Spacer(),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                leading: widget.loggingOut
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: widget.loggingOut ? null : widget.onLogout,
              ),
            ],
          ),
        ),
      ),
      body: _selectedIndex == 0
          ? _buildBody()
          : _selectedIndex == 1
          ? _buildProfileView()
          : _buildMedicalHistoryView(),
      floatingActionButton: _selectedIndex != 1
          ? FloatingActionButton(
              onPressed: () async {
                final result = await showDialog(
                  context: context,
                  builder: (context) => const BookAppointmentDialog(),
                );
                if (result == true) {
                  _loadAppointments();
                }
              },
              backgroundColor: const Color(0xFF679B6A),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 36),
            )
          : null, // Hide FAB on profile page
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(String name, String? profilePicture) {
    return AppBar(
      backgroundColor: const Color(0xFF679B6A), // Green header
      elevation: 0,
      iconTheme: const IconThemeData(
        color: Colors.black,
        size: 24,
      ), // Hamburger menu
      titleSpacing: -15, // Reduces space between hamburger and title
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Placeholder for Logo
          Container(
            padding: const EdgeInsets.all(2),
            child: Image.asset(
              'assets/images/logo.png',
              width: 40, // slightly larger, logo looks a bit small
              height: 40,
            ),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'SMART',
                    style: TextStyle(
                      color: Color(0xFFE8C355), // Yellow from logo
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: -0.5,
                    ),
                  ),
                  TextSpan(
                    text: 'DentQueue',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black54),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsView()),
            );
          },
        ),
        // Profile chip placeholder
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'PATIENT',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    backgroundImage: profilePicture != null
                        ? NetworkImage('${AppConfig.baseUrl}$profilePicture')
                        : null,
                    child: profilePicture == null
                        ? const Icon(Icons.person, color: Colors.grey, size: 20)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    final visibleAppointments = _visibleAppointments();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 96),
      child: Column(
        children: [
          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _messageType == 'success'
                    ? const Color(0xFFE8F5E9)
                    : const Color(0xFFFFCCCC),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _messageType == 'success'
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: _messageType == 'success'
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFD32F2F),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _successMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _messageType == 'success'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'PATIENT DASHBOARD',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Builder(
            builder: (context) {
              final pendingCount = _appointments
                  .where(
                    (a) =>
                        _normalizeAppointmentStatus(a['status']) == 'pending',
                  )
                  .length;
              final approvedCount = _appointments
                  .where(
                    (a) =>
                        _normalizeAppointmentStatus(a['status']) == 'approved',
                  )
                  .length;
              final completedCount = _appointments
                  .where(
                    (a) =>
                        _normalizeAppointmentStatus(a['status']) == 'completed',
                  )
                  .length;
              final cancelledCount = _appointments
                  .where(
                    (a) =>
                        _normalizeAppointmentStatus(a['status']) == 'cancelled',
                  )
                  .length;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.35,
                      children: [
                        _buildStatusCard(
                          title: 'PENDING',
                          count: pendingCount.toString(),
                          icon: Icons.access_time_filled,
                          color: Colors.orange,
                          backgroundColor: const Color(0xFFFFF7EF),
                          filter: _PatientAppointmentFilter.pending,
                        ),
                        _buildStatusCard(
                          title: 'APPROVED',
                          count: approvedCount.toString(),
                          icon: Icons.check_circle_outline,
                          color: Colors.blue,
                          backgroundColor: const Color(0xFFF1F7FF),
                          filter: _PatientAppointmentFilter.approved,
                        ),
                        _buildStatusCard(
                          title: 'COMPLETED',
                          count: completedCount.toString(),
                          icon: Icons.medical_services_outlined,
                          color: Colors.green,
                          backgroundColor: const Color(0xFFF1FFF7),
                          filter: _PatientAppointmentFilter.completed,
                        ),
                        _buildStatusCard(
                          title: 'CANCELLED',
                          count: cancelledCount.toString(),
                          icon: Icons.cancel_outlined,
                          color: Colors.redAccent,
                          backgroundColor: const Color(0xFFFFF1F1),
                          filter: _PatientAppointmentFilter.cancelled,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildTodayQueuePanel(),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                _buildFilterChip(
                  'ALL',
                  filter: _PatientAppointmentFilter.all,
                  isSelected: _selectedFilter == _PatientAppointmentFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pending',
                  filter: _PatientAppointmentFilter.pending,
                  isSelected:
                      _selectedFilter == _PatientAppointmentFilter.pending,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Approved',
                  filter: _PatientAppointmentFilter.approved,
                  isSelected:
                      _selectedFilter == _PatientAppointmentFilter.approved,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Completed',
                  filter: _PatientAppointmentFilter.completed,
                  isSelected:
                      _selectedFilter == _PatientAppointmentFilter.completed,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Cancelled',
                  filter: _PatientAppointmentFilter.cancelled,
                  isSelected:
                      _selectedFilter == _PatientAppointmentFilter.cancelled,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingAppointments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_appointments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No Appointment Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else if (visibleAppointments.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No appointments found for this status.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8.0,
              ),
              itemCount: visibleAppointments.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return _buildAppointmentCard(visibleAppointments[index]);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryView() {
    final completedAppts = _appointments
        .where((a) => a['status']?.toString().toLowerCase() == 'completed')
        .toList();

    // Sort by date descending
    completedAppts.sort((a, b) {
      final dateA = a['appointment_date']?.toString() ?? '';
      final dateB = b['appointment_date']?.toString() ?? '';
      return dateB.compareTo(dateA); // descending
    });

    return Column(
      children: [
        const SizedBox(height: 32),
        const Text(
          'Medical History',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your past dental procedure',
          style: TextStyle(
            color: Color(0xFF7E8CA0),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 24),
        if (completedAppts.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No completed appointments found.',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: completedAppts.length,
              itemBuilder: (context, index) {
                final appt = completedAppts[index];
                final serviceType =
                    appt['service_type']?.toString() ?? 'Service';
                final date =
                    appt['appointment_date']?.toString() ?? 'YYYY-MM-DD';
                final note =
                    appt['notes']?.toString() ??
                    appt['reason']?.toString() ??
                    'Routine checkup completed.';

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF679B6A), width: 6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              serviceType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: Color(0xFF1E293B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF679B6A),
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '"$note"',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontStyle: FontStyle.italic,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProfileView() {
    final Map<String, dynamic> userInfo = _localUserInfo;

    // First try "name", if missing then try assembling from first_name, middle_name, last_name
    String fullName = userInfo['name']?.toString() ?? '';
    if (fullName.isEmpty) {
      fullName =
          '${userInfo['first_name'] ?? ''} ${userInfo['middle_name'] ?? ''} ${userInfo['last_name'] ?? ''}'
              .trim();
    }
    fullName = fullName.toUpperCase();

    final String address =
        (userInfo['location'] ?? userInfo['address'])?.toString() ?? 'N/A';
    final String gender = userInfo['gender']?.toString() ?? 'N/A';

    String birthdate = userInfo['birthdate']?.toString() ?? 'N/A';
    // Remove the trailing time like T00:00:00.000000Z
    if (birthdate.contains('T')) {
      birthdate = birthdate.split('T')[0];
    }

    final String contactNumber =
        (userInfo['phone_number'] ?? userInfo['contact_number'])?.toString() ??
        'N/A';
    String? profilePicture = userInfo['profile_picture']?.toString();
    if (profilePicture != null &&
        (profilePicture.isEmpty ||
            profilePicture == 'null' ||
            profilePicture == '/storage/')) {
      profilePicture = null;
    }
    final String paddedId =
        userInfo['id']?.toString().padLeft(4, '0') ?? '0002';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Circular Avatar
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF679B6A), width: 3),
                  color: const Color(0xFFF8FAFC),
                  image: profilePicture != null
                      ? DecorationImage(
                          image: NetworkImage(
                            '${AppConfig.baseUrl}$profilePicture',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: profilePicture == null
                    ? const Icon(Icons.person, size: 80, color: Colors.grey)
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            // Name and Title
            Text(
              fullName.isNotEmpty ? fullName : 'User Name',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Patient Account\nID: SDQ-$paddedId',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),

            // Info Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileField(
                    Icons.person_outline,
                    'FULL NAME',
                    fullName,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.calendar_today_outlined,
                    'BIRTHDATE',
                    birthdate,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.location_on_outlined,
                    'ADDRESS',
                    address,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(Icons.people_outline, 'GENDER', gender),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.phone_outlined,
                    'CONTACT NUMBER',
                    contactNumber,
                  ),
                  const SizedBox(height: 32),

                  // Edit Profile Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        // Show Edit Profile Dialog
                        final result = await showDialog(
                          context: context,
                          builder: (context) =>
                              EditProfileDialog(userInfo: _localUserInfo),
                        );
                        // If result is a Map, it means profile was updated
                        if (result is Map<String, dynamic>) {
                          setState(() {
                            _localUserInfo = result;
                            _successMessage = 'Profile updated successfully.';
                            _messageType = 'success';
                          });

                          // Clear the success message after 3 seconds
                          Future.delayed(const Duration(seconds: 3), () {
                            if (mounted) {
                              setState(() {
                                _successMessage = null;
                              });
                            }
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF679B6A,
                        ), // Green brand color
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF679B6A), size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7E8CA0),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required _PatientAppointmentFilter filter,
  }) {
    final isSelected = _selectedFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.5)
                : color.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              count,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayQueuePanel() {
    final nowServing =
        _todayQueueStatus?['now_serving'] as Map<String, dynamic>?;
    final patientQueue =
        _todayQueueStatus?['patient_queue'] as Map<String, dynamic>?;
    final hasActiveTodayAppointment = _appointments.any((appointment) {
      final date = appointment['appointment_date']?.toString() ?? '';
      final status = _normalizeAppointmentStatus(appointment['status']);
      final today = DateTime.now().toIso8601String().split('T').first;
      return date == today && status != 'cancelled';
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Queue',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildQueueMetricCard(
                  label: 'NOW SERVING',
                  value: _formatQueueNumber(nowServing?['queue_number']),
                  caption: nowServing?['patient_name']?.toString() ?? 'Waiting',
                  color: const Color(0xFF16A34A),
                  backgroundColor: const Color(0xFFEFFCF3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQueueMetricCard(
                  label: 'YOUR QUEUE',
                  value: _formatQueueNumber(patientQueue?['queue_number']),
                  caption: patientQueue == null
                      ? 'No queue yet'
                      : '${patientQueue['people_ahead'] ?? 0} ahead of you',
                  color: const Color(0xFF1D4ED8),
                  backgroundColor: const Color(0xFFEFF5FF),
                ),
              ),
            ],
          ),
          if (patientQueue != null) ...[
            const SizedBox(height: 8),
            Text(
              patientQueue['is_now_serving'] == true
                  ? 'It is your turn now.'
                  : 'Status: ${patientQueue['status'] ?? 'Pending'}',
              style: TextStyle(
                color: patientQueue['is_now_serving'] == true
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF475569),
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ] else if (hasActiveTodayAppointment) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isJoiningQueue ? null : _joinTodayQueue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF679B6A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isJoiningQueue
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Join Today\'s Queue'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueMetricCard({
    required String label,
    required String value,
    required String caption,
    required Color color,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '#$value',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label, {
    required _PatientAppointmentFilter filter,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF679B6A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _visibleAppointments() {
    return _appointments.where((appointment) {
      final status = _normalizeAppointmentStatus(appointment['status']);

      return switch (_selectedFilter) {
        _PatientAppointmentFilter.all => true,
        _PatientAppointmentFilter.pending => status == 'pending',
        _PatientAppointmentFilter.approved => status == 'approved',
        _PatientAppointmentFilter.completed => status == 'completed',
        _PatientAppointmentFilter.cancelled => status == 'cancelled',
      };
    }).toList();
  }

  String _normalizeAppointmentStatus(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? '';
    if (raw == 'confirmed' || raw == 'approved') {
      return 'approved';
    }
    if (raw == 'completed') {
      return 'completed';
    }
    if (raw == 'cancelled') {
      return 'cancelled';
    }
    return 'pending';
  }

  String _formatQueueNumber(dynamic value) {
    if (value == null) {
      return '--';
    }

    final parsed = int.tryParse(value.toString());
    if (parsed == null) {
      return '--';
    }

    return parsed.toString().padLeft(2, '0');
  }

  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: Colors.white,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Appointments Tab
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.event_available,
                        color: _selectedIndex == 0
                            ? const Color(0xFF679B6A)
                            : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Appointments',
                        style: TextStyle(
                          color: _selectedIndex == 0
                              ? const Color(0xFF679B6A)
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 48), // Space for FAB
            // Profile Tab
            Expanded(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: _selectedIndex == 1
                            ? const Color(0xFF679B6A)
                            : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Profile',
                        style: TextStyle(
                          color: _selectedIndex == 1
                              ? const Color(0xFF679B6A)
                              : Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final serviceType = appt['service_type']?.toString() ?? 'Service';
    final date = appt['appointment_date']?.toString() ?? 'YYYY-MM-DD';
    String formattedTime = '--:--';
    final rawTime = appt['appointment_time']?.toString() ?? '--:--';
    if (rawTime != '--:--') {
      try {
        final parts = rawTime.split(':');
        final hour = int.parse(parts[0]);
        final minute = parts.length > 1 ? parts[1] : '00';
        final amPm = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        formattedTime = '$displayHour:$minute $amPm';
      } catch (e) {
        formattedTime = rawTime;
      }
    }
    final time = formattedTime;
    final queue = appt['queue_number']?.toString() ?? '--';
    final initial = serviceType.isNotEmpty ? serviceType[0].toUpperCase() : 'S';
    final status = appt['status']?.toString().toLowerCase() ?? 'pending';

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AppointmentDetailsDialog(appointment: appt),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Icon wrapper
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F7FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceType,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              date,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(
                              Icons.access_time_outlined,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Queue Num
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'QUEUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF7E8CA0),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        '#$queue',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF679B6A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (status == 'pending' || status == 'confirmed')
              InkWell(
                onTap: () =>
                    _showCancelConfirmationDialog((appt['id'] as num).toInt()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                  child: const Center(
                    child: Text(
                      'CANCEL APPOINTMENT',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCancelConfirmationDialog(int id) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Color(0xFFD32F2F),
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Cancel Appointment?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Are you sure you want to cancel this\nappointment? This action cannot be\nundone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'No, Keep it',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        await _cancelAppointment(id);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: const Color(0xFFFF4949),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelAppointment(int id) async {
    try {
      await _appointmentService.cancelAppointment(id);
      if (!mounted) return;

      setState(() {
        _successMessage = 'Appointment Cancelled Successfully!!';
        _messageType = 'error';
      });

      // Load appointments to update UI
      await _loadAppointments();

      // Auto-hide success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel appointment: $e')),
      );
    }
  }
}
