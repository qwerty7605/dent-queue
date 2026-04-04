import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/appointment_queue_order.dart';
import '../core/appointment_status.dart';
import '../core/config.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import '../services/notification_service.dart';
import '../services/patient_record_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/appointment_success_dialog.dart';
import '../widgets/appointment_status_badge.dart';
import '../widgets/edit_profile_dialog.dart';
import '../widgets/staff_appointment_details_dialog.dart';
import 'staff_calendar_view.dart';
import 'notifications_view.dart';
import 'recycle_bin_view.dart';
import 'staff_patient_records_view.dart';
import 'staff_walk_in_view.dart';

enum _StaffTab { appointments, walkIn, calendar, records, profile }

enum _StaffFilter { all, pending, approved, completed, cancelled }

class StaffDashboardView extends StatefulWidget {
  const StaffDashboardView({
    super.key,
    required this.userInfo,
    required this.tokenStorage,
    required this.onLogout,
    required this.loggingOut,
    this.readOnly = false,
    this.appointmentService,
    this.notificationService,
  });

  final Map<String, dynamic>? userInfo;
  final TokenStorage tokenStorage;
  final VoidCallback onLogout;
  final bool loggingOut;
  final bool readOnly;
  final AppointmentService? appointmentService;
  final NotificationService? notificationService;

  @override
  State<StaffDashboardView> createState() => _StaffDashboardViewState();
}

