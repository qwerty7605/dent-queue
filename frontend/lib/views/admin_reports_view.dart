import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';

enum _TrendView { daily, weekly, monthly }

class _AppointmentTrendPoint {
  const _AppointmentTrendPoint({required this.label, required this.count});

  final String label;
  final int count;
}

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({
    super.key,
    required this.adminDashboardService,
    required this.appointmentService,
  });

  final AdminDashboardService adminDashboardService;
  final AppointmentService appointmentService;

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  static const Color _reportAccent = Color(0xFF3F6341);
  static const Color _reportAccentSoft = Color(0xFF6A9A8B);
  static const Color _reportHighlight = Color(0xFFE8C355);

  // Prep for API integration
  bool _isLoading = true;
  List<Map<String, dynamic>> _detailedRecords = [];

  // Filled by the reports endpoint later; placeholder buckets keep the chart
  // layout stable before backend integration lands.
  final Map<_TrendView, List<_AppointmentTrendPoint>> _appointmentTrends =
      <_TrendView, List<_AppointmentTrendPoint>>{
        _TrendView.daily: const <_AppointmentTrendPoint>[],
        _TrendView.weekly: const <_AppointmentTrendPoint>[],
        _TrendView.monthly: const <_AppointmentTrendPoint>[],
      };
  _TrendView _selectedTrendView = _TrendView.daily;

  // Dummy values based on acceptance criteria to ensure zero values do not break UI
  Map<String, int> _reportStats = {
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
    await Future.wait([_fetchReportSummary(), _fetchDetailedRecords()]);
  }

  Future<void> _fetchDetailedRecords() async {
    try {
      final records = await widget.appointmentService.getAdminMasterList();
      if (!mounted) return;
      setState(() {
        _detailedRecords = records;
      });
    } catch (_) {
      // Silently fail or handle error
    }
  }

  Future<void> _fetchReportSummary() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final stats = await widget.adminDashboardService.getReportSummary();
      if (!mounted) return;
      setState(() {
        _reportStats = stats;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load report summary')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reports',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _fetchData,
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
          const SizedBox(height: 48),

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
                mainColor: const Color(0xFFE5CC82), // Sand Yellow
                darkColor: const Color(0xFFBCA663),
              ),
              _buildReportCard(
                title: 'Approved',
                value: _isLoading ? '...' : _reportStats['approved'].toString(),
                icon: Icons.check_circle_outline,
                mainColor: const Color(0xFF86B9B0), // Teal
                darkColor: const Color(0xFF6E9A92),
              ),
              _buildReportCard(
                title: 'Completed',
                value: _isLoading
                    ? '...'
                    : _reportStats['completed'].toString(),
                icon: Icons.done_all,
                mainColor: const Color(0xFF4CAF50), // Greenish
                darkColor: const Color(0xFF388E3C),
              ),
              _buildReportCard(
                title: 'Cancelled',
                value: _isLoading
                    ? '...'
                    : _reportStats['cancelled'].toString(),
                icon: Icons.cancel_outlined,
                mainColor: const Color(0xFFE28B71), // Orange Red
                darkColor: const Color(0xFFBA6952),
              ),
            ],
          ),
          const SizedBox(height: 56),

          _buildAppointmentTrendsSection(),
          const SizedBox(height: 56),

          // Status Distribution Chart Section
          _buildDistributionChart(),
          const SizedBox(height: 56),

          // Detailed Report Table Section
          _buildDetailedReportTable(),
        ],
      ),
    );
  }

  Widget _buildAppointmentTrendsSection() {
    final List<_AppointmentTrendPoint> points = _currentTrendPoints;
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
        borderRadius: BorderRadius.circular(18),
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
                  value: hasRealData ? 'Live' : 'API pending',
                  icon: hasRealData ? Icons.cloud_done : Icons.cloud_off,
                  emphasize: !hasRealData,
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
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
                          borderRadius: BorderRadius.circular(999),
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
                              borderRadius: BorderRadius.circular(18),
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
                        if (!hasRealData)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFD7E2D8),
                                ),
                              ),
                              child: const Text(
                                'Chart is ready for API integration.',
                                style: TextStyle(
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
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        key: Key('appointment-trends-${view.name}'),
        onTap: () {
          if (view == _selectedTrendView) {
            return;
          }

          setState(() {
            _selectedTrendView = view;
          });
        },
        borderRadius: BorderRadius.circular(999),
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
        borderRadius: BorderRadius.circular(14),
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
          const Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'Detailed Records',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
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
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: MediaQuery.of(context).size.width - 400,
                ),
                child: DataTable(
                  headingRowHeight: 64,
                  dataRowMinHeight: 64,
                  dataRowMaxHeight: 64,
                  columns: const [
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Patient',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Booking Type',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Service',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Queue No.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _detailedRecords.map((record) {
                    return DataRow(
                      cells: [
                        DataCell(Text(record['date']?.toString() ?? '-')),
                        DataCell(
                          Text(record['patient_name']?.toString() ?? '-'),
                        ),
                        DataCell(
                          Text(record['booking_type']?.toString() ?? '-'),
                        ),
                        DataCell(Text(record['service']?.toString() ?? '-')),
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
