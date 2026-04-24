import 'dart:async';

import 'package:flutter/material.dart';

import '../services/admin_staff_service.dart';
import '../widgets/add_staff_dialog.dart';
import '../widgets/app_alert_dialog.dart';
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
  static const int _pageSize = 5;
  static const Color _surface = Colors.white;
  static const Color _outline = Color(0xFFE3EAF6);
  static const Color _text = Color(0xFF1D3264);
  static const Color _muted = Color(0xFF667792);
  static const Color _navy = Color(0xFF21396E);

  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<Map<String, dynamic>> _staffMembers = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isSearching = false;
  int? _processingStaffId;
  int _currentPage = 1;
  int _totalStaffMembers = 0;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStaff({
    bool forceRefresh = false,
    int page = 1,
    String? query,
  }) async {
    final String normalizedQuery = (query ?? _activeQuery).trim();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = normalizedQuery.isEmpty;
      _isSearching = normalizedQuery.isNotEmpty;
      _activeQuery = normalizedQuery;
    });

    try {
      if (forceRefresh) {
        widget.adminStaffService.invalidateStaffCache();
      }

      if (normalizedQuery.isNotEmpty) {
        final List<Map<String, dynamic>> allStaff = await widget
            .adminStaffService
            .getAllStaff();
        final String search = normalizedQuery.toLowerCase();
        final List<Map<String, dynamic>> filtered = allStaff.where((
          Map<String, dynamic> staffMember,
        ) {
          final String haystack = <String>[
            _resolveStaffName(staffMember),
            _resolveStaffRecordId(staffMember),
            _resolveAccountNumber(staffMember),
            _resolveContact(staffMember),
            _resolveRoleLabel(staffMember),
          ].join(' ').toLowerCase();
          return haystack.contains(search);
        }).toList();

        final int start = (page - 1) * _pageSize;
        final int end = (start + _pageSize).clamp(0, filtered.length);
        final List<Map<String, dynamic>> visible = start >= filtered.length
            ? <Map<String, dynamic>>[]
            : filtered.sublist(start, end);

        if (!mounted) {
          return;
        }

        setState(() {
          _staffMembers = visible;
          _currentPage = page;
          _totalStaffMembers = filtered.length;
          _isLoading = false;
          _isSearching = false;
        });
        return;
      }

      final staffPage = await widget.adminStaffService.getStaffPage(
        page: page,
        perPage: _pageSize,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _staffMembers = staffPage.items;
        _currentPage = staffPage.currentPage;
        _totalStaffMembers = staffPage.totalItems;
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
        const SnackBar(content: Text('Failed to load staff records')),
      );
    }
  }

  void _handleSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), () {
      _loadStaff(page: 1, query: value);
    });
  }

  Future<void> _confirmDeactivate(Map<String, dynamic> staffMember) async {
    final int? staffId = _readInt(staffMember['id']);
    if (staffId == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AppAlertDialog(
          title: const Text('Deactivate Staff Account'),
          content: Text(
            'Are you sure you want to deactivate the account for ${_resolveStaffName(staffMember)}?',
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

    setState(() {
      _processingStaffId = staffId;
    });

    try {
      final String message = await widget.adminStaffService.deactivateStaff(
        staffId,
      );
      if (!mounted) {
        return;
      }

      await _loadStaff(
        forceRefresh: true,
        page: _currentPage,
        query: _activeQuery,
      );
      widget.onStaffChanged?.call();

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
    final Map<String, dynamic>? result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AddStaffDialog(
        onSubmit: (Map<String, dynamic> data) =>
            widget.adminStaffService.createStaff(data),
      ),
    );

    if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Account successfully created.',
          ),
          backgroundColor: const Color(0xFF4A769E),
        ),
      );
      _loadStaff(forceRefresh: true, page: 1, query: _activeQuery);
      widget.onStaffChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final EdgeInsets pagePadding = EdgeInsets.fromLTRB(
      width < 900 ? 16 : 24,
      22,
      width < 900 ? 16 : 24,
      28,
    );

    return RefreshIndicator(
      onRefresh: () => _loadStaff(
        forceRefresh: true,
        page: _currentPage,
        query: _activeQuery,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildTopBar(),
            const SizedBox(height: 22),
            _buildStaffSheet(),
            const SizedBox(height: 18),
            _buildPaginationFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final Widget searchField = Container(
          constraints: const BoxConstraints(maxWidth: 500, minHeight: 50),
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
                        'Search registry by name, staff ID, or account number...',
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
                    _loadStaff(page: 1, query: '');
                  },
                  icon: const Icon(Icons.close_rounded, color: _muted, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(width: 28, height: 28),
                  splashRadius: 16,
                  tooltip: 'Clear search',
                ),
            ],
          ),
        );

        final Widget registerButton = FilledButton.icon(
          onPressed: _isLoading ? null : _showAddStaffDialog,
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            minimumSize: const Size(228, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'REGISTER STAFF',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.2,
            ),
          ),
        );

        if (constraints.maxWidth < 1100) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              searchField,
              const SizedBox(height: 16),
              registerButton,
            ],
          );
        }

        return Row(
          children: <Widget>[
            searchField,
            const SizedBox(width: 20),
            registerButton,
            const Spacer(),
          ],
        );
      },
    );
  }

  Widget _buildStaffSheet() {
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
            child: _StaffHeaderRow(),
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
                          child: CircularProgressIndicator(color: _navy),
                        ),
                      )
                    : _staffMembers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: AppEmptyState(
                          key: const Key('admin-staff-empty-state'),
                          icon: Icons.group_off_outlined,
                          title: _activeQuery.isEmpty
                              ? 'No staff accounts yet'
                              : 'No staff records matched your search',
                          message: _activeQuery.isEmpty
                              ? 'Staff and intern accounts will appear here after they are created.'
                              : 'Try another name, staff ID, or account number.',
                          actionLabel: 'Register Staff',
                          actionIcon: Icons.person_add_alt_1_rounded,
                          onAction: _showAddStaffDialog,
                        ),
                      )
                : Column(
                        children: List<Widget>.generate(_staffMembers.length, (
                          int index,
                        ) {
                          final Map<String, dynamic> staffMember =
                              _staffMembers[index];
                          return Column(
                            children: <Widget>[
                              if (index > 0)
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Color(0xFFF2F5FB),
                                ),
                              _StaffRow(
                                staffMember: staffMember,
                                isProcessing:
                                    _processingStaffId != null &&
                                    _processingStaffId ==
                                        _readInt(staffMember['id']),
                                onDelete: () => _confirmDeactivate(staffMember),
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

  Widget _buildPaginationFooter() {
    final int totalPages = ((_totalStaffMembers + _pageSize - 1) / _pageSize)
        .floor();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'STAFF REGISTRY OVERVIEW',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _activeQuery.isNotEmpty
                  ? 'Showing ${_staffMembers.length} of $_totalStaffMembers matching accounts'
                  : 'Displaying ${_rangeStart()}-${_rangeEnd()} of $_totalStaffMembers active staff accounts',
              style: const TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        );

        final Widget pagination = totalPages > 0
            ? Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _PageNavButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _currentPage > 1,
                    onTap: () =>
                        _loadStaff(page: _currentPage - 1, query: _activeQuery),
                  ),
                  ..._visiblePages(totalPages).map((int page) {
                    final bool active = page == _currentPage;
                    return _PageNumberButton(
                      label: page.toString(),
                      active: active,
                      onTap: () => _loadStaff(page: page, query: _activeQuery),
                    );
                  }),
                  _PageNavButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _currentPage < totalPages,
                    onTap: () =>
                        _loadStaff(page: _currentPage + 1, query: _activeQuery),
                  ),
                ],
              )
            : const SizedBox.shrink();

        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[summary, const SizedBox(height: 16), pagination],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: summary),
            pagination,
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
    if (_totalStaffMembers == 0) {
      return 0;
    }
    return ((_currentPage - 1) * _pageSize) + 1;
  }

  int _rangeEnd() {
    if (_totalStaffMembers == 0) {
      return 0;
    }
    return (_rangeStart() + _staffMembers.length - 1).clamp(
      0,
      _totalStaffMembers,
    );
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    return int.tryParse(value?.toString() ?? '');
  }

  String _resolveStaffName(Map<String, dynamic> staffMember) {
    final String firstName = staffMember['first_name']?.toString().trim() ?? '';
    final String middleName =
        staffMember['middle_name']?.toString().trim() ?? '';
    final String lastName = staffMember['last_name']?.toString().trim() ?? '';

    final String fullName = <String>[
      firstName,
      middleName,
      lastName,
    ].where((String part) => part.isNotEmpty).join(' ').trim();

    return fullName.isEmpty ? 'No data yet' : fullName;
  }

  String _resolveContact(Map<String, dynamic> staffMember) {
    final Map<String, dynamic> staffRecord = _readMap(
      staffMember['staff_record'],
    );
    final dynamic contact =
        staffRecord['contact_number'] ?? staffMember['phone_number'];
    return _resolveText(contact);
  }

  String _resolveRoleLabel(Map<String, dynamic> staffMember) {
    final Map<String, dynamic> role = _readMap(staffMember['role']);
    final String name = role['name']?.toString().trim() ?? '';
    return name.isEmpty ? 'Staff' : name;
  }

  String _resolveStaffRecordId(Map<String, dynamic> staffMember) {
    final Map<String, dynamic> staffRecord = _readMap(
      staffMember['staff_record'],
    );
    final dynamic staffRecordId = staffRecord['staff_id'];
    if (staffRecordId != null && staffRecordId.toString().trim().isNotEmpty) {
      return staffRecordId.toString();
    }
    final int? userId = _readInt(staffMember['id']);
    return userId != null
        ? 'S${userId.toString().padLeft(3, '0')}'
        : 'No data yet';
  }

  String _resolveAccountNumber(Map<String, dynamic> staffMember) {
    final String username = staffMember['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) {
      return username.toUpperCase();
    }
    final int? userId = _readInt(staffMember['id']);
    return userId != null ? 'ACC-${1000 + userId}' : 'No data yet';
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
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? 'No data yet' : text;
  }
}

