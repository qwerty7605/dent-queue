import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/file_download.dart';
import '../core/mobile_typography.dart';
import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/appointment_status_badge.dart';
import '../widgets/paginated_table_footer.dart';

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

class _ReportDateRangeSelection {
  const _ReportDateRangeSelection({this.startDate, this.endDate});

  final DateTime? startDate;
  final DateTime? endDate;
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
  static const Color _reportAccent = Color(0xFF1A2F64);
  static const Color _exportButtonColor = Color(0xFF1A2F64);
  static const List<Color> _reportCardPalette = <Color>[
    Color(0xFF1A2F64),
    Color(0xFF4A769E),
    Color(0xFF6E9A92),
    Color(0xFF64748B),
  ];
  static const double _reportSectionRadius = 20;
  static const int _detailedRecordsPageSize = 25;
  static const List<String> _reportStatuses = <String>[
    'Pending',
    'Approved',
    'Completed',
    'Cancelled',
    'Cancelled by Doctor',
    'Reschedule Required',
  ];
  static const List<String> _reportBookingTypes = <String>[
    'Online Booking',
    'Walk-In Booking',
  ];
  static const int _defaultTrendBucketLimit = 10;
  static const List<_TrendView> _trendViewOrder = <_TrendView>[
    _TrendView.monthly,
    _TrendView.weekly,
    _TrendView.daily,
  ];

  bool _isLoading = true;
  bool _isTrendLoading = true;
  bool _isExporting = false;
  bool _isLoadingMoreDetailedRecords = false;
  String? _trendLoadError;
  List<Map<String, dynamic>> _detailedRecords = [];
  int _currentDetailedRecordsPage = 0;
  int _totalDetailedRecords = 0;
  bool _hasMoreDetailedRecords = false;
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
  _TrendView _selectedTrendView = _TrendView.monthly;

