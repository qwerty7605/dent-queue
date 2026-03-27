import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';
import '../services/appointment_service.dart';

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
  // Prep for API integration
  bool _isLoading = true;
  List<Map<String, dynamic>> _detailedRecords = [];
  
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
    await Future.wait([
      _fetchReportSummary(),
      _fetchDetailedRecords(),
    ]);
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
                value: _isLoading ? '...' : _reportStats['completed'].toString(),
                icon: Icons.done_all,
                mainColor: const Color(0xFF4CAF50), // Greenish
                darkColor: const Color(0xFF388E3C),
              ),
              _buildReportCard(
                title: 'Cancelled',
                value: _isLoading ? '...' : _reportStats['cancelled'].toString(),
                icon: Icons.cancel_outlined,
                mainColor: const Color(0xFFE28B71), // Orange Red
                darkColor: const Color(0xFFBA6952),
              ),
            ],
          ),
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

  Widget _buildDetailedReportTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          top: BorderSide(
            color: Color(0xFF679B6A),
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
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Patient', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Booking Type', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Service', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Queue No.', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _detailedRecords.map((record) {
                    return DataRow(cells: [
                      DataCell(Text(record['date']?.toString() ?? '-')),
                      DataCell(Text(record['patient_name']?.toString() ?? '-')),
                      DataCell(Text(record['booking_type']?.toString() ?? '-')),
                      DataCell(Text(record['service']?.toString() ?? '-')),
                      DataCell(Text(record['queue_number']?.toString() ?? '-')),
                      DataCell(_buildStatusBadge(record['status']?.toString() ?? 'Pending')),
                    ]);
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
              Expanded(child: _buildChartRow('Pending', _reportStats['pending'] ?? 0, total, const Color(0xFFE5CC82))),
              const SizedBox(width: 48),
              Expanded(child: _buildChartRow('Approved', _reportStats['approved'] ?? 0, total, const Color(0xFF86B9B0))),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildChartRow('Completed', _reportStats['completed'] ?? 0, total, const Color(0xFF4CAF50))),
              const SizedBox(width: 48),
              Expanded(child: _buildChartRow('Cancelled', _reportStats['cancelled'] ?? 0, total, const Color(0xFFE28B71))),
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
      height: 160,
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
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 24.0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
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
            Icon(
              icon,
              size: 64,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