class _StaffHeaderRow extends StatelessWidget {
  const _StaffHeaderRow();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final TextStyle style = TextStyle(
      color: isDark
          ? const Color(0xFFAAB8D4)
          : _AdminStaffViewState._muted,
      fontSize: 9.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.4,
    );

    return Row(
      children: <Widget>[
        Expanded(flex: 2, child: Text('STAFF #', style: style)),
        Expanded(flex: 4, child: Text('STAFF MEMBER', style: style)),
        Expanded(flex: 3, child: Text('ACCOUNT', style: style)),
        Expanded(flex: 2, child: Text('CONTACT', style: style)),
        Expanded(flex: 2, child: Text('STATUS', style: style)),
        Expanded(
          flex: 2,
          child: Text('ACTION', style: style, textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.staffMember,
    required this.isProcessing,
    required this.onDelete,
  });

  final Map<String, dynamic> staffMember;
  final bool isProcessing;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark
        ? const Color(0xFFEAF1FF)
        : _AdminStaffViewState._text;
    final Color mutedColor = isDark
        ? const Color(0xFFAAB8D4)
        : _AdminStaffViewState._muted;
    final String name = _resolveStaffName(staffMember);
    final String role = _resolveRoleLabel(staffMember);
    final String staffId = _resolveStaffRecordId(staffMember);
    final String accountNumber = _resolveAccountNumber(staffMember);
    final String contact = _resolveContact(staffMember);
    final bool isIntern = role.toLowerCase() == 'intern';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Text(
              staffId,
              style: TextStyle(
                color: mutedColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF22314B)
                        : _AdminStaffViewState._navy,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x1421396E),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.account_circle_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
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
                        role.toUpperCase(),
                        style: TextStyle(
                          color: isIntern
                              ? const Color(0xFFE2A93B)
                              : mutedColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
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
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: isDark
                      ? const Color(0xFFAAB8D4)
                      : const Color(0xFFB8C5DC),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    accountNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFD7E4FF)
                          : const Color(0xFF42536F),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              contact,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
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
                  color: isDark
                      ? const Color(0xFF173127)
                      : const Color(0xFFEAFBF3),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF28533F)
                        : const Color(0xFFD3F2E2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.circle, size: 8, color: Color(0xFF27C08A)),
                    SizedBox(width: 8),
                    Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Color(0xFF21A777),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2A1E24)
                                : const Color(0xFFFFF4F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF5C3944)
                                  : const Color(0xFFF3E1E3),
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            color: isDark
                                ? const Color(0xFFFFA8AE)
                                : const Color(0xFFE27D82),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveStaffName(Map<String, dynamic> staffMember) {
    final String firstName = staffMember['first_name']?.toString().trim() ?? '';
    final String middleName =
        staffMember['middle_name']?.toString().trim() ?? '';
    final String lastName = staffMember['last_name']?.toString().trim() ?? '';

    final String fullName = <String>[
      firstName,
      middleName,
      lastName,
    ].where((String part) => part.isNotEmpty).join(' ').trim();

    return fullName.isEmpty ? 'No data yet' : fullName;
  }