  // Default zero state keeps the layout stable when the API returns no rows.
  Map<String, int> _reportStats = <String, int>{
    'total': 0,
    'report_records': 0,
    'pending': 0,
    'approved': 0,
    'completed': 0,
    'cancelled': 0,
    'cancelled_by_doctor': 0,
    'reschedule_required': 0,
  };
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF162033) : Colors.white;
  Color get _surfaceAltColor =>
      _isDarkMode ? const Color(0xFF1B2740) : const Color(0xFFFBFCFF);
  Color get _fieldFillColor =>
      _isDarkMode ? const Color(0xFF1E2B45) : const Color(0xFFF8FAFF);
  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF30415F) : const Color(0xFFE7EDF8);
  Color get _textColor =>
      _isDarkMode ? const Color(0xFFEAF1FF) : Colors.black87;
  Color get _mutedTextColor =>
      _isDarkMode ? const Color(0xFFAAB8D4) : const Color(0xFF97A6C3);
  Color get _exportButtonForeground =>
      _isDarkMode ? const Color(0xFFE6EEFF) : _reportAccent;
  Color get _exportButtonBackground =>
      _isDarkMode ? const Color(0xFF1D3369) : _surfaceColor;
  Color get _exportButtonBorder =>
      _isDarkMode ? const Color(0xFF4C69A8) : _borderColor;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    final Map<String, String> filters = _activeReportFilters;

    if (forceRefresh) {
      widget.adminDashboardService.invalidateReportCaches();
      widget.appointmentService.invalidateAppointmentCaches();
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _clearTrendCache();
      });
    }

    try {
      await Future.wait(<Future<void>>[
        _fetchReportSummary(filters, forceRefresh),
        if (widget.showDetailedRecords) _fetchDetailedRecords(filters),
        _loadTrendData(
          _selectedTrendView,
          filters: filters,
          forceRefresh: forceRefresh,
        ),
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
      final recordsPage = await widget.appointmentService
          .getAdminMasterListPage(
            filters: filters,
            page: 1,
            perPage: _detailedRecordsPageSize,
          );
      if (!mounted) return;
      setState(() {
        _detailedRecords = recordsPage.items;
        _currentDetailedRecordsPage = recordsPage.currentPage;
        _totalDetailedRecords = recordsPage.totalItems;
        _hasMoreDetailedRecords = recordsPage.hasMorePages;
        _isLoadingMoreDetailedRecords = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailedRecords = <Map<String, dynamic>>[];
        _currentDetailedRecordsPage = 0;
        _totalDetailedRecords = 0;
        _hasMoreDetailedRecords = false;
        _isLoadingMoreDetailedRecords = false;
      });
    }
  }

  Future<void> _loadMoreDetailedRecords() async {
    if (_isLoading ||
        _isLoadingMoreDetailedRecords ||
        !_hasMoreDetailedRecords) {
      return;
    }

    setState(() {
      _isLoadingMoreDetailedRecords = true;
    });

    try {
      final recordsPage = await widget.appointmentService
          .getAdminMasterListPage(
            filters: _activeReportFilters,
            page: _currentDetailedRecordsPage + 1,
            perPage: _detailedRecordsPageSize,
          );
      if (!mounted) return;

      setState(() {
        _detailedRecords = <Map<String, dynamic>>[
          ..._detailedRecords,
          ...recordsPage.items,
        ];
        _currentDetailedRecordsPage = recordsPage.currentPage;
        _totalDetailedRecords = recordsPage.totalItems;
        _hasMoreDetailedRecords = recordsPage.hasMorePages;
        _isLoadingMoreDetailedRecords = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingMoreDetailedRecords = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load more report records')),
      );
    }
  }

  Future<void> _fetchReportSummary([
    Map<String, String> filters = const <String, String>{},
    bool forceRefresh = false,
  ]) async {
    try {
      final stats = await widget.adminDashboardService.getReportSummary(
        filters,
        forceRefresh,
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
          'report_records': 0,
          'pending': 0,
          'approved': 0,
          'completed': 0,
          'cancelled': 0,
          'cancelled_by_doctor': 0,
          'reschedule_required': 0,
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
        forceRefresh,
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

  Map<String, String> get _exportReportFilters {
    final Map<String, String> filters = <String, String>{};

    if (_hasAppliedDateFilters) {
      if (_appliedStartDate != null) {
        filters['start_date'] = _formatReportFilterDate(_appliedStartDate);
      }

      if (_appliedEndDate != null) {
        filters['end_date'] = _formatReportFilterDate(_appliedEndDate);
      }
    } else {
      final _ReportDateRangeSelection range = _defaultExportDateRange(
        _selectedTrendView,
      );
      filters['start_date'] = _formatReportFilterDate(range.startDate);
      filters['end_date'] = _formatReportFilterDate(range.endDate);
    }

    if (_appliedStatus != null) {
      filters['status'] = _appliedStatus!;
    }

    if (_appliedBookingType != null) {
      filters['booking_type'] = _appliedBookingType!;
    }

    return filters;
  }

  String get _reportExportScopeTitle {
    if (_hasAppliedDateFilters) {
      return 'Current report filters will be exported';
    }

    return 'Default ${_trendLabel(_selectedTrendView).toLowerCase()} window will be exported';
  }

  String get _reportExportScopeBody {
    if (_hasAppliedDateFilters) {
      return 'The downloaded file uses the same date range, status, and booking type filters currently applied to the report cards, trends, and detailed table.';
    }

    return 'No custom dates are selected, so the export uses the current ${_trendLabel(_selectedTrendView).toLowerCase()} trend window: $_defaultExportWindowDescription. Status and booking type filters are still applied when selected.';
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
      count: math.max(0, _toInt(row['count'])),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final String sanitized = (value?.toString() ?? '').replaceAll(
      RegExp(r'[^0-9-]'),
      '',
    );

    return int.tryParse(sanitized) ?? 0;
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
          .exportDetailedRecords(format, _exportReportFilters);
      final savedPath = await saveDownloadedFile(
        filename: exportFile.filename,
        bytes: exportFile.bytes,
        mimeType: exportFile.contentType,
      );

      if (!mounted) {
        return;
      }

      final String formatLabel = format.label;
      final String baseMessage = savedPath == null
          ? '$formatLabel export started.'
          : '$formatLabel exported to $savedPath';
      final String message =
          exportFile.wasLimited &&
              exportFile.exportedRecordCount != null &&
              exportFile.totalRecordCount != null
          ? '$baseMessage PDF includes the first ${exportFile.exportedRecordCount} of ${exportFile.totalRecordCount} matching records.'
          : baseMessage;

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

    return FilledButton.icon(
      key: const Key('report-export-button'),
      onPressed: () async {
        final ReportExportFormat? selectedFormat = await _showExportDialog();
        if (selectedFormat == null) {
          return;
        }

        await _exportReport(selectedFormat);
      },
      icon: const Icon(Icons.download_outlined),
      label: const Text('Export'),
      style: FilledButton.styleFrom(
        backgroundColor: _exportButtonColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<ReportExportFormat?> _showExportDialog() async {
    ReportExportFormat selectedFormat = ReportExportFormat.csv;

    return showDialog<ReportExportFormat>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AppAlertDialog(
              scrollable: true,
              title: const Text('Export Report'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose the file format. The export will use the date window and filters listed below.',
                      ),
                      const SizedBox(height: 20),
                      DropdownButtonFormField<ReportExportFormat>(
                        initialValue: selectedFormat,
                        decoration: _reportFilterInputDecoration(
                          hintText: 'Select format',
                          prefixIcon: const Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: Color(0xFF55655B),
                          ),
                        ),
                        items: ReportExportFormat.values
                            .map(
                              (ReportExportFormat format) =>
                                  DropdownMenuItem<ReportExportFormat>(
                                    value: format,
                                    child: Text(format.label),
                                  ),
                            )
                            .toList(),
                        onChanged: (ReportExportFormat? value) {
                          if (value == null) {
                            return;
                          }

                          setDialogState(() {
                            selectedFormat = value;
                          });
                        },
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surfaceAltColor,
                          borderRadius: BorderRadius.circular(
                            _reportSectionRadius,
                          ),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.filter_alt_outlined,
                                  size: 18,
                                  color: _reportAccent,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _reportExportScopeTitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _reportExportScopeBody,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _mutedTextColor,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: _exportScopeChips.map((chip) {
                                return _buildAppliedFilterChip(chip);
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(selectedFormat);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _exportButtonColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Export'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildEmbeddedContent(context);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MobileTypography.isPhone(context) ? 14 : 20,
        16,
        MobileTypography.isPhone(context) ? 14 : 20,
        20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1540),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportFilterSection(),
              const SizedBox(height: 28),
              _buildAppointmentTrendsSection(),
              const SizedBox(height: 28),
              _buildDistributionChart(),
              if (widget.showDetailedRecords) ...[
                const SizedBox(height: 28),
                _buildDetailedReportTable(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmbeddedContent(BuildContext context) {
    final bool isPhone = MobileTypography.isPhone(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isPhone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Report',
                style: TextStyle(
                  fontSize: MobileTypography.pageTitle(context) - 4,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? const Color(0xFFEAF1FF) : Colors.black,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _isLoading || _isTrendLoading
                        ? null
                        : () => _fetchData(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontWeight: FontWeight.bold),
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
                  'Detailed Report',
                  style: TextStyle(
                    fontSize: MobileTypography.pageTitle(context) - 4,
                    fontWeight: FontWeight.bold,
                    color: _isDarkMode ? const Color(0xFFEAF1FF) : Colors.black,
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
                        : () => _fetchData(forceRefresh: true),
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildExportButton(),
                ],
              ),
            ],
          ),
        SizedBox(height: MobileTypography.isPhone(context) ? 18 : 28),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          alignment: WrapAlignment.start,
          children: [
            _buildReportCard(
              title: 'Total Appointments',
              value: _isLoading ? '...' : _reportStats['total'].toString(),
              icon: Icons.calendar_month,
              accentColor: _reportCardPalette[0],
            ),
            _buildReportCard(
              title: 'Linked Reports',
              value: _isLoading
                  ? '...'
                  : _reportStats['report_records'].toString(),
              icon: Icons.summarize_outlined,
              accentColor: _reportCardPalette[1],
            ),
            _buildReportCard(
              title: 'Pending',
              value: _isLoading ? '...' : _reportStats['pending'].toString(),
              icon: Icons.hourglass_empty,
              accentColor: _reportCardPalette[2],
            ),
            _buildReportCard(
              title: 'Approved',
              value: _isLoading ? '...' : _reportStats['approved'].toString(),
              icon: Icons.check_circle_outline,
              accentColor: _reportCardPalette[0],
            ),
            _buildReportCard(
              title: 'Completed',
              value: _isLoading ? '...' : _reportStats['completed'].toString(),
              icon: Icons.done_all,
              accentColor: _reportCardPalette[1],
            ),
            _buildReportCard(
              title: 'Cancelled',
              value: _isLoading ? '...' : _reportStats['cancelled'].toString(),
              icon: Icons.cancel_outlined,
              accentColor: _reportCardPalette[3],
            ),
            _buildReportCard(
              title: 'Cancelled by Doctor',
              value: _isLoading
                  ? '...'
                  : _reportStats['cancelled_by_doctor'].toString(),
              icon: Icons.event_busy_outlined,
              accentColor: _reportCardPalette[2],
            ),
            _buildReportCard(
              title: 'Reschedule Required',
              value: _isLoading
                  ? '...'
                  : _reportStats['reschedule_required'].toString(),
              icon: Icons.update_outlined,
              accentColor: _reportCardPalette[0],
            ),
          ],
        ),
        const SizedBox(height: 28),
        _buildReportFilterSection(),
        const SizedBox(height: 28),
        _buildAppointmentTrendsSection(),
        const SizedBox(height: 28),
        _buildDistributionChart(),
        if (widget.showDetailedRecords) ...[
          const SizedBox(height: 28),
          _buildDetailedReportTable(),
        ],
      ],
    );
  }

  Widget _buildReportFilterSection() {
    return Container(
      key: const Key('report-filters-section'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: (_isDarkMode ? Colors.black : const Color(0xFF17305F))
                .withValues(alpha: _isDarkMode ? 0.24 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints outerConstraints) {
          final EdgeInsets sectionPadding = _reportSectionPadding(
            outerConstraints.maxWidth,
          );

          return Padding(
            padding: sectionPadding,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool compactHeader = constraints.maxWidth < 980;
                final double fieldWidth = _reportFilterHorizontalFieldWidth(
                  constraints.maxWidth,
                );

                final Widget header = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _SectionIconBadge(
                          icon: Icons.filter_alt_outlined,
                          iconColor: _reportAccent,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'REPORT CONFIGURATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _reportAccent,
                              letterSpacing: 1.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final Widget primaryActions = Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      height: 40,
                      child: TextButton(
                        key: const Key('report-filter-reset'),
                        onPressed: () async {
                          await _resetReportFilters();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: _mutedTextColor,
                          backgroundColor: _fieldFillColor,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'RESET',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: FilledButton(
                        key: const Key('report-filter-apply'),
                        onPressed: () async {
                          await _applyReportFilters();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _reportAccent,
                          foregroundColor: Colors.white,
                          elevation: 8,
                          shadowColor: _reportAccent.withValues(alpha: 0.22),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'APPLY FILTERS',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
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
                        children: [header, const SizedBox(height: 18)],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [Expanded(child: header)],
                      ),
                    const SizedBox(height: 22),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: fieldWidth,
                            child: _buildDateFilterField(
                              fieldKey: const Key('report-filter-start-date'),
                              label: 'START DATE',
                              placeholder: 'dd/mm/yyyy',
                              value: _draftStartDate,
                              onTap: _pickReportDateRange,
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildDateFilterField(
                              fieldKey: const Key('report-filter-end-date'),
                              label: 'END DATE',
                              placeholder: 'dd/mm/yyyy',
                              value: _draftEndDate,
                              onTap: _pickReportDateRange,
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildDropdownFilterField(
                              fieldKey: const Key('report-filter-status-field'),
                              containerKey: const Key('report-filter-status'),
                              optionPrefix: 'report-filter-status',
                              label: 'STATUS',
                              hint: 'All Statuses',
                              value: _draftStatus,
                              options: _reportStatuses,
                              onChanged: (String? value) {
                                setState(() {
                                  _draftStatus = value;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 18),
                          SizedBox(
                            width: fieldWidth,
                            child: _buildDropdownFilterField(
                              fieldKey: const Key(
                                'report-filter-booking-type-field',
                              ),
                              containerKey: const Key(
                                'report-filter-booking-type',
                              ),
                              optionPrefix: 'report-filter-booking-type',
                              label: 'BOOKING TYPE',
                              hint: 'All Bookings',
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
                    ),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          primaryActions,
                          const SizedBox(width: 18),
                          _buildReportExportAction(),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  double _reportFilterHorizontalFieldWidth(double maxWidth) {
    if (maxWidth >= 1440) {
      return 260;
    }

    if (maxWidth >= 1200) {
      return 236;
    }

    return 220;
  }

  EdgeInsets _reportSectionPadding(double maxWidth) {
    if (maxWidth < 360) {
      return const EdgeInsets.fromLTRB(16, 18, 16, 18);
    }

    if (maxWidth < 520) {
      return const EdgeInsets.fromLTRB(18, 20, 18, 20);
    }

    return const EdgeInsets.fromLTRB(24, 22, 24, 24);
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
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: _mutedTextColor,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          key: fieldKey,
          onTap: onTap,
          borderRadius: BorderRadius.circular(_reportSectionRadius),
          child: InputDecorator(
            decoration: _reportFilterInputDecoration(
              hintText: placeholder,
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: _mutedTextColor,
              ),
              suffixIcon: Icon(
                Icons.calendar_today_outlined,
                size: 16,
                color: _textColor,
              ),
            ),
            child: Text(
              hasValue ? _formatReportFilterDate(value) : placeholder,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: hasValue ? _textColor : _mutedTextColor,
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _mutedTextColor,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: fieldKey,
            initialValue: value,
            isExpanded: true,
            onChanged: onChanged,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _mutedTextColor,
            ),
            decoration: _reportFilterInputDecoration(hintText: hint),
            items: options.map((String option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(
                  option,
                  key: Key('$optionPrefix-option-${_slugFilterKey(option)}'),
                  overflow: TextOverflow.ellipsis,
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
      hintStyle: TextStyle(
        color: _mutedTextColor,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _fieldFillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _reportAccent, width: 1.5),
      ),
    );
  }

  Widget _buildReportExportAction() {
    return OutlinedButton(
      key: const Key('report-export-button'),
      onPressed: _isExporting
          ? null
          : () async {
              final ReportExportFormat? selectedFormat =
                  await _showExportDialog();
              if (selectedFormat == null) {
                return;
              }
              await _exportReport(selectedFormat);
            },
      style: OutlinedButton.styleFrom(
        foregroundColor: _exportButtonForeground,
        backgroundColor: _exportButtonBackground,
        side: BorderSide(color: _exportButtonBorder),
        minimumSize: const Size(220, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExporting)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _exportButtonForeground,
              ),
            )
          else
            const Icon(Icons.download_outlined, size: 16),
          const SizedBox(width: 8),
          const Text(
            'EXPORT REPORT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
        ],
      ),
    );
  }

  Widget _buildAppliedFilterChip(_ReportFilterChipData chip) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(_reportSectionRadius),
        border: Border.all(color: _borderColor),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '${chip.label}: ',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _mutedTextColor,
              ),
            ),
            TextSpan(
              text: chip.value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_ReportFilterChipData> get _exportScopeChips {
    final Map<String, String> filters = _exportReportFilters;
    final List<_ReportFilterChipData> chips = <_ReportFilterChipData>[];

    if (!_hasAppliedDateFilters) {
      chips.add(
        _ReportFilterChipData(
          label: 'Trend View',
          value: _trendLabel(_selectedTrendView),
        ),
      );
    }

    chips.add(
      _ReportFilterChipData(
        label: 'Start Date',
        value: filters['start_date'] ?? '-',
      ),
    );
    chips.add(
      _ReportFilterChipData(
        label: 'End Date',
        value: filters['end_date'] ?? '-',
      ),
    );

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

  bool get _hasAppliedDateFilters =>
      _appliedStartDate != null || _appliedEndDate != null;

  Future<void> _pickReportDateRange() async {
    final _ReportDateRangeSelection? selectedRange =
        await _showReportDateRangePicker();

    if (selectedRange == null) {
      return;
    }

    setState(() {
      _draftStartDate = selectedRange.startDate;
      _draftEndDate = selectedRange.endDate;
    });
  }

  Future<_ReportDateRangeSelection?> _showReportDateRangePicker() async {
    final DateTime firstDate = DateTime(2020);
    final DateTime lastDate = DateTime(2100);
    final DateTime today = _dateOnly(DateTime.now());
    DateTime? selectedStart = _draftStartDate;
    DateTime? selectedEnd = _draftEndDate;

    DateTime initialDateFor(DateTime? selectedDate) {
      if (selectedDate != null) {
        return selectedDate;
      }

      if (today.isBefore(firstDate)) {
        return firstDate;
      }

      if (today.isAfter(lastDate)) {
        return lastDate;
      }

      return today;
    }

    return showDialog<_ReportDateRangeSelection>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            final String startLabel = selectedStart == null
                ? 'Not selected'
                : _formatReportFilterDate(selectedStart);
            final String endLabel = selectedEnd == null
                ? 'Not selected'
                : _formatReportFilterDate(selectedEnd);

            Widget buildCalendarPanel({
              required Key key,
              required String title,
              required String subtitle,
              required DateTime? selectedDate,
              required ValueChanged<DateTime> onDateChanged,
            }) {
              return Container(
                width: 330,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                decoration: BoxDecoration(
                  color: _surfaceAltColor,
                  borderRadius: BorderRadius.circular(_reportSectionRadius),
                  border: Border.all(color: _borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _reportAccent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _mutedTextColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 360,
                      child: CalendarDatePicker(
                        key: key,
                        initialDate: initialDateFor(selectedDate),
                        firstDate: firstDate,
                        lastDate: lastDate,
                        currentDate: selectedDate,
                        onDateChanged: onDateChanged,
                      ),
                    ),
                  ],
                ),
              );
            }

            final Widget calendars = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildCalendarPanel(
                  key: ValueKey<String>(
                    'report-start-calendar-${selectedStart?.toIso8601String() ?? 'empty'}',
                  ),
                  title: 'START DATE',
                  subtitle: 'Choose the first day from the left calendar.',
                  selectedDate: selectedStart,
                  onDateChanged: (DateTime value) {
                    final DateTime start = _dateOnly(value);
                    setDialogState(() {
                      selectedStart = start;
                      if (selectedEnd != null && selectedEnd!.isBefore(start)) {
                        selectedEnd = start;
                      }
                    });
                  },
                ),
                const SizedBox(width: 16),
                buildCalendarPanel(
                  key: ValueKey<String>(
                    'report-end-calendar-${selectedEnd?.toIso8601String() ?? 'empty'}',
                  ),
                  title: 'END DATE',
                  subtitle: 'Choose the last day from the right calendar.',
                  selectedDate: selectedEnd,
                  onDateChanged: (DateTime value) {
                    final DateTime end = _dateOnly(value);
                    setDialogState(() {
                      selectedEnd = end;
                      if (selectedStart != null &&
                          selectedStart!.isAfter(end)) {
                        selectedStart = end;
                      }
                    });
                  },
                ),
              ],
            );

            return AppAlertDialog(
              scrollable: true,
              title: const Text('Select Report Date Range'),
              content: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: 676,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _fieldFillColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _borderColor),
                        ),
                        child: Text(
                          'Selected range: $startLabel to $endLabel',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _textColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      calendars,
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      selectedStart = null;
                      selectedEnd = null;
                    });
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  key: const Key('report-date-range-apply'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _ReportDateRangeSelection(
                        startDate: selectedStart,
                        endDate: selectedEnd,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _reportAccent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Apply Dates'),
                ),
              ],
            );
          },
        );
      },
    );
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

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _slugFilterKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  Widget _buildAppointmentTrendsSection() {
    final List<_AppointmentTrendPoint> points = _currentTrendPoints;
    final List<_AppointmentTrendPoint> displayPoints = _trendLoadError != null
        ? const <_AppointmentTrendPoint>[]
        : points;
    final bool hasLoadedSelectedTrend = _loadedTrendViews.contains(
      _selectedTrendView,
    );
    final bool hasRealData = _hasTrendDataFor(_selectedTrendView);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: (_isDarkMode ? Colors.black : const Color(0xFF17305F))
                .withValues(alpha: _isDarkMode ? 0.22 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints outerConstraints) {
          return Padding(
            padding: _reportSectionPadding(outerConstraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxWidth < 900;
                    final Widget header = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _SectionIconBadge(
                              icon: Icons.trending_up_rounded,
                              iconColor: Color(0xFF39B98A),
                              backgroundColor: Color(0xFFEAF9F3),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Appointment Volume Trends',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: _reportAccent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'ANALYZED THROUGH TEMPORAL THROUGHPUT PROTOCOLS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _mutedTextColor,
                            letterSpacing: 1.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_trendLabel(_selectedTrendView)} view',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _mutedTextColor,
                          ),
                        ),
                      ],
                    );

                    final Widget controls = _buildTrendViewToggle();

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          header,
                          const SizedBox(height: 12),
                          controls,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: header),
                        const SizedBox(width: 16),
                        controls,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    color: _surfaceAltColor,
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        key: const Key('appointment-trends-chart'),
                        child: LayoutBuilder(
                          builder: (BuildContext context, BoxConstraints constraints) {
                            final double pointWidth =
                                switch (_selectedTrendView) {
                                  _TrendView.daily => 88,
                                  _TrendView.weekly => 74,
                                  _TrendView.monthly => 82,
                                };
                            final double chartWidth = math.max(
                              constraints.maxWidth,
                              math.max(
                                constraints.maxWidth,
                                64 + (displayPoints.length * pointWidth),
                              ),
                            );

                            return SingleChildScrollView(
                              key: const Key('appointment-trends-scroll'),
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: chartWidth,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 250,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: _surfaceColor,
                                                borderRadius:
                                                    BorderRadius.circular(26),
                                              ),
                                              child: CustomPaint(
                                                painter:
                                                    _AppointmentTrendChartPainter(
                                                      points: displayPoints,
                                                      lineColor: _reportAccent,
                                                      fillColor: const Color(
                                                        0xFFCAD7F3,
                                                      ),
                                                      highlightColor:
                                                          const Color(
                                                            0xFFEEF3FF,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                          if (_isTrendLoading)
                                            const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: _reportAccent,
                                                      strokeWidth: 2.5,
                                                    ),
                                              ),
                                            )
                                          else if (_trendLoadError != null)
                                            Center(
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 18,
                                                      vertical: 12,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: _surfaceColor
                                                      .withValues(alpha: 0.95),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        _reportSectionRadius,
                                                      ),
                                                  border: Border.all(
                                                    color: _borderColor,
                                                  ),
                                                ),
                                                child: Text(
                                                  _trendLoadError!,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: _mutedTextColor,
                                                  ),
                                                ),
                                              ),
                                            )
                                          else if (hasLoadedSelectedTrend &&
                                              !hasRealData)
                                            const Center(
                                              child: AppEmptyState(
                                                key: Key(
                                                  'appointment-trends-empty-state',
                                                ),
                                                icon: Icons.show_chart_rounded,
                                                title: 'No trend data yet',
                                                message:
                                                    'No appointment trend data available yet.',
                                                compact: true,
                                                framed: false,
                                                maxWidth: 320,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (displayPoints.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      SizedBox(
                                        height: 28,
                                        width: chartWidth,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            for (
                                              int index = 0;
                                              index < displayPoints.length;
                                              index++
                                            )
                                              Positioned(
                                                left:
                                                    _trendPointX(
                                                      index: index,
                                                      pointCount:
                                                          displayPoints.length,
                                                      chartWidth: chartWidth,
                                                    ) -
                                                    (pointWidth / 2),
                                                width: pointWidth,
                                                top: 0,
                                                child: Text(
                                                  displayPoints[index].label,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: _mutedTextColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              if (constraints.maxWidth < 420) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _trendDataSourceLabel(
                                        hasLoadedSelectedTrend:
                                            hasLoadedSelectedTrend,
                                        hasRealData: hasRealData,
                                      ),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color:
                                            _trendLoadError != null ||
                                                !hasRealData
                                            ? _mutedTextColor
                                            : const Color(0xFF39B98A),
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _trendAxisCaption(_selectedTrendView),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _mutedTextColor,
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Text(
                                    _trendDataSourceLabel(
                                      hasLoadedSelectedTrend:
                                          hasLoadedSelectedTrend,
                                      hasRealData: hasRealData,
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          _trendLoadError != null ||
                                              !hasRealData
                                          ? _mutedTextColor
                                          : const Color(0xFF39B98A),
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _trendAxisCaption(_selectedTrendView),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: _mutedTextColor,
                                    ),
                                  ),
                                ],
                              );
                            },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendViewToggle() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _fieldFillColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _trendViewOrder.map(_buildTrendViewButton).toList(),
        ),
      ),
    );
  }

  Widget _buildTrendViewButton(_TrendView view) {
    final bool isSelected = view == _selectedTrendView;
    final Color foregroundColor = isSelected
        ? _reportAccent
        : const Color(0xFF95A2BE);

    return Material(
      color: isSelected ? _surfaceColor : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 2 : 0,
      shadowColor: const Color(0xFF17305F).withValues(alpha: 0.08),
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
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: SizedBox(
            width: 72,
            child: Text(
              _trendLabel(view).toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: foregroundColor,
                letterSpacing: 1.2,
              ),
            ),
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

  List<_AppointmentTrendPoint> get _currentTrendPoints {
    final List<_AppointmentTrendPoint> apiPoints =
        _appointmentTrends[_selectedTrendView] ??
        const <_AppointmentTrendPoint>[];
    final bool hasDateFilter =
        _appliedStartDate != null || _appliedEndDate != null;

    if (!hasDateFilter) {
      return _defaultTrendPoints(_selectedTrendView, apiPoints);
    }

    if (apiPoints.isNotEmpty) {
      return apiPoints;
    }

    return _placeholderTrendPoints(_selectedTrendView);
  }

  List<_AppointmentTrendPoint> _defaultTrendPoints(
    _TrendView view,
    List<_AppointmentTrendPoint> points,
  ) {
    final Map<String, int> countsByLabel = <String, int>{
      for (final _AppointmentTrendPoint point in points)
        point.label: point.count,
    };
    final DateTime endPeriod = _resolveDefaultTrendEndDate(view, points);
    final List<String> labels = switch (view) {
      _TrendView.daily => _lastDailyTrendLabels(endPeriod),
      _TrendView.weekly => _lastWeeklyTrendLabels(endPeriod),
      _TrendView.monthly => _lastMonthlyTrendLabels(endPeriod),
    };

    return labels.map((String label) {
      return _AppointmentTrendPoint(
        label: label,
        count: countsByLabel[label] ?? 0,
      );
    }).toList();
  }

  String get _defaultExportWindowDescription {
    final _ReportDateRangeSelection range = _defaultExportDateRange(
      _selectedTrendView,
    );
    final String unit = switch (_selectedTrendView) {
      _TrendView.daily => 'days',
      _TrendView.weekly => 'weeks',
      _TrendView.monthly => 'months',
    };

    return 'last $_defaultTrendBucketLimit $unit (${_formatReportFilterDate(range.startDate)} to ${_formatReportFilterDate(range.endDate)})';
  }

  _ReportDateRangeSelection _defaultExportDateRange(_TrendView view) {
    final List<_AppointmentTrendPoint> points =
        _appointmentTrends[view] ?? const <_AppointmentTrendPoint>[];
    final DateTime endPeriod = _resolveDefaultTrendEndDate(view, points);

    switch (view) {
      case _TrendView.daily:
        final DateTime endDate = _dateOnly(endPeriod);
        return _ReportDateRangeSelection(
          startDate: endDate.subtract(
            const Duration(days: _defaultTrendBucketLimit - 1),
          ),
          endDate: endDate,
        );
      case _TrendView.weekly:
        final DateTime weekStart = _isoWeekStartDate(
          _isoWeekYear(endPeriod),
          _isoWeekNumber(endPeriod),
        );
        return _ReportDateRangeSelection(
          startDate: weekStart.subtract(
            const Duration(days: 7 * (_defaultTrendBucketLimit - 1)),
          ),
          endDate: weekStart.add(const Duration(days: 6)),
        );
      case _TrendView.monthly:
        final DateTime monthStart = DateTime(endPeriod.year, endPeriod.month);
        return _ReportDateRangeSelection(
          startDate: DateTime(
            monthStart.year,
            monthStart.month - (_defaultTrendBucketLimit - 1),
          ),
          endDate: DateTime(monthStart.year, monthStart.month + 1, 0),
        );
    }
  }

  DateTime _resolveDefaultTrendEndDate(
    _TrendView view,
    List<_AppointmentTrendPoint> points,
  ) {
    DateTime? latest;

    for (final _AppointmentTrendPoint point in points) {
      final DateTime? parsed = _parseTrendLabelDate(view, point.label);
      if (parsed == null) {
        continue;
      }

      if (latest == null || parsed.isAfter(latest)) {
        latest = parsed;
      }
    }

    return latest ?? _dateOnly(DateTime.now());
  }

  DateTime? _parseTrendLabelDate(_TrendView view, String label) {
    try {
      switch (view) {
        case _TrendView.daily:
          return _dateOnly(DateTime.parse(label));
        case _TrendView.weekly:
          final RegExpMatch? match = RegExp(
            r'^(\d{4})-W(\d{2})$',
          ).firstMatch(label);
          if (match == null) {
            return null;
          }

          final int year = int.parse(match.group(1)!);
          final int week = int.parse(match.group(2)!);
          return _isoWeekStartDate(year, week);
        case _TrendView.monthly:
          final List<String> parts = label.split('-');
          if (parts.length != 2) {
            return null;
          }

          return DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
      }
    } on FormatException {
      return null;
    } on RangeError {
      return null;
    }
  }

  List<String> _lastDailyTrendLabels(DateTime endDate) {
    final DateTime end = _dateOnly(endDate);

    return List<String>.generate(_defaultTrendBucketLimit, (int index) {
      return _formatReportFilterDate(
        end.subtract(Duration(days: _defaultTrendBucketLimit - 1 - index)),
      );
    });
  }

  List<String> _lastWeeklyTrendLabels(DateTime endDate) {
    final DateTime weekStart = _isoWeekStartDate(
      _isoWeekYear(endDate),
      _isoWeekNumber(endDate),
    );

    return List<String>.generate(_defaultTrendBucketLimit, (int index) {
      final DateTime date = weekStart.subtract(
        Duration(days: 7 * (_defaultTrendBucketLimit - 1 - index)),
      );
      return _isoWeekLabel(date);
    });
  }

  List<String> _lastMonthlyTrendLabels(DateTime endDate) {
    final DateTime monthStart = DateTime(endDate.year, endDate.month, 1);

    return List<String>.generate(_defaultTrendBucketLimit, (int index) {
      final DateTime date = DateTime(
        monthStart.year,
        monthStart.month - (_defaultTrendBucketLimit - 1 - index),
        1,
      );
      final String month = date.month.toString().padLeft(2, '0');
      return '${date.year}-$month';
    });
  }

  String _isoWeekLabel(DateTime date) {
    final int year = _isoWeekYear(date);
    final int week = _isoWeekNumber(date);
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  int _isoWeekYear(DateTime date) {
    return date.add(Duration(days: 4 - date.weekday)).year;
  }

  int _isoWeekNumber(DateTime date) {
    final DateTime target = date.add(Duration(days: 4 - date.weekday));
    final DateTime firstThursday = DateTime(target.year, 1, 4);
    final DateTime firstWeekStart = firstThursday.subtract(
      Duration(days: firstThursday.weekday - 1),
    );

    return 1 + target.difference(firstWeekStart).inDays ~/ 7;
  }

  DateTime _isoWeekStartDate(int year, int week) {
    final DateTime firstThursday = DateTime(year, 1, 4);
    final DateTime firstWeekStart = firstThursday.subtract(
      Duration(days: firstThursday.weekday - 1),
    );

    return firstWeekStart.add(Duration(days: (week - 1) * 7));
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

  double _trendPointX({
    required int index,
    required int pointCount,
    required double chartWidth,
  }) {
    if (pointCount <= 1) {
      return _AppointmentTrendChartPainter.chartLeftPadding +
          ((chartWidth -
                  _AppointmentTrendChartPainter.chartLeftPadding -
                  _AppointmentTrendChartPainter.chartRightPadding) /
              2);
    }

    final double plotWidth =
        chartWidth -
        _AppointmentTrendChartPainter.chartLeftPadding -
        _AppointmentTrendChartPainter.chartRightPadding;

    return _AppointmentTrendChartPainter.chartLeftPadding +
        ((plotWidth / (pointCount - 1)) * index);
  }

  Widget _buildDetailedReportTable() {
    final bool isPhone = MediaQuery.of(context).size.width < 800;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          top: BorderSide(color: Color(0xFF4A769E), width: 6.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.22 : 0.05),
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
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Rows are grouped by status and ordered from the earliest appointment IDs upward within each status.',
                  style: TextStyle(
                    fontSize: MobileTypography.bodySmall(context),
                    fontWeight: FontWeight.w600,
                    color: _mutedTextColor,
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
                child: CircularProgressIndicator(color: Color(0xFF4A769E)),
              ),
            )
          else if (_detailedRecords.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: AppEmptyState(
                key: const Key('admin-reports-detailed-empty-state'),
                icon: Icons.table_rows_outlined,
                title: _hasAppliedReportFilters
                    ? 'No report data found'
                    : 'No report records yet',
                message: _hasAppliedReportFilters
                    ? 'No detailed records match the selected filters.'
                    : 'Detailed appointment records will appear here once report data is available.',
                actionLabel: _hasAppliedReportFilters ? 'Reset Filters' : null,
                actionIcon: Icons.restart_alt_rounded,
                onAction: _hasAppliedReportFilters
                    ? () {
                        _resetReportFilters();
                      }
                    : null,
              ),
            )
          else
            Column(
              children: [
                AdminDataTable(
                  minWidth: isPhone
                      ? 860
                      : MediaQuery.of(context).size.width - 400,
                  columnSpacing: isPhone ? 22 : 32,
                  horizontalMargin: 18,
                  contentPadding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                  headingRowHeight: 58,
                  dataRowMinHeight: 68,
                  dataRowMaxHeight: 76,
                  columns: <DataColumn>[
                    DataColumn(
                      label: AdminDataTable.headerLabel(
                        'Date',
                        context: context,
                        width: 100,
                      ),
                    ),
                    DataColumn(
                      label: AdminDataTable.headerLabel(
                        'Patient',
                        context: context,
                        width: isPhone ? 160 : 220,
                      ),
                    ),
                    DataColumn(
                      label: AdminDataTable.headerLabel(
                        'Booking Type',
                        context: context,
                        width: 130,
                      ),
                    ),
                    DataColumn(
                      label: AdminDataTable.headerLabel(
                        'Service',
                        context: context,
                        width: isPhone ? 150 : 190,
                      ),
                    ),
                    DataColumn(
                      label: AdminDataTable.headerLabel(
                        'Queue No.',
                        context: context,
                        width: 90,
                        alignment: Alignment.center,
                      ),
                    ),
                    DataColumn(
                      label: AdminDataTable.headerLabel(
                        'Status',
                        context: context,
                        width: 180,
                        alignment: Alignment.center,
                      ),
                    ),
                  ],
                  rows: _detailedRecords.asMap().entries.map((entry) {
                    final int index = entry.key;
                    final Map<String, dynamic> record = entry.value;

                    return DataRow.byIndex(
                      index: index,
                      color: AdminDataTable.rowColor(index, context: context),
                      cells: <DataCell>[
                        DataCell(
                          AdminDataTable.cellText(
                            record['date']?.toString() ?? '-',
                            context: context,
                            width: 100,
                          ),
                        ),
                        DataCell(
                          AdminDataTable.cellText(
                            record['patient_name']?.toString() ?? '-',
                            context: context,
                            width: isPhone ? 160 : 220,
                            maxLines: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        DataCell(
                          AdminDataTable.cellText(
                            record['booking_type']?.toString() ?? '-',
                            context: context,
                            width: 130,
                            maxLines: 2,
                          ),
                        ),
                        DataCell(
                          AdminDataTable.cellText(
                            record['service']?.toString() ?? '-',
                            context: context,
                            width: isPhone ? 150 : 190,
                            maxLines: 2,
                          ),
                        ),
                        DataCell(
                          AdminDataTable.cellText(
                            record['queue_number']?.toString() ?? '-',
                            context: context,
                            width: 90,
                            alignment: Alignment.center,
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 180,
                            child: Align(
                              alignment: Alignment.center,
                              child: AppointmentStatusBadge(
                                status:
                                    record['status']?.toString() ?? 'Pending',
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
                  loadedItemCount: _detailedRecords.length,
                  totalItemCount: _totalDetailedRecords,
                  itemLabel: 'records',
                  hasMorePages: _hasMoreDetailedRecords,
                  isLoadingMore: _isLoadingMoreDetailedRecords,
                  onLoadMore: _loadMoreDetailedRecords,
                  loadMoreButtonKey: const Key('admin-reports-load-more'),
                ),
              ],
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDistributionChart() {
    final List<_StatusDistributionDatum> allSegments =
        <_StatusDistributionDatum>[
          _StatusDistributionDatum(
            label: 'Completed',
            subtitle: 'Finished appointments',
            value: _reportStats['completed'] ?? 0,
            color: const Color(0xFF1FBA8A),
          ),
          _StatusDistributionDatum(
            label: 'Approved',
            subtitle: 'Confirmed schedules',
            value: _reportStats['approved'] ?? 0,
            color: const Color(0xFF223C7A),
          ),
          _StatusDistributionDatum(
            label: 'Pending',
            subtitle: 'Awaiting action',
            value: _reportStats['pending'] ?? 0,
            color: const Color(0xFFFFB10A),
          ),
          _StatusDistributionDatum(
            label: 'Reschedule Required',
            subtitle: 'Needs new schedule',
            value: _reportStats['reschedule_required'] ?? 0,
            color: const Color(0xFF0E7490),
          ),
          _StatusDistributionDatum(
            label: 'Cancelled',
            subtitle: 'Patient cancellation',
            value: _reportStats['cancelled'] ?? 0,
            color: const Color(0xFFFF4E4E),
          ),
          _StatusDistributionDatum(
            label: 'Cancelled by Doctor',
            subtitle: 'Clinic cancellation',
            value: _reportStats['cancelled_by_doctor'] ?? 0,
            color: const Color(0xFFB91C1C),
          ),
        ];
    final List<_StatusDistributionDatum> segments = allSegments
        .where((_StatusDistributionDatum segment) => segment.value > 0)
        .toList(growable: false);
    final int total = segments.fold<int>(
      0,
      (int sum, _StatusDistributionDatum segment) => sum + segment.value,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: (_isDarkMode ? Colors.black : const Color(0xFF17305F))
                .withValues(alpha: _isDarkMode ? 0.22 : 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints outerConstraints) {
          return Padding(
            padding: _reportSectionPadding(outerConstraints.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _SectionIconBadge(
                      icon: Icons.pie_chart_outline_rounded,
                      iconColor: Color(0xFF9FB5E6),
                      backgroundColor: Color(0xFFF3F6FD),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'System Status Distribution',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: _reportAccent,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'STATISTICAL ANALYSIS OF PATIENT SCHEDULING STATUSES',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: _mutedTextColor,
                    letterSpacing: 1.8,
                  ),
                ),
                const SizedBox(height: 20),
                if (segments.isEmpty)
                  const AppEmptyState(
                    key: Key('status-distribution-empty-state'),
                    icon: Icons.pie_chart_outline_rounded,
                    title: 'No status data',
                    message:
                        'No appointment statuses match the current report filters.',
                    compact: true,
                    framed: false,
                    maxWidth: 360,
                  )
                else
                  LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final bool compact = constraints.maxWidth < 1280;
                          final double chartSize = math.min(
                            280,
                            math.max(
                              160,
                              constraints.maxWidth - (compact ? 24 : 120),
                            ),
                          );

                          final Widget chart = Center(
                            child: SizedBox(
                              width: chartSize,
                              height: chartSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: Size.square(chartSize),
                                    painter: _StatusDistributionPainter(
                                      segments: segments,
                                      total: total,
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        total == 0 ? '0%' : '100%',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          color: _reportAccent,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'AGGREGATE',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: _mutedTextColor,
                                          letterSpacing: 1.8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );

                          final Widget legend = Column(
                            children: segments.map((segment) {
                              final int percentage = total == 0
                                  ? 0
                                  : ((segment.value / total) * 100).round();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildDistributionStatCard(
                                  label: segment.label,
                                  subtitle: segment.subtitle,
                                  percentage: percentage,
                                  color: segment.color,
                                ),
                              );
                            }).toList(),
                          );

                          if (compact) {
                            return Column(
                              children: [
                                chart,
                                const SizedBox(height: 18),
                                legend,
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(flex: 6, child: chart),
                              const SizedBox(width: 20),
                              Expanded(flex: 7, child: legend),
                            ],
                          );
                        },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDistributionStatCard({
    required String label,
    required String subtitle,
    required int percentage,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _surfaceAltColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.14 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: _reportAccent,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: _mutedTextColor,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$percentage%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _reportAccent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      width: 240,
      height: 118,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _isDarkMode ? 0.16 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: accentColor),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: accentColor,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _textColor,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDistributionDatum {
  const _StatusDistributionDatum({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.color,
  });

  final String label;
  final String subtitle;
  final int value;
  final Color color;
}

class _SectionIconBadge extends StatelessWidget {
  const _SectionIconBadge({
    required this.icon,
    required this.iconColor,
    this.backgroundColor = const Color(0xFFF4F7FD),
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }
}

class _StatusDistributionPainter extends CustomPainter {
  const _StatusDistributionPainter({
    required this.segments,
    required this.total,
  });

  final List<_StatusDistributionDatum> segments;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.width / 2 - 18,
    );
    final List<_StatusDistributionDatum> visibleSegments = segments
        .where((_StatusDistributionDatum segment) => segment.value > 0)
        .toList(growable: false);

    if (total <= 0 || visibleSegments.isEmpty) {
      final Paint basePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFFF0F3FA);
      canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);
      return;
    }

    const double fullCircle = math.pi * 2;
    const double seamOverlap = 0.001;
    const double initialStartAngle = -math.pi / 2;
    double startAngle = -math.pi / 2;
    for (int index = 0; index < visibleSegments.length; index++) {
      final _StatusDistributionDatum segment = visibleSegments[index];
      final double proportionalSweep = (segment.value / total) * fullCircle;
      final bool isLastSegment = index == visibleSegments.length - 1;
      final double sweep = isLastSegment
          ? (initialStartAngle + fullCircle) - startAngle
          : proportionalSweep + seamOverlap;
      final Paint segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.butt
        ..color = segment.color;
      canvas.drawArc(rect, startAngle, sweep, false, segmentPaint);
      startAngle += proportionalSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusDistributionPainter oldDelegate) {
    return oldDelegate.total != total || oldDelegate.segments != segments;
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

  static const double chartLeftPadding = 48;
  static const double chartRightPadding = 16;

  @override
  void paint(Canvas canvas, Size size) {
    const double topPadding = 18;
    const double bottomPadding = 22;

    final Rect chartRect = Rect.fromLTWH(
      chartLeftPadding,
      topPadding,
      size.width - chartLeftPadding - chartRightPadding,
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
      ..strokeWidth = 3
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
      canvas.drawCircle(offset, 6.5, haloPaint);
      canvas.drawCircle(offset, 3.8, dotPaint);
      canvas.drawCircle(offset, 1.8, innerDotPaint);
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
