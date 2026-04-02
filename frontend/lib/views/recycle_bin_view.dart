import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../core/mobile_typography.dart';
import '../models/recycle_bin_entry.dart';
import '../services/appointment_service.dart';

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF4F5ED),
        appBar: _buildAppBar(),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF679B6A)),
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
      backgroundColor: const Color(0xFFF4F5ED),
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
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
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
                        color: Color(0xFF679B6A),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Recycle Bin',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
      backgroundColor: const Color(0xFF679B6A),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildHeroCard({
    required int recoverableCount,
    required int expiredCount,
    required bool usingPreviewData,
  }) {
    return Container(
      key: const Key('recycle-bin-hero'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4EA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.restore_from_trash_outlined,
                  color: Color(0xFF497A52),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.role == RecycleBinRole.patient
                          ? 'Patient Recycle Bin'
                          : 'Staff Recycle Bin',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.role == RecycleBinRole.patient
                          ? 'Review cancelled appointments and check whether each one is still eligible for restore.'
                          : 'Review cancelled appointments, confirm what can still be restored, and flag what has already expired.',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 14,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (usingPreviewData) ...[
            const SizedBox(height: 14),
            Container(
              key: const Key('recycle-bin-preview-banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6DB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8C355)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 18,
                    color: Color(0xFF9A6700),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Preview data is showing the recycle bin layout until the backend retrieval API is connected.',
                      style: TextStyle(
                        color: Color(0xFF7C5A00),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryChip(
                  key: const Key('recycle-bin-summary-recoverable'),
                  label: 'Recoverable',
                  value: recoverableCount.toString(),
                  tint: const Color(0xFFE8F4EA),
                  textColor: const Color(0xFF497A52),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryChip(
                  key: const Key('recycle-bin-summary-expired'),
                  label: 'Expired',
                  value: expiredCount.toString(),
                  tint: const Color(0xFFF8E5E5),
                  textColor: const Color(0xFF9F3030),
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(RecycleBinEntry entry) {
    final DateFormat dateFormatter = DateFormat('MMM d, yyyy');
    final DateFormat timeFormatter = DateFormat('h:mm a');

    return Container(
      key: Key('recycle-bin-entry-${entry.id}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: entry.isRestorable
              ? const Color(0xFFD7E8D8)
              : const Color(0xFFE8D5D5),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.service,
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: MobileTypography.cardTitle(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildTag(
                          label: entry.statusLabel,
                          backgroundColor: const Color(0xFFF8E5E5),
                          textColor: const Color(0xFF9F3030),
                        ),
                        _buildTag(
                          key: Key(
                            entry.isRestorable
                                ? 'recycle-bin-chip-available-${entry.id}'
                                : 'recycle-bin-chip-expired-${entry.id}',
                          ),
                          label: entry.isRestorable
                              ? 'Restore Available'
                              : 'Expired',
                          backgroundColor: entry.isRestorable
                              ? const Color(0xFFE8F4EA)
                              : const Color(0xFFF1F5F9),
                          textColor: entry.isRestorable
                              ? const Color(0xFF497A52)
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: entry.isRestorable
                      ? const Color(0xFFE8F4EA)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  entry.isRestorable
                      ? Icons.restore_outlined
                      : Icons.lock_clock_outlined,
                  color: entry.isRestorable
                      ? const Color(0xFF497A52)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _buildDetailBlock(
                label: 'Date',
                value: dateFormatter.format(entry.appointmentAt),
              ),
              _buildDetailBlock(
                label: 'Time',
                value: timeFormatter.format(entry.appointmentAt),
              ),
              _buildDetailBlock(
                label: 'Moved To Bin',
                value: dateFormatter.format(entry.deletedAt),
              ),
              if (widget.role == RecycleBinRole.staff &&
                  entry.patientName != null)
                _buildDetailBlock(label: 'Patient', value: entry.patientName!),
            ],
          ),
          if (entry.notes != null && entry.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                entry.notes!,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            key: Key('recycle-bin-restore-area-${entry.id}'),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: entry.isRestorable
                  ? const Color(0xFFF7FBF7)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: entry.isRestorable
                    ? const Color(0xFFD7E8D8)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Restore Area',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.isRestorable
                      ? _restoreWindowCopy(entry.expiresAt, dateFormatter)
                      : 'This cancelled appointment is no longer restorable, but it stays visible here for history and recovery validation.',
                  style: TextStyle(
                    color: Color(0xFF475569),
                    fontSize: MobileTypography.bodySmall(context),
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: entry.isRestorable
                      ? OutlinedButton.icon(
                          onPressed: () => _restoreAppointment(entry.id),
                          icon: const Icon(Icons.restore_outlined),
                          label: const Text('Restore Appointment'),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Restore expired',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag({
    Key? key,
    required String label,
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDetailBlock({required String label, required String value}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: MobileTypography.caption(context),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: MobileTypography.bodySmall(context),
              fontWeight: FontWeight.w800,
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
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_delete_outlined,
                  size: 44,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Recycle Bin is empty',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: MobileTypography.sectionTitle(context),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.role == RecycleBinRole.patient
                    ? 'Cancelled appointments will appear here if they are eligible.'
                    : 'Cancelled appointments will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: MobileTypography.bodySmall(context),
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _restoreWindowCopy(DateTime? expiresAt, DateFormat dateFormatter) {
    if (expiresAt == null) {
      return 'This appointment is still eligible for restore. Click below to recover it.';
    }

    return 'This appointment stays restorable until ${dateFormatter.format(expiresAt)}. Click below to restore it.';
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
        service: 'Dental Check-up',
        appointmentAt: DateTime(2026, 4, 15, 11, 0),
        deletedAt: DateTime(2026, 3, 30, 9, 10),
        statusLabel: 'Cancelled',
        isRestorable: true,
        expiresAt: DateTime(2026, 4, 4),
        notes:
            'Restore availability is prepared while the backend flow is pending.',
      ),
      RecycleBinEntry(
        id: 602,
        service: 'Tooth Extraction',
        appointmentAt: DateTime(2026, 3, 21, 16, 30),
        deletedAt: DateTime(2026, 3, 14, 13, 20),
        statusLabel: 'Cancelled',
        isRestorable: false,
        expiresAt: DateTime(2026, 3, 20),
        notes:
            'This item is no longer restorable but remains visible in the bin history.',
      ),
    ];
  }
}
