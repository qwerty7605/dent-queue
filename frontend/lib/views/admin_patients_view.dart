import 'package:flutter/material.dart';

import '../services/patient_record_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/admin_data_table.dart';

class AdminPatientsView extends StatefulWidget {
  const AdminPatientsView({super.key, required this.patientRecordService});

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

  Future<void> _confirmDeactivate(Map<String, dynamic> patient) async {
    final patientId = patient['patient_id']?.toString();
    if (patientId == null) return;

    final fullName = patient['full_name']?.toString() ?? 'this patient';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppAlertDialog(
          title: const Text('Deactivate Patient Account'),
          content: Text(
            'Are you sure you want to deactivate the account for $fullName?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Active'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
              child: const Text('Deactivate Account'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    try {
      final message = await widget.patientRecordService.deactivatePatient(
        patientId,
      );
      if (!mounted) return;

      await _loadPatients();

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF679B6A),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to deactivate patient account')),
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
                      child: AdminDataTable(
                        minWidth: 760,
                        columnSpacing: 26,
                        columns: <DataColumn>[
                          DataColumn(
                            label: AdminDataTable.headerLabel(
                              'No.',
                              width: 52,
                              alignment: Alignment.center,
                            ),
                          ),
                          DataColumn(
                            label: AdminDataTable.headerLabel(
                              'Patient',
                              width: 240,
                            ),
                          ),
                          DataColumn(
                            label: AdminDataTable.headerLabel(
                              'Gender',
                              width: 108,
                            ),
                          ),
                          DataColumn(
                            label: AdminDataTable.headerLabel(
                              'Contact',
                              width: 170,
                            ),
                          ),
                          DataColumn(
                            label: AdminDataTable.headerLabel(
                              'Action',
                              width: 72,
                              alignment: Alignment.center,
                            ),
                          ),
                        ],
                        rows: _patients.asMap().entries.map((entry) {
                          final int index = entry.key;
                          final Map<String, dynamic> patient = entry.value;

                          return DataRow.byIndex(
                            index: index,
                            color: AdminDataTable.rowColor(index),
                            cells: <DataCell>[
                              DataCell(
                                AdminDataTable.cellText(
                                  '${index + 1}',
                                  width: 52,
                                  alignment: Alignment.center,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              DataCell(
                                AdminDataTable.cellText(
                                  _displayText(patient['full_name']),
                                  width: 240,
                                  maxLines: 2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              DataCell(
                                AdminDataTable.cellText(
                                  _displayText(patient['gender']),
                                  width: 108,
                                ),
                              ),
                              DataCell(
                                AdminDataTable.cellText(
                                  _displayText(patient['contact_number']),
                                  width: 170,
                                  maxLines: 2,
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 72,
                                  child: Center(
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Color(0xFFD32F2F),
                                      ),
                                      onPressed: () =>
                                          _confirmDeactivate(patient),
                                      tooltip: 'Deactivate account',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
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

  String _displayText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return 'No data yet';
    }

    return text;
  }
}
