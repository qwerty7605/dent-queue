import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/appointment_service.dart';
import '../services/patient_record_service.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/staff_book_appointment_dialog.dart';
import 'staff_patient_detail_view.dart';

class StaffPatientRecordsView extends StatefulWidget {
  const StaffPatientRecordsView({
    super.key,
    required this.patientRecordService,
    required this.appointmentService,
  });

  final PatientRecordService patientRecordService;
  final AppointmentService appointmentService;

  @override
  State<StaffPatientRecordsView> createState() =>
      _StaffPatientRecordsViewState();
}

class _StaffPatientRecordsViewState extends State<StaffPatientRecordsView> {
  final TextEditingController _searchController = TextEditingController();

  List<StaffPatientSearchResult> _searchResults =
      const <StaffPatientSearchResult>[];
  StaffPatientRecordData? _selectedPatient;
  StaffPatientSearchResult? _selectedSearchResult;

  bool _hasSearched = false;
  bool _isSearching = false;
  bool _isLoadingDetail = false;

  String? _searchError;
  String? _detailError;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _hasSearched = false;
        _isSearching = false;
        _isLoadingDetail = false;
        _searchError = null;
        _detailError = null;
        _selectedSearchResult = null;
        _selectedPatient = null;
        _searchResults = const <StaffPatientSearchResult>[];
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _hasSearched = true;
      _isSearching = true;
      _searchError = null;
      _detailError = null;
      _selectedSearchResult = null;
      _selectedPatient = null;
      _searchResults = const <StaffPatientSearchResult>[];
    });

    try {
      final results = await widget.patientRecordService.searchPatients(query);
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchResults = results
            .map(StaffPatientSearchResult.fromApi)
            .where((item) => item.patientId.isNotEmpty)
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchError = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _searchError =
            'Unable to search patient records right now. Please try again.';
      });
    }
  }

  Future<void> _loadPatientDetail(StaffPatientSearchResult patient) async {
    setState(() {
      _selectedSearchResult = patient;
      _selectedPatient = null;
      _detailError = null;
      _isLoadingDetail = true;
    });

    try {
      final detail = await widget.patientRecordService.getPatientDetail(
        patient.patientId,
      );
      if (!mounted) return;

      setState(() {
        _searchController.text = patient.fullName;
        _selectedPatient = StaffPatientRecordData.fromDetailResponse(detail);
        _isLoadingDetail = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingDetail = false;
        _detailError = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingDetail = false;
        _detailError =
            'Unable to load patient details right now. Please try again.';
      });
    }
  }

  void _clearSelection() {
    setState(() {
      _selectedPatient = null;
      _selectedSearchResult = null;
      _detailError = null;
      _isLoadingDetail = false;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _hasSearched = false;
      _isSearching = false;
      _searchError = null;
      _detailError = null;
      _selectedPatient = null;
      _selectedSearchResult = null;
      _searchResults = const <StaffPatientSearchResult>[];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _openBookAppointmentDialog(
    StaffPatientRecordData patient,
  ) async {
    final booked = await showDialog<bool>(
      context: context,
      builder: (_) => StaffBookAppointmentDialog(
        patient: patient.toDialogPatient(),
        appointmentService: widget.appointmentService,
      ),
    );

    if (booked == true && _selectedSearchResult != null) {
      await _loadPatientDetail(_selectedSearchResult!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 440 ? 14.0 : 22.0;
        final maxWidth = constraints.maxWidth > 1024 ? 560.0 : double.infinity;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Records',
                          style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A2F64),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Manage and review patient clinical history',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF7B8798),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildBodyState(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBodyState() {
    if (_isLoadingDetail) {
      return _InfoPanel(
        key: const ValueKey<String>('detail-loading'),
        child: const _LoadingState(label: 'Loading patient details...'),
      );
    }

    if (_detailError != null) {
      return _InfoPanel(
        key: const ValueKey<String>('detail-error'),
        child: _ErrorState(
          message: _detailError!,
          actionLabel: 'Retry',
          onRetry: _selectedSearchResult == null
              ? null
              : () => _loadPatientDetail(_selectedSearchResult!),
        ),
      );
    }

    if (_selectedPatient != null) {
      return StaffPatientDetailView(
        key: ValueKey<String>(_selectedPatient!.patientId),
        patient: _selectedPatient!,
        onBack: _clearSelection,
        onBookAppointment: () {
          _openBookAppointmentDialog(_selectedPatient!);
        },
      );
    }

    return _buildSearchState();
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onSubmitted: (_) => _performSearch(),
        decoration: InputDecoration(
          hintText: 'Search by name, ID or phone',
          hintStyle: const TextStyle(
            color: Color(0xFFD2D9E6),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 20,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFFB9C3D3),
            size: 28,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFFC8D1DF),
                  ),
                  onPressed: _clearSearch,
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildSearchState() {
    if (!_hasSearched) {
      return const _InfoPanel(
        key: ValueKey<String>('search-empty'),
        child: AppEmptyState(
          icon: Icons.manage_search_rounded,
          title: 'Search patient records',
          message:
              'Find a patient to view details, history, and upcoming appointments.',
          framed: false,
          compact: true,
        ),
      );
    }

    if (_isSearching) {
      return const _InfoPanel(
        key: ValueKey<String>('search-loading'),
        child: _LoadingState(label: 'Searching patient records...'),
      );
    }

    if (_searchError != null) {
      return _InfoPanel(
        key: const ValueKey<String>('search-error'),
        child: _ErrorState(
          message: _searchError!,
          actionLabel: 'Retry Search',
          onRetry: _performSearch,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return _InfoPanel(
        key: ValueKey<String>('search-no-results'),
        child: AppEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No patient records found',
          message:
              'No patient records matched your search. Try another name or clear the current query.',
          actionLabel: 'Clear Search',
          actionIcon: Icons.restart_alt_rounded,
          onAction: _clearSearch,
          framed: false,
          compact: true,
        ),
      );
    }

    return ListView.separated(
      key: const ValueKey<String>('search-results'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _searchResults.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final patient = _searchResults[index];
        return _buildPatientCard(patient);
      },
    );
  }

  Widget _buildPatientCard(StaffPatientSearchResult patient) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => _loadPatientDetail(patient),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EEFF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: Text(
                      patient.initial,
                      style: const TextStyle(
                        color: Color(0xFF1A2F64),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.fullName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A2F64),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.sell_outlined,
                            size: 13,
                            color: Color(0xFFD1D8E5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            patient.patientId,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFA5B0C2),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patient.contactNumber,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF7D889B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFE0E6F0),
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7EBEE)),
      ),
      child: child,
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.8,
            color: Color(0xFF4A769E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.actionLabel,
    this.onRetry,
  });

  final String message;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 44,
          color: Color(0xFFD97706),
        ),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF475569),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A769E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}
