import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/recycle_bin_entry.dart';

enum RecycleBinRole { patient, staff }

class RecycleBinView extends StatelessWidget {
  const RecycleBinView({super.key, required this.role, this.entries});

  final RecycleBinRole role;
  final List<RecycleBinEntry>? entries;

  @override
  Widget build(BuildContext context) {
    final List<RecycleBinEntry> resolvedEntries =
        entries ?? _previewEntriesForRole(role);
    final int recoverableCount = resolvedEntries
        .where((RecycleBinEntry entry) => entry.isRestorable)
        .length;
    final int expiredCount = resolvedEntries.length - recoverableCount;
    final bool usingPreviewData = entries == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5ED),
      appBar: AppBar(
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
      ),
      body: resolvedEntries.isEmpty
          ? _buildEmptyState()
          : ListView(
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
                      role == RecycleBinRole.patient
                          ? 'Patient Recycle Bin'
                          : 'Staff Recycle Bin',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      role == RecycleBinRole.patient
                          ? 'Review cancelled appointments and check whether each one is still eligible for restore.'
                          : 'Review cancelled appointments, confirm what can still be restored, and flag what has already expired.',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 13,
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
                        fontSize: 12,
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
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
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
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
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
              if (role == RecycleBinRole.staff && entry.patientName != null)
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
                  fontSize: 12,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.isRestorable
                      ? _restoreWindowCopy(entry.expiresAt, dateFormatter)
                      : 'This cancelled appointment is no longer restorable, but it stays visible here for history and recovery validation.',
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: entry.isRestorable
                      ? OutlinedButton.icon(
                          onPressed: null,
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
          fontSize: 11,
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
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
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
              const Text(
                'Recycle Bin is empty',
                style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                role == RecycleBinRole.patient
                    ? 'Cancelled appointments will appear here once recycle bin retrieval is connected for patient accounts.'
                    : 'Cancelled appointments will appear here once recycle bin retrieval is connected for staff accounts.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
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
      return 'This appointment is still eligible for restore. The action button is prepared and will activate once the backend restore flow is connected.';
    }

    return 'This appointment stays restorable until ${dateFormatter.format(expiresAt)}. The action button is prepared and will activate once the backend restore flow is connected.';
  }

  static List<RecycleBinEntry> _previewEntriesForRole(RecycleBinRole role) {
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
