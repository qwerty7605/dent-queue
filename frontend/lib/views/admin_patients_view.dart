import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/patient_record_service.dart';
import '../widgets/app_alert_dialog.dart';

class AdminPatientsView extends StatefulWidget {
  const AdminPatientsView({super.key, required this.patientRecordService});

  final PatientRecordService patientRecordService;

  @override
  State<AdminPatientsView> createState() => _AdminPatientsViewState();
}

class _AdminPatientsViewState extends State<AdminPatientsView> {
  static const int _pageSize = 5;
  static const Color _surface = Colors.white;
  static const Color _outline = Color(0xFFE3EAF6);
  static const Color _text = Color(0xFF1D3264);
  static const Color _muted = Color(0xFF667792);
  static const Color _softBlue = Color(0xFFF3F6FF);
  static const Color _softBlueBorder = Color(0xFFE6ECF8);
  static const Color _dangerBg = Color(0xFFFFF5F4);
  static const Color _dangerBorder = Color(0xFFF2E0E0);
  static const Color _danger = Color(0xFFE37979);

  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _patients = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isSearching = false;
  bool _hasMorePages = false;
  int _currentPage = 1;
  int _totalPatients = 0;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients({
    bool forceRefresh = false,
    int page = 1,
    String? query,
  }) async {
    final String normalizedQuery = (query ?? _activeQuery).trim();

    setState(() {
      _isLoading = normalizedQuery.isEmpty;
      _isSearching = normalizedQuery.isNotEmpty;
      _activeQuery = normalizedQuery;
    });

    try {
      if (forceRefresh) {
        widget.patientRecordService.invalidatePatientCaches();
      }

      if (normalizedQuery.isNotEmpty) {
        final List<Map<String, dynamic>> results = await widget
            .patientRecordService
            .searchPatients(normalizedQuery);
        if (!mounted) {
          return;
        }
        setState(() {
          _patients = results;
          _currentPage = 1;
          _totalPatients = results.length;
          _hasMorePages = false;
          _isLoading = false;
          _isSearching = false;
        });
        return;
      }

      final patientsPage = await widget.patientRecordService.getPatientsPage(
        page: page,
        perPage: _pageSize,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _patients = patientsPage.items;
        _currentPage = patientsPage.currentPage;
        _totalPatients = patientsPage.totalItems;
        _hasMorePages = patientsPage.hasMorePages;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load patient records')),
      );
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadPatients(query: value, page: 1);
    });
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> patient) async {
    final String? patientId = patient['patient_id']?.toString();
    if (patientId == null) {
      return;
    }

    final String fullName = patient['full_name']?.toString() ?? 'this patient';

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AppAlertDialog(
          title: const Text('Deactivate Patient Account'),
          content: Text(
            'Are you sure you want to deactivate the account for $fullName?',
          ),
          actions: <Widget>[
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

    try {
      final String message = await widget.patientRecordService
          .deactivatePatient(patientId);
      if (!mounted) {
        return;
      }

      await _loadPatients(forceRefresh: true, page: _currentPage);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: const Color(0xFF4A769E),
          ),
        );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to deactivate patient account')),
      );
    }
  }

  Future<void> _showPatientProfile(Map<String, dynamic> patient) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AppAlertDialog(
          title: Text(patient['full_name']?.toString() ?? 'Patient Details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _DetailLine(
                label: 'Patient ID',
                value: _displayText(patient['patient_id']),
              ),
              _DetailLine(
                label: 'Gender',
                value: _displayText(patient['gender']),
              ),
              _DetailLine(
                label: 'Birthdate',
                value: _formatPatientBirthdate(patient['birthdate']),
              ),
              _DetailLine(
                label: 'Contact',
                value: _displayText(patient['contact_number']),
              ),
              _DetailLine(
                label: 'Account Type',
                value: _displayText(patient['patient_type']),
              ),
              _DetailLine(
                label: 'Status',
                value: _displayText(patient['account_status']),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final EdgeInsets pagePadding = EdgeInsets.fromLTRB(
      width < 900 ? 16 : 26,
      22,
      width < 900 ? 16 : 26,
      28,
    );

    return RefreshIndicator(
      onRefresh: () => _loadPatients(forceRefresh: true, page: _currentPage),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildSearchBar(),
            const SizedBox(height: 22),
            _buildPatientSheet(),
            const SizedBox(height: 16),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620, minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141C2E) : _surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF2B3956) : _outline,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x080E1A3A),
              blurRadius: 16,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search_rounded, color: _muted, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _handleSearchChanged,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _text,
                ),
                decoration: const InputDecoration(
                  hintText:
                      'Filter accounts by name, patient ID, or primary contact info...',
                  hintStyle: TextStyle(
                    color: Color(0xFFC1CADC),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.only(left: 6),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_searchController.text.trim().isNotEmpty)
              IconButton(
                onPressed: () {
                  _searchController.clear();
                  _loadPatients(query: '', page: 1);
                },
                icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                splashRadius: 16,
                tooltip: 'Clear search',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSheet() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141C2E) : _surface,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: isDark ? const Color(0xFF2B3956) : _outline,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x080E1A3A),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: _PatientsHeaderRow(),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF182132) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF2B3956)
                    : const Color(0xFFEEF2FA),
              ),
            ),
            child: _isLoading
                ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 96),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF1F356C),
                              ),
                            ),
                          )
                : _patients.isEmpty
                ? Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 72,
                            ),
                            child: Column(
                              children: <Widget>[
                                const Icon(
                                  Icons.person_search_outlined,
                                  size: 36,
                                  color: _muted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _activeQuery.isEmpty
                                      ? 'No patient records found'
                                      : 'No accounts matched your search',
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                : Column(
                            children: List<Widget>.generate(_patients.length, (
                              int index,
                            ) {
                              final Map<String, dynamic> patient =
                                  _patients[index];
                              return Column(
                                children: <Widget>[
                                  if (index > 0)
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: Color(0xFFF2F5FB),
                                    ),
                                  _PatientRow(
                                    patient: patient,
                                    onView: () => _showPatientProfile(patient),
                                    onDelete: () => _confirmDeactivate(patient),
                                  ),
                                ],
                              );
                            }),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final bool searching = _activeQuery.isNotEmpty;
    final int totalPages = ((_totalPatients + _pageSize - 1) / _pageSize)
        .floor();
    final int currentVisibleCount = _patients.length;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'REGISTRY OVERVIEW',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              searching
                  ? 'Showing $currentVisibleCount matching account${currentVisibleCount == 1 ? '' : 's'}'
                  : 'Displaying ${_rangeStart()}-${_rangeEnd()} of $_totalPatients validated records',
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );

        final Widget? pagination = !searching && totalPages > 0
            ? Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  _PageNavButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _currentPage > 1,
                    onTap: () => _loadPatients(page: _currentPage - 1),
                  ),
                  ..._visiblePages(totalPages).map((int page) {
                    final bool active = page == _currentPage;
                    return _PageNumberButton(
                      label: page.toString(),
                      active: active,
                      onTap: () => _loadPatients(page: page),
                    );
                  }),
                  _PageNavButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _hasMorePages,
                    onTap: () => _loadPatients(page: _currentPage + 1),
                  ),
                ],
              )
            : null;

        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              summary,
              if (pagination != null) ...<Widget>[
                const SizedBox(height: 16),
                pagination,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: summary),
            if (pagination case final Widget paginationWidget) paginationWidget,
          ],
        );
      },
    );
  }

  List<int> _visiblePages(int totalPages) {
    if (totalPages <= 4) {
      return List<int>.generate(totalPages, (int index) => index + 1);
    }

    if (_currentPage <= 2) {
      return <int>[1, 2, 3, 4];
    }

    if (_currentPage >= totalPages - 1) {
      return <int>[totalPages - 3, totalPages - 2, totalPages - 1, totalPages];
    }

    return <int>[
      _currentPage - 1,
      _currentPage,
      _currentPage + 1,
      _currentPage + 2,
    ];
  }

  int _rangeStart() {
    if (_totalPatients == 0) {
      return 0;
    }
    return ((_currentPage - 1) * _pageSize) + 1;
  }

  int _rangeEnd() {
    if (_totalPatients == 0) {
      return 0;
    }
    return (_rangeStart() + _patients.length - 1).clamp(0, _totalPatients);
  }

  String _displayText(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'No data yet' : text;
  }
}

