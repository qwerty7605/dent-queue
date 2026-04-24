import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/appointment_status.dart';
import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';
import '../widgets/app_empty_state.dart';

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
  static const int _pageSize = 5;
  static const Color _surface = Colors.white;
  static const Color _outline = Color(0xFFE3EAF6);
  static const Color _text = Color(0xFF1D3264);
  static const Color _muted = Color(0xFF667792);
  static const Color _navy = Color(0xFF21396E);

  Color _surfaceColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF141C2E)
      : _surface;
  Color _surfaceAltColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF182132)
      : const Color(0xFFF7F9FD);
  Color _outlineColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2B3956)
      : _outline;
  Color _textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFEAF1FF)
      : _text;
  Color _mutedTextColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFAAB8D4)
      : _muted;

  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _appointments = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isSearching = false;
  int _currentPage = 1;
  int _totalAppointments = 0;
  String _activeQuery = '';
  _MasterListFilter _selectedFilter = _MasterListFilter.all;
  _MasterListDateFilter _selectedDateFilter = _MasterListDateFilter.all;

  @override
  void initState() {
    super.initState();
    _loadMasterList();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterList({
    bool forceRefresh = false,
    int page = 1,
    String? query,
  }) async {
    final String normalizedQuery = (query ?? _activeQuery).trim();

    setState(() {
      _isLoading = normalizedQuery.isEmpty;
      _isSearching = normalizedQuery.isNotEmpty;
      _activeQuery = normalizedQuery;
    });

    try {
      if (forceRefresh) {
        widget.appointmentService.invalidateAppointmentCaches();
      }

      if (normalizedQuery.isNotEmpty) {
        final List<Map<String, dynamic>> allAppointments = await widget
            .appointmentService
            .getAdminMasterList(_activeMasterListFilters);
        final List<Map<String, dynamic>> filtered = allAppointments.where((
          Map<String, dynamic> appointment,
        ) {
          final String haystack = <String>[
            appointment['patient_name']?.toString() ?? '',
            appointment['service']?.toString() ?? '',
            appointment['service_type']?.toString() ?? '',
            appointment['contact']?.toString() ?? '',
            appointment['appointment_id']?.toString() ?? '',
            appointment['queue_number']?.toString() ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(normalizedQuery.toLowerCase());
        }).toList();

        final int start = (page - 1) * _pageSize;
        final int end = (start + _pageSize).clamp(0, filtered.length);
        final List<Map<String, dynamic>> visible = start >= filtered.length
            ? <Map<String, dynamic>>[]
            : filtered.sublist(start, end);

        if (!mounted) {
          return;
        }
        setState(() {
          _appointments = visible;
          _currentPage = page;
          _totalAppointments = filtered.length;
          _isLoading = false;
          _isSearching = false;
        });
        return;
      }

      final appointmentsPage = await widget.appointmentService
          .getAdminMasterListPage(
            filters: _activeMasterListFilters,
            page: page,
            perPage: _pageSize,
          );
      if (!mounted) {
        return;
      }

      setState(() {
        _appointments = appointmentsPage.items;
        _currentPage = appointmentsPage.currentPage;
        _totalAppointments = appointmentsPage.totalItems;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load master list')),
      );
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadMasterList(page: 1, query: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final EdgeInsets pagePadding = EdgeInsets.fromLTRB(
      width < 900 ? 16 : 24,
      22,
      width < 900 ? 16 : 24,
      28,
    );

    return RefreshIndicator(
      onRefresh: () => _loadMasterList(
        forceRefresh: true,
        page: _currentPage,
        query: _activeQuery,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildFilterRow(),
            const SizedBox(height: 22),
            _buildSearchBar(),
            const SizedBox(height: 22),
            _buildMasterListSheet(),
            const SizedBox(height: 18),
            _buildPaginationFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget filters = Wrap(
          spacing: 14,
          runSpacing: 14,
          children: <Widget>[
            _buildFilterButton('ALL', _MasterListFilter.all),
            _buildFilterButton('PENDING', _MasterListFilter.pending),
            _buildFilterButton('APPROVED', _MasterListFilter.approved),
            _buildFilterButton('COMPLETED', _MasterListFilter.completed),
            _buildFilterButton('CANCELLED', _MasterListFilter.cancelled),
          ],
        );

        final Widget dateMenu = _buildDateFilterMenu();

        if (constraints.maxWidth < 1180) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[filters, const SizedBox(height: 14), dateMenu],
          );
        }

        return Row(
          children: <Widget>[
            Expanded(child: filters),
            const SizedBox(width: 16),
            dateMenu,
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: _surfaceColor(context),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _outlineColor(context)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x080E1A3A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.search_rounded,
              color: _mutedTextColor(context),
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _handleSearchChanged,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _textColor(context),
                ),
                decoration: InputDecoration(
                  hintText:
                      'Search records by patient identity, ID or service procedure...',
                  hintStyle: TextStyle(
                    color: _mutedTextColor(context).withValues(alpha: 0.8),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_searchController.text.trim().isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  _loadMasterList(page: 1, query: '');
                },
                icon: Icon(
                  Icons.close_rounded,
                  color: _mutedTextColor(context),
                  size: 18,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                splashRadius: 16,
                tooltip: 'Clear search',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMasterListSheet() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: _outlineColor(context)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080E1A3A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: _MasterListHeaderRow(),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: _surfaceAltColor(context),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _outlineColor(context)),
            ),
            child: _isLoading
                ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 96),
                        child: Center(
                          child: CircularProgressIndicator(color: _navy),
                        ),
                      )
                    : _appointments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(28),
                        child: AppEmptyState(
                          key: const Key('admin-master-list-empty-state'),
                          icon: Icons.list_alt_outlined,
                          title: !_hasActiveFilters && _activeQuery.isEmpty
                              ? 'No appointments yet'
                              : 'No appointments found',
                          message: _activeQuery.isNotEmpty
                              ? 'No appointment records matched your search. Try a different patient, ID, or service.'
                              : !_hasActiveFilters
                              ? 'Appointments will appear in the master list once records are available.'
                              : 'Try clearing the selected status or date filter to view more appointment records.',
                          actionLabel:
                              _hasActiveFilters || _activeQuery.isNotEmpty
                              ? 'Clear Filters'
                              : null,
                          actionIcon: Icons.restart_alt_rounded,
                          onAction: _hasActiveFilters || _activeQuery.isNotEmpty
                              ? () {
                                  _searchController.clear();
                                  _resetFilters();
                                }
                              : null,
                        ),
                      )
                    : Column(
                        children: List<Widget>.generate(_appointments.length, (
                          int index,
                        ) {
                          final Map<String, dynamic> appointment =
                              _appointments[index];
                          return Column(
                            children: <Widget>[
                              if (index > 0)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: _outlineColor(context).withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                              _MasterListRow(appointment: appointment),
                            ],
                          );
                        }),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter() {
    final int totalPages = ((_totalAppointments + _pageSize - 1) / _pageSize)
        .floor();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'MASTER LIST OVERVIEW',
              style: TextStyle(
                color: _mutedTextColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activeQuery.isNotEmpty
                  ? 'Showing ${_appointments.length} of $_totalAppointments matching records'
                  : 'Displaying ${_rangeStart()}-${_rangeEnd()} of $_totalAppointments appointment records',
              style: TextStyle(
                color: _textColor(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );

        final Widget pagination = totalPages > 0
            ? Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _PageNavButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _currentPage > 1,
                    onTap: () => _loadMasterList(
                      page: _currentPage - 1,
                      query: _activeQuery,
                    ),
                  ),
                  ..._visiblePages(totalPages).map((int page) {
                    final bool active = page == _currentPage;
                    return _PageNumberButton(
                      label: page.toString(),
                      active: active,
                      onTap: () =>
                          _loadMasterList(page: page, query: _activeQuery),
                    );
                  }),
                  _PageNavButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _currentPage < totalPages,
                    onTap: () => _loadMasterList(
                      page: _currentPage + 1,
                      query: _activeQuery,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink();

        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[summary, const SizedBox(height: 16), pagination],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: summary),
            pagination,
          ],
        );
      },
    );
  }

  Widget _buildFilterButton(String label, _MasterListFilter filter) {
    final bool isSelected = _selectedFilter == filter;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedFilter == filter) {
            return;
          }
          setState(() {
            _selectedFilter = filter;
          });
          _loadMasterList(page: 1, query: _activeQuery);
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? _navy
                : _surfaceAltColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? _navy
                  : _outlineColor(context),
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x080E1A3A),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : _mutedTextColor(context),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
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
        _loadMasterList(page: 1, query: _activeQuery);
      },
      itemBuilder: (BuildContext context) {
        return _MasterListDateFilter.values.map((filter) {
          final bool selected = filter == _selectedDateFilter;
          return PopupMenuItem<_MasterListDateFilter>(
            value: filter,
            child: Row(
              children: <Widget>[
                if (selected)
                  const Icon(Icons.check, size: 18, color: _navy)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 10),
                Text(
                  _dateFilterLabel(filter),
                  style: TextStyle(color: _textColor(context)),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          color: _surfaceAltColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _outlineColor(context)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x080E1A3A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: _mutedTextColor(context),
            ),
            const SizedBox(width: 12),
            Text(
              _dateFilterLabel(_selectedDateFilter).toUpperCase(),
              style: TextStyle(
                color: _textColor(context),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.expand_more_rounded, color: _textColor(context)),
          ],
        ),
      ),
    );
  }

  Future<void> _resetFilters() async {
    setState(() {
      _selectedFilter = _MasterListFilter.all;
      _selectedDateFilter = _MasterListDateFilter.all;
      _activeQuery = '';
    });

    await _loadMasterList(page: 1, query: '');
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

  List<int> _visiblePages(int totalPages) {
    if (totalPages <= 4) {
      return List<int>.generate(totalPages, (int index) => index + 1);
    }
    if (_currentPage <= 2) {
      return <int>[1, 2, 3, 4];
    }
    if (_currentPage >= totalPages - 1) {
      return <int>[totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
    }
    return <int>[
      _currentPage - 1,
      _currentPage,
      _currentPage + 1,
      _currentPage + 2,
    ];
  }

  int _rangeStart() {
    if (_totalAppointments == 0) {
      return 0;
    }
    return ((_currentPage - 1) * _pageSize) + 1;
  }

  int _rangeEnd() {
    if (_totalAppointments == 0) {
      return 0;
    }
    return (_rangeStart() + _appointments.length - 1).clamp(
      0,
      _totalAppointments,
    );
  }
}

class _MasterListHeaderRow extends StatelessWidget {
  const _MasterListHeaderRow();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final TextStyle style = TextStyle(
      color: isDark
          ? const Color(0xFFAAB8D4)
          : _AdminMasterListViewState._muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    );

    return Row(
      children: <Widget>[
        Expanded(flex: 4, child: Text('PATIENT', style: style)),
        Expanded(flex: 4, child: Text('SERVICE / PROCEDURE', style: style)),
        Expanded(flex: 2, child: Text('SCHEDULE', style: style)),
        Expanded(flex: 2, child: Text('CONTACT', style: style)),
        Expanded(
          flex: 2,
          child: Text('STATUS', style: style, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _MasterListRow extends StatelessWidget {
  const _MasterListRow({required this.appointment});

  final Map<String, dynamic> appointment;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark
        ? const Color(0xFFEAF1FF)
        : _AdminMasterListViewState._text;
    final Color mutedColor = isDark
        ? const Color(0xFFAAB8D4)
        : _AdminMasterListViewState._muted;
    final Color pillColor = isDark
        ? const Color(0xFF1A253A)
        : const Color(0xFFF5F7FC);
    final Color pillTextColor = isDark
        ? const Color(0xFFD7E4FF)
        : const Color(0xFF475975);
    final Color avatarColor = isDark
        ? const Color(0xFF22314B)
        : const Color(0xFFF3F6FB);
    final Color avatarTextColor = isDark
        ? const Color(0xFFEAF1FF)
        : _AdminMasterListViewState._text;
    final String patientName =
        appointment['patient_name']?.toString().trim().isNotEmpty == true
        ? appointment['patient_name'].toString().trim()
        : 'No data yet';
    final String queueLabel =
        appointment['queue_number']?.toString().trim().isNotEmpty == true &&
            appointment['queue_number']?.toString() != '-'
        ? 'APT-${appointment['queue_number']}'
        : 'APT-${appointment['appointment_id'] ?? '--'}';
    final String initials = _initialsFromName(patientName);
    final AppointmentStatusVisual visual = appointmentStatusVisual(
      appointment['status'],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: avatarColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: avatarTextColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        patientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        queueLabel,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2B3956)
                        : const Color(0xFFE3EAF6),
                  ),
                ),
                child: Text(
                  (appointment['service']?.toString() ??
                          appointment['service_type']?.toString() ??
                          'Unknown Service')
                      .toUpperCase(),
                  style: TextStyle(
                    color: pillTextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _formatAppointmentDate(
                    appointment['appointment_date'] ?? appointment['date'],
                  ),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatAppointmentTime(appointment['appointment_time']),
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2B3956)
                        : const Color(0xFFE3EAF6),
                  ),
                ),
                child: Text(
                  appointment['contact']?.toString() ?? 'No data yet',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A253A)
                      : visual.backgroundColor,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF2B3956)
                        : visual.borderColor,
                  ),
                ),
                child: Text(
                  visual.label.toUpperCase(),
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFD7E4FF)
                        : visual.foregroundColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _initialsFromName(String name) {
    final List<String> parts = name
        .split(RegExp(r'\s+'))
        .where((String part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '--';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}

class _PageNavButton extends StatelessWidget {
  const _PageNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 46,
          height: 42,
          decoration: BoxDecoration(
            color: enabled
                ? (isDark ? const Color(0xFF1A253A) : Colors.white)
                : (isDark ? const Color(0xFF162033) : const Color(0xFFF7F8FC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2B3956)
                  : const Color(0xFFE3EAF6),
            ),
          ),
          child: Icon(
            icon,
            color: enabled
                ? (isDark
                      ? const Color(0xFFD7E4FF)
                      : _AdminMasterListViewState._muted)
                : (isDark
                      ? const Color(0xFF5D6C8B)
                      : const Color(0xFFD4DCEA)),
          ),
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 46,
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? _AdminMasterListViewState._navy
                : (isDark ? const Color(0xFF1A253A) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? _AdminMasterListViewState._navy
                  : (isDark
                        ? const Color(0xFF2B3956)
                        : const Color(0xFFE3EAF6)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFFD7E4FF)
                          : _AdminMasterListViewState._muted),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatAppointmentDate(dynamic value) {
  final String raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return 'No schedule';
  }
  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }
  return DateFormat('MMM d, yyyy').format(parsed);
}

String _formatAppointmentTime(dynamic value) {
  final String raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return 'TIME PENDING';
  }
  final DateTime? parsed = DateTime.tryParse(
    '2024-01-01 ${raw.length == 5 ? '$raw:00' : raw}',
  );
  if (parsed == null) {
    return raw.toUpperCase();
  }
  return DateFormat('hh:mm a').format(parsed).toUpperCase();
}
