import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/file_download.dart';
import '../core/mobile_typography.dart';
import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';

enum _TrendView { daily, weekly, monthly }

class _AppointmentTrendPoint {
  const _AppointmentTrendPoint({required this.label, required this.count});

  final String label;
  final int count;
}

class _ReportFilterChipData {
  const _ReportFilterChipData({required this.label, required this.value});

  final String label;
  final String value;
}

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({
    super.key,
    required this.adminDashboardService,
    required this.appointmentService,
    this.embedded = false,
    this.showDetailedRecords = true,
  });

  final AdminDashboardService adminDashboardService;
  final AppointmentService appointmentService;
  final bool embedded;
  final bool showDetailedRecords;

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  static const Color _reportAccent = Color(0xFF3F6341);
  static const Color _reportAccentSoft = Color(0xFF6A9A8B);
  static const Color _reportHighlight = Color(0xFFE8C355);
  static const Color _exportButtonColor = Color(0xFF2E7D32);
  static const double _reportSectionRadius = 3;
  static const List<String> _reportStatuses = <String>[
    'Pending',
    'Approved',
    'Completed',
    'Cancelled',
  ];
  static const List<String> _reportBookingTypes = <String>[
    'Online Booking',
    'Walk-In Booking',
  ];

  bool _isLoading = true;
  bool _isTrendLoading = true;
  bool _isExporting = false;
  String? _trendLoadError;
  List<Map<String, dynamic>> _detailedRecords = [];
  DateTime? _draftStartDate;
  DateTime? _draftEndDate;
  String? _draftStatus;
  String? _draftBookingType;
  DateTime? _appliedStartDate;
  DateTime? _appliedEndDate;
  String? _appliedStatus;
  String? _appliedBookingType;

  final Map<_TrendView, List<_AppointmentTrendPoint>> _appointmentTrends =
      <_TrendView, List<_AppointmentTrendPoint>>{
        _TrendView.daily: const <_AppointmentTrendPoint>[],
        _TrendView.weekly: const <_AppointmentTrendPoint>[],
        _TrendView.monthly: const <_AppointmentTrendPoint>[],
      };
  final Set<_TrendView> _loadedTrendViews = <_TrendView>{};
  _TrendView _selectedTrendView = _TrendView.daily;

  // Default zero state keeps the layout stable when the API returns no rows.
  Map<String, int> _reportStats = <String, int>{
    'total': 0,
    'pending': 0,
    'approved': 0,
    'completed': 0,
    'cancelled': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final Map<String, String> filters = _activeReportFilters;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _clearTrendCache();
      });
    }

    try {
      await Future.wait([
        _fetchReportSummary(filters),
        _fetchDetailedRecords(filters),
        _loadTrendData(_selectedTrendView, filters: filters),
      ]);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchDetailedRecords([
    Map<String, String> filters = const <String, String>{},
  ]) async {
    try {
      final records = await widget.appointmentService.getAdminMasterList(
        filters,
      );
      if (!mounted) return;
      setState(() {
        _detailedRecords = records;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailedRecords = <Map<String, dynamic>>[];
      });
    }
  }

  Future<void> _fetchReportSummary([
    Map<String, String> filters = const <String, String>{},
  ]) async {
    try {
      final stats = await widget.adminDashboardService.getReportSummary(
        filters,
      );
      if (!mounted) return;
      setState(() {
        _reportStats = stats;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reportStats = <String, int>{
          'total': 0,
          'pending': 0,
          'approved': 0,
          'completed': 0,
          'cancelled': 0,
        };
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load report summary')),
      );
    }
  }

  Future<void> _loadTrendData(
    _TrendView view, {
    bool forceRefresh = false,
    Map<String, String>? filters,
  }) async {
    final Map<String, String> effectiveFilters =
        filters ?? _activeReportFilters;

    if (!forceRefresh && _loadedTrendViews.contains(view)) {
      return;
    }

    if (mounted) {
      setState(() {
        _isTrendLoading = true;
        _trendLoadError = null;
        if (forceRefresh) {
          _loadedTrendViews.remove(view);
        }
      });
    }

    try {
      final trendRows = await widget.adminDashboardService.getAppointmentTrends(
        view.name,
        effectiveFilters,
      );

      if (!mounted) return;

      setState(() {
        _appointmentTrends[view] = trendRows.map(_mapTrendPoint).toList();
        _loadedTrendViews.add(view);
        _isTrendLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _appointmentTrends[view] = const <_AppointmentTrendPoint>[];
        _loadedTrendViews.remove(view);
        _isTrendLoading = false;
        _trendLoadError = 'Unable to load appointment trends.';
      });
    }
  }

  Map<String, String> get _activeReportFilters {
    final Map<String, String> filters = <String, String>{};

    if (_appliedStartDate != null) {
      filters['start_date'] = _formatReportFilterDate(_appliedStartDate);
    }

    if (_appliedEndDate != null) {
      filters['end_date'] = _formatReportFilterDate(_appliedEndDate);
    }

    if (_appliedStatus != null) {
      filters['status'] = _appliedStatus!;
    }

    if (_appliedBookingType != null) {
      filters['booking_type'] = _appliedBookingType!;
    }

    return filters;
  }

  int get _activeFilterCount => _activeReportFilters.length;

  String get _reportFilterStateTitle {
    if (_hasAppliedReportFilters) {
      return '$_activeFilterCount active filter${_activeFilterCount == 1 ? '' : 's'}';
    }

    return 'Showing all report data';
  }

  String get _reportFilterStateBody {
    if (_hasAppliedReportFilters) {
      return 'Cards, appointment trends, status distribution, and detailed records are showing the current filtered results.';
    }

    return 'No filters are active. Apply a date range, status, or booking type to narrow the report results.';
  }

  void _clearTrendCache() {
    _loadedTrendViews.clear();

    for (final _TrendView view in _TrendView.values) {
      _appointmentTrends[view] = const <_AppointmentTrendPoint>[];
    }
  }

  _AppointmentTrendPoint _mapTrendPoint(Map<String, dynamic> row) {
    return _AppointmentTrendPoint(
      label: row['label']?.toString() ?? '-',
      count: _toInt(row['count']),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Future<void> _exportCsv() async {
    return _exportReport(ReportExportFormat.csv);
  }

  Future<void> _exportReport(ReportExportFormat format) async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final exportFile = await widget.adminDashboardService
          .exportDetailedRecords(format, _activeReportFilters);
      final savedPath = await saveDownloadedFile(
        filename: exportFile.filename,
        bytes: exportFile.bytes,
        mimeType: exportFile.contentType,
      );

      if (!mounted) {
        return;
      }

      final String formatLabel = format.label;
      final message = savedPath == null
          ? '$formatLabel export started.'
          : '$formatLabel exported to $savedPath';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to export report ${format.label}.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Widget _buildExportButton() {
    if (_isExporting) {
      return FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text('Exporting...'),
        style: FilledButton.styleFrom(
          backgroundColor: _exportButtonColor,
          foregroundColor: Colors.white,
        ),
      );
    }

    return PopupMenuButton<ReportExportFormat>(
      key: const Key('report-export-button'),
      onSelected: _exportReport,
      itemBuilder: (BuildContext context) => ReportExportFormat.values
          .map(
            (ReportExportFormat format) => PopupMenuItem<ReportExportFormat>(
              key: Key('report-export-option-${format.queryValue}'),
              value: format,
              child: Text('Export ${format.label}'),
            ),
          )
          .toList(),
      child: FilledButton.icon(
        onPressed: null,
        icon: const Icon(Icons.download_outlined),
        label: const Text('Export'),
        style: FilledButton.styleFrom(
          backgroundColor: _exportButtonColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPhone = MobileTypography.isPhone(context);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPhone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.embedded ? 'Detailed Report' : 'Reports',
                style: TextStyle(
                  fontSize: MobileTypography.pageTitle(context),
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading || _isTrendLoading
                        ? null
                        : _fetchData,
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
                  _buildExportButton(),
                ],
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.embedded ? 'Detailed Report' : 'Reports',
                  style: TextStyle(
                    fontSize: MobileTypography.pageTitle(context),
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading || _isTrendLoading
                        ? null
                        : _fetchData,
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
                  _buildExportButton(),
                ],
              ),
            ],
          ),
        SizedBox(height: MobileTypography.isPhone(context) ? 24 : 48),
        Wrap(
          spacing: 32,
          runSpacing: 32,
          alignment: WrapAlignment.start,
          children: [
            _buildReportCard(
              title: 'Total Appointments',
              value: _isLoading ? '...' : _reportStats['total'].toString(),
              icon: Icons.calendar_month,
              mainColor: const Color(0xFF6A9A8B),
              darkColor: const Color(0xFF50786A),
            ),
            _buildReportCard(
              title: 'Pending',
              value: _isLoading ? '...' : _reportStats['pending'].toString(),
              icon: Icons.hourglass_empty,
              mainColor: const Color(0xFFE5CC82),
              darkColor: const Color(0xFFBCA663),
            ),
            _buildReportCard(
              title: 'Approved',
              value: _isLoading ? '...' : _reportStats['approved'].toString(),
              icon: Icons.check_circle_outline,
              mainColor: const Color(0xFF86B9B0),
              darkColor: const Color(0xFF6E9A92),
            ),
            _buildReportCard(
              title: 'Completed',
              value: _isLoading ? '...' : _reportStats['completed'].toString(),
              icon: Icons.done_all,
              mainColor: const Color(0xFF4CAF50),
              darkColor: const Color(0xFF388E3C),
            ),
            _buildReportCard(
              title: 'Cancelled',
              value: _isLoading ? '...' : _reportStats['cancelled'].toString(),
              icon: Icons.cancel_outlined,
              mainColor: const Color(0xFFE28B71),
              darkColor: const Color(0xFFBA6952),
            ),
          ],
        ),
        const SizedBox(height: 56),
        _buildReportFilterSection(),
        const SizedBox(height: 56),
        _buildAppointmentTrendsSection(),
        const SizedBox(height: 56),
        _buildDistributionChart(),
        if (widget.showDetailedRecords) ...[
          const SizedBox(height: 56),
          _buildDetailedReportTable(),
        ],
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return SingleChildScrollView(
      padding: MobileTypography.screenPadding(context),
      child: content,
    );
  }

  Widget _buildReportFilterSection() {
    return Container(
      key: const Key('report-filters-section'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        border: const Border(
          top: BorderSide(color: _reportHighlight, width: 6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeader = constraints.maxWidth < 900;
            final double fieldWidth = _reportFilterFieldWidth(
              constraints.maxWidth,
            );

            final Widget header = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E0),
                    borderRadius: BorderRadius.circular(_reportSectionRadius),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.filter_alt_outlined,
                        size: 16,
                        color: Color(0xFF8A6B10),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Filters Live',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF8A6B10),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Report Filters',
                  style: TextStyle(
                    fontSize: MobileTypography.sectionTitle(context),
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Filter report cards, appointment trends, status distribution, and detailed records by date range, status, and booking type.',
                  style: TextStyle(
                    fontSize: MobileTypography.bodySmall(context),
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5E6C63),
                  ),
                ),
              ],
            );

            final Widget actions = Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  key: const Key('report-filter-reset'),
                  onPressed: () async {
                    await _resetReportFilters();
                  },
                  icon: const Icon(Icons.restart_alt),
                  label: const Text(
                    'Reset',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF55655B),
                    side: const BorderSide(color: Color(0xFFD2DCD4)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_reportSectionRadius),
                    ),
                  ),
                ),
                FilledButton.icon(
                  key: const Key('report-filter-apply'),
                  onPressed: () async {
                    await _applyReportFilters();
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Apply Filters',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _reportAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_reportSectionRadius),
                    ),
                  ),
                ),
              ],
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (compactHeader)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, const SizedBox(height: 20), actions],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: header),
                      const SizedBox(width: 24),
                      actions,
                    ],
                  ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: fieldWidth,
                      child: _buildDateFilterField(
                        fieldKey: const Key('report-filter-start-date'),
                        label: 'Start Date',
                        placeholder: 'Select start date',
                        value: _draftStartDate,
                        onTap: () => _pickReportFilterDate(isStartDate: true),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildDateFilterField(
                        fieldKey: const Key('report-filter-end-date'),
                        label: 'End Date',
                        placeholder: 'Select end date',
                        value: _draftEndDate,
                        onTap: () => _pickReportFilterDate(isStartDate: false),
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildDropdownFilterField(
                        fieldKey: const Key('report-filter-status-field'),
                        containerKey: const Key('report-filter-status'),
                        optionPrefix: 'report-filter-status',
                        label: 'Status',
                        hint: 'Select status',
                        icon: Icons.flag_outlined,
                        value: _draftStatus,
                        options: _reportStatuses,
                        onChanged: (String? value) {
                          setState(() {
                            _draftStatus = value;
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: fieldWidth,
                      child: _buildDropdownFilterField(
                        fieldKey: const Key('report-filter-booking-type-field'),
                        containerKey: const Key('report-filter-booking-type'),
                        optionPrefix: 'report-filter-booking-type',
                        label: 'Booking Type',
                        hint: 'Select booking type',
                        icon: Icons.meeting_room_outlined,
                        value: _draftBookingType,
                        options: _reportBookingTypes,
                        onChanged: (String? value) {
                          setState(() {
                            _draftBookingType = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF8),
                    borderRadius: BorderRadius.circular(_reportSectionRadius),
                    border: Border.all(color: const Color(0xFFDCE7DE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.integration_instructions_outlined,
                            size: 18,
                            color: _reportAccent,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _reportFilterStateTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _reportFilterStateBody,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF647167),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_hasAppliedReportFilters)
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _appliedFilterChips.map((chip) {
                            return _buildAppliedFilterChip(chip);
                          }).toList(),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              _reportSectionRadius,
                            ),
                            border: Border.all(color: const Color(0xFFDCE7DE)),
                          ),
                          child: const Text(
                            'All appointments are included in the current report view.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5E6C63),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _reportFilterFieldWidth(double maxWidth) {
    if (maxWidth >= 1200) {
      return (maxWidth - 48) / 4;
    }

    if (maxWidth >= 720) {
      return (maxWidth - 16) / 2;
    }

    return maxWidth;
  }

  Widget _buildDateFilterField({
    required Key fieldKey,
    required String label,
    required String placeholder,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    final bool hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF5E6C63),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          key: fieldKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(_reportSectionRadius),
          child: InputDecorator(
            decoration: _reportFilterInputDecoration(
              hintText: placeholder,
              suffixIcon: const Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: Color(0xFF55655B),
              ),
            ),
            child: Text(
              hasValue ? _formatReportFilterDate(value) : placeholder,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: hasValue ? Colors.black87 : const Color(0xFF8A948D),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownFilterField({
    required Key fieldKey,
    required Key containerKey,
    required String optionPrefix,
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      key: containerKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5E6C63),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: fieldKey,
            initialValue: value,
            onChanged: onChanged,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF55655B),
            ),
            decoration: _reportFilterInputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, size: 18, color: const Color(0xFF55655B)),
            ),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  key: Key('$optionPrefix-option-${_slugFilterKey(option)}'),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  InputDecoration _reportFilterInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF8A948D),
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF6F8F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        borderSide: const BorderSide(color: Color(0xFFD6DED8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        borderSide: const BorderSide(color: Color(0xFFD6DED8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        borderSide: const BorderSide(color: _reportAccent, width: 1.5),
      ),
    );
  }

  Widget _buildAppliedFilterChip(_ReportFilterChipData chip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        border: Border.all(color: const Color(0xFFD6DED8)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${chip.label}: ',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF5E6C63),
              ),
            ),
            TextSpan(
              text: chip.value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ReportFilterChipData> get _appliedFilterChips {
    final List<_ReportFilterChipData> chips = <_ReportFilterChipData>[];

    if (_appliedStartDate != null) {
      chips.add(
        _ReportFilterChipData(
          label: 'Start Date',
          value: _formatReportFilterDate(_appliedStartDate),
        ),
      );
    }

    if (_appliedEndDate != null) {
      chips.add(
        _ReportFilterChipData(
          label: 'End Date',
          value: _formatReportFilterDate(_appliedEndDate),
        ),
      );
    }

    if (_appliedStatus != null) {
      chips.add(_ReportFilterChipData(label: 'Status', value: _appliedStatus!));
    }

    if (_appliedBookingType != null) {
      chips.add(
        _ReportFilterChipData(
          label: 'Booking Type',
          value: _appliedBookingType!,
        ),
      );
    }

    return chips;
  }

  bool get _hasAppliedReportFilters =>
      _appliedStartDate != null ||
      _appliedEndDate != null ||
      _appliedStatus != null ||
      _appliedBookingType != null;

  Future<void> _pickReportFilterDate({required bool isStartDate}) async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = isStartDate
        ? (_draftStartDate ?? now)
        : (_draftEndDate ?? _draftStartDate ?? now);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isStartDate ? 'Select start date' : 'Select end date',
    );

    if (picked == null) {
      return;
    }

    final DateTime selectedDate = DateTime(
      picked.year,
      picked.month,
      picked.day,
    );

    setState(() {
      if (isStartDate) {
        _draftStartDate = selectedDate;
        if (_draftEndDate != null && _draftEndDate!.isBefore(selectedDate)) {
          _draftEndDate = selectedDate;
        }
      } else {
        _draftEndDate = selectedDate;
        if (_draftStartDate != null && _draftStartDate!.isAfter(selectedDate)) {
          _draftStartDate = selectedDate;
        }
      }
    });
  }

  Future<void> _applyReportFilters() async {
    setState(() {
      _appliedStartDate = _draftStartDate;
      _appliedEndDate = _draftEndDate;
      _appliedStatus = _draftStatus;
      _appliedBookingType = _draftBookingType;
    });

    await _fetchData();
  }

  Future<void> _resetReportFilters() async {
    setState(() {
      _draftStartDate = null;
      _draftEndDate = null;
      _draftStatus = null;
      _draftBookingType = null;
      _appliedStartDate = null;
      _appliedEndDate = null;
      _appliedStatus = null;
      _appliedBookingType = null;
    });

    await _fetchData();
  }

  String _formatReportFilterDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _slugFilterKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  Widget _buildAppointmentTrendsSection() {
    final List<_AppointmentTrendPoint> points = _currentTrendPoints;
    final bool hasLoadedSelectedTrend = _loadedTrendViews.contains(
      _selectedTrendView,
    );
    final bool hasRealData = _hasTrendDataFor(_selectedTrendView);
    final int totalAppointments = points.fold<int>(
      0,
      (int sum, _AppointmentTrendPoint point) => sum + point.count,
    );
    final int peakVolume = points.fold<int>(
      0,
      (int maxCount, _AppointmentTrendPoint point) =>
          math.max(maxCount, point.count),
    );
    final double averageVolume = points.isEmpty
        ? 0
        : totalAppointments / points.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        border: const Border(top: BorderSide(color: _reportAccent, width: 6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compact = constraints.maxWidth < 900;
                final Widget header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Appointment Trends',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _trendNarrative(_selectedTrendView),
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5E6C63),
                      ),
                    ),
                  ],
                );

                final Widget controls = _buildTrendViewToggle();

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [header, const SizedBox(height: 20), controls],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: header),
                    const SizedBox(width: 24),
                    controls,
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildTrendSummaryChip(
                  label: '${_trendLabel(_selectedTrendView)} view',
                  value: '${points.length} buckets',
                  icon: Icons.tune,
                ),
                _buildTrendSummaryChip(
                  label: 'Peak volume',
                  value: peakVolume.toString(),
                  icon: Icons.north_east,
                ),
                _buildTrendSummaryChip(
                  label: 'Average',
                  value: averageVolume.toStringAsFixed(1),
                  icon: Icons.show_chart,
                ),
                _buildTrendSummaryChip(
                  label: 'Data source',
                  value: _trendDataSourceLabel(
                    hasLoadedSelectedTrend: hasLoadedSelectedTrend,
                    hasRealData: hasRealData,
                  ),
                  icon: _trendDataSourceIcon(
                    hasLoadedSelectedTrend: hasLoadedSelectedTrend,
                    hasRealData: hasRealData,
                  ),
                  emphasize: _trendLoadError != null || !hasRealData,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_reportSectionRadius),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFF7FBF8), Color(0xFFFCFAF1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: const Color(0xFFDCE7DE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _reportAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            _reportSectionRadius,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.timeline,
                              size: 16,
                              color: _reportAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Trend Chart',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _reportAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _trendAxisCaption(_selectedTrendView),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF69786F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    key: const Key('appointment-trends-chart'),
                    height: 260,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.74),
                              borderRadius: BorderRadius.circular(
                                _reportSectionRadius,
                              ),
                            ),
                            child: CustomPaint(
                              painter: _AppointmentTrendChartPainter(
                                points: points,
                                lineColor: _reportAccent,
                                fillColor: _reportAccentSoft,
                                highlightColor: _reportHighlight,
                              ),
                            ),
                          ),
                        ),
                        if (_isTrendLoading)
                          const Center(
                            child: SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                color: _reportAccent,
                                strokeWidth: 3,
                              ),
                            ),
                          )
                        else if (_trendLoadError != null ||
                            (hasLoadedSelectedTrend && !hasRealData))
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(
                                  _reportSectionRadius,
                                ),
                                border: Border.all(
                                  color: const Color(0xFFD7E2D8),
                                ),
                              ),
                              child: Text(
                                _trendLoadError ??
                                    'No appointment trend data available yet.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5A685E),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Row(
                          children: [
                            for (final _AppointmentTrendPoint point in points)
                              Expanded(
                                child: Text(
                                  point.label,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5E6C63),
                                  ),
                                ),
                              ),
                          ],
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
    );
  }

  Widget _buildTrendViewToggle() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _TrendView.values.map(_buildTrendViewButton).toList(),
    );
  }

  Widget _buildTrendViewButton(_TrendView view) {
    final bool isSelected = view == _selectedTrendView;
    final Color foregroundColor = isSelected
        ? Colors.white
        : const Color(0xFF55655B);

    return Material(
      color: isSelected ? _reportAccent : const Color(0xFFF1F5F2),
      borderRadius: BorderRadius.circular(_reportSectionRadius),
      child: InkWell(
        key: Key('appointment-trends-${view.name}'),
        onTap: () async {
          if (view == _selectedTrendView) {
            return;
          }

          setState(() {
            _selectedTrendView = view;
            _trendLoadError = null;
          });

          await _loadTrendData(view);
        },
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_trendIcon(view), size: 18, color: foregroundColor),
              const SizedBox(width: 8),
              Text(
                _trendLabel(view),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _trendDataSourceLabel({
    required bool hasLoadedSelectedTrend,
    required bool hasRealData,
  }) {
    if (_isTrendLoading) {
      return 'Loading';
    }

    if (_trendLoadError != null) {
      return 'Unavailable';
    }

    if (hasLoadedSelectedTrend && hasRealData) {
      return 'Live';
    }

    if (hasLoadedSelectedTrend) {
      return 'No data';
    }

    return 'Pending';
  }

  IconData _trendDataSourceIcon({
    required bool hasLoadedSelectedTrend,
    required bool hasRealData,
  }) {
    if (_isTrendLoading) {
      return Icons.sync;
    }

    if (_trendLoadError != null) {
      return Icons.cloud_off;
    }

    if (hasLoadedSelectedTrend && hasRealData) {
      return Icons.cloud_done;
    }

    if (hasLoadedSelectedTrend) {
      return Icons.inbox_outlined;
    }

    return Icons.schedule;
  }

  Widget _buildTrendSummaryChip({
    required String label,
    required String value,
    required IconData icon,
    bool emphasize = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: emphasize ? const Color(0xFFFFF8E2) : const Color(0xFFF5F8F5),
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        border: Border.all(
          color: emphasize ? const Color(0xFFE8D48E) : const Color(0xFFDDE7DF),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 18,
            color: emphasize ? const Color(0xFF9A7A19) : _reportAccent,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF66746B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<_AppointmentTrendPoint> get _currentTrendPoints {
    final List<_AppointmentTrendPoint> apiPoints =
        _appointmentTrends[_selectedTrendView] ??
        const <_AppointmentTrendPoint>[];
    if (apiPoints.isNotEmpty) {
      return apiPoints;
    }

    return _placeholderTrendPoints(_selectedTrendView);
  }

  bool _hasTrendDataFor(_TrendView view) {
    final List<_AppointmentTrendPoint> points =
        _appointmentTrends[view] ?? const <_AppointmentTrendPoint>[];
    return points.isNotEmpty;
  }

  List<_AppointmentTrendPoint> _placeholderTrendPoints(_TrendView view) {
    switch (view) {
      case _TrendView.daily:
        return const <_AppointmentTrendPoint>[
          _AppointmentTrendPoint(label: 'Mon', count: 0),
          _AppointmentTrendPoint(label: 'Tue', count: 0),
          _AppointmentTrendPoint(label: 'Wed', count: 0),
          _AppointmentTrendPoint(label: 'Thu', count: 0),
          _AppointmentTrendPoint(label: 'Fri', count: 0),
          _AppointmentTrendPoint(label: 'Sat', count: 0),
          _AppointmentTrendPoint(label: 'Sun', count: 0),
        ];
      case _TrendView.weekly:
        return const <_AppointmentTrendPoint>[
          _AppointmentTrendPoint(label: 'W1', count: 0),
          _AppointmentTrendPoint(label: 'W2', count: 0),
          _AppointmentTrendPoint(label: 'W3', count: 0),
          _AppointmentTrendPoint(label: 'W4', count: 0),
          _AppointmentTrendPoint(label: 'W5', count: 0),
          _AppointmentTrendPoint(label: 'W6', count: 0),
        ];
      case _TrendView.monthly:
        return const <_AppointmentTrendPoint>[
          _AppointmentTrendPoint(label: 'Jan', count: 0),
          _AppointmentTrendPoint(label: 'Feb', count: 0),
          _AppointmentTrendPoint(label: 'Mar', count: 0),
          _AppointmentTrendPoint(label: 'Apr', count: 0),
          _AppointmentTrendPoint(label: 'May', count: 0),
          _AppointmentTrendPoint(label: 'Jun', count: 0),
        ];
    }
  }

  String _trendLabel(_TrendView view) {
    switch (view) {
      case _TrendView.daily:
        return 'Daily';
      case _TrendView.weekly:
        return 'Weekly';
      case _TrendView.monthly:
        return 'Monthly';
    }
  }

  String _trendNarrative(_TrendView view) {
    switch (view) {
      case _TrendView.daily:
        return 'Daily view highlights short-term spikes so admins can spot busy appointment days quickly.';
      case _TrendView.weekly:
        return 'Weekly view makes it easier to compare appointment flow across each week in the reporting window.';
      case _TrendView.monthly:
        return 'Monthly view reveals broader booking patterns and long-range seasonal movement at a glance.';
    }
  }

  String _trendAxisCaption(_TrendView view) {
    switch (view) {
      case _TrendView.daily:
        return 'Appointments per day';
      case _TrendView.weekly:
        return 'Appointments per week';
      case _TrendView.monthly:
        return 'Appointments per month';
    }
  }

  IconData _trendIcon(_TrendView view) {
    switch (view) {
      case _TrendView.daily:
        return Icons.today_outlined;
      case _TrendView.weekly:
        return Icons.view_week_outlined;
      case _TrendView.monthly:
        return Icons.calendar_month_outlined;
    }
  }

  Widget _buildDetailedReportTable() {
    final bool isPhone = MediaQuery.of(context).size.width < 800;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          top: BorderSide(color: Color(0xFF679B6A), width: 6.0),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Detailed Records',
                  style: TextStyle(
                    fontSize: MobileTypography.sectionTitle(context),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rows are grouped by status and ordered from the earliest appointment IDs upward within each status.',
                  style: TextStyle(
                    fontSize: MobileTypography.bodySmall(context),
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5E6C63),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(48.0),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF679B6A)),
              ),
            )
          else if (_detailedRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  _hasAppliedReportFilters
                      ? 'No detailed records match the active filters.'
                      : 'No detailed report records available yet.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5E6C63),
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: isPhone
                      ? 860
                      : MediaQuery.of(context).size.width - 400,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: DataTableTheme(
                      data: DataTableThemeData(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF4F8F4),
                        ),
                        headingTextStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF29412B),
                          fontSize: 14,
                        ),
                        dataTextStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                        dividerThickness: 0.6,
                      ),
                      child: DataTable(
                        headingRowHeight: 58,
                        dataRowMinHeight: 68,
                        dataRowMaxHeight: 76,
                        horizontalMargin: 18,
                        columnSpacing: isPhone ? 22 : 32,
                        border: TableBorder.all(
                          color: const Color(0xFFE6ECE6),
                          width: 0.75,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Patient')),
                          DataColumn(label: Text('Booking Type')),
                          DataColumn(label: Text('Service')),
                          DataColumn(label: Text('Queue No.')),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: _detailedRecords.map((record) {
                          return DataRow(
                            cells: [
                              DataCell(Text(record['date']?.toString() ?? '-')),
                              DataCell(
                                SizedBox(
                                  width: isPhone ? 160 : 220,
                                  child: Text(
                                    record['patient_name']?.toString() ?? '-',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 130,
                                  child: Text(
                                    record['booking_type']?.toString() ?? '-',
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: isPhone ? 150 : 190,
                                  child: Text(
                                    record['service']?.toString() ?? '-',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(record['queue_number']?.toString() ?? '-'),
                              ),
                              DataCell(
                                _buildStatusBadge(
                                  record['status']?.toString() ?? 'Pending',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 16),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildDistributionChart() {
    final total = _reportStats['total'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          const Text(
            'Status Distribution',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildChartRow(
                  'Pending',
                  _reportStats['pending'] ?? 0,
                  total,
                  const Color(0xFFE5CC82),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: _buildChartRow(
                  'Approved',
                  _reportStats['approved'] ?? 0,
                  total,
                  const Color(0xFF86B9B0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildChartRow(
                  'Completed',
                  _reportStats['completed'] ?? 0,
                  total,
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 48),
              Expanded(
                child: _buildChartRow(
                  'Cancelled',
                  _reportStats['cancelled'] ?? 0,
                  total,
                  const Color(0xFFE28B71),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartRow(String label, int count, int total, Color color) {
    final double percentage = total > 0 ? (count / total * 100) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            Text(
              '${percentage.toStringAsFixed(1)}% ($count)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(6),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: total > 0 ? (count / total) : 0,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color mainColor,
    required Color darkColor,
  }) {
    return Container(
      width: 320,
      height: 176,
      decoration: BoxDecoration(
        color: mainColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(icon, size: 64, color: Colors.white.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

class _AppointmentTrendChartPainter extends CustomPainter {
  const _AppointmentTrendChartPainter({
    required this.points,
    required this.lineColor,
    required this.fillColor,
    required this.highlightColor,
  });

  final List<_AppointmentTrendPoint> points;
  final Color lineColor;
  final Color fillColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double leftPadding = 48;
    const double topPadding = 18;
    const double rightPadding = 16;
    const double bottomPadding = 22;

    final Rect chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      size.width - leftPadding - rightPadding,
      size.height - topPadding - bottomPadding,
    );

    final int maxValue = points.fold<int>(
      0,
      (int maxCount, _AppointmentTrendPoint point) =>
          math.max(maxCount, point.count),
    );
    final int displayMax = maxValue <= 0 ? 4 : _roundedChartMax(maxValue);

    final Paint gridPaint = Paint()
      ..color = const Color(0xFFDCE6DE)
      ..strokeWidth = 1;
    final Paint axisPaint = Paint()
      ..color = const Color(0xFFB9C9BC)
      ..strokeWidth = 1.4;

    for (int step = 0; step <= 4; step++) {
      final double progress = step / 4;
      final double y = chartRect.bottom - (chartRect.height * progress);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        step == 0 ? axisPaint : gridPaint,
      );

      final double rawValue = displayMax * progress;
      final String label = rawValue.round().toString();
      final TextPainter labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6A786F),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      labelPainter.paint(
        canvas,
        Offset(
          chartRect.left - labelPainter.width - 12,
          y - (labelPainter.height / 2),
        ),
      );
    }

    if (points.isEmpty) {
      return;
    }

    final double xStep = points.length == 1
        ? 0
        : chartRect.width / (points.length - 1);
    final List<Offset> pointOffsets = <Offset>[];

    for (int index = 0; index < points.length; index++) {
      final _AppointmentTrendPoint point = points[index];
      final double normalized = displayMax == 0 ? 0 : point.count / displayMax;
      final double x = points.length == 1
          ? chartRect.center.dx
          : chartRect.left + (xStep * index);
      final double y = chartRect.bottom - (normalized * chartRect.height);
      pointOffsets.add(Offset(x, y));
    }

    final Path areaPath = Path()
      ..moveTo(pointOffsets.first.dx, chartRect.bottom);
    for (final Offset offset in pointOffsets) {
      areaPath.lineTo(offset.dx, offset.dy);
    }
    areaPath
      ..lineTo(pointOffsets.last.dx, chartRect.bottom)
      ..close();

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          fillColor.withValues(alpha: 0.30),
          fillColor.withValues(alpha: 0.05),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(chartRect);
    canvas.drawPath(areaPath, fillPaint);

    final Path linePath = Path()
      ..moveTo(pointOffsets.first.dx, pointOffsets.first.dy);
    for (int index = 1; index < pointOffsets.length; index++) {
      final Offset previous = pointOffsets[index - 1];
      final Offset current = pointOffsets[index];
      final double controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = lineColor;
    canvas.drawPath(linePath, linePaint);

    final Paint haloPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = highlightColor.withValues(alpha: 0.28);
    final Paint dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = highlightColor;
    final Paint innerDotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = lineColor;

    for (final Offset offset in pointOffsets) {
      canvas.drawCircle(offset, 10, haloPaint);
      canvas.drawCircle(offset, 5.5, dotPaint);
      canvas.drawCircle(offset, 2.5, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AppointmentTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.highlightColor != highlightColor;
  }

  int _roundedChartMax(int rawMax) {
    if (rawMax <= 5) {
      return 5;
    }

    if (rawMax <= 10) {
      return 10;
    }

    final int magnitude = math
        .pow(10, (math.log(rawMax) / math.ln10).floor())
        .toInt();
    return ((rawMax / magnitude).ceil() * magnitude);
  }
}
