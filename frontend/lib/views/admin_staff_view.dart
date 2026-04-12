import 'package:flutter/material.dart';

import '../services/admin_staff_service.dart';
import '../widgets/add_staff_dialog.dart';
import '../widgets/app_empty_state.dart';

class AdminStaffView extends StatefulWidget {
  const AdminStaffView({
    super.key,
    required this.adminStaffService,
    this.onStaffChanged,
  });

  final AdminStaffService adminStaffService;
  final VoidCallback? onStaffChanged;

  @override
  State<AdminStaffView> createState() => _AdminStaffViewState();
}

class _AdminStaffViewState extends State<AdminStaffView> {
  List<Map<String, dynamic>> _staffMembers = [];
  bool _isLoading = true;
  int? _processingStaffId;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final staffMembers = await widget.adminStaffService.getAllStaff();
      if (!mounted) {
        return;
      }

      setState(() {
        _staffMembers = staffMembers;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load staff records')),
      );
    }
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> staffMember) async {
    final staffId = _readInt(staffMember['id']);
    if (staffId == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Deactivate Staff Account'),
          content: Text(
            'Are you sure you want to deactivate the account for ${_resolveStaffName(staffMember)}?',
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _processingStaffId = staffId;
    });

    try {
      final message = await widget.adminStaffService.deactivateStaff(staffId);
      if (!mounted) {
        return;
      }

      await _loadStaff();
      widget.onStaffChanged?.call();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF679B6A),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to deactivate staff account')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingStaffId = null;
        });
      }
    }
  }

  Future<void> _showAddStaffDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddStaffDialog(
        onSubmit: (data) => widget.adminStaffService.createStaff(data),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Account successfully created.',
          ),
          backgroundColor: Color(0xFF679B6A),
        ),
      );
      _loadStaff();
      widget.onStaffChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Staff & Intern Accounts',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _loadStaff,
                icon: const Icon(Icons.refresh),
                label: const Text(
                  'Refresh',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _isLoading ? null : _showAddStaffDialog,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Staff / Intern',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(color: Color(0xFF679B6A), width: 6),
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
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Staff & Intern List',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
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
                  else if (_staffMembers.isEmpty)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppEmptyState(
                          key: const Key('admin-staff-empty-state'),
                          icon: Icons.group_off_outlined,
                          title: 'No staff accounts yet',
                          message:
                              'Staff and intern accounts will appear here after they are created.',
                          actionLabel: 'Add Staff / Intern',
                          actionIcon: Icons.person_add_alt_1_rounded,
                          onAction: () {
                            _showAddStaffDialog();
                          },
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            horizontalMargin: 28,
                            columnSpacing: 44,
                            headingRowHeight: 60,
                            dataRowMinHeight: 72,
                            dataRowMaxHeight: 84,
                            headingRowColor: WidgetStateProperty.resolveWith(
                              (states) => Colors.transparent,
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'No.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Account',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Role',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Gender',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Contact',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Action',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ],
                            rows: _staffMembers.asMap().entries.map((entry) {
                              final index = entry.key;
                              final staffMember = entry.value;
                              final staffId = _readInt(staffMember['id']);
                              final isProcessing =
                                  _processingStaffId != null &&
                                  _processingStaffId == staffId;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 52,
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: 220,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            _resolveStaffName(staffMember),
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _resolveStaffRecordId(staffMember),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 100,
                                      child: Text(
                                        _resolveRoleLabel(staffMember),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF356042),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        _resolveGender(staffMember),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 160,
                                      child: Text(
                                        _resolveContact(staffMember),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 84,
                                      child: Center(
                                        child: isProcessing
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : IconButton(
                                                onPressed: () =>
                                                    _confirmDeactivate(
                                                      staffMember,
                                                    ),
                                                icon: const Icon(
                                                  Icons.person_remove_alt_1,
                                                  color: Color(0xFFD32F2F),
                                                ),
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

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '');
  }

  String _resolveStaffName(Map<String, dynamic> staffMember) {
    final firstName = staffMember['first_name']?.toString().trim() ?? '';
    final middleName = staffMember['middle_name']?.toString().trim() ?? '';
    final lastName = staffMember['last_name']?.toString().trim() ?? '';

    final fullName = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ').trim();

    return fullName.isEmpty ? 'No data yet' : fullName;
  }

  String _resolveContact(Map<String, dynamic> staffMember) {
    final staffRecord = _readMap(staffMember['staff_record']);
    final contact =
        staffRecord['contact_number'] ?? staffMember['phone_number'];

    return _resolveText(contact);
  }

  String _resolveRoleLabel(Map<String, dynamic> staffMember) {
    final role = _readMap(staffMember['role']);
    final name = role['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Staff' : name;
  }

  String _resolveGender(Map<String, dynamic> staffMember) {
    final staffRecord = _readMap(staffMember['staff_record']);
    final gender = staffRecord['gender'] ?? staffMember['gender'];
    final text = _resolveText(gender);
    if (text == 'No data yet') return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _resolveStaffRecordId(Map<String, dynamic> staffMember) {
    final staffRecord = _readMap(staffMember['staff_record']);
    final staffRecordId = staffRecord['staff_id'];

    if (staffRecordId != null && staffRecordId.toString().trim().isNotEmpty) {
      return staffRecordId.toString();
    }

    final userId = _readInt(staffMember['id']);

    return userId != null ? 'STAFF-$userId' : 'No data yet';
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
  }

  String _resolveText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'No data yet' : text;
  }
}
