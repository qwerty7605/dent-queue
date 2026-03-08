import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import '../widgets/staff_appointment_details_dialog.dart';

enum _StaffTab { appointments, walkIn, records, calendar }

enum _StaffFilter { all, pending, approved, completed, cancelled }

class StaffDashboardView extends StatefulWidget {
  const StaffDashboardView({
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
  State<StaffDashboardView> createState() => _StaffDashboardViewState();
}

class _StaffDashboardViewState extends State<StaffDashboardView> {
  final TextEditingController _searchController = TextEditingController();
  late final AppointmentService _appointmentService;

  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  _StaffTab _selectedTab = _StaffTab.appointments;
  _StaffFilter _selectedFilter = _StaffFilter.all;

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppointments = true;
  String? _appointmentsLoadError;
  final int _profileImageVersion = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _appointmentService = AppointmentService(
      BaseService(ApiClient(tokenStorage: widget.tokenStorage)),
    );
    _loadAppointmentsForSelectedDate();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointmentsForSelectedDate({
    bool showLoader = true,
  }) async {
    final date = _formatApiDate(_selectedDate);

    if (showLoader) {
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
      final list = await _appointmentService.getAdminAppointmentsByDate(date);
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _isLoadingAppointments = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _appointments = [];
        _isLoadingAppointments = false;
        _appointmentsLoadError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _appointments = [];
        _isLoadingAppointments = false;
        _appointmentsLoadError =
            'Unable to load daily queue for $date. Please try again.';
      });
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
      _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    });
    await _loadAppointmentsForSelectedDate();
  }

  void _changeCalendarMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + delta,
        1,
      );
      final maxDay = DateUtils.getDaysInMonth(
        _visibleMonth.year,
        _visibleMonth.month,
      );
      final clampedDay = _selectedDate.day > maxDay
          ? maxDay
          : _selectedDate.day;
      _selectedDate = DateTime(
        _visibleMonth.year,
        _visibleMonth.month,
        clampedDay,
      );
    });
    _loadAppointmentsForSelectedDate();
  }

  void _openAppointmentDetails(Map<String, dynamic> appointment) {
    showDialog<void>(
      context: context,
      builder: (_) => StaffAppointmentDetailsDialog(appointment: appointment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userInfo = widget.userInfo;
    final name = _resolveDisplayName(userInfo);
    final profilePicture = _normalizeProfilePicture(
      userInfo?['profile_picture'],
    );
    final profileImageUrl = _buildProfileImageUrl(profilePicture);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5ED),
      appBar: _buildAppBar(name, profileImageUrl),
      drawer: _buildDrawer(name, profileImageUrl),
      body: SafeArea(
        child: switch (_selectedTab) {
          _StaffTab.appointments => _buildAppointmentsTab(),
          _StaffTab.walkIn => _buildPlaceholderTab(
            title: 'WALK-IN',
            subtitle: 'Walk-in registration module goes here.',
            icon: Icons.directions_walk,
          ),
          _StaffTab.records => _buildPlaceholderTab(
            title: 'RECORDS',
            subtitle: 'Patient records module goes here.',
            icon: Icons.search,
          ),
          _StaffTab.calendar => _buildCalendarTab(),
        },
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  PreferredSizeWidget _buildAppBar(String name, String? profileImageUrl) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final chipWidth = screenWidth < 390 ? 130.0 : 160.0;

    return AppBar(
      backgroundColor: const Color(0xFF679B6A),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.black, size: 24),
      titleSpacing: -8,
      title: Row(
        children: [
          Image.asset('assets/images/logo.png', width: 38, height: 38),
          const SizedBox(width: 4),
          const Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'SMART',
                    style: TextStyle(
                      color: Color(0xFFE8C355),
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
        Padding(
          padding: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
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
                        const Text(
                          'STAFF',
                          style: TextStyle(
                            color: Color(0xFFE8C355),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
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
                        ? const Icon(Icons.person, color: Colors.grey, size: 18)
                        : null,
                  ),
                ],
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF679B6A),
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
                  const SizedBox(width: 12),
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
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'STAFF ACCOUNT',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
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
            _buildDrawerItem(
              icon: Icons.directions_walk,
              title: 'Walk In',
              selected: _selectedTab == _StaffTab.walkIn,
              onTap: () {
                setState(() {
                  _selectedTab = _StaffTab.walkIn;
                });
                Navigator.pop(context);
              },
            ),
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
        color: selected ? const Color(0xFF679B6A) : const Color(0xFF64748B),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selected ? const Color(0xFF679B6A) : const Color(0xFF64748B),
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }

  Widget _buildAppointmentsTab() {
    final visibleAppointments = _computeVisibleAppointments();

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 440 ? 14.0 : 22.0;
        final maxWidth = constraints.maxWidth > 1024 ? 920.0 : double.infinity;

        return SingleChildScrollView(
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
                  const Center(
                    child: Text(
                      'STAFF DASHBOARD',
                      style: TextStyle(
                        fontSize: 28,
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
        );
      },
    );
  }

  Widget _buildCalendarTab() {
    final selectedDateKey = _formatApiDate(_selectedDate);
    final schedules =
        _appointments
            .where(
              (appointment) =>
                  appointment['appointment_date'] == selectedDateKey,
            )
            .toList()
          ..sort(
            (a, b) => _timeToMinutes(
              a['time']?.toString() ?? '',
            ).compareTo(_timeToMinutes(b['time']?.toString() ?? '')),
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 440 ? 14.0 : 22.0;
        final maxWidth = constraints.maxWidth > 1024 ? 920.0 : 560.0;

        return SingleChildScrollView(
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
                  const Center(
                    child: Text(
                      'CALENDAR',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                                style: const TextStyle(
                                  color: Color(0xFF1E293B),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            _buildMonthArrow(Icons.chevron_left, () {
                              _changeCalendarMonth(-1);
                            }),
                            const SizedBox(width: 8),
                            _buildMonthArrow(Icons.chevron_right, () {
                              _changeCalendarMonth(1);
                            }),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'M',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'T',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'W',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'T',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'F',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildCalendarGrid(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        size: 18,
                        color: Color(0xFF7DA980),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Schedule for ${_formatLongDate(_selectedDate)}',
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (schedules.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'No schedule for selected date.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: schedules.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        return _buildScheduleCard(schedules[index]);
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthArrow(IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final firstWeekday = firstDay.weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final totalCells = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final dayNumber = index - firstWeekday + 1;
        if (dayNumber < 1 || dayNumber > daysInMonth) {
          return const SizedBox.shrink();
        }

        final date = DateTime(
          _visibleMonth.year,
          _visibleMonth.month,
          dayNumber,
        );
        final isSelected = _isSameDate(date, _selectedDate);
        final isToday = _isSameDate(date, DateTime.now());

        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
            _loadAppointmentsForSelectedDate();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF679B6A) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: const Color(0xFF679B6A), width: 1.2)
                  : null,
            ),
            child: Center(
              child: Text(
                '$dayNumber',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> appointment) {
    final patientName = appointment['patient_name']?.toString() ?? 'Patient';
    final serviceType = appointment['service_type']?.toString() ?? 'Service';
    final status = _normalizeStatus(appointment['status']);
    final timeRaw = appointment['time']?.toString() ?? '--:--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              _formatAmPmTime(timeRaw),
              style: const TextStyle(
                color: Color(0xFF679B6A),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceType.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _scheduleBadgeBackground(status),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                color: _scheduleBadgeForeground(status),
                fontWeight: FontWeight.w900,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth > 900 ? 900 : double.infinity,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 36,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(icon, size: 36, color: const Color(0xFF679B6A)),
                    const SizedBox(height: 10),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
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
            borderSide: const BorderSide(color: Color(0xFF679B6A), width: 1.3),
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
      child: Row(
        children: [
          const Icon(
            Icons.format_list_numbered,
            size: 18,
            color: Color(0xFF679B6A),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Daily Queue - ${_formatLongDate(_selectedDate)}',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            color: const Color(0xFF679B6A),
            tooltip: 'Select date',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: _isLoadingAppointments
                ? null
                : () => _loadAppointmentsForSelectedDate(),
            icon: const Icon(Icons.refresh, size: 18),
            color: const Color(0xFF679B6A),
            tooltip: 'Refresh daily queue',
            visualDensity: VisualDensity.compact,
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
              backgroundColor: const Color(0xFF679B6A),
              foregroundColor: Colors.white,
              minimumSize: const Size(116, 36),
            ),
          ),
        ],
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
          color: selected ? const Color(0xFF679B6A) : const Color(0xFFECEDEA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF6B7280),
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Column(
        children: [
          Icon(Icons.list_alt_outlined, size: 36, color: Color(0xFF94A3B8)),
          SizedBox(height: 10),
          Text(
            'No appointments in queue for this day',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Try a different status filter or search keyword.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
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
    final status = _normalizeStatus(appointment['status']);
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
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceType,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
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
                                style: const TextStyle(
                                  fontSize: 10,
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
                                style: const TextStyle(
                                  fontSize: 10,
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
                        const Text(
                          'QUEUE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF94A3B8),
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          '#$queueNumber',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF679B6A),
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                    bottomRight: Radius.circular(10),
                  ),
                  border: Border(top: BorderSide(color: Color(0xFFD8DEE8))),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: Text(
                    _statusLabel(status),
                    style: TextStyle(
                      color: _statusColor(status),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'approved' => const Color(0xFF1D4ED8),
      'completed' => const Color(0xFF16A34A),
      'cancelled' => const Color(0xFFDC2626),
      _ => const Color(0xFFF97316),
    };
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
              icon: Icons.directions_walk,
              label: 'Walk In',
              tab: _StaffTab.walkIn,
            ),
            _buildNavItem(
              icon: Icons.search,
              label: 'Records',
              tab: _StaffTab.records,
            ),
            _buildNavItem(
              icon: Icons.calendar_today_outlined,
              label: 'Calendar',
              tab: _StaffTab.calendar,
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
    final color = selected ? const Color(0xFF679B6A) : const Color(0xFF94A3B8);

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
    return _appointments
        .where((a) => _normalizeStatus(a['status']) == key)
        .length;
  }

  List<Map<String, dynamic>> _computeVisibleAppointments() {
    final query = _searchController.text.trim().toLowerCase();

    final filtered = _appointments.where((appointment) {
      final status = _normalizeStatus(appointment['status']);
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

    filtered.sort((a, b) {
      final queueA = _parseQueueNumber(a['queue_number']);
      final queueB = _parseQueueNumber(b['queue_number']);
      return queueA.compareTo(queueB);
    });

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

  int _timeToMinutes(String rawTime) {
    final parts = rawTime.split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour * 60) + minute;
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _normalizeStatus(dynamic value) {
    final raw = value?.toString().toLowerCase().trim() ?? '';
    if (raw == 'approved' || raw == 'confirmed') {
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

  String _statusLabel(String status) {
    return switch (status) {
      'approved' => 'APPROVED',
      'completed' => 'COMPLETED',
      'cancelled' => 'CANCELLED',
      _ => 'PENDING',
    };
  }

  Color _scheduleBadgeBackground(String status) {
    return switch (status) {
      'approved' => const Color(0xFFE8F1FF),
      'completed' => const Color(0xFFEAF8EE),
      'cancelled' => const Color(0xFFFFE9E9),
      _ => const Color(0xFFFFF7DF),
    };
  }

  Color _scheduleBadgeForeground(String status) {
    return switch (status) {
      'approved' => const Color(0xFF1D4ED8),
      'completed' => const Color(0xFF16A34A),
      'cancelled' => const Color(0xFFDC2626),
      _ => const Color(0xFFD0A100),
    };
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
    if (userInfo == null) return 'Staff';

    final direct = userInfo['name']?.toString().trim() ?? '';
    if (direct.isNotEmpty) return direct;

    final parts = [
      userInfo['first_name']?.toString().trim() ?? '',
      userInfo['middle_name']?.toString().trim() ?? '',
      userInfo['last_name']?.toString().trim() ?? '',
    ].where((part) => part.isNotEmpty).toList();

    if (parts.isEmpty) return 'Staff';
    return parts.join(' ');
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

  String _formatDisplayTime(String rawTime) {
    final trimmed = rawTime.trim();
    if (trimmed.isEmpty) return '--:--';
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatAmPmTime(String rawTime) {
    final trimmed = rawTime.trim();
    if (trimmed.isEmpty) return '--:--';
    final parts = trimmed.split(':');
    if (parts.length < 2) return trimmed;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts[1].padLeft(2, '0');
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final suffix = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:$minute $suffix';
  }

  String _formatApiDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
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
