import 'package:flutter/material.dart';
import '../services/appointment_service.dart';
import '../core/api_exception.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'CALENDAR',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              children: [
                _buildCalendarHeader(),
                const SizedBox(height: 14),
                _buildDaysOfWeek(),
                const SizedBox(height: 6),
                _buildCalendarGrid(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildScheduleSection()),
      ],
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
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
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
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: const Color(0xFF64748B), size: 24),
      ),
    );
  }

  Widget _buildDaysOfWeek() {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: days
          .map(
            (day) => Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                fontSize: 14,
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

    // Empty boxes for first day offset
    for (int i = 0; i < firstDayOffset; i++) {
      dayWidgets.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final isSelected =
          _selectedDate.year == date.year &&
          _selectedDate.month == date.month &&
          _selectedDate.day == date.day;

      dayWidgets.add(
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedDate = date;
            });
            _loadAppointmentsForDate(date);
          },
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF679B6A) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF679B6A).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              day.toString(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 7,
      mainAxisSpacing: 6,
      crossAxisSpacing: 6,
      childAspectRatio: 1.18,
      physics: const NeverScrollableScrollPhysics(),
      children: dayWidgets,
    );
  }

  Widget _buildScheduleSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF7DA97F),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Schedule for ${_formatScheduleDate(_selectedDate)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF243B53),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: Center(
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFB91C1C)),
                ),
              ),
            )
          else if (_dayAppointments.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'No appointments for this day.',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _dayAppointments.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final appt = _dayAppointments[index];
                  return _buildAppointmentListItem(appt);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppointmentListItem(Map<String, dynamic> appointment) {
    final patientName = appointment['patient_name'] ?? 'Unknown Patient';
    final serviceType = appointment['service_type'] ?? 'General Service';
    final time = _formatAppointmentTime(
      appointment['appointment_time'] ??
          appointment['time'] ??
          appointment['time_slot'],
    );
    final status = _normalizeStatusLabel(
      appointment['status']?.toString() ?? 'pending',
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF7DA97F),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF243B53),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceType.toString().toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7B8794),
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          _buildStatusBadge(status),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'approved':
      case 'confirmed':
        return const Color(0xFF1D4ED8);
      case 'completed':
        return const Color(0xFF16A34A);
      case 'cancelled':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF97316);
    }
  }

  Widget _buildStatusBadge(String status) {
    final statusKey = status.toLowerCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(statusKey).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _getStatusColor(statusKey),
        ),
      ),
    );
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
    return '$normalizedHour:$minute $suffix';
  }

  String _normalizeStatusLabel(String rawStatus) {
    final normalized = rawStatus.trim().toLowerCase();
    switch (normalized) {
      case 'confirmed':
      case 'approved':
        return 'Approved';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return normalized.isEmpty
            ? 'Pending'
            : '${normalized[0].toUpperCase()}${normalized.substring(1)}';
    }
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
