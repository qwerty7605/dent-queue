import 'package:flutter/material.dart';
import '../services/patient_record_service.dart';

class AdminPatientsView extends StatefulWidget {
  const AdminPatientsView({
    super.key,
    required this.patientRecordService,
  });

  final PatientRecordService patientRecordService;

  @override
  State<AdminPatientsView> createState() => _AdminPatientsViewState();
}

class _AdminPatientsViewState extends State<AdminPatientsView> {
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final patients = await widget.patientRecordService.getAllPatients();
      if (!mounted) return;
      setState(() {
        _patients = patients;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      // Handle error visually if necessary
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load patient records')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          const Text(
            'Patients Accounts',
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
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: const Text(
                      'Patient List',
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
                                'Birthday',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            DataColumn(
                              label: Text(
                                'Gender',
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
                                'Action',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ],
                          rows: _patients.map((patient) {
                            return DataRow(
                              cells: [
                                DataCell(Text(
                                  patient['full_name']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(Text(
                                  patient['birthdate']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(Text(
                                  patient['gender']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(Text(
                                  patient['contact_number']?.toString() ?? '-',
                                  style: const TextStyle(fontSize: 15, color: Colors.black87),
                                )),
                                DataCell(
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Color(0xFFD32F2F)),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Deactivate patient ${patient['full_name']} (To be implemented)'),
                                        ),
                                      );
                                    },
                                    tooltip: 'Remove / Deactivate',
                                  ),
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
}
