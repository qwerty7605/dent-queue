import 'package:flutter/material.dart';
import '../services/appointment_service.dart';

enum _MasterListFilter { all, approved, cancelled, completed, pending }

class AdminMasterListView extends StatefulWidget {
  const AdminMasterListView({
    super.key,
    required this.appointmentService,
  });

  final AppointmentService appointmentService;

  @override
  State<AdminMasterListView> createState() => _AdminMasterListViewState();
}

class _AdminMasterListViewState extends State<AdminMasterListView> {
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  _MasterListFilter _selectedFilter = _MasterListFilter.all;

  @override
  void initState() {
    super.initState();
    _loadMasterList();
  }

  Future<void> _loadMasterList() async {
    setState(() {
      _isLoading = true;
    });

    try {
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
    if (_selectedFilter == _MasterListFilter.all) {
      return _appointments;
    }

    return _appointments.where((appointment) {
      final status = _normalizeStatus(appointment['status']?.toString());

      return switch (_selectedFilter) {
        _MasterListFilter.approved => status == 'approved',
        _MasterListFilter.cancelled => status == 'cancelled',
        _MasterListFilter.completed => status == 'completed',
        _MasterListFilter.pending => status == 'pending',
        _MasterListFilter.all => true,
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
                onPressed: _isLoading ? null : _loadMasterList,
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
                _buildFilterButton('Approved', _MasterListFilter.approved),
                _buildFilterButton('Cancelled', _MasterListFilter.cancelled),
                _buildFilterButton('Completed', _MasterListFilter.completed),
                _buildFilterButton('Pending', _MasterListFilter.pending),
              ],
            ),
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Service',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Date',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Contact',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Status',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                          rows: filteredAppointments.map((appointment) {
                            final status = appointment['status']?.toString() ?? 'Unknown';
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  appointment['patient_name']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(Text(
                                  appointment['service']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(Text(
                                  appointment['date']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(
                                  Text(
                                    appointment['contact']?.toString() ?? '-',
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: status.toLowerCase() == 'cancelled' ? Colors.blue[700] : Colors.black87,
                                      decoration: status.toLowerCase() == 'cancelled' ? TextDecoration.underline : TextDecoration.none,
                                      decorationColor: Colors.blue[700],
                                    ),
                                  ),
                                ),
                                DataCell(
                                  _buildStatusBadge(status),
                                ),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
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
