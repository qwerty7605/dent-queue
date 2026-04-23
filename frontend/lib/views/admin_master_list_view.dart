import 'package:flutter/material.dart';

import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/appointment_status_badge.dart';
import '../widgets/paginated_table_footer.dart';

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
  static const int _pageSize = 25;

  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePages = false;
  int _currentPage = 0;
  int _totalAppointments = 0;
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

      final appointmentsPage = await widget.appointmentService
          .getAdminMasterListPage(
            filters: _activeMasterListFilters,
            page: 1,
            perPage: _pageSize,
          );
      if (!mounted) return;
      setState(() {
        _appointments = appointmentsPage.items;
        _currentPage = appointmentsPage.currentPage;
        _totalAppointments = appointmentsPage.totalItems;
        _hasMorePages = appointmentsPage.hasMorePages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load master list')),
      );
    }
  }

  Future<void> _loadMoreMasterList() async {
    if (_isLoading || _isLoadingMore || !_hasMorePages) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final appointmentsPage = await widget.appointmentService
          .getAdminMasterListPage(
            filters: _activeMasterListFilters,
            page: _currentPage + 1,
            perPage: _pageSize,
          );
      if (!mounted) return;

      setState(() {
        _appointments = <Map<String, dynamic>>[
          ..._appointments,
          ...appointmentsPage.items,
        ];
        _currentPage = appointmentsPage.currentPage;
        _totalAppointments = appointmentsPage.totalItems;
        _hasMorePages = appointmentsPage.hasMorePages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load more appointments')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool compactHeader = MediaQuery.sizeOf(context).width < 1100;
    final EdgeInsets pagePadding = MediaQuery.sizeOf(context).width < 900
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);
    final Widget title = const Text(
      'Master List',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
    final Widget action = OutlinedButton.icon(
      onPressed: _isLoading ? null : () => _loadMasterList(forceRefresh: true),
      icon: const Icon(Icons.refresh),
      label: const Text(
        'Refresh',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
    );

    return SingleChildScrollView(
      padding: pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactHeader)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 16), action],
              ),
            )
          else
            Row(
              children: [
                Expanded(child: title),
                action,
              ],
            ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 10),
          Align(alignment: Alignment.centerLeft, child: _buildDateFilterMenu()),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: const Border(
                top: BorderSide(
                  color: Color(0xFF4A769E),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 96),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A769E),
                      ),
                    ),
                  )
                else if (_appointments.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: AppEmptyState(
                      key: const Key('admin-master-list-empty-state'),
                      icon: Icons.list_alt_outlined,
                      title: !_hasActiveFilters
                          ? 'No appointments yet'
                          : 'No appointments found',
                      message: !_hasActiveFilters
                          ? 'Appointments will appear in the master list once records are available.'
                          : 'Try clearing the selected status or date filter to view more appointment records.',
                      actionLabel: _hasActiveFilters ? 'Clear Filters' : null,
                      actionIcon: Icons.restart_alt_rounded,
                      onAction: _hasActiveFilters
                          ? () {
                              _resetFilters();
                            }
                          : null,
                    ),
                  )
                else
                  Column(
                    children: [
                      AdminDataTable(
                              enableVerticalScroll: false,
                              minWidth: 920,
                              columnSpacing: 18,
                              horizontalMargin: 14,
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                12,
                              ),
                              columns: <DataColumn>[
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    '#',
                                    width: 52,
                                    alignment: Alignment.center,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Patient',
                                    width: 200,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Service',
                                    width: 190,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Date',
                                    width: 116,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Contact',
                                    width: 150,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Status',
                                    width: 150,
                                    alignment: Alignment.center,
                                  ),
                                ),
                              ],
                              rows: _appointments.asMap().entries.map((entry) {
                                final int index = entry.key;
                                final Map<String, dynamic> appointment =
                                    entry.value;
                                final String status =
                                    appointment['status']?.toString() ??
                                    'Unknown';
                                final bool isCancelled =
                                    status.toLowerCase() == 'cancelled';

                                return DataRow.byIndex(
                                  index: index,
                                  color: AdminDataTable.rowColor(index),
                                  cells: <DataCell>[
                                    DataCell(
                                      AdminDataTable.cellText(
                                        '${index + 1}',
                                        width: 52,
                                        alignment: Alignment.center,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    DataCell(
                                      AdminDataTable.cellText(
                                        _displayText(
                                          appointment['patient_name'],
                                        ),
                                        width: 200,
                                        maxLines: 2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    DataCell(
                                      AdminDataTable.cellText(
                                        _displayText(appointment['service']),
                                        width: 190,
                                        maxLines: 2,
                                      ),
                                    ),
                                    DataCell(
                                      AdminDataTable.cellText(
                                        _displayText(appointment['date']),
                                        width: 116,
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          _displayText(appointment['contact']),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.35,
                                            fontWeight: FontWeight.w600,
                                            color: isCancelled
                                                ? Colors.blue[700]
                                                : const Color(0xFF334155),
                                            decoration: isCancelled
                                                ? TextDecoration.underline
                                                : TextDecoration.none,
                                            decorationColor: Colors.blue[700],
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Align(
                                          alignment: Alignment.center,
                                          child: AppointmentStatusBadge(
                                            status: status,
                                            compact: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                      ),
                      PaginatedTableFooter(
                        loadedItemCount: _appointments.length,
                        totalItemCount: _totalAppointments,
                        itemLabel: 'appointments',
                        hasMorePages: _hasMorePages,
                        isLoadingMore: _isLoadingMore,
                        onLoadMore: _loadMoreMasterList,
                        loadMoreButtonKey: const Key(
                          'admin-master-list-load-more',
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
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
      onSelected: (bool selected) {
        if (!selected || _selectedFilter == filter) {
          return;
        }

        setState(() {
          _selectedFilter = filter;
        });
        _loadMasterList();
      },
      selectedColor: const Color(0xFF4A769E),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF4A769E)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildDateFilterMenu() {
    return PopupMenuButton<_MasterListDateFilter>(
      tooltip: 'Date filter',
      onSelected: (_MasterListDateFilter filter) {
        if (_selectedDateFilter == filter) {
          return;
        }

        setState(() {
          _selectedDateFilter = filter;
        });
        _loadMasterList();
      },
      itemBuilder: (context) => _MasterListDateFilter.values.map((filter) {
        final selected = filter == _selectedDateFilter;
        return PopupMenuItem<_MasterListDateFilter>(
          value: filter,
          child: Row(
            children: [
              if (selected)
                const Icon(Icons.check, size: 18, color: Color(0xFF1A2F64))
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
              color: Color(0xFF1A2F64),
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

  Future<void> _resetFilters() async {
    setState(() {
      _selectedFilter = _MasterListFilter.all;
      _selectedDateFilter = _MasterListDateFilter.all;
    });

    await _loadMasterList();
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

  bool get _hasActiveFilters {
    return _selectedFilter != _MasterListFilter.all ||
        _selectedDateFilter != _MasterListDateFilter.all;
  }

  Map<String, String> get _activeMasterListFilters {
    final Map<String, String> filters = <String, String>{};
    final String? status = _statusQueryValue(_selectedFilter);

    if (status != null) {
      filters['status'] = status;
    }

    filters.addAll(_dateQueryParameters(_selectedDateFilter));
    return filters;
  }

  String? _statusQueryValue(_MasterListFilter filter) {
    return switch (filter) {
      _MasterListFilter.all => null,
      _MasterListFilter.pending => 'pending',
      _MasterListFilter.approved => 'approved',
      _MasterListFilter.completed => 'completed',
      _MasterListFilter.cancelled => 'cancelled',
    };
  }

  Map<String, String> _dateQueryParameters(_MasterListDateFilter filter) {
    if (filter == _MasterListDateFilter.all) {
      return const <String, String>{};
    }

    final DateTime today = _normalizedToday();
    late final DateTime startDate;
    late final DateTime endDate;

    switch (filter) {
      case _MasterListDateFilter.all:
        return const <String, String>{};
      case _MasterListDateFilter.today:
        startDate = today;
        endDate = today;
        break;
      case _MasterListDateFilter.yesterday:
        startDate = today.subtract(const Duration(days: 1));
        endDate = startDate;
        break;
      case _MasterListDateFilter.thisWeek:
        startDate = _startOfWeek(today);
        endDate = startDate.add(const Duration(days: 6));
        break;
      case _MasterListDateFilter.lastWeek:
        endDate = _startOfWeek(today).subtract(const Duration(days: 1));
        startDate = endDate.subtract(const Duration(days: 6));
        break;
      case _MasterListDateFilter.thisMonth:
        startDate = DateTime(today.year, today.month, 1);
        endDate = DateTime(today.year, today.month + 1, 0);
        break;
      case _MasterListDateFilter.pastMonth:
        startDate = today.subtract(const Duration(days: 30));
        endDate = today;
        break;
    }

    return <String, String>{
      'start_date': _formatDateQueryValue(startDate),
      'end_date': _formatDateQueryValue(endDate),
    };
  }

  DateTime _normalizedToday() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfWeek(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _formatDateQueryValue(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
