import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../models/recycle_bin_entry.dart';
import '../services/appointment_service.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/app_empty_state.dart';
import '../widgets/navigation_chrome.dart';

enum RecycleBinRole { patient, staff }

class RecycleBinView extends StatefulWidget {
  const RecycleBinView({
    super.key,
    required this.role,
    this.entries,
    this.appointmentService,
  });

  final RecycleBinRole role;
  final List<RecycleBinEntry>? entries; // For offline preview if provided
  final AppointmentService? appointmentService;

  @override
  State<RecycleBinView> createState() => _RecycleBinViewState();
}

class _RecycleBinViewState extends State<RecycleBinView> {
  List<RecycleBinEntry>? _entries;
  bool _isLoading = true;
  bool _isRestoring = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.entries != null) {
      _entries = widget.entries;
      _isLoading = false;
    } else {
      _fetchRecycleBin();
    }
  }

  Future<void> _fetchRecycleBin() async {
    if (widget.appointmentService == null) {
      setState(() {
        _entries = _previewEntriesForRole(widget.role);
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawEntries = await widget.appointmentService!
          .getRecycleBinAppointments(widget.role == RecycleBinRole.staff);

      final List<RecycleBinEntry> parsed = rawEntries.map((json) {
        final rb = json['recycle_bin'] as Map<String, dynamic>? ?? {};

        // Handle datetime parsing safely
        DateTime apptAt = DateTime.now();
        try {
          final dateStr = json['appointment_date']?.toString() ?? '';
          final timeStr = (json['appointment_time']?.toString() ?? '10:00 AM')
              .split(' - ')
              .first;
          if (dateStr.isNotEmpty) {
            final format = DateFormat('yyyy-MM-dd h:mm a');
            apptAt = format.parse('$dateStr $timeStr');
          }
        } catch (_) {}

        DateTime deletedAt = DateTime.now();
        if (rb['deleted_at'] != null) {
          deletedAt = DateTime.parse(rb['deleted_at'].toString());
        }

        DateTime? expiresAt;
        if (rb['expires_at'] != null) {
          expiresAt = DateTime.parse(rb['expires_at'].toString());
        }

        final today = DateTime.now();
        final startOfToday = DateTime(today.year, today.month, today.day);
        final appointmentDay = DateTime(apptAt.year, apptAt.month, apptAt.day);
        final isPastAppointment = appointmentDay.isBefore(startOfToday);

        return RecycleBinEntry(
          id: json['id'] as int,
          service: json['service_type']?.toString() ?? 'Dental Check-up',
          appointmentAt: apptAt,
          deletedAt: deletedAt,
          statusLabel: 'Cancelled',
          isRestorable: rb['is_restorable'] == true && !isPastAppointment,
          expiresAt: expiresAt,
          patientName: json['patient_name']?.toString(),
          notes: json['notes']?.toString(),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _entries = parsed;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load recycle bin.';
        _isLoading = false;
      });
    }
  }

  Future<void> _restoreAppointment(int id) async {
    if (widget.appointmentService == null) return;

    setState(() => _isRestoring = true);
    try {
      await widget.appointmentService!.restoreAppointment(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment restored successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _fetchRecycleBin();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to restore appointment. Conflict detected.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isRestoring = false);
      }
    }
  }

  Future<void> _confirmRestoreAppointment(RecycleBinEntry entry) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppAlertDialog(
          title: const Text('Restore Appointment?'),
          content: Text(
            'Restore ${entry.service} back to the active appointment list?',
          ),
          actions: [
            TextButton(
              key: const Key('recycle-bin-restore-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep in Recycle Bin'),
            ),
            FilledButton(
              key: const Key('recycle-bin-restore-confirm'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore Appointment'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _restoreAppointment(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppNavigationTheme.background,
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: AppNavigationTheme.primary),
        ),
      );
    }

    final resolvedEntries = _entries ?? [];
    final int recoverableCount = resolvedEntries
        .where((e) => e.isRestorable)
        .length;
    final int expiredCount = resolvedEntries.length - recoverableCount;
    final bool usingPreviewData =
        widget.appointmentService == null && widget.entries == null;

    return Scaffold(
      backgroundColor: AppNavigationTheme.background,
      appBar: _buildAppBar(),
      body: _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : resolvedEntries.isEmpty
          ? _buildEmptyState()
          : Stack(
              children: [
                ListView(
                  key: const Key('recycle-bin-list'),
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
                  children: [
                    _buildHeroCard(
                      recoverableCount: recoverableCount,
                      expiredCount: expiredCount,
                      usingPreviewData: usingPreviewData,
                    ),
                    const SizedBox(height: 16),
                    ...resolvedEntries.map(_buildEntryCard),
                  ],
                ),
                if (_isRestoring)
                  Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF4A769E),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return const AppHeaderBar(
      titleWidget: AppBrandLockup(logoSize: 40, spacing: 4),
      titleSpacing: -8,
      showBottomAccent: false,
    );
  }

  Widget _buildHeroCard({
    required int recoverableCount,
    required int expiredCount,
    required bool usingPreviewData,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildBackButton(isDark),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Recycle Bin',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1F3763),
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (usingPreviewData && widget.role == RecycleBinRole.staff) ...[
          const SizedBox(height: 12),
          Container(
            key: const Key('recycle-bin-preview-banner'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF352A14) : const Color(0xFFFFF6DB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD0B36A)),
            ),
            child: Text(
              'Preview data is showing the recycle bin layout until the backend retrieval API is connected.',
              style: TextStyle(
                color: isDark ? const Color(0xFFF9E2A6) : const Color(0xFF7C5A00),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSummaryChip(
                key: const Key('recycle-bin-summary-recoverable'),
                label: 'RECOVERABLE',
                value: recoverableCount.toString(),
                tint: isDark ? const Color(0xFF17243A) : Colors.white,
                textColor: isDark ? Colors.white : const Color(0xFF1F3763),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryChip(
                key: const Key('recycle-bin-summary-expired'),
                label: 'EXPIRED',
                value: expiredCount.toString(),
                tint: isDark ? const Color(0xFF17243A) : Colors.white,
                textColor: isDark ? const Color(0xFFB9C4D8) : const Color(0xFFBFC7D4),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBackButton(bool isDark) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.of(context).maybePop(),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17243A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          Icons.chevron_left_rounded,
          color: isDark ? Colors.white : const Color(0xFF1F3763),
        ),
      ),
    );
  }

  Widget _buildSummaryChip({
    required Key key,
    required String label,
    required String value,
    required Color tint,
    required Color textColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2A3A55)
              : const Color(0xFFE8ECF4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(RecycleBinEntry entry) {
    final DateFormat dateFormatter = DateFormat('MMM d, yyyy');
    final DateFormat timeFormatter = DateFormat('h:mm a');
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? const Color(0xFF17243A) : Colors.white;
    final Color headlineColor = isDark ? Colors.white : const Color(0xFF1F3763);
    final Color mutedText = isDark
        ? const Color(0xFFAAB7CD)
        : const Color(0xFF8E99AB);

    return Container(
      key: Key('recycle-bin-entry-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE8ECF4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2D2330) : const Color(0xFFFFF4F4),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFE26868),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.service,
                      style: TextStyle(
                        color: headlineColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${dateFormatter.format(entry.appointmentAt)}, ${timeFormatter.format(entry.appointmentAt)}',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: entry.isRestorable
                      ? (isDark
                            ? const Color(0xFF3A3220)
                            : const Color(0xFFFCEFD8))
                      : (isDark
                            ? const Color(0xFF22314D)
                            : const Color(0xFFF4F6FB)),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  entry.isRestorable ? 'RESTORE\nAVAILABLE' : 'EXPIRED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: entry.isRestorable
                        ? const Color(0xFFDAA032)
                        : mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: mutedText.withValues(alpha: 0.8),
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C2A43) : const Color(0xFFF6F8FC),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: mutedText, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.isRestorable
                        ? 'Moved to bin on recently'
                        : 'Restore window ended on ${dateFormatter.format(entry.expiresAt ?? entry.deletedAt)}',
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.role == RecycleBinRole.staff && entry.patientName != null) ...[
            const SizedBox(height: 10),
            Text(
              'Patient: ${entry.patientName!}',
              style: TextStyle(
                color: mutedText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: entry.isRestorable
                ? ElevatedButton(
                    onPressed: () => _confirmRestoreAppointment(entry),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF233D78),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 17),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text(
                      'Restore Appointment',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  )
                : OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: const Text('Restore Unavailable'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      key: const Key('recycle-bin-empty-state'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
      children: [
        AppEmptyState(
          icon: Icons.auto_delete_outlined,
          title: 'Recycle Bin is empty',
          message: widget.role == RecycleBinRole.patient
              ? 'Cancelled appointments will appear here if they are still eligible for restore.'
              : 'Cancelled appointments will appear here when items are moved into recovery.',
          actionLabel: widget.appointmentService != null ? 'Refresh' : null,
          actionIcon: Icons.refresh_rounded,
          onAction: widget.appointmentService != null
              ? () {
                  _fetchRecycleBin();
                }
              : null,
        ),
      ],
    );
  }

  List<RecycleBinEntry> _previewEntriesForRole(RecycleBinRole role) {
    if (role == RecycleBinRole.staff) {
      return [
        RecycleBinEntry(
          id: 501,
          service: 'Dental Cleaning',
          appointmentAt: DateTime(2026, 4, 18, 9, 30),
          deletedAt: DateTime(2026, 3, 30, 10, 15),
          statusLabel: 'Cancelled',
          isRestorable: true,
          expiresAt: DateTime(2026, 4, 6),
          patientName: 'Ava Stone',
          notes: 'Cancelled by patient before queue confirmation.',
        ),
        RecycleBinEntry(
          id: 502,
          service: 'Root Canal Consultation',
          appointmentAt: DateTime(2026, 3, 25, 14, 0),
          deletedAt: DateTime(2026, 3, 18, 8, 45),
          statusLabel: 'Cancelled',
          isRestorable: false,
          expiresAt: DateTime(2026, 3, 24),
          patientName: 'Noah Lane',
          notes: 'Expired from restore window, retained for verification.',
        ),
      ];
    }

    return [
      RecycleBinEntry(
        id: 601,
        service: 'Root Canal',
        appointmentAt: DateTime(2026, 4, 10, 11, 0),
        deletedAt: DateTime(2026, 3, 30, 9, 10),
        statusLabel: 'Cancelled',
        isRestorable: true,
        expiresAt: DateTime(2026, 4, 4),
        notes: 'Moved to bin on recently',
      ),
    ];
  }
}
