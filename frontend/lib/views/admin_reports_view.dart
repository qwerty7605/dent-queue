import 'package:flutter/material.dart';
import '../services/admin_dashboard_service.dart';

class AdminReportsView extends StatefulWidget {
  const AdminReportsView({
    super.key,
    required this.adminDashboardService,
  });

  final AdminDashboardService adminDashboardService;

  @override
  State<AdminReportsView> createState() => _AdminReportsViewState();
}

class _AdminReportsViewState extends State<AdminReportsView> {
  // Prep for API integration
  bool _isLoading = false;
  
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
    _fetchReportSummary();
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
                onPressed: _isLoading ? null : _fetchReportSummary,
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
        ],
      ),
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
