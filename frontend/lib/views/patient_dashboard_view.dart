import 'dart:async';

import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/appointment_status.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import '../services/notification_service.dart';
import '../core/config.dart';

import '../widgets/book_appointment_dialog.dart';
import '../widgets/appointment_details_dialog.dart';
import '../widgets/appointment_status_badge.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/edit_profile_dialog.dart';
import 'notifications_view.dart';
import 'recycle_bin_view.dart';

class PatientDashboardView extends StatefulWidget {
  const PatientDashboardView({
    super.key,
    required this.userInfo,
    required this.onLogout,
    required this.loggingOut,
    this.appointmentService,
  });

  final Map<String, dynamic>? userInfo;
  final VoidCallback onLogout;
  final bool loggingOut;
  final AppointmentService? appointmentService;

  @override
  State<PatientDashboardView> createState() => _PatientDashboardViewState();
}

enum _PatientAppointmentFilter { all, pending, approved, completed, cancelled }

class _PatientDashboardViewState extends State<PatientDashboardView>
    with WidgetsBindingObserver {
  static const Duration _queueRefreshInterval = Duration(seconds: 10);

  int _selectedIndex = 0; // 0 for Appointments, 1 for Profile

  late final AppointmentService _appointmentService;
  late final NotificationService _notificationService;
  Timer? _queueRefreshTimer;
  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _cancelledAppointments = [];
  Map<String, dynamic>? _todayQueueStatus;
  _PatientAppointmentFilter _selectedFilter = _PatientAppointmentFilter.all;
  bool _isLoadingAppointments = true;
  String? _successMessage;
  String _messageType = 'success'; // 'success' or 'error'
  late Map<String, dynamic> _localUserInfo;
  int _unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _localUserInfo = widget.userInfo ?? {};
    final TokenStorage tokenStorage = SecureTokenStorage();
    _appointmentService =
        widget.appointmentService ??
        AppointmentService(BaseService(ApiClient(tokenStorage: tokenStorage)));
    _notificationService = NotificationService(
      BaseService(ApiClient(tokenStorage: tokenStorage)),
      tokenStorage: tokenStorage,
    );
    _loadAppointments();
    _loadUnreadNotificationCount();
    _startQueueAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queueRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUnreadNotificationCount();
      _refreshAppointmentsSilently(forceRefresh: true);
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final NotificationListResult result = await _notificationService
          .getNotifications('patient');
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = result.unreadCount;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = 0;
      });
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsView()),
    );
    if (!mounted) return;
    await _loadUnreadNotificationCount();
    await _refreshAppointmentsSilently();
  }

  Future<void> _loadAppointments({
    bool showLoader = true,
    bool forceRefresh = false,
    bool notifyOnError = true,
  }) async {
    final bool hasVisibleContent =
        _appointments.isNotEmpty ||
        _cancelledAppointments.isNotEmpty ||
        _todayQueueStatus != null;

    if (showLoader || !hasVisibleContent) {
      setState(() => _isLoadingAppointments = true);
    }

    try {
      if (forceRefresh) {
        _appointmentService.invalidateAppointmentCaches();
      }

      final Future<List<Map<String, dynamic>>> appointmentsFuture =
          _appointmentService.getPatientAppointments();
      final Future<List<Map<String, dynamic>>> recycleBinFuture =
          _appointmentService
              .getRecycleBinAppointments(false)
              .catchError((_) => <Map<String, dynamic>>[]);
      final Future<Map<String, dynamic>?> queueStatusFuture =
          _appointmentService
              .getPatientTodayQueue()
              .then<Map<String, dynamic>?>(
                (Map<String, dynamic> value) => value,
              )
              .catchError((_) => null);

      final List<Map<String, dynamic>> list = await appointmentsFuture;
      final List<Map<String, dynamic>> recycleBinAppointments =
          await recycleBinFuture;
      final Map<String, dynamic>? queueStatus = await queueStatusFuture;
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _cancelledAppointments = recycleBinAppointments;
        _todayQueueStatus = queueStatus;
        _isLoadingAppointments = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!showLoader && hasVisibleContent) {
        setState(() {
          _isLoadingAppointments = false;
        });
        if (notifyOnError) {
          _showStatusMessage('Unable to refresh appointments right now.');
        }
        return;
      }

      setState(() {
        _cancelledAppointments = [];
        _isLoadingAppointments = false;
        _todayQueueStatus = null;
      });
    }
  }

  List<Map<String, dynamic>> _dashboardAppointments() {
    return [..._appointments, ..._cancelledAppointments];
  }

  Future<void> _refreshAppointmentsAndQueue() {
    return _loadAppointments(showLoader: false, forceRefresh: true);
  }

  Future<void> _refreshAppointmentsSilently({bool forceRefresh = false}) {
    return _loadAppointments(
      showLoader: false,
      forceRefresh: forceRefresh,
      notifyOnError: false,
    );
  }

  Future<void> _refreshQueueStatusSilently({bool forceRefresh = false}) async {
    try {
      if (forceRefresh) {
        _appointmentService.invalidatePatientTodayQueueCache();
      }

      final Map<String, dynamic> queueStatus = await _appointmentService
          .getPatientTodayQueue(forceRefresh: forceRefresh);
      if (!mounted) {
        return;
      }

      setState(() {
        _todayQueueStatus = queueStatus;
      });
    } catch (_) {
      // Keep the current queue snapshot when a background refresh fails.
    }
  }

  void _startQueueAutoRefresh() {
    _queueRefreshTimer?.cancel();
    _queueRefreshTimer = Timer.periodic(_queueRefreshInterval, (_) {
      if (!mounted) {
        return;
      }

      _refreshQueueStatusSilently(forceRefresh: true);
    });
  }

  void _showStatusMessage(String message) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
    final chipName = _topBarName(userInfo);

    String? profilePicture = userInfo['profile_picture']?.toString();
    if (profilePicture != null &&
        (profilePicture.isEmpty ||
            profilePicture == 'null' ||
            profilePicture == '/storage/')) {
      profilePicture = null;
    }
    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F5ED,
      ), // Faint greyish green for the background
      appBar: _buildAppBar(chipName, profilePicture),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF356042),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
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
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'PATIENT ACCOUNT',
                            style: TextStyle(
                              color: Color(0xFFE8C355),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
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
                  color: Color(0xFF356042),
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(
                    color: Color(0xFF356042),
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
                  color: Color(0xFF356042),
                ),
                title: const Text(
                  'My Appointments',
                  style: TextStyle(
                    color: Color(0xFF356042),
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
                  color: Color(0xFF356042),
                ),
                title: const Text(
                  'Medical History',
                  style: TextStyle(
                    color: Color(0xFF356042),
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
                  color: Color(0xFF356042),
                ),
                title: const Text(
                  'Notifications',
                  style: TextStyle(
                    color: Color(0xFF356042),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _openNotifications();
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 32),
                leading: const Icon(
                  Icons.restore_from_trash_outlined,
                  color: Color(0xFF356042),
                ),
                title: const Text(
                  'Recycle Bin',
                  style: TextStyle(
                    color: Color(0xFF356042),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecycleBinView(
                        role: RecycleBinRole.patient,
                        appointmentService: _appointmentService,
                      ),
                    ),
                  ).then((_) => _loadAppointments(showLoader: false));
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
              onPressed: _openBookAppointmentDialog,
              backgroundColor: const Color(0xFF356042),
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 36),
            )
          : null, // Hide FAB on profile page
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(String name, String? profilePicture) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double profileChipWidth = screenWidth < 380
        ? 108
        : screenWidth < 430
        ? 132
        : 164;

    return AppBar(
      backgroundColor: const Color(0xFF356042), // Green header
      elevation: 0,
      iconTheme: const IconThemeData(
        color: Colors.white,
        size: 24,
      ), // Hamburger menu
      titleSpacing: -15, // Reduces space between hamburger and title
      title: Row(
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'SMART',
                  style: TextStyle(
                    color: Color(0xFFE8C355), // Yellow from logo
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                Text(
                  'DentQueue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: _buildNotificationIcon(_unreadNotificationCount),
          onPressed: _openNotifications,
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
            child: SizedBox(
              width: profileChipWidth,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            'PATIENT',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white,
                      backgroundImage: profilePicture != null
                          ? NetworkImage('${AppConfig.baseUrl}$profilePicture')
                          : null,
                      child: profilePicture == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 20,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openBookAppointmentDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const BookAppointmentDialog(),
    );

    if (result == true) {
      _loadAppointments();
    }
  }

  Widget _buildBody() {
    final visibleAppointments = _visibleAppointments();

    return RefreshIndicator(
      key: const Key('patient-dashboard-refresh'),
      onRefresh: _refreshAppointmentsAndQueue,
      color: const Color(0xFF356042),
      child: SingleChildScrollView(
        key: const Key('patient-dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
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
            Center(
              child: Text(
                'PATIENT DASHBOARD',
                style: TextStyle(
                  fontSize: MobileTypography.sectionTitle(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Builder(
              builder: (context) {
                final allAppointments = _dashboardAppointments();
                final pendingCount = allAppointments
                    .where(
                      (a) =>
                          normalizeAppointmentStatus(a['status']) == 'pending',
                    )
                    .length;
                final approvedCount = allAppointments
                    .where(
                      (a) =>
                          normalizeAppointmentStatus(a['status']) == 'approved',
                    )
                    .length;
                final completedCount = allAppointments
                    .where(
                      (a) =>
                          normalizeAppointmentStatus(a['status']) ==
                          'completed',
                    )
                    .length;
                final cancelledCount = allAppointments
                    .where(
                      (a) =>
                          normalizeAppointmentStatus(a['status']) ==
                          'cancelled',
                    )
                    .length;
                final cards = <Map<String, dynamic>>[
                  <String, dynamic>{
                    'title': 'PENDING',
                    'count': pendingCount.toString(),
                    'icon': Icons.access_time_filled,
                    'color': Colors.orange,
                    'backgroundColor': const Color(0xFFFFF7EF),
                    'filter': _PatientAppointmentFilter.pending,
                  },
                  <String, dynamic>{
                    'title': 'APPROVED',
                    'count': approvedCount.toString(),
                    'icon': Icons.check_circle_outline,
                    'color': Colors.blue,
                    'backgroundColor': const Color(0xFFF1F7FF),
                    'filter': _PatientAppointmentFilter.approved,
                  },
                  <String, dynamic>{
                    'title': 'COMPLETED',
                    'count': completedCount.toString(),
                    'icon': Icons.medical_services_outlined,
                    'color': Colors.green,
                    'backgroundColor': const Color(0xFFF1FFF7),
                    'filter': _PatientAppointmentFilter.completed,
                  },
                  <String, dynamic>{
                    'title': 'CANCELLED',
                    'count': cancelledCount.toString(),
                    'icon': Icons.cancel_outlined,
                    'color': Colors.redAccent,
                    'backgroundColor': const Color(0xFFFFF1F1),
                    'filter': _PatientAppointmentFilter.cancelled,
                  },
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth < 420
                        ? 16.0
                        : 24.0;
                    final contentWidth = constraints.maxWidth > 920
                        ? 920.0
                        : constraints.maxWidth;
                    final crossAxisCount = contentWidth >= 860
                        ? 4
                        : contentWidth >= 420
                        ? 2
                        : 1;

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 920),
                          child: Column(
                            children: [
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: cards.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      mainAxisExtent: 148,
                                    ),
                                itemBuilder: (context, index) {
                                  final card = cards[index];
                                  final color = card['color']! as Color;

                                  return DashboardStatCard(
                                    title: card['title']! as String,
                                    value: card['count']! as String,
                                    icon: card['icon']! as IconData,
                                    accentColor: color,
                                    backgroundColor:
                                        card['backgroundColor']! as Color,
                                    isSelected:
                                        _selectedFilter ==
                                        card['filter']!
                                            as _PatientAppointmentFilter,
                                    onTap: () {
                                      setState(() {
                                        _selectedFilter =
                                            card['filter']!
                                                as _PatientAppointmentFilter;
                                      });
                                    },
                                    valueStyle: TextStyle(
                                      fontSize:
                                          MobileTypography.sectionTitle(
                                            context,
                                          ) +
                                          4,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                    ),
                                    titleStyle: TextStyle(
                                      fontSize: MobileTypography.caption(
                                        context,
                                      ),
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                      letterSpacing: 0.4,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 14),
                              _buildTodayQueuePanel(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
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
                    isSelected:
                        _selectedFilter == _PatientAppointmentFilter.all,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: AppEmptyState(
                  key: const Key('patient-appointments-empty-state'),
                  icon: Icons.event_busy_outlined,
                  title: 'No appointments yet',
                  message:
                      'Your upcoming appointments will appear here after you book one.',
                  actionLabel: 'Book Appointment',
                  actionIcon: Icons.add_rounded,
                  onAction: () {
                    _openBookAppointmentDialog();
                  },
                ),
              )
            else if (visibleAppointments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: AppEmptyState(
                  key: const Key('patient-appointments-filter-empty-state'),
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No appointments match this filter',
                  message:
                      'Try switching to another status to see your appointment records.',
                  actionLabel: 'Show All',
                  actionIcon: Icons.restart_alt_rounded,
                  onAction: () {
                    setState(() {
                      _selectedFilter = _PatientAppointmentFilter.all;
                    });
                  },
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
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: AppEmptyState(
                key: Key('patient-history-empty-state'),
                icon: Icons.history_toggle_off_rounded,
                title: 'No completed appointments yet',
                message:
                    'Finished dental visits will appear here as part of your medical history.',
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
                      left: BorderSide(color: Color(0xFF356042), width: 6),
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
                            color: Color(0xFF356042),
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
    final String firstName = _profileValue(userInfo['first_name']);
    final String middleName = _profileValue(userInfo['middle_name']);
    final String lastName = _profileValue(userInfo['last_name']);
    final String fullName = _fullProfileName(userInfo).toUpperCase();

    final String address =
        (userInfo['location'] ?? userInfo['address'])?.toString() ?? 'N/A';
    final String gender = userInfo['gender']?.toString() ?? 'N/A';

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
                  border: Border.all(color: const Color(0xFF356042), width: 3),
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
                    Icons.badge_outlined,
                    'FIRST NAME',
                    firstName,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.assignment_ind_outlined,
                    'MIDDLE NAME',
                    middleName,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.person_pin_outlined,
                    'LAST NAME',
                    lastName,
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
                          0xFF356042,
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
        Icon(icon, color: const Color(0xFF356042), size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: MobileTypography.caption(context),
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF7E8CA0),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: MobileTypography.body(context),
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

  String _profileValue(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'N/A' : text;
  }

  String _fullProfileName(Map<String, dynamic> userInfo) {
    final List<String> parts = <String>[
      userInfo['first_name']?.toString().trim() ?? '',
      userInfo['middle_name']?.toString().trim() ?? '',
      userInfo['last_name']?.toString().trim() ?? '',
    ].where((String part) => part.isNotEmpty).toList();

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    final String fallback = userInfo['name']?.toString().trim() ?? '';
    return fallback.isEmpty ? 'User Name' : fallback;
  }

  String _topBarName(Map<String, dynamic> userInfo) {
    final String firstName = userInfo['first_name']?.toString().trim() ?? '';
    if (firstName.isNotEmpty) {
      return firstName;
    }

    final String fullName = _fullProfileName(userInfo);
    final List<String> parts = fullName.split(RegExp(r'\s+'));
    return parts.isEmpty ? 'User' : parts.first;
  }

  Widget _buildNotificationIcon(int unreadCount) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.notifications_none, color: Colors.white),
        if (unreadCount > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8C355),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Center(
                child: Text(
                  unreadCount > 99 ? '99+' : unreadCount.toString(),
                  style: const TextStyle(
                    color: Color(0xFF1F2A22),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTodayQueuePanel() {
    final nowServing =
        _todayQueueStatus?['now_serving'] as Map<String, dynamic>?;
    final patientQueue =
        _todayQueueStatus?['patient_queue'] as Map<String, dynamic>?;
    final bool isPatientEffectivelyNext =
        patientQueue != null &&
        patientQueue['is_now_serving'] != true &&
        (patientQueue['people_ahead'] ?? 0) == 0;
    final nextUp =
        _todayQueueStatus?['next_up'] as Map<String, dynamic>? ??
        (isPatientEffectivelyNext ? patientQueue : null);
    final bool isPatientNextUp =
        patientQueue != null &&
        nextUp != null &&
        patientQueue['appointment_id'] == nextUp['appointment_id'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
          Text(
            'Today\'s Queue',
            style: TextStyle(
              fontSize: MobileTypography.label(context),
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
                  label: 'NEXT UP',
                  value: _formatQueueNumber(nextUp?['queue_number']),
                  caption: isPatientNextUp
                      ? 'You are next in line'
                      : nextUp?['patient_name']?.toString() ?? 'No one in line',
                  color: const Color(0xFF0F766E),
                  backgroundColor: const Color(0xFFEFFCFB),
                ),
              ),
            ],
          ),
          if (patientQueue != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: patientQueue['is_now_serving'] == true
                    ? const Color(0xFFEFFCF3)
                    : isPatientNextUp
                    ? const Color(0xFFEFF5FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: patientQueue['is_now_serving'] == true
                      ? const Color(0xFF16A34A).withValues(alpha: 0.22)
                      : isPatientNextUp
                      ? const Color(0xFF1D4ED8).withValues(alpha: 0.22)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patientQueue['is_now_serving'] == true
                        ? 'Please proceed to clinic.'
                        : isPatientNextUp
                        ? 'You are up next.'
                        : 'Your queue number is ${_formatQueueNumber(patientQueue['queue_number'])}.',
                    style: TextStyle(
                      color: patientQueue['is_now_serving'] == true
                          ? const Color(0xFF166534)
                          : isPatientNextUp
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF334155),
                      fontWeight: FontWeight.w800,
                      fontSize: MobileTypography.body(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    patientQueue['is_now_serving'] == true
                        ? 'It is your turn now.'
                        : isPatientNextUp
                        ? 'Please get ready. Your turn is approaching.'
                        : '${patientQueue['people_ahead'] ?? 0} ahead of you. Status: ${patientQueue['status'] ?? 'Pending'}',
                    style: TextStyle(
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.w700,
                      fontSize: MobileTypography.caption(context),
                    ),
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
              fontSize: MobileTypography.caption(context),
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '#$value',
            style: TextStyle(
              fontSize: MobileTypography.cardTitle(context),
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
            style: TextStyle(
              fontSize: MobileTypography.caption(context),
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
          color: isSelected ? const Color(0xFF356042) : Colors.white,
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
    return _dashboardAppointments().where((appointment) {
      final status = normalizeAppointmentStatus(appointment['status']);

      return switch (_selectedFilter) {
        _PatientAppointmentFilter.all => true,
        _PatientAppointmentFilter.pending => status == 'pending',
        _PatientAppointmentFilter.approved => status == 'approved',
        _PatientAppointmentFilter.completed => status == 'completed',
        _PatientAppointmentFilter.cancelled => status == 'cancelled',
      };
    }).toList();
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
                            ? const Color(0xFF356042)
                            : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Appointments',
                        style: TextStyle(
                          color: _selectedIndex == 0
                              ? const Color(0xFF356042)
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
                            ? const Color(0xFF356042)
                            : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Profile',
                        style: TextStyle(
                          color: _selectedIndex == 1
                              ? const Color(0xFF356042)
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
    final status = normalizeAppointmentStatus(appt['status']);

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
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              serviceType,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            AppointmentStatusBadge(
                              status: status,
                              compact: true,
                            ),
                          ],
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
                          color: Color(0xFF356042),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (status == 'pending' || status == 'approved')
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
                        'Keep Appointment',
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
                        'Cancel Appointment',
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
