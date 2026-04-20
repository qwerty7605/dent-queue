import 'package:flutter/material.dart';

import '../services/patient_record_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/admin_data_table.dart';
import '../widgets/paginated_table_footer.dart';

class AdminPatientsView extends StatefulWidget {
  const AdminPatientsView({super.key, required this.patientRecordService});

  final PatientRecordService patientRecordService;

  @override
  State<AdminPatientsView> createState() => _AdminPatientsViewState();
}

class _AdminPatientsViewState extends State<AdminPatientsView> {
  static const int _pageSize = 25;

  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMorePages = false;
  int _currentPage = 0;
  int _totalPatients = 0;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (forceRefresh) {
        widget.patientRecordService.invalidatePatientCaches();
      }

      final patientsPage = await widget.patientRecordService.getPatientsPage(
        page: 1,
        perPage: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _patients = patientsPage.items;
        _currentPage = patientsPage.currentPage;
        _totalPatients = patientsPage.totalItems;
        _hasMorePages = patientsPage.hasMorePages;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      // Handle error visually if necessary
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load patient records')),
      );
    }
  }

  Future<void> _loadMorePatients() async {
    if (_isLoading || _isLoadingMore || !_hasMorePages) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final patientsPage = await widget.patientRecordService.getPatientsPage(
        page: _currentPage + 1,
        perPage: _pageSize,
      );
      if (!mounted) return;

      setState(() {
        _patients = <Map<String, dynamic>>[..._patients, ...patientsPage.items];
        _currentPage = patientsPage.currentPage;
        _totalPatients = patientsPage.totalItems;
        _hasMorePages = patientsPage.hasMorePages;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load more patient records')),
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

      await _loadPatients(forceRefresh: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF4A769E),
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
    final bool compactHeader = MediaQuery.sizeOf(context).width < 1100;
    final EdgeInsets pagePadding = MediaQuery.sizeOf(context).width < 900
        ? const EdgeInsets.all(16)
        : const EdgeInsets.all(24);
    final Widget title = const Text(
      'Patients Accounts',
      style: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );

    return SingleChildScrollView(
      padding: pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactHeader)
            title
          else
            Row(children: [Expanded(child: title)]),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: const Border(
                top: BorderSide(color: Color(0xFF4A769E), width: 6.0),
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 96),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A769E),
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      AdminDataTable(
                              enableVerticalScroll: false,
                              minWidth: 720,
                              columnSpacing: 18,
                              horizontalMargin: 14,
                              contentPadding: const EdgeInsets.fromLTRB(
                                12,
                                8,
                                12,
                                12,
                              ),
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
                                    width: 220,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Gender',
                                    width: 96,
                                  ),
                                ),
                                DataColumn(
                                  label: AdminDataTable.headerLabel(
                                    'Contact',
                                    width: 150,
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
                                final Map<String, dynamic> patient =
                                    entry.value;

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
                                        width: 220,
                                        maxLines: 2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    DataCell(
                                      AdminDataTable.cellText(
                                        _displayText(patient['gender']),
                                        width: 96,
                                      ),
                                    ),
                                    DataCell(
                                      AdminDataTable.cellText(
                                        _displayText(patient['contact_number']),
                                        width: 150,
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
                      PaginatedTableFooter(
                        loadedItemCount: _patients.length,
                        totalItemCount: _totalPatients,
                        itemLabel: 'patients',
                        hasMorePages: _hasMorePages,
                        isLoadingMore: _isLoadingMore,
                        onLoadMore: _loadMorePatients,
                        loadMoreButtonKey: const Key(
                          'admin-patients-load-more',
                        ),
                      ),
                    ],
                  ),
              ],
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
