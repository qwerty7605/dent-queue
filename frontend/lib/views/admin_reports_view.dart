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
  _TrendView _selectedTrendView = _TrendView.daily;

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

  String get _reportExportScopeTitle {
    if (_hasAppliedReportFilters) {
      return 'Current report filters will be exported';
    }

    return 'Export will include all report records';
  }

  String get _reportExportScopeBody {
    if (_hasAppliedReportFilters) {
      return 'The downloaded file uses the same date range, status, and booking type filters currently applied to the report cards, trends, and detailed table.';
    }

    return 'No filters are active, so the download will include the same unfiltered report data currently shown on screen.';
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
                        'Choose the file format. The export will use the same filters applied to the report table.',
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
                                  color: _surfaceColor,
                                  borderRadius: BorderRadius.circular(
                                    _reportSectionRadius,
                                  ),
                                  border: Border.all(color: _borderColor),
                                ),
                                child: Text(
                                  'All dates, statuses, and booking types are included in this export.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _mutedTextColor,
                                  ),
                                ),
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
                              onTap: () =>
                                  _pickReportFilterDate(isStartDate: true),
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
                              onTap: () =>
                                  _pickReportFilterDate(isStartDate: false),
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
        foregroundColor: _reportAccent,
        backgroundColor: _surfaceColor,
        side: BorderSide(color: _borderColor),
        minimumSize: const Size(220, 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExporting)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
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
                                  _TrendView.daily => 56,
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
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 34,
                                          right: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            for (final _AppointmentTrendPoint
                                                point
                                                in displayPoints)
                                              SizedBox(
                                                width: pointWidth,
                                                child: Text(
                                                  point.label,
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
          children: _TrendView.values.map(_buildTrendViewButton).toList(),
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
    final int completed = _reportStats['completed'] ?? 0;
    final int approved = _reportStats['approved'] ?? 0;
    final int pending =
        (_reportStats['pending'] ?? 0) +
        (_reportStats['reschedule_required'] ?? 0);
    final int cancelled =
        (_reportStats['cancelled'] ?? 0) +
        (_reportStats['cancelled_by_doctor'] ?? 0);
    final int total = completed + approved + pending + cancelled;
    final List<_StatusDistributionDatum> segments = <_StatusDistributionDatum>[
      _StatusDistributionDatum(
        label: 'Completed',
        subtitle: 'Operational Metrics',
        value: completed,
        color: const Color(0xFF1FBA8A),
      ),
      _StatusDistributionDatum(
        label: 'Approved',
        subtitle: 'Operational Metrics',
        value: approved,
        color: const Color(0xFF223C7A),
      ),
      _StatusDistributionDatum(
        label: 'Pending',
        subtitle: 'Operational Metrics',
        value: pending,
        color: const Color(0xFFFFB10A),
      ),
      _StatusDistributionDatum(
        label: 'Cancelled',
        subtitle: 'Operational Metrics',
        value: cancelled,
        color: const Color(0xFFFF4E4E),
      ),
    ];

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
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final bool compact = constraints.maxWidth < 1080;
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
                        children: [chart, const SizedBox(height: 18), legend],
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
    final Paint basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 44
      ..strokeCap = StrokeCap.butt
      ..color = const Color(0xFFF0F3FA);
    canvas.drawArc(rect, 0, math.pi * 2, false, basePaint);

    if (total <= 0) {
      return;
    }

    const double gapRadians = 0.16;
    double startAngle = -math.pi / 2;
    for (final _StatusDistributionDatum segment in segments) {
      if (segment.value <= 0) {
        continue;
      }

      final double sweep =
          ((segment.value / total) * (math.pi * 2)) - gapRadians;
      final Paint segmentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.butt
        ..color = segment.color;
      canvas.drawArc(rect, startAngle, sweep, false, segmentPaint);
      startAngle += sweep + gapRadians;
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
