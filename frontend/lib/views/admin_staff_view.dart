import 'package:flutter/material.dart';

import '../services/admin_staff_service.dart';
import '../widgets/add_staff_dialog.dart';

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
          title: const Text('Remove Staff'),
          content: Text(
            'Deactivate ${_resolveStaffName(staffMember)} from the staff list?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
              ),
              child: const Text('Deactivate'),
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
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddStaffDialog(
        onSubmit: (data) => widget.adminStaffService.createStaff(data),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Staff account successfully created.'),
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
                  'Staff Accounts',
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
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF679B6A),
                  side: const BorderSide(color: Color(0xFF679B6A)),
                ),
              ),
              const SizedBox(width: 16),
              FilledButton.icon(
                onPressed: _isLoading ? null : _showAddStaffDialog,
                icon: const Icon(Icons.add),
                label: const Text(
                  'Add Staff',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF679B6A),
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
                  top: BorderSide(
                    color: Color(0xFF679B6A),
                    width: 6,
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
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Staff List',
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
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No staff accounts found.',
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
                        padding: const EdgeInsets.all(12),
                        scrollDirection: Axis.horizontal,
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.resolveWith(
                              (states) => Colors.transparent,
                            ),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Staff',
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
                            rows: _staffMembers.map((staffMember) {
                              final staffId = _readInt(staffMember['id']);
                              final isProcessing = _processingStaffId != null &&
                                  _processingStaffId == staffId;

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          _resolveStaffName(staffMember),
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                                        ),
                                        Text(
                                          _resolveStaffRecordId(staffMember),
                                          style: const TextStyle(fontSize: 13, color: Colors.black54),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _resolveText(staffMember['birthdate']),
                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _resolveGender(staffMember),
                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      _resolveContact(staffMember),
                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                    ),
                                  ),
                                  DataCell(
                                    isProcessing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : IconButton(
                                            onPressed: () => _confirmDeactivate(staffMember),
                                            icon: const Icon(
                                              Icons.person_remove_alt_1,
                                              color: Color(0xFFD32F2F),
                                            ),
                                            tooltip: 'Deactivate staff',
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

    final fullName = [firstName, middleName, lastName]
        .where((part) => part.isNotEmpty)
        .join(' ')
        .trim();

    return fullName.isEmpty ? '-' : fullName;
  }

  String _resolveContact(Map<String, dynamic> staffMember) {
    final staffRecord = _readMap(staffMember['staff_record']);
    final contact = staffRecord['contact_number'] ?? staffMember['phone_number'];

    return _resolveText(contact);
  }

  String _resolveGender(Map<String, dynamic> staffMember) {
    final staffRecord = _readMap(staffMember['staff_record']);
    final gender = staffRecord['gender'] ?? staffMember['gender'];
    final text = _resolveText(gender);
    if (text == '-') return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _resolveStaffRecordId(Map<String, dynamic> staffMember) {
    final staffRecord = _readMap(staffMember['staff_record']);
    final staffRecordId = staffRecord['staff_id'];

    if (staffRecordId != null && staffRecordId.toString().trim().isNotEmpty) {
      return staffRecordId.toString();
    }

    final userId = _readInt(staffMember['id']);

    return userId != null ? 'STAFF-$userId' : '-';
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
    return text.isEmpty ? '-' : text;
  }
}