class _StaffDashboardViewState extends State<StaffDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  late final BaseService _baseService;
  late final AppointmentService _appointmentService;
  late final NotificationService _notificationService;
  late final PatientRecordService _patientRecordService;
  late Map<String, dynamic> _localUserInfo;

  late DateTime _selectedDate;
  _StaffTab _selectedTab = _StaffTab.appointments;
  _StaffFilter _selectedFilter = _StaffFilter.all;

  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _cancelledAppointments = [];
  Map<String, dynamic>? _queueStatus;
  bool _isLoadingAppointments = true;
  bool _isCallingNext = false;
  String? _appointmentsLoadError;
  final int _profileImageVersion = DateTime.now().millisecondsSinceEpoch;
  int _unreadNotificationCount = 0;

  bool get _isReadOnlyAccount =>
      widget.readOnly || _resolvedRole(_localUserInfo) == 'intern';
  String get _accountRoleLabel => _isReadOnlyAccount ? 'Intern' : 'Staff';
  String get _accountRoleTag => _isReadOnlyAccount ? 'INTERN' : 'STAFF';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _baseService = BaseService(ApiClient(tokenStorage: widget.tokenStorage));
    _appointmentService =
        widget.appointmentService ?? AppointmentService(_baseService);
    _notificationService =
        widget.notificationService ?? NotificationService(_baseService);
    _patientRecordService = PatientRecordService(_baseService);
    _localUserInfo = widget.userInfo != null
        ? Map<String, dynamic>.from(widget.userInfo!)
        : <String, dynamic>{};
    _initializeAppointments();
    if (_isReadOnlyAccount) {
      _unreadNotificationCount = 0;
    } else {
      _loadUnreadNotificationCount();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointmentsForSelectedDate({
    bool showLoader = true,
    bool forceRefresh = false,
  }) async {
    final date = _formatApiDate(_selectedDate);
    final bool hasVisibleContent =
        _appointments.isNotEmpty ||
        _cancelledAppointments.isNotEmpty ||
        _queueStatus != null;

    if (showLoader || !hasVisibleContent) {
      setState(() {
        _isLoadingAppointments = true;
        _appointmentsLoadError = null;
      });
    } else {
      setState(() {
        _appointmentsLoadError = null;
      });
    }

    try {
      if (forceRefresh) {
        _appointmentService.invalidateAppointmentCaches();
      }

      final Future<List<Map<String, dynamic>>> appointmentsFuture =
          _appointmentService.getAdminAppointmentsByDate(date);
      final Future<List<Map<String, dynamic>>> recycleBinFuture =
          _isReadOnlyAccount
          ? Future<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[])
          : _appointmentService
                .getRecycleBinAppointments(true)
                .catchError((_) => <Map<String, dynamic>>[]);
      final Future<Map<String, dynamic>> queueFuture = _appointmentService
          .getAdminTodayQueue(date);

      final List<Map<String, dynamic>> list = await appointmentsFuture;
      final List<Map<String, dynamic>> recycleBinAppointments =
          await recycleBinFuture;
      Map<String, dynamic>? queueStatus;
      try {
        queueStatus = await queueFuture;
      } on ApiException {
        queueStatus = _buildQueueStatusFallback(list, date);
      } catch (_) {
        queueStatus = _buildQueueStatusFallback(list, date);
      }
      if (!mounted) return;
      final cancelledForSelectedDate = recycleBinAppointments
          .where(
            (appointment) =>
                appointment['appointment_date']?.toString() == date,
          )
          .toList();
      setState(() {
        _appointments = list;
        _cancelledAppointments = cancelledForSelectedDate;
        _queueStatus = queueStatus;
        _isLoadingAppointments = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      if (!showLoader && hasVisibleContent) {
        setState(() {
          _isLoadingAppointments = false;
        });
        _showStatusMessage(e.message);
        return;
      }

      setState(() {
        _appointments = [];
        _cancelledAppointments = [];
        _queueStatus = null;
        _isLoadingAppointments = false;
        _appointmentsLoadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      if (!showLoader && hasVisibleContent) {
        setState(() {
          _isLoadingAppointments = false;
        });
        _showStatusMessage('Unable to refresh daily queue right now.');
        return;
      }

      setState(() {
        _appointments = [];
        _cancelledAppointments = [];
        _queueStatus = null;
        _isLoadingAppointments = false;
        _appointmentsLoadError =
            'Unable to load daily queue for $date. Please try again.';
      });
    }
  }

  Future<void> _refreshAppointmentsAndQueue() {
    return _loadAppointmentsForSelectedDate(
      showLoader: false,
      forceRefresh: true,
    );
  }

  Future<void> _initializeAppointments() async {
    await _selectNextBookedDateForInitialLoad();
    if (!mounted) return;
    await _loadAppointmentsForSelectedDate();
  }

  Future<void> _loadUnreadNotificationCount() async {
    if (_isReadOnlyAccount) {
      if (!mounted) return;
      setState(() {
        _unreadNotificationCount = 0;
      });
      return;
    }

    try {
      final NotificationListResult result = await _notificationService
          .getNotifications('staff');
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
    if (_isReadOnlyAccount) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsView()),
    );
    if (!mounted) return;
    await _loadUnreadNotificationCount();
  }

  Future<void> _selectNextBookedDateForInitialLoad() async {
    try {
      final appointments = await _appointmentService.getAdminMasterList();
      final today = _startOfDay(DateTime.now());

      DateTime? nextBookedDate;

      for (final appointment in appointments) {
        final status = normalizeAppointmentStatus(appointment['status']);
        if (status == 'cancelled') {
          continue;
        }

        final parsedDate = _parseApiDate(appointment['date']);
        if (parsedDate == null || parsedDate.isBefore(today)) {
          continue;
        }

        if (nextBookedDate == null || parsedDate.isBefore(nextBookedDate)) {
          nextBookedDate = parsedDate;
        }
      }

      if (nextBookedDate != null) {
        _selectedDate = nextBookedDate;
      }
    } catch (_) {
      // Fall back to today's queue when the master list is unavailable.
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });
    await _loadAppointmentsForSelectedDate();
  }

  Future<void> _callNextPatient() async {
    if (_isCallingNext) return;

    setState(() {
      _isCallingNext = true;
    });

    try {
      final response = await _appointmentService.callNextQueue(
        date: _formatApiDate(_selectedDate),
      );
      if (!mounted) return;

      setState(() {
        _queueStatus = Map<String, dynamic>.from(response);
      });

      final message =
          response['message']?.toString() ?? 'Queue updated successfully.';
      _showStatusMessage(message);
      await _loadAppointmentsForSelectedDate(showLoader: false);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showStatusMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showStatusMessage('Unable to call the next patient right now.');
    } finally {
      if (mounted) {
        setState(() {
          _isCallingNext = false;
        });
      }
    }
  }

  void _openAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog<void>(
      context: context,
      builder: (_) => StaffAppointmentDetailsDialog(
        appointment: appointment,
        showStatusActions: !_isReadOnlyAccount,
        onStatusUpdate: _isReadOnlyAccount
            ? null
            : (nextStatus) => _updateAppointmentStatus(appointment, nextStatus),
      ),
    );
  }

  Future<bool> _updateAppointmentStatus(
    Map<String, dynamic> appointment,
    String nextStatus,
  ) async {
    final appointmentId = _parseAppointmentId(appointment['id']);
    if (appointmentId == null) {
      _showStatusMessage('Unable to update status: invalid appointment ID.');
      return false;
    }

    try {
      await _appointmentService.updateAdminAppointmentStatus(
        appointmentId,
        nextStatus,
      );
      if (!mounted) return false;

      await _loadAppointmentsForSelectedDate(showLoader: false);
      if (!mounted) return true;

      final updatedLabel = appointmentStatusLabel(nextStatus);

      if (normalizeAppointmentStatus(nextStatus) == 'approved') {
        await showAppointmentSuccessDialog(
          context,
          title: 'Appointment\nSuccessfully Approved!',
          message: 'The appointment has been successfully approved.',
          buttonLabel: 'Return to Queue',
        );
        if (!mounted) return true;
      } else {
        _showStatusMessage('Appointment updated to $updatedLabel.');
      }

      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      _showStatusMessage(e.message);
      return false;
    } catch (_) {
      if (!mounted) return false;
      _showStatusMessage('Unable to update appointment status right now.');
      return false;
    }
  }

  void _showStatusMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openEditProfileDialog() async {
    if (_isReadOnlyAccount) {
      _showStatusMessage('Intern accounts are view-only.');
      return;
    }

    if (_localUserInfo['id'] == null) {
      _showStatusMessage('Unable to edit profile right now.');
      return;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => EditProfileDialog(userInfo: _localUserInfo),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _localUserInfo = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = _localUserInfo;
    final name = _resolveDisplayName(userInfo);
    final chipName = _resolveTopBarName(userInfo);
    final profilePicture = _normalizeProfilePicture(
      userInfo['profile_picture'],
    );
    final profileImageUrl = _buildProfileImageUrl(profilePicture);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5ED),
      appBar: _buildAppBar(chipName, profileImageUrl),
      drawer: _buildDrawer(name, profileImageUrl),
      body: SafeArea(child: _buildSelectedTab(profileImageUrl)),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildSelectedTab(String? profileImageUrl) {
    return switch (_selectedTab) {
      _StaffTab.appointments => _buildAppointmentsTab(),
      _StaffTab.walkIn =>
        _isReadOnlyAccount
            ? _buildRestrictedSectionState('Walk-in')
            : StaffWalkInView(
                appointmentService: _appointmentService,
                onWalkInSuccess: () {
                  if (mounted) {
                    setState(() {
                      _selectedTab = _StaffTab.appointments;
                    });
                  }
                  _loadAppointmentsForSelectedDate(showLoader: false);
                },
              ),
      _StaffTab.calendar => StaffCalendarView(
        appointmentService: _appointmentService,
      ),
      _StaffTab.records =>
        _isReadOnlyAccount
            ? _buildRestrictedSectionState('Records')
            : StaffPatientRecordsView(
                patientRecordService: _patientRecordService,
                appointmentService: _appointmentService,
              ),
      _StaffTab.profile => _buildProfileTab(profileImageUrl),
    };
  }

  PreferredSizeWidget _buildAppBar(String name, String? profileImageUrl) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final chipWidth = screenWidth < 390 ? 130.0 : 160.0;

    return AppBar(
      backgroundColor: const Color(0xFF356042),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white, size: 24),
      titleSpacing: -8,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 38, height: 38),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'SMART',
                  style: TextStyle(
                    color: Color(0xFFE8C355),
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
        if (!_isReadOnlyAccount)
          IconButton(
            icon: _buildNotificationIcon(_unreadNotificationCount),
            onPressed: _openNotifications,
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              setState(() {
                _selectedTab = _StaffTab.profile;
              });
            },
            child: SizedBox(
              width: chipWidth,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _accountRoleTag,
                            style: TextStyle(
                              color: Color(0xFFE8C355),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      backgroundImage: profileImageUrl != null
                          ? NetworkImage(profileImageUrl)
                          : null,
                      child: profileImageUrl == null
                          ? const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 18,
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
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(4),
        child: ColoredBox(color: Color(0xFFE8C355), child: SizedBox(height: 4)),
      ),
    );
  }

  Widget _buildDrawer(String name, String? profileImageUrl) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              color: const Color(0xFF356042),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: profileImageUrl != null
                        ? NetworkImage(profileImageUrl)
                        : null,
                    child: profileImageUrl == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: Colors.white,
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_accountRoleTag ACCOUNT',
                          style: TextStyle(
                            color: Color(0xFFE8C355),
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
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
            const SizedBox(height: 10),
            _buildDrawerItem(
              icon: Icons.person_outline,
              title: 'Profile',
              selected: _selectedTab == _StaffTab.profile,
              onTap: () {
                setState(() {
                  _selectedTab = _StaffTab.profile;
                });
                Navigator.pop(context);
              },
            ),
            _buildDrawerItem(
              icon: Icons.event_available_outlined,
              title: 'Appointments',
              selected: _selectedTab == _StaffTab.appointments,
              onTap: () {
                setState(() {
                  _selectedTab = _StaffTab.appointments;
                });
                Navigator.pop(context);
              },
            ),
            if (!_isReadOnlyAccount)
              _buildDrawerItem(
                icon: Icons.directions_walk,
                title: 'Walk-in',
                selected: _selectedTab == _StaffTab.walkIn,
                onTap: () {
                  setState(() {
                    _selectedTab = _StaffTab.walkIn;
                  });
                  Navigator.pop(context);
                },
              ),
            if (!_isReadOnlyAccount)
              _buildDrawerItem(
                icon: Icons.search,
                title: 'Records',
                selected: _selectedTab == _StaffTab.records,
                onTap: () {
                  setState(() {
                    _selectedTab = _StaffTab.records;
                  });
                  Navigator.pop(context);
                },
              ),
            _buildDrawerItem(
              icon: Icons.calendar_month_outlined,
              title: 'Calendar',
              selected: _selectedTab == _StaffTab.calendar,
              onTap: () {
                setState(() {
                  _selectedTab = _StaffTab.calendar;
                });
                Navigator.pop(context);
              },
            ),
            if (!_isReadOnlyAccount)
              _buildDrawerItem(
                icon: Icons.notifications_none,
                title: 'Notifications',
                selected: false,
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
            if (!_isReadOnlyAccount)
              _buildDrawerItem(
                icon: Icons.restore_from_trash_outlined,
                title: 'Recycle Bin',
                selected: false,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecycleBinView(
                        role: RecycleBinRole.staff,
                        appointmentService: _appointmentService,
                      ),
                    ),
                  ).then(
                    (_) => _loadAppointmentsForSelectedDate(showLoader: false),
                  );
                },
              ),
            const Spacer(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 28,
                vertical: 8,
              ),
              leading: widget.loggingOut
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text(
                'Logout',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: widget.loggingOut ? null : widget.onLogout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 26),
      leading: Icon(
        icon,
        color: selected ? const Color(0xFF356042) : const Color(0xFF64748B),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? const Color(0xFF356042) : const Color(0xFF64748B),
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildProfileTab(String? profileImageUrl) {
    final userInfo = _localUserInfo;
    final displayName = _resolveDisplayName(userInfo).toUpperCase();
    final fullName = _resolveFullName(userInfo).toUpperCase();
    final firstName = _resolveProfileValue(userInfo['first_name']);
    final middleName = _resolveProfileValue(userInfo['middle_name']);
    final lastName = _resolveProfileValue(userInfo['last_name']);
    final address = _resolveProfileValue(
      userInfo['location'] ?? userInfo['address'],
    );
    final gender = _resolveProfileValue(userInfo['gender']);
    final contactNumber = _resolveProfileValue(
      userInfo['phone_number'] ?? userInfo['contact_number'],
    );
    final accountId = _formatStaffAccountId(userInfo['id']);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
        child: Column(
          children: [
            Container(
              width: 144,
              height: 144,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF356042), width: 3),
                color: const Color(0xFFF8FAFC),
                image: profileImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(profileImageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profileImageUrl == null
                  ? const Icon(Icons.person, size: 80, color: Colors.grey)
                  : null,
            ),
            const SizedBox(height: 18),
            Text(
              displayName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '$_accountRoleLabel Account\nID: $accountId',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileField(
                    icon: Icons.person_outline,
                    label: 'FULL NAME',
                    value: fullName,
                  ),
                  const SizedBox(height: 18),
                  _buildProfileField(
                    icon: Icons.badge_outlined,
                    label: 'FIRST NAME',
                    value: firstName,
                  ),
                  const SizedBox(height: 18),
                  _buildProfileField(
                    icon: Icons.assignment_ind_outlined,
                    label: 'MIDDLE NAME',
                    value: middleName,
                  ),
                  const SizedBox(height: 18),
                  _buildProfileField(
                    icon: Icons.person_pin_outlined,
                    label: 'LAST NAME',
                    value: lastName,
                  ),
                  const SizedBox(height: 18),
                  _buildProfileField(
                    icon: Icons.location_on_outlined,
                    label: 'ADDRESS',
                    value: address,
                  ),
                  const SizedBox(height: 18),
                  _buildProfileField(
                    icon: Icons.people_outline,
                    label: 'GENDER',
                    value: gender,
                  ),
                  const SizedBox(height: 18),
                  _buildProfileField(
                    icon: Icons.phone_outlined,
                    label: 'CONTACT NUMBER',
                    value: contactNumber,
                  ),
                  const SizedBox(height: 24),
                  if (_isReadOnlyAccount)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Profile details are view-only for intern accounts.',
                              style: TextStyle(
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          await _openEditProfileDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF356042),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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

  Widget _buildProfileField({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF356042), size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF94A3B8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentsTab() {
    final visibleAppointments = _computeVisibleAppointments();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 440 ? 14.0 : 22.0;
        final maxWidth = constraints.maxWidth > 1024 ? 920.0 : double.infinity;

        return RefreshIndicator(
          key: const Key('staff-dashboard-refresh'),
          onRefresh: _refreshAppointmentsAndQueue,
          color: const Color(0xFF356042),
          child: SingleChildScrollView(
            key: const Key('staff-dashboard-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              16,
              horizontalPadding,
              16,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        '$_accountRoleTag DASHBOARD',
                        style: TextStyle(
                          fontSize: MobileTypography.pageTitle(context),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDailyQueueHeader(),
                    const SizedBox(height: 10),
                    _buildSummaryCards(constraints.maxWidth),
                    const SizedBox(height: 10),
                    _buildTodayQueuePanel(),
                    const SizedBox(height: 14),
                    _buildSearchField(),
                    const SizedBox(height: 10),
                    _buildFilterRow(),
                    const SizedBox(height: 12),
                    if (_isLoadingAppointments)
                      _buildLoadingState()
                    else if (_appointmentsLoadError != null)
                      _buildErrorState(_appointmentsLoadError!)
                    else if (visibleAppointments.isEmpty)
                      _buildEmptyState()
                    else
                      ListView.builder(
                        itemCount: visibleAppointments.length,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          return _buildAppointmentCard(
                            visibleAppointments[index],
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(double availableWidth) {
    final pendingCount = _countByStatus('pending');
    final approvedCount = _countByStatus('approved');
    final completedCount = _countByStatus('completed');
    final cancelledCount = _countByStatus('cancelled');

    final cards = [
      {
        'label': 'PENDING',
        'count': pendingCount.toString(),
        'icon': Icons.access_time_filled,
        'color': const Color(0xFFF97316),
        'backgroundColor': const Color(0xFFFFF3E8),
        'filter': _StaffFilter.pending,
      },
      {
        'label': 'APPROVED',
        'count': approvedCount.toString(),
        'icon': Icons.check_circle_outline,
        'color': const Color(0xFF1D4ED8),
        'backgroundColor': const Color(0xFFEFF5FF),
        'filter': _StaffFilter.approved,
      },
      {
        'label': 'COMPLETED',
        'count': completedCount.toString(),
        'icon': Icons.medical_services_outlined,
        'color': const Color(0xFF16A34A),
        'backgroundColor': const Color(0xFFEFFCF3),
        'filter': _StaffFilter.completed,
      },
      {
        'label': 'CANCELLED',
        'count': cancelledCount.toString(),
        'icon': Icons.cancel_outlined,
        'color': const Color(0xFFDC2626),
        'backgroundColor': const Color(0xFFFFF0F0),
        'filter': _StaffFilter.cancelled,
      },
    ];

    final crossAxisCount = availableWidth > 760 ? 4 : 2;
    final childAspectRatio = availableWidth < 360 ? 1.15 : 1.3;

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final card = cards[index];
        final label = card['label']! as String;
        final count = card['count']! as String;
        final icon = card['icon']! as IconData;
        final color = card['color']! as Color;
        final backgroundColor = card['backgroundColor']! as Color;
        final filter = card['filter']! as _StaffFilter;

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
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: _selectedFilter == filter
                    ? color.withValues(alpha: 0.45)
                    : color.withValues(alpha: 0.12),
                width: _selectedFilter == filter ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 8),
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'Search Patient name...',
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w600,
          ),
          suffixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF356042), width: 1.3),
          ),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDailyQueueHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.format_list_numbered,
                size: 18,
                color: Color(0xFF356042),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Daily Queue - ${_formatLongDate(_selectedDate)}',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: MobileTypography.label(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                color: const Color(0xFF356042),
                tooltip: 'Select date',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: _isLoadingAppointments
                    ? null
                    : () => _loadAppointmentsForSelectedDate(),
                icon: const Icon(Icons.refresh, size: 18),
                color: const Color(0xFF356042),
                tooltip: 'Refresh daily queue',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayQueuePanel() {
    final nowServing = _queueStatus?['now_serving'] as Map<String, dynamic>?;
    final nextUp = _queueStatus?['next_up'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                child: _buildQueueStatusCard(
                  label: 'NOW SERVING',
                  queueNumber: nowServing?['queue_number'],
                  caption: nowServing?['patient_name']?.toString() ?? 'Waiting',
                  accentColor: const Color(0xFF16A34A),
                  backgroundColor: const Color(0xFFEFFCF3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildQueueStatusCard(
                  label: 'NEXT UP',
                  queueNumber: nextUp?['queue_number'],
                  caption:
                      nextUp?['patient_name']?.toString() ?? 'No one in line',
                  accentColor: const Color(0xFF1D4ED8),
                  backgroundColor: const Color(0xFFEFF5FF),
                ),
              ),
            ],
          ),
          if (!_isReadOnlyAccount) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isCallingNext || _isLoadingAppointments)
                    ? null
                    : _callNextPatient,
                icon: _isCallingNext
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.campaign_outlined, size: 18),
                label: Text(_isCallingNext ? 'Calling...' : 'Call Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF356042),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQueueStatusCard({
    required String label,
    required dynamic queueNumber,
    required String caption,
    required Color accentColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: MobileTypography.caption(context),
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '#${_formatQueueNumber(queueNumber)}',
            style: TextStyle(
              fontSize: MobileTypography.sectionTitle(context),
              fontWeight: FontWeight.w900,
              color: accentColor,
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

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          SizedBox(height: 10),
          Text(
            'Loading daily queue...',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 32, color: Color(0xFFDC2626)),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFFB91C1C),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _loadAppointmentsForSelectedDate(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF356042),
              foregroundColor: Colors.white,
              minimumSize: const Size(116, 36),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestrictedSectionState(String sectionName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 36,
                color: Color(0xFF64748B),
              ),
              const SizedBox(height: 12),
              Text(
                '$sectionName is not available for intern accounts.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedTab = _StaffTab.appointments;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF356042),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Back to Appointments'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildFilterChip('ALL', _StaffFilter.all),
          const SizedBox(width: 8),
          _buildFilterChip('Pending', _StaffFilter.pending),
          const SizedBox(width: 8),
          _buildFilterChip('Approved', _StaffFilter.approved),
          const SizedBox(width: 8),
          _buildFilterChip('Completed', _StaffFilter.completed),
          const SizedBox(width: 8),
          _buildFilterChip('Cancelled', _StaffFilter.cancelled),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, _StaffFilter filter) {
    final selected = _selectedFilter == filter;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF356042) : const Color(0xFFECEDEA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool hasSearch = _searchController.text.trim().isNotEmpty;
    final bool hasFilters = _selectedFilter != _StaffFilter.all;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      child: AppEmptyState(
        key: const Key('staff-appointments-empty-state'),
        icon: Icons.fact_check_outlined,
        title: hasSearch || hasFilters
            ? 'No appointments match your view'
            : 'No appointments in queue for this day',
        message: hasSearch || hasFilters
            ? 'Clear the current search or status filter to see the full appointment queue.'
            : 'New bookings for the selected day will appear here once they are available.',
        actionLabel: hasSearch || hasFilters ? 'Clear Filters' : null,
        actionIcon: Icons.restart_alt_rounded,
        onAction: hasSearch || hasFilters ? _clearAppointmentFilters : null,
      ),
    );
  }

  void _clearAppointmentFilters() {
    _searchController.clear();
    setState(() {
      _selectedFilter = _StaffFilter.all;
    });
    FocusScope.of(context).unfocus();
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appointment) {
    final serviceType = appointment['service_type']?.toString() ?? 'Service';
    final patientName = appointment['patient_name']?.toString() ?? 'Patient';
    final date =
        appointment['appointment_date']?.toString() ??
        _formatApiDate(DateTime.now());
    final rawTime =
        appointment['time']?.toString() ??
        appointment['appointment_time']?.toString() ??
        '--:--';
    final time = _formatDisplayTime(rawTime);
    final status = normalizeAppointmentStatus(appointment['status']);
    final queueNumber = _formatQueueNumber(appointment['queue_number']);
    final initial = serviceType.isNotEmpty ? serviceType[0].toUpperCase() : 'S';
    final accent = _serviceAccentColor(serviceType);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _openAppointmentDetails(appointment),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD8DEE8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: accent,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                serviceType,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: MobileTypography.body(context),
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF334155),
                                ),
                              ),
                              AppointmentStatusBadge(
                                status: status,
                                compact: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: MobileTypography.caption(context),
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 11,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: MobileTypography.caption(context),
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.access_time_outlined,
                                size: 11,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: MobileTypography.caption(context),
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'QUEUE',
                          style: TextStyle(
                            fontSize: MobileTypography.caption(context),
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          '#$queueNumber',
                          style: TextStyle(
                            fontSize: MobileTypography.pageTitle(context),
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF356042),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            _buildNavItem(
              icon: Icons.event_available_outlined,
              label: 'Appointments',
              tab: _StaffTab.appointments,
            ),
            _buildNavItem(
              icon: Icons.calendar_month_outlined,
              label: 'Calendar',
              tab: _StaffTab.calendar,
            ),
            if (!_isReadOnlyAccount)
              _buildNavItem(
                icon: Icons.directions_walk,
                label: 'Walk In',
                tab: _StaffTab.walkIn,
              ),
            if (!_isReadOnlyAccount)
              _buildNavItem(
                icon: Icons.search,
                label: 'Records',
                tab: _StaffTab.records,
              ),
            _buildNavItem(
              icon: Icons.person_outline,
              label: 'Profile',
              tab: _StaffTab.profile,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required _StaffTab tab,
  }) {
    final selected = _selectedTab == tab;
    final color = selected ? const Color(0xFF356042) : const Color(0xFF94A3B8);

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedTab = tab;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countByStatus(String key) {
    return _dashboardAppointments()
        .where((a) => normalizeAppointmentStatus(a['status']) == key)
        .length;
  }

  List<Map<String, dynamic>> _dashboardAppointments() {
    return [..._appointments, ..._cancelledAppointments];
  }

  List<Map<String, dynamic>> _computeVisibleAppointments() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _dashboardAppointments().where((appointment) {
      final status = normalizeAppointmentStatus(appointment['status']);
      final matchesStatus = switch (_selectedFilter) {
        _StaffFilter.all => true,
        _StaffFilter.pending => status == 'pending',
        _StaffFilter.approved => status == 'approved',
        _StaffFilter.completed => status == 'completed',
        _StaffFilter.cancelled => status == 'cancelled',
      };

      if (!matchesStatus) return false;
      if (query.isEmpty) return true;

      final patientName =
          appointment['patient_name']?.toString().toLowerCase() ?? '';
      final serviceType =
          appointment['service_type']?.toString().toLowerCase() ?? '';
      final queue = appointment['queue_number']?.toString().toLowerCase() ?? '';
      return patientName.contains(query) ||
          serviceType.contains(query) ||
          queue.contains(query);
    }).toList();

    filtered.sort(compareAppointmentQueueDisplayOrder);

    return filtered;
  }

  int _parseQueueNumber(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return 9999;
    }
    return int.tryParse(value.toString()) ?? 9999;
  }

  int? _parseAppointmentId(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return null;
    }
    return int.tryParse(value.toString());
  }

  Color _serviceAccentColor(String serviceType) {
    const palette = [
      Color(0xFF2563EB),
      Color(0xFF0EA5E9),
      Color(0xFF16A34A),
      Color(0xFFF97316),
      Color(0xFF9333EA),
      Color(0xFFDC2626),
    ];
    return palette[serviceType.hashCode.abs() % palette.length];
  }

  String _resolveDisplayName(Map<String, dynamic>? userInfo) {
    if (userInfo == null) return _accountRoleLabel;

    final direct = userInfo['name']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final parts = [
      userInfo['first_name']?.toString().trim() ?? '',
      userInfo['middle_name']?.toString().trim() ?? '',
      userInfo['last_name']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return _accountRoleLabel;
    return parts.join(' ');
  }

  String _resolveFullName(Map<String, dynamic>? userInfo) {
    if (userInfo == null) {
      return 'N/A';
    }

    final parts = [
      userInfo['first_name']?.toString().trim() ?? '',
      userInfo['middle_name']?.toString().trim() ?? '',
      userInfo['last_name']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isNotEmpty) {
      return parts.join(' ');
    }

    final direct = userInfo['name']?.toString().trim() ?? '';
    return direct.isNotEmpty ? direct : 'N/A';
  }

  String _resolveTopBarName(Map<String, dynamic>? userInfo) {
    if (userInfo == null) {
      return _accountRoleLabel;
    }

    final firstName = userInfo['first_name']?.toString().trim() ?? '';
    if (firstName.isNotEmpty) {
      return firstName;
    }

    final displayName = _resolveDisplayName(userInfo);
    final parts = displayName.split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.trim().isEmpty) {
      return _accountRoleLabel;
    }

    return parts.first;
  }

  String _resolvedRole(Map<String, dynamic>? userInfo) {
    if (userInfo == null) {
      return 'staff';
    }

    final dynamic directRole = userInfo['role'];
    if (directRole is String && directRole.trim().isNotEmpty) {
      return directRole.trim().toLowerCase();
    }

    if (directRole is Map) {
      final String roleName =
          directRole['name']?.toString().trim().toLowerCase() ?? '';
      if (roleName.isNotEmpty) {
        return roleName;
      }
    }

    final String roleName =
        userInfo['role_name']?.toString().trim().toLowerCase() ?? '';
    if (roleName.isNotEmpty) {
      return roleName;
    }

    return 'staff';
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

  String _resolveProfileValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isNotEmpty ? text : 'N/A';
  }

  String _formatStaffAccountId(dynamic value) {
    final id = value?.toString().trim() ?? '';
    return id.isNotEmpty ? 'SDQ-$id' : 'SDQ-';
  }

  String? _normalizeProfilePicture(dynamic value) {
    if (value == null) {
      return null;
    }

    final raw = value.toString().trim();
    if (raw.isEmpty ||
        raw == '/storage' ||
        raw == '/storage/' ||
        raw == 'storage' ||
        raw == 'storage/') {
      return null;
    }

    return raw;
  }

  String? _buildProfileImageUrl(String? profilePicture) {
    if (profilePicture == null) {
      return null;
    }

    String baseUrl;
    if (profilePicture.startsWith('http://') ||
        profilePicture.startsWith('https://')) {
      baseUrl = profilePicture;
    } else {
      final normalizedPath = profilePicture.startsWith('/')
          ? profilePicture
          : '/$profilePicture';
      baseUrl = '${AppConfig.baseUrl}$normalizedPath';
    }

    final separator = baseUrl.contains('?') ? '&' : '?';
    return '$baseUrl${separator}v=$_profileImageVersion';
  }

  String _formatQueueNumber(dynamic value) {
    final queue = _parseQueueNumber(value);
    if (queue >= 9999) {
      return '--';
    }
    return queue.toString().padLeft(2, '0');
  }

  Map<String, dynamic> _buildQueueStatusFallback(
    List<Map<String, dynamic>> appointments,
    String date,
  ) {
    final nowServingCandidates =
        appointments
            .where((appointment) => appointment['is_called'] == true)
            .toList()
          ..sort(compareAppointmentQueueDisplayOrderDescending);

    final nextUpCandidates =
        appointments
            .where(
              (appointment) =>
                  appointment['is_called'] != true &&
                  normalizeAppointmentStatus(appointment['status']) ==
                      'approved',
            )
            .toList()
          ..sort(compareAppointmentQueueDisplayOrder);

    return {
      'date': date,
      'now_serving': nowServingCandidates.isEmpty
          ? null
          : _toQueueStatusEntry(nowServingCandidates.first),
      'next_up': nextUpCandidates.isEmpty
          ? null
          : _toQueueStatusEntry(nextUpCandidates.first),
    };
  }

  Map<String, dynamic> _toQueueStatusEntry(Map<String, dynamic> appointment) {
    return {
      'appointment_id': appointment['id'],
      'queue_number': _parseQueueNumber(appointment['queue_number']),
      'patient_name': appointment['patient_name']?.toString() ?? 'Patient',
      'service_type': appointment['service_type']?.toString() ?? 'Service',
      'appointment_time': appointment['time']?.toString() ?? '--:--',
      'status': appointment['status']?.toString() ?? 'Pending',
      'is_called': appointment['is_called'] == true,
    };
  }

  String _formatDisplayTime(String rawTime) {
    final trimmed = rawTime.trim();
    if (trimmed.isEmpty) return '--:--';
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime? _parseApiDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return null;
    }

    return _startOfDay(parsed);
  }

  String _formatLongDate(DateTime date) {
    final month = _monthName(date.month);
    final day = date.day.toString().padLeft(2, '0');
    return '$month $day, ${date.year}';
  }

  String _monthName(int month) {
    const monthNames = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month - 1];
  }
}
