import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';

enum _MasterListFilter { all, approved, cancelled, completed, pending }

enum _MasterListDateFilter {
  all,
  today,
  yesterday,
  thisWeek,
  lastWeek,
  thisMonth,
  pastMonth,
}

class AdminMasterListView extends StatefulWidget {
  const AdminMasterListView({
    super.key,
    required this.appointmentService,
    this.adminDashboardService,
  });

  final AppointmentService appointmentService;
  final AdminDashboardService? adminDashboardService;

  @override
  State<AdminMasterListView> createState() => _AdminMasterListViewState();
}

class _AdminMasterListViewState extends State<AdminMasterListView> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  _MasterListFilter _selectedFilter = _MasterListFilter.all;
  _MasterListDateFilter _selectedDateFilter = _MasterListDateFilter.all;

  @override
  void initState() {
    super.initState();
    _loadMasterList();
  }

  Future<void> _loadMasterList({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (forceRefresh) {
        widget.appointmentService.invalidateAppointmentCaches();
      }

      final appointments = await widget.appointmentService.getAdminMasterList();
      if (!mounted) return;
      setState(() {
        _appointments = appointments;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load master list')),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredAppointments {
    return _appointments.where((appointment) {
      final status = _normalizeStatus(appointment['status']?.toString());
      final matchesStatus = switch (_selectedFilter) {
        _MasterListFilter.approved => status == 'approved',
        _MasterListFilter.cancelled => status == 'cancelled',
        _MasterListFilter.completed => status == 'completed',
        _MasterListFilter.pending => status == 'pending',
        _MasterListFilter.all => true,
      };

      if (!matchesStatus) {
        return false;
      }

      final appointmentDate = _parseAppointmentDate(
        appointment['date']?.toString(),
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      return switch (_selectedDateFilter) {
        _MasterListDateFilter.all => true,
        _MasterListDateFilter.today =>
          appointmentDate != null && _isSameDay(appointmentDate, today),
        _MasterListDateFilter.yesterday =>
          appointmentDate != null &&
          _isSameDay(
            appointmentDate,
            today.subtract(const Duration(days: 1)),
          ),
        _MasterListDateFilter.thisWeek =>
          appointmentDate != null && _isWithinCurrentWeek(appointmentDate, today),
        _MasterListDateFilter.lastWeek =>
          appointmentDate != null && _isWithinLastWeek(appointmentDate, today),
        _MasterListDateFilter.thisMonth =>
          appointmentDate != null &&
          appointmentDate.year == today.year &&
          appointmentDate.month == today.month,
        _MasterListDateFilter.pastMonth =>
          appointmentDate != null &&
          !appointmentDate.isAfter(today) &&
          !appointmentDate.isBefore(today.subtract(const Duration(days: 30))),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAppointments = _filteredAppointments;

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Master List',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading
                    ? null
                    : () => _loadMasterList(forceRefresh: true),
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF679B6A),
                  side: const BorderSide(color: Color(0xFF679B6A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildFilterButton('All', _MasterListFilter.all),
                _buildFilterButton('Pending', _MasterListFilter.pending),
                _buildFilterButton('Approved', _MasterListFilter.approved),
                _buildFilterButton('Completed', _MasterListFilter.completed),
                _buildFilterButton('Cancelled', _MasterListFilter.cancelled),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _buildDateFilterMenu(),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(
                    color: Color(0xFF679B6A), // Dark Green matching sidebar
                    width: 6.0,
                  ),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'All Appointments',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.black12),
                  if (_isLoading)
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF679B6A),
                        ),
                      ),
                    )
                  else if (filteredAppointments.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No appointments found for this filter.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.resolveWith(
                            (states) => Colors.transparent,
                          ),
                          columns: const [
                            DataColumn(
                              label: Text(
                                'Patient',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Service',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Contact',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                          rows: filteredAppointments.map((appointment) {
                            final status =
                                appointment['status']?.toString() ?? 'Unknown';
                            return DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    _displayText(appointment['patient_name']),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _displayText(appointment['service']),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _displayText(appointment['date']),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    _displayText(appointment['contact']),
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: status.toLowerCase() == 'cancelled'
                                          ? Colors.blue[700]
                                          : Colors.black87,
                                      decoration:
                                          status.toLowerCase() == 'cancelled'
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                      decorationColor: Colors.blue[700],
                                    ),
                                  ),
                                ),
                                DataCell(_buildStatusBadge(status)),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status.toLowerCase()) {
      case 'completed':
        backgroundColor = const Color(0xFF81C784); // Light Green
        textColor = const Color(0xFF1B5E20); // Dark Green
        break;
      case 'cancelled':
        backgroundColor = const Color(0xFFE57373); // Light Red
        textColor = const Color(0xFFB71C1C); // Dark Red
        break;
      case 'pending':
        backgroundColor = const Color(0xFFFFD54F); // Light Yellow
        textColor = const Color(0xFFF57F17); // Dark Orange/Yellow
        break;
      case 'approved':
        backgroundColor = const Color(0xFF64B5F6); // Light Blue
        textColor = const Color(0xFF0D47A1); // Dark Blue
        break;
      default:
        backgroundColor = Colors.grey[300]!;
        textColor = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  String _displayText(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'No data yet' : text;
  }

  Widget _buildFilterButton(String label, _MasterListFilter filter) {
    final isSelected = _selectedFilter == filter;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : const Color(0xFF4B5563),
        ),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _selectedFilter = filter;
        });
      },
      selectedColor: const Color(0xFF679B6A),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF679B6A)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildDateFilterMenu() {
    return PopupMenuButton<_MasterListDateFilter>(
      tooltip: 'Date filter',
      onSelected: (_MasterListDateFilter filter) {
        setState(() {
          _selectedDateFilter = filter;
        });
      },
      itemBuilder: (context) => _MasterListDateFilter.values.map((filter) {
        final selected = filter == _selectedDateFilter;
        return PopupMenuItem<_MasterListDateFilter>(
          value: filter,
          child: Row(
            children: [
              if (selected)
                const Icon(Icons.check, size: 18, color: Color(0xFF3F6341))
              else
                const SizedBox(width: 18),
              const SizedBox(width: 10),
              Text(_dateFilterLabel(filter)),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: Color(0xFF3F6341),
            ),
            const SizedBox(width: 10),
            Text(
              _dateFilterLabel(_selectedDateFilter),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF4B5563)),
          ],
        ),
      ),
    );
  }

  String _dateFilterLabel(_MasterListDateFilter filter) {
    return switch (filter) {
      _MasterListDateFilter.all => 'All Dates',
      _MasterListDateFilter.today => 'Today',
      _MasterListDateFilter.yesterday => 'Yesterday',
      _MasterListDateFilter.thisWeek => 'This Week',
      _MasterListDateFilter.lastWeek => 'Last Week',
      _MasterListDateFilter.thisMonth => 'This Month',
      _MasterListDateFilter.pastMonth => 'Past Month',
    };
  }

  DateTime? _parseAppointmentDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return null;
    }

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  bool _isWithinCurrentWeek(DateTime date, DateTime today) {
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return !date.isBefore(startOfWeek) && !date.isAfter(endOfWeek);
  }

  bool _isWithinLastWeek(DateTime date, DateTime today) {
    final startOfCurrentWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfCurrentWeek.subtract(const Duration(days: 7));
    final endOfLastWeek = startOfCurrentWeek.subtract(const Duration(days: 1));

    return !date.isBefore(startOfLastWeek) && !date.isAfter(endOfLastWeek);
  }

  String _normalizeStatus(String? status) {
    final raw = status?.trim().toLowerCase() ?? 'pending';

    if (raw == 'approved' || raw == 'confirmed') {
      return 'approved';
    }

    if (raw == 'cancelled') {
      return 'cancelled';
    }

    if (raw == 'completed') {
      return 'completed';
    }

    return 'pending';
  }
}