String _formatPatientBirthdate(dynamic value) {
  final String raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return 'BORN: No data yet';
  }

  final DateTime? parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return 'BORN: $raw';
  }

  return 'BORN: ${DateFormat('yyyy-MM-dd').format(parsed)}';
}

class _PatientsHeaderRow extends StatelessWidget {
  const _PatientsHeaderRow();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final TextStyle style = TextStyle(
      color: isDark
          ? const Color(0xFFAAB8D4)
          : _AdminPatientsViewState._muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    );

    return Row(
      children: <Widget>[
        Expanded(flex: 4, child: Text('PATIENT NAME', style: style)),
        Expanded(flex: 3, child: Text('CONTACT', style: style)),
        Expanded(flex: 2, child: Text('DETAILS', style: style)),
        Expanded(flex: 2, child: Text('STATUS', style: style)),
        Expanded(
          flex: 2,
          child: Text('ACTIONS', style: style, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _PatientRow extends StatelessWidget {
  const _PatientRow({
    required this.patient,
    required this.onView,
    required this.onDelete,
  });

  final Map<String, dynamic> patient;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark
        ? const Color(0xFFEAF1FF)
        : _AdminPatientsViewState._text;
    final Color mutedColor = isDark
        ? const Color(0xFFAAB8D4)
        : _AdminPatientsViewState._muted;
    final Color profileBg = isDark
        ? const Color(0xFF22314B)
        : const Color(0xFFF2F5FB);
    final Color statusBg = isDark
        ? const Color(0xFF1A253A)
        : const Color(0xFFF4F6FE);
    final Color statusBorder = isDark
        ? const Color(0xFF2B3956)
        : const Color(0xFFE3EAF6);
    final String accountStatus =
        patient['account_status']?.toString().trim().isNotEmpty == true
        ? patient['account_status'].toString().trim()
        : 'Registered Account';
    final String patientType =
        patient['patient_type']?.toString().trim().isNotEmpty == true
        ? patient['patient_type'].toString().trim()
        : 'No activity yet';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 4,
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: profileBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.account_circle_outlined,
                    color: textColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        patient['full_name']?.toString() ?? 'No data yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        patient['patient_id']?.toString() ?? 'No data yet',
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _InfoTextRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Primary contact on file',
                ),
                const SizedBox(height: 4),
                _InfoTextRow(
                  icon: Icons.call_outlined,
                  label: patient['contact_number']?.toString() ?? 'No data yet',
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  patient['gender']?.toString() ?? 'No data yet',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatPatientBirthdate(patient['birthdate']),
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusBorder),
                ),
                child: Text(
                  patientType == 'Registered'
                      ? accountStatus.toUpperCase()
                      : patientType.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _PatientActionButton(
                  icon: Icons.edit_outlined,
                  backgroundColor: isDark
                      ? const Color(0xFF1A253A)
                      : _AdminPatientsViewState._softBlue,
                  borderColor: isDark
                      ? const Color(0xFF2B3956)
                      : _AdminPatientsViewState._softBlueBorder,
                  iconColor: textColor,
                  onTap: onView,
                ),
                const SizedBox(width: 8),
                _PatientActionButton(
                  icon: Icons.delete_outline_rounded,
                  backgroundColor: isDark
                      ? const Color(0xFF2A1E24)
                      : _AdminPatientsViewState._dangerBg,
                  borderColor: isDark
                      ? const Color(0xFF5C3944)
                      : _AdminPatientsViewState._dangerBorder,
                  iconColor: isDark
                      ? const Color(0xFFFFA8AE)
                      : _AdminPatientsViewState._danger,
                  onTap: onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTextRow extends StatelessWidget {
  const _InfoTextRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: <Widget>[
        Icon(
          icon,
          size: 14,
          color: isDark ? const Color(0xFFAAB8D4) : const Color(0xFF8FA0B8),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark
                  ? const Color(0xFFD7E4FF)
                  : const Color(0xFF42536F),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _PatientActionButton extends StatelessWidget {
  const _PatientActionButton({
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
      ),
    );
  }
}

class _PageNavButton extends StatelessWidget {
  const _PageNavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 46,
          height: 42,
          decoration: BoxDecoration(
            color: enabled
                ? (isDark ? const Color(0xFF1A253A) : Colors.white)
                : (isDark ? const Color(0xFF162033) : const Color(0xFFF7F8FC)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2B3956)
                  : const Color(0xFFE3EAF6),
            ),
          ),
          child: Icon(
            icon,
            color: enabled
                ? (isDark
                      ? const Color(0xFFD7E4FF)
                      : _AdminPatientsViewState._muted)
                : (isDark
                      ? const Color(0xFF5D6C8B)
                      : const Color(0xFFD4DCEA)),
          ),
        ),
      ),
    );
  }
}

class _PageNumberButton extends StatelessWidget {
  const _PageNumberButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: active ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 46,
          height: 42,
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF21396E)
                : (isDark ? const Color(0xFF1A253A) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? const Color(0xFF21396E)
                  : (isDark
                        ? const Color(0xFF2B3956)
                        : const Color(0xFFE3EAF6)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? Colors.white
                    : (isDark
                          ? const Color(0xFFD7E4FF)
                          : _AdminPatientsViewState._muted),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: RichText(
        text: TextSpan(
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF64748B)),
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