  String _resolveRoleLabel(Map<String, dynamic> staffMember) {
    final dynamic roleValue = staffMember['role'];
    if (roleValue is Map) {
      final String text = roleValue['name']?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return 'Staff';
  }

  String _resolveStaffRecordId(Map<String, dynamic> staffMember) {
    final dynamic staffRecordValue = staffMember['staff_record'];
    if (staffRecordValue is Map) {
      final String text = staffRecordValue['staff_id']?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    final int? id = int.tryParse(staffMember['id']?.toString() ?? '');
    return id != null ? 'S${id.toString().padLeft(3, '0')}' : 'No data yet';
  }

  String _resolveAccountNumber(Map<String, dynamic> staffMember) {
    final String username = staffMember['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) {
      return username.toUpperCase();
    }
    final int? id = int.tryParse(staffMember['id']?.toString() ?? '');
    return id != null ? 'ACC-${1000 + id}' : 'No data yet';
  }

  String _resolveContact(Map<String, dynamic> staffMember) {
    final dynamic staffRecordValue = staffMember['staff_record'];
    if (staffRecordValue is Map) {
      final String contact =
          staffRecordValue['contact_number']?.toString().trim() ?? '';
      if (contact.isNotEmpty) {
        return contact;
      }
    }
    final String phone = staffMember['phone_number']?.toString().trim() ?? '';
    return phone.isEmpty ? 'No data yet' : phone;
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
                      : _AdminStaffViewState._muted)
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
                ? _AdminStaffViewState._navy
                : (isDark ? const Color(0xFF1A253A) : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? _AdminStaffViewState._navy
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
                          : _AdminStaffViewState._muted),
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
