import 'package:flutter/material.dart';

class AdminMasterListView extends StatelessWidget {
  const AdminMasterListView({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> appointments = [
      {
        'Patient': 'Kyle Josh Aldea',
        'Service': 'Dental Check-up',
        'Date': '2026/01/2',
        'Contact': '09169014483',
        'Status': 'Completed',
      },
      {
        'Patient': 'Aldrin clyde Grandeza',
        'Service': 'Root Canal',
        'Date': '2026/02/22',
        'Contact': '09274448237',
        'Status': 'Cancelled',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          const Text(
            'Master List',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 24),
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
                      'Master List',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1, color: Colors.black12),
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
                        rows: appointments.map((appointment) {
                          return DataRow(
                            cells: [
                              DataCell(Text(
                                appointment['Patient']!,
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              )),
                              DataCell(Text(
                                appointment['Service']!,
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              )),
                              DataCell(Text(
                                appointment['Date']!,
                                style: const TextStyle(fontSize: 15, color: Colors.black87),
                              )),
                              DataCell(
                                Text(
                                  appointment['Contact']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: appointment['Status'] == 'Cancelled' ? Colors.blue[700] : Colors.black87,
                                    decoration: appointment['Status'] == 'Cancelled' ? TextDecoration.underline : TextDecoration.none,
                                    decorationColor: Colors.blue[700],
                                  ),
                                ),
                              ),
                              DataCell(
                                _buildStatusBadge(appointment['Status']!),
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
}
