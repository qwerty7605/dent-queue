import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/api_client.dart';
import '../core/appointment_status.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import '../services/notification_service.dart';
import '../core/config.dart';

import '../widgets/book_appointment_dialog.dart';
import '../widgets/app_confirmation_dialog.dart';
import '../widgets/appointment_details_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/navigation_chrome.dart';
import '../widgets/reschedule_appointment_dialog.dart';
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

  int _selectedIndex = 0; // 0 for Home, 1 for Profile, 2 for History, 3 for Appointments

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
    final ImageProvider<Object>? profileImage = profilePicture != null
        ? NetworkImage('${AppConfig.baseUrl}$profilePicture')
        : null;

    return Scaffold(
      backgroundColor: AppNavigationTheme.background,
      appBar: _buildAppBar(chipName, profileImage),
      drawer: _buildDrawer(name, profileImage),
      body: _selectedIndex == 0
          ? _buildBody()
          : _selectedIndex == 1
          ? _buildProfileView()
          : _selectedIndex == 3
          ? _buildAppointmentsView()
          : _buildMedicalHistoryView(),
      floatingActionButton: _selectedIndex != 1
          ? FloatingActionButton(
              onPressed: _openBookAppointmentDialog,
              backgroundColor: AppNavigationTheme.primary,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, color: Colors.white, size: 36),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  void _selectSection(int index, {bool closeDrawer = false}) {
    setState(() {
      _selectedIndex = index;
    });

    if (closeDrawer) {
      Navigator.pop(context);
    }
  }

  PreferredSizeWidget _buildAppBar(
    String name,
    ImageProvider<Object>? profileImage,
  ) {
    return AppHeaderBar(
      titleSpacing: -8,
      titleWidget: const AppBrandLockup(logoSize: 40, spacing: 4),
      showBottomAccent: false,
      actions: <Widget>[
        IconButton(
          icon: _buildNotificationIcon(_unreadNotificationCount),
          onPressed: _openNotifications,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => _selectSection(1),
            child: CircleAvatar(
              radius: 21,
              backgroundColor: Colors.white.withValues(alpha: 0.20),
              backgroundImage: profileImage,
              child: profileImage == null
                  ? const Icon(Icons.person, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(String name, ImageProvider<Object>? profileImage) {
    final String patientId =
        _localUserInfo['patient_id']?.toString().trim().isNotEmpty == true
        ? _localUserInfo['patient_id'].toString().trim()
        : 'PT-${(_localUserInfo['id'] ?? '0001').toString().padLeft(4, '0')}';
    return Drawer(
      backgroundColor: AppNavigationTheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            AppNavigationDrawerHeader(
              name: name,
              roleLabel: patientId,
              profileImage: profileImage,
              fallbackInitial: name.isNotEmpty ? name[0].toUpperCase() : 'U',
            ),
            const Divider(height: 1, color: AppNavigationTheme.divider),
            const SizedBox(height: 10),
            AppNavigationDrawerItem(
              icon: Icons.calendar_today_outlined,
              label: 'My Appointments',
              selected: _selectedIndex == 3,
              onTap: () => _selectSection(3, closeDrawer: true),
            ),
            AppNavigationDrawerItem(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: _selectedIndex == 1,
              onTap: () => _selectSection(1, closeDrawer: true),
            ),
            AppNavigationDrawerItem(
              icon: Icons.access_time_outlined,
              label: 'Medical History',
              selected: _selectedIndex == 2,
              onTap: () => _selectSection(2, closeDrawer: true),
            ),
            AppNavigationDrawerItem(
              icon: Icons.notifications_none,
              label: 'Notifications',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                _openNotifications();
              },
            ),
            AppNavigationDrawerItem(
              icon: Icons.restore_from_trash_outlined,
              label: 'Recycle Bin',
              selected: false,
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
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: widget.loggingOut ? null : widget.onLogout,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF6F6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        widget.loggingOut
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.logout, color: Colors.red),
                        const SizedBox(width: 14),
                        const Text(
                          'Logout Account',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFFFFB5B5),
                        ),
                      ],
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

  Future<void> _openBookAppointmentDialog() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const BookAppointmentDialog(
          asPage: true,
        ),
      ),
    );

    if (result == true) {
      _loadAppointments();
    }
  }

  Future<void> _openRescheduleDialog(Map<String, dynamic> appointment) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RescheduleAppointmentDialog(
        appointment: appointment,
        appointmentService: _appointmentService,
      ),
    );

    if (result == true) {
      await _loadAppointments(showLoader: false, forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _successMessage = 'Appointment Rescheduled Successfully!';
        _messageType = 'success';
      });

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _successMessage = null;
          });
        }
      });
    }
  }

  Widget _buildBody() {
    final String firstName = _topBarName(_localUserInfo);

    return RefreshIndicator(
      key: const Key('patient-dashboard-refresh'),
      onRefresh: _refreshAppointmentsAndQueue,
      color: const Color(0xFF1A2F64),
      child: SingleChildScrollView(
        key: const Key('patient-dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            if (_successMessage != null) _buildInlineMessage(),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $firstName!',
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A2F64),
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Here's your appointment update today.",
                            style: TextStyle(
                              color: Color(0xFF6D7484),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: Color(0xFFC5D0E7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildPatientStatsGrid(),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildAppointmentsShortcutCard(),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTodayQueuePanel(),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentsView() {
    final List<Map<String, dynamic>> visibleAppointments = _visibleAppointments();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _refreshAppointmentsAndQueue,
      color: const Color(0xFF1A2F64),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          children: [
            const SizedBox(height: 18),
            _buildPatientPageTitle(
              title: 'My Appointments',
              subtitle: null,
              onBack: () => _selectSection(0),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAppointmentFilterChip(
                      label: 'All',
                      selected: _selectedFilter == _PatientAppointmentFilter.all,
                      onTap: () => setState(
                        () => _selectedFilter = _PatientAppointmentFilter.all,
                      ),
                    ),
                    _buildAppointmentFilterChip(
                      label: 'Pending',
                      selected:
                          _selectedFilter == _PatientAppointmentFilter.pending,
                      onTap: () => setState(
                        () => _selectedFilter = _PatientAppointmentFilter.pending,
                      ),
                    ),
                    _buildAppointmentFilterChip(
                      label: 'Approved',
                      selected:
                          _selectedFilter == _PatientAppointmentFilter.approved,
                      onTap: () => setState(
                        () => _selectedFilter = _PatientAppointmentFilter.approved,
                      ),
                    ),
                    _buildAppointmentFilterChip(
                      label: 'Completed',
                      selected:
                          _selectedFilter == _PatientAppointmentFilter.completed,
                      onTap: () => setState(
                        () => _selectedFilter = _PatientAppointmentFilter.completed,
                      ),
                    ),
                    _buildAppointmentFilterChip(
                      label: 'Cancelled',
                      selected:
                          _selectedFilter == _PatientAppointmentFilter.cancelled,
                      onTap: () => setState(
                        () => _selectedFilter = _PatientAppointmentFilter.cancelled,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: 12,
                  width: 255,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF22314D)
                        : const Color(0xFFDCE7FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
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
                  onAction: _openBookAppointmentDialog,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: visibleAppointments.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemBuilder: (BuildContext context, int index) {
                    return _buildAppointmentCard(visibleAppointments[index]);
                  },
                ),
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
        const SizedBox(height: 18),
        _buildPatientPageTitle(
          title: 'Medical History',
          subtitle: null,
          onBack: () => _selectSection(0),
        ),
        const SizedBox(height: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: completedAppts.length,
              itemBuilder: (context, index) {
                final appt = completedAppts[index];
                final serviceType =
                    appt['service_type']?.toString() ?? 'Service';
                final date =
                    appt['appointment_date']?.toString() ?? 'YYYY-MM-DD';
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFFCF7),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: Color(0xFF28C48F),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  serviceType,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    color: Color(0xFF233B6B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatHistoryDate(date, appt['appointment_time']),
                                  style: const TextStyle(
                                    color: Color(0xFF7D879A),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFFCF7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'COMPLETED',
                              style: TextStyle(
                                color: Color(0xFF28C48F),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFFD6DCEA),
                          ),
                        ],
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

  Widget _buildInlineMessage() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _messageType == 'success'
            ? const Color(0xFFEFFCF7)
            : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            _messageType == 'success'
                ? Icons.check_circle_outline
                : Icons.error_outline,
            color: _messageType == 'success'
                ? const Color(0xFF28C48F)
                : const Color(0xFFD32F2F),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _successMessage ?? '',
              style: TextStyle(
                color: _messageType == 'success'
                    ? const Color(0xFF1E8D69)
                    : const Color(0xFFD32F2F),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientStatsGrid() {
    final allAppointments = _dashboardAppointments();
    final int pendingCount = allAppointments
        .where((a) => normalizeAppointmentStatus(a['status']) == 'pending')
        .length;
    final int approvedCount = allAppointments
        .where((a) => normalizeAppointmentStatus(a['status']) == 'approved')
        .length;
    final int completedCount = allAppointments
        .where((a) => normalizeAppointmentStatus(a['status']) == 'completed')
        .length;
    final int cancelledCount = allAppointments
        .where((a) => normalizeAppointmentStatus(a['status']) == 'cancelled')
        .length;

    final List<Map<String, dynamic>> cards = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'PENDING',
        'count': pendingCount.toString().padLeft(2, '0'),
        'color': const Color(0xFFF0B400),
        'filter': _PatientAppointmentFilter.pending,
      },
      <String, dynamic>{
        'title': 'APPROVED',
        'count': approvedCount.toString().padLeft(2, '0'),
        'color': const Color(0xFF2B73F3),
        'filter': _PatientAppointmentFilter.approved,
      },
      <String, dynamic>{
        'title': 'COMPLETED',
        'count': completedCount.toString().padLeft(2, '0'),
        'color': const Color(0xFF22C792),
        'filter': _PatientAppointmentFilter.completed,
      },
      <String, dynamic>{
        'title': 'CANCELLED',
        'count': cancelledCount.toString().padLeft(2, '0'),
        'color': const Color(0xFFE63974),
        'filter': _PatientAppointmentFilter.cancelled,
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.38,
      ),
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> card = cards[index];
        final Color color = card['color'] as Color;
        final bool selected =
            _selectedFilter == card['filter'] as _PatientAppointmentFilter;

        return InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () {
            setState(() {
              _selectedFilter = card['filter'] as _PatientAppointmentFilter;
            });
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border(
                top: BorderSide(color: color, width: 4),
                left: BorderSide(color: color, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: selected ? 0.16 : 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  card['title'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  card['count'] as String,
                  style: const TextStyle(
                    color: Color(0xFF1A2F64),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppointmentsShortcutCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () => _selectSection(3),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(color: const Color(0xFFF0F3F8)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'My Appointments',
                      style: TextStyle(
                        color: Color(0xFF1A2F64),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'View and manage your bookings',
                      style: TextStyle(
                        color: Color(0xFF9AA3B2),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD2D8E5),
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientPageTitle({
    required String title,
    String? subtitle,
    required VoidCallback onBack,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: IconButton(
              onPressed: onBack,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF1A2F64),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2F64),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7E8CA0),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatHistoryDate(dynamic dateValue, dynamic timeValue) {
    final String date = dateValue?.toString() ?? '';
    final String rawTime = timeValue?.toString() ?? '';
    String time = rawTime;
    if (rawTime.isNotEmpty) {
      try {
        final List<String> parts = rawTime.split(':');
        final int hour = int.parse(parts[0]);
        final String minute = parts.length > 1 ? parts[1] : '00';
        final String amPm = hour >= 12 ? 'PM' : 'AM';
        final int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        time = '$displayHour:$minute $amPm';
      } catch (_) {}
    }
    final DateTime? parsed = DateTime.tryParse(date);
    if (parsed == null) {
      return '$date • $time';
    }
    return '${DateFormat('MMM d, yyyy').format(parsed)} • $time';
  }

  Widget _buildProfileView() {
    final Map<String, dynamic> userInfo = _localUserInfo;
    final String fullName = _fullProfileName(userInfo);

    final String address =
        (userInfo['location'] ?? userInfo['address'])?.toString() ?? 'N/A';
    final String gender = userInfo['gender']?.toString() ?? 'N/A';
    final String contactNumber =
        (userInfo['phone_number'] ?? userInfo['contact_number'])?.toString() ??
        'N/A';
    final String birthdate = _formatPatientBirthdate(userInfo['birthdate']);
    String? profilePicture = userInfo['profile_picture']?.toString();
    if (profilePicture != null &&
        (profilePicture.isEmpty ||
            profilePicture == 'null' ||
            profilePicture == '/storage/')) {
      profilePicture = null;
    }
    final String patientId =
        userInfo['patient_id']?.toString().trim().isNotEmpty == true
        ? userInfo['patient_id'].toString().trim()
        : 'PT-${(userInfo['id'] ?? '0001').toString().padLeft(4, '0')}';
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color headlineColor = isDark ? Colors.white : const Color(0xFF1F3763);
    final Color mutedText = isDark
        ? const Color(0xFFAAB7CD)
        : const Color(0xFF8E99AB);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPatientPageTitle(
              title: 'Profile Settings',
              subtitle: null,
              onBack: () => _selectSection(0),
            ),
            const SizedBox(height: 26),
            Center(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 146,
                    height: 146,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? const Color(0xFF17243A) : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
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
                        ? Icon(
                            Icons.person,
                            size: 80,
                            color: mutedText,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 2,
                    bottom: 6,
                    child: InkWell(
                      onTap: () async {
                        final result = await showDialog(
                          context: context,
                          builder: (context) =>
                              EditProfileDialog(userInfo: _localUserInfo),
                        );
                        if (result is Map<String, dynamic>) {
                          setState(() {
                            _localUserInfo = result;
                            _successMessage = 'Profile updated successfully.';
                            _messageType = 'success';
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF233D78),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF101A2C) : Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Center(
              child: Text(
                fullName.isNotEmpty ? fullName : 'User Name',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: headlineColor,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF17243A) : const Color(0xFFF8FAFE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE6EBF5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color: Color(0xFFA8B9DB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'PATIENT ACCOUNT',
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: 12,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'ID: $patientId',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'PERSONAL DETAILS',
              style: TextStyle(
                color: mutedText,
                fontSize: 12,
                letterSpacing: 2.6,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF17243A) : Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE7ECF4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileField(
                    Icons.calendar_today_outlined,
                    'BIRTHDATE',
                    birthdate,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.phone_outlined,
                    'CONTACT NUMBER',
                    contactNumber,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(
                    Icons.location_on_outlined,
                    'ADDRESS',
                    address,
                  ),
                  const SizedBox(height: 20),
                  _buildProfileField(Icons.people_outline, 'GENDER', gender),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 62,
              child: ElevatedButton(
                onPressed: () async {
                  final result = await showDialog(
                    context: context,
                    builder: (context) =>
                        EditProfileDialog(userInfo: _localUserInfo),
                  );
                  if (result is Map<String, dynamic>) {
                    setState(() {
                      _localUserInfo = result;
                      _successMessage = 'Profile updated successfully.';
                      _messageType = 'success';
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF233D78),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.menu_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Edit Profile Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileField(IconData icon, String label, String value) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF22314D) : const Color(0xFFF8FAFE),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: const Color(0xFFA8B9DB), size: 22),
        ),
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
                  color: isDark ? const Color(0xFFAAB7CD) : const Color(0xFF7E8CA0),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: MobileTypography.body(context),
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatPatientBirthdate(dynamic value) {
    final String raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return 'N/A';
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    return DateFormat('yyyy-MM-dd').format(parsed);
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
                color: const Color(0xFF9CB5E8),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final String queueDate = DateFormat('MMM d, yyyy').format(DateTime.now());
    final String yourQueueNumber = _formatQueueNumber(
      patientQueue?['queue_number'],
    );
    final String nowServingNumber = _formatQueueNumber(
      nowServing?['queue_number'],
    );
    final String queueHeadline = patientQueue?['is_now_serving'] == true
        ? 'It is your turn'
        : isPatientNextUp
        ? 'You are next'
        : 'Please wait';
    final String queueMessage = patientQueue?['is_now_serving'] == true
        ? 'Please proceed to the clinic now.'
        : isPatientNextUp
        ? 'Please get ready. Your turn is approaching.'
        : '${patientQueue?['people_ahead'] ?? 0} patients ahead of you.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2B4A) : const Color(0xFF233D78),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today\'s Queue',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFAFC2E9),
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            queueDate,
            style: const TextStyle(
              color: Color(0xFFB8C6E1),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NOW SERVING',
                      style: TextStyle(
                        color: Color(0xFFAFC2E9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '#$nowServingNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'YOUR QUEUE',
                      style: TextStyle(
                        color: Color(0xFFAFC2E9),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '#$yourQueueNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'LIVE STATUS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      queueHeadline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      queueMessage,
                      style: const TextStyle(
                        color: Color(0xFFD7E0F2),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
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

  Widget _buildAppointmentFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF233D78)
                : (isDark ? const Color(0xFF17243A) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF233D78)
                  : (isDark
                        ? const Color(0xFF2A3A55)
                        : const Color(0xFFE7ECF4)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: selected ? 0.10 : 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark
                        ? const Color(0xFFAAB7CD)
                        : const Color(0xFF7B879C)),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildBottomNavigationBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: AppNavigationTheme.surface,
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            Expanded(
              child: AppBottomNavItem(
                icon: Icons.home_outlined,
                label: 'Home',
                selected: _selectedIndex == 0,
                onTap: () => _selectSection(0),
              ),
            ),
            const SizedBox(width: 48),
            Expanded(
              child: AppBottomNavItem(
                icon: Icons.person_outline,
                label: 'Profile',
                selected: _selectedIndex == 1,
                onTap: () => _selectSection(1),
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
    final status = normalizeAppointmentStatus(appt['status']);
    final queue = _patientVisibleQueueNumber(appt, status);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? const Color(0xFF17243A) : Colors.white;
    final Color headlineColor = isDark ? Colors.white : const Color(0xFF1F3763);
    final Color mutedText = isDark
        ? const Color(0xFFAAB7CD)
        : const Color(0xFF8E99AB);
    final Color pillColor = switch (status) {
      'pending' => isDark ? const Color(0xFF3A3220) : const Color(0xFFFCEFD8),
      'approved' => isDark ? const Color(0xFF1D3A2A) : const Color(0xFFE9F8EE),
      'completed' => isDark ? const Color(0xFF22314D) : const Color(0xFFEFF4FF),
      _ => isDark ? const Color(0xFF22314D) : const Color(0xFFF4F6FB),
    };
    final Color pillTextColor = switch (status) {
      'pending' => const Color(0xFFDAA032),
      'approved' => const Color(0xFF249A5A),
      'completed' => const Color(0xFF3F67C7),
      'reschedule_required' => const Color(0xFFD97706),
      _ => mutedText,
    };
    final String statusLabel = appointmentStatusLabel(appt['status']);
    final String? rescheduleReason =
        status == 'reschedule_required'
        ? _normalizeCardReason(appt['reschedule_reason'])
        : null;

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
          color: cardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE7ECF4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF22314D) : const Color(0xFFF8FAFE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.sentiment_satisfied_alt_outlined,
                      color: isDark
                          ? const Color(0xFFAFC2E9)
                          : const Color(0xFF1F3763),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceType,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: headlineColor,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: pillColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel.toUpperCase(),
                                style: TextStyle(
                                  color: pillTextColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatAppointmentDate(date),
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.access_time_outlined,
                              size: 14,
                              color: mutedText,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              time,
                              style: TextStyle(
                                color: mutedText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (rescheduleReason != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2D2417)
                                  : const Color(0xFFFFF8EC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF6F5A25)
                                    : const Color(0xFFF5D18B),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'REASON FOR RESCHEDULE',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFF6D58E)
                                        : const Color(0xFFC58A12),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  rescheduleReason,
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFFF6E7C3)
                                        : const Color(0xFF8A5A06),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: isDark
                              ? const Color(0xFF273750)
                              : const Color(0xFFF0F3F8),
                        ),
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final bool showActions =
                                status == 'pending' ||
                                status == 'approved' ||
                                status == 'cancelled_by_doctor' ||
                                status == 'reschedule_required';
                            final bool stackActions = constraints.maxWidth < 250;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'QUEUE\nNUMBER',
                                            style: TextStyle(
                                              color: mutedText,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '#${_formatQueueNumber(queue)}',
                                            maxLines: 1,
                                            overflow: TextOverflow.visible,
                                            style: TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: headlineColor,
                                              height: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (showActions && !stackActions) ...[
                                      const SizedBox(width: 12),
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            _buildAppointmentAction(
                                              label: 'Reschedule',
                                              color: isDark
                                                  ? const Color(0xFF22314D)
                                                  : const Color(0xFFF8FAFE),
                                              textColor: headlineColor,
                                              onTap: () => _openRescheduleDialog(appt),
                                            ),
                                            const SizedBox(width: 10),
                                            _buildAppointmentAction(
                                              label: status == 'pending' || status == 'approved'
                                                  ? 'Cancel'
                                                  : 'Requires Action',
                                              color: status == 'pending' || status == 'approved'
                                                  ? (isDark
                                                        ? const Color(0xFF3A1E24)
                                                        : const Color(0xFFFFF4F4))
                                                  : (isDark
                                                        ? const Color(0xFF22314D)
                                                        : const Color(0xFFF8FAFC)),
                                              textColor: status == 'pending' || status == 'approved'
                                                  ? const Color(0xFFE26B6B)
                                                  : mutedText,
                                              onTap: status == 'pending' || status == 'approved'
                                                  ? () => _showCancelConfirmationDialog(appt)
                                                  : null,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (showActions && stackActions) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildAppointmentAction(
                                          label: 'Reschedule',
                                          color: isDark
                                              ? const Color(0xFF22314D)
                                              : const Color(0xFFF8FAFE),
                                          textColor: headlineColor,
                                          onTap: () => _openRescheduleDialog(appt),
                                          expand: true,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildAppointmentAction(
                                          label: status == 'pending' || status == 'approved'
                                              ? 'Cancel'
                                              : 'Requires Action',
                                          color: status == 'pending' || status == 'approved'
                                              ? (isDark
                                                    ? const Color(0xFF3A1E24)
                                                    : const Color(0xFFFFF4F4))
                                              : (isDark
                                                    ? const Color(0xFF22314D)
                                                    : const Color(0xFFF8FAFC)),
                                          textColor: status == 'pending' || status == 'approved'
                                              ? const Color(0xFFE26B6B)
                                              : mutedText,
                                          onTap: status == 'pending' || status == 'approved'
                                              ? () => _showCancelConfirmationDialog(appt)
                                              : null,
                                          expand: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentAction({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback? onTap,
    bool expand = false,
  }) {
    final Widget child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );

    return child;
  }

  String _formatAppointmentDate(String rawDate) {
    final DateTime? parsed = DateTime.tryParse(rawDate);
    if (parsed == null) {
      return rawDate;
    }
    return DateFormat('MMM d, yyyy').format(parsed);
  }

  String _patientVisibleQueueNumber(
    Map<String, dynamic> appointment,
    String status,
  ) {
    if (status != 'approved' && status != 'completed') {
      return '--';
    }

    final String queue = appointment['queue_number']?.toString().trim() ?? '';
    return queue.isEmpty ? '--' : queue;
  }

  String? _normalizeCardReason(dynamic value) {
    final String reason = value?.toString().trim() ?? '';
    if (reason.isEmpty) {
      return null;
    }

    return reason;
  }

  void _showCancelConfirmationDialog(Map<String, dynamic> appointment) {
    final int id = (appointment['id'] as num).toInt();
    final String serviceType =
        appointment['service_type']?.toString().trim().isNotEmpty == true
        ? appointment['service_type'].toString().trim()
        : 'this appointment';
    final String formattedDate = _formatAppointmentDate(
      appointment['appointment_date']?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmationDialog(
        icon: Icons.close_rounded,
        iconBackgroundColor: const Color(0xFFFFECEC),
        iconColor: const Color(0xFFFF4747),
        title: 'Cancel Appointment?',
        message:
            'Are you sure you want to cancel your appointment for '
            '$serviceType on $formattedDate?',
        secondaryLabel: 'No, Keep it',
        primaryLabel: 'Yes, Cancel',
        primaryColor: const Color(0xFFFF4B4B),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(),
        onPrimaryPressed: () async {
          Navigator.of(dialogContext).pop();
          await _cancelAppointment(id);
        },
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
