import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/appointment_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/staff_appointment_details_dialog.dart';

class StaffCalendarView extends StatefulWidget {
  const StaffCalendarView({super.key, required this.appointmentService});

  final AppointmentService appointmentService;

  @override
  State<StaffCalendarView> createState() => _StaffCalendarViewState();
}

class _StaffCalendarViewState extends State<StaffCalendarView> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  bool _isLoading = false;
  int? _loadingAppointmentId;
  List<Map<String, dynamic>> _dayAppointments = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadAppointmentsForDate(_selectedDate);
  }

  Future<void> _loadAppointmentsForDate(DateTime date) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final formattedDate =
          "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final appointments = await widget.appointmentService
          .getAdminCalendarAppointments(formattedDate);
      if (mounted) {
        setState(() {
          _dayAppointments = appointments;
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _isLoading = false;
          _dayAppointments = [];
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load appointments.";
          _isLoading = false;
          _dayAppointments = [];
        });
      }
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  Future<void> _openAppointmentDetails(Map<String, dynamic> appointment) async {
    final appointmentId = _parseAppointmentId(appointment['id']);
    if (appointmentId == null) {
      _showMessage('Unable to open appointment details.');
      return;
    }

    setState(() {
      _loadingAppointmentId = appointmentId;
    });

    try {
      final details = await widget.appointmentService
          .getAdminCalendarAppointmentDetails(appointmentId);
      if (!mounted) return;

      final payload = <String, dynamic>{...appointment, ...details};

      await showDialog<void>(
        context: context,
        builder: (_) => StaffAppointmentDetailsDialog(
          appointment: payload,
          showStatusActions: false,
        ),
      );
    } on ApiException catch (e) {
      _showMessage(e.message);
    } catch (_) {
      _showMessage('Unable to load appointment details right now.');
    } finally {
      if (mounted) {
        setState(() {
          _loadingAppointmentId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  _buildPageTitle(),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1A2F64,
                            ).withValues(alpha: 0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
                      child: Column(
                        children: [
                          _buildCalendarHeader(),
                          const SizedBox(height: 22),
                          _buildDaysOfWeek(),
                          const SizedBox(height: 12),
                          _buildCalendarGrid(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _buildScheduleSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPageTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFF1A2F64),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Calendar',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A2F64),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'MANAGE APPOINTMENTS BY DATE',
                  style: TextStyle(
                    color: Color(0xFFA0AABF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarHeader() {
    final monthName = _getMonthName(_currentMonth.month);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '$monthName ${_currentMonth.year}',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A2F64),
          ),
        ),
        Row(
          children: [
            _buildNavButton(Icons.chevron_left, _previousMonth),
            const SizedBox(width: 8),
            _buildNavButton(Icons.chevron_right, _nextMonth),
          ],
        ),
      ],
    );
  }

  Widget _buildNavButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFF0F3F8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFFB5BFCE), size: 20),
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['SU', 'MO', 'TU', 'WE', 'TH', 'FR', 'SA'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (day) => Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Color(0xFFD1D6E0),
                fontSize: 12,
                letterSpacing: 1.1,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final firstDayOffset =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;

    final List<Widget> dayWidgets = [];
    final DateTime today = DateTime.now();

    for (int i = 0; i < firstDayOffset; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelected =
          _selectedDate.year == date.year &&
          _selectedDate.month == date.month &&
          _selectedDate.day == date.day;
      final isToday =
          today.year == date.year &&
          today.month == date.month &&
          today.day == date.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
            _loadAppointmentsForDate(date);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF233D78) : Colors.transparent,
              shape: BoxShape.circle,
              border: !isSelected && isToday
                  ? Border.all(color: const Color(0xFFD8DDE8), width: 2)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF233D78).withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  day.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : const Color(0xFF66758F),
                    fontSize: 14,
                  ),
                ),
                if (!isSelected && day % 6 == 0)
                  const Positioned(
                    bottom: 5,
                    child: Icon(
                      Icons.circle,
                      size: 4,
                      color: Color(0xFFB6BFCE),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 7,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.95,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  Widget _buildScheduleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF233D78),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Schedule for ${_formatScheduleDate(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF243B53),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            )
          else if (_dayAppointments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: AppEmptyState(
                  key: Key('staff-calendar-empty-state'),
                  icon: Icons.event_busy_outlined,
                  title: 'No appointments for this day',
                  message:
                      'Booked appointments for the selected date will appear here.',
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _dayAppointments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final appt = _dayAppointments[index];
                return _buildAppointmentListItem(appt);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentListItem(Map<String, dynamic> appointment) {
    final appointmentId = _parseAppointmentId(appointment['id']);
    final isOpening =
        appointmentId != null && _loadingAppointmentId == appointmentId;
    final patientName = appointment['patient_name'] ?? 'Unknown Patient';
    final serviceType = appointment['service_type'] ?? 'General Service';
    final time = _formatAppointmentTime(
      appointment['appointment_time'] ??
          appointment['time'] ??
          appointment['time_slot'],
    );
    final parts = time.split(' ');
    final timeLabel = parts.isNotEmpty ? parts.first : time;
    final meridiem = parts.length > 1 ? parts.last : '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: isOpening ? null : () => _openAppointmentDetails(appointment),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF233D78),
                      ),
                    ),
                    if (meridiem.isNotEmpty)
                      Text(
                        meridiem,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: Color(0xFFA0AABF),
                        ),
                      ),
                  ],
                ),
              ),
              Container(width: 1, height: 46, color: const Color(0xFFF0F3F8)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            patientName.toString(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: Color(0xFF243B53),
                            ),
                          ),
                        ),
                        if (!isOpening)
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF08B1D),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      serviceType.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7B8794),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (isOpening)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFD2D8E5),
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
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

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatScheduleDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    return '${_getMonthName(date.month)} $day, ${date.year}';
  }

  String _formatAppointmentTime(dynamic rawValue) {
    final raw = rawValue?.toString().trim() ?? '';
    if (raw.isEmpty) {
      return '--:--';
    }

    final normalized = raw.toUpperCase();
    if (normalized.endsWith('AM') || normalized.endsWith('PM')) {
      return normalized.replaceAll(RegExp(r'\s+'), ' ');
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2})?$').firstMatch(raw);
    if (match == null) {
      return raw;
    }

    final hour = int.tryParse(match.group(1) ?? '');
    final minute = match.group(2);
    if (hour == null || minute == null) {
      return raw;
    }

    final suffix = hour >= 12 ? 'PM' : 'AM';
    final normalizedHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$normalizedHour:${minute.padLeft(2, '0')} $suffix';
  }

  String _getMonthName(int month) {
    const months = [
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
    return months[month - 1];
  }
}
