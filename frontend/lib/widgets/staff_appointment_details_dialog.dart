import 'package:flutter/material.dart';

import '../core/appointment_actions.dart';
import '../core/appointment_status.dart';
import 'app_alert_dialog.dart';
import 'app_confirmation_dialog.dart';
import 'app_dialog_scaffold.dart';
import 'appointment_status_badge.dart';

typedef StaffAppointmentStatusUpdater =
    Future<bool> Function(String nextStatus, {String? cancellationReason});

class StaffAppointmentDetailsDialog extends StatefulWidget {
  const StaffAppointmentDetailsDialog({
    super.key,
    required this.appointment,
    this.onStatusUpdate,
    this.showStatusActions = true,
    this.actorRole = 'staff',
  });

  final Map<String, dynamic> appointment;
  final StaffAppointmentStatusUpdater? onStatusUpdate;
  final bool showStatusActions;
  final String actorRole;

  @override
  State<StaffAppointmentDetailsDialog> createState() =>
      _StaffAppointmentDetailsDialogState();
}

class _StaffAppointmentDetailsDialogState
    extends State<StaffAppointmentDetailsDialog> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final patientName = _readValue('patient_name', fallback: 'Patient');
    final serviceType = _readValue('service_type', fallback: 'Service');
    final formattedDate = _formatDate(
      widget.appointment['appointment_date']?.toString() ?? '',
    );
    final formattedTime = _formatTime(
      widget.appointment['time']?.toString() ??
          widget.appointment['appointment_time']?.toString() ??
          '',
    );
    final notes = widget.appointment['notes']?.toString().trim() ?? '';
    final cancellationReason =
        widget.appointment['cancellation_reason']?.toString().trim() ?? '';
    final cancelledBy =
        widget.appointment['cancelled_by_name']?.toString().trim() ?? '';
    final cancelledAt = _formatDateTime(
      widget.appointment['cancelled_at']?.toString() ?? '',
    );
    final status = normalizeAppointmentStatus(widget.appointment['status']);
    final queueNumber = _formatQueueNumber(widget.appointment['queue_number']);
    final logs = _readLogs();
    final actions = widget.showStatusActions && widget.onStatusUpdate != null
        ? _allowedActionsForAppointment(widget.appointment, widget.actorRole)
        : const <_AppointmentAction>[];

    return AppDialogScaffold(
      title: 'Appointment Details',
      titleTextStyle: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: Color(0xFF1E293B),
      ),
      onClose: _isSubmitting ? null : () => Navigator.of(context).pop(),
      headerTrailing: AppointmentStatusBadge(status: status, compact: true),
      footer: _buildFooter(actions),
      showFooterDivider: actions.isNotEmpty || _isSubmitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailBlock(label: 'PATIENT NAME', value: patientName),
          const SizedBox(height: 16),
          _DetailBlock(label: 'SERVICES', value: serviceType),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailBlock(label: 'DATE', value: formattedDate),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailBlock(label: 'TIME', value: formattedTime),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _DetailBlock(
            label: 'NOTES',
            value: notes.isEmpty ? 'No notes provided' : notes,
          ),
          if (cancellationReason.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DetailBlock(
              label: 'CANCELLATION REASON',
              value: cancellationReason,
            ),
          ],
          if (cancelledBy.isNotEmpty || cancelledAt.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DetailBlock(
                    label: 'CANCELLED BY',
                    value: cancelledBy.isEmpty ? 'Not recorded' : cancelledBy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DetailBlock(
                    label: 'CANCELLED AT',
                    value: cancelledAt.isEmpty ? 'Not recorded' : cancelledAt,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailBlock(
                  label: 'STATUS',
                  value: appointmentStatusLabel(status),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DetailBlock(
                  label: 'QUEUE NUMBER',
                  value: '#$queueNumber',
                ),
              ),
            ],
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: 18),
            _AppointmentLogsBlock(logs: logs),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _readLogs() {
    final rawLogs = widget.appointment['logs'];
    if (rawLogs is! List) {
      return const <Map<String, dynamic>>[];
    }

    return rawLogs
        .whereType<Map>()
        .map((dynamic item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Widget? _buildFooter(List<_AppointmentAction> actions) {
    if (_isSubmitting) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }

    if (actions.isEmpty) {
      return null;
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          Expanded(
            child: _ActionButton(
              config: actions[i],
              onTap: () => _handleAction(actions[i]),
            ),
          ),
          if (i < actions.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Future<void> _handleAction(_AppointmentAction action) async {
    String? cancellationReason;
    final String normalizedStatus = normalizeAppointmentStatus(
      action.nextStatus,
    );

    if (normalizedStatus == 'cancelled') {
      cancellationReason = await _showCancelReasonDialog();
      if (cancellationReason == null || !mounted) {
        return;
      }
    } else {
      final confirmed = await _showConfirmationDialog(action);
      if (!confirmed || !mounted) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final updater = widget.onStatusUpdate;
    if (updater == null) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      return;
    }

    final success = await updater(
      action.nextStatus,
      cancellationReason: cancellationReason,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _showConfirmationDialog(_AppointmentAction action) async {
    final String normalizedStatus = normalizeAppointmentStatus(
      action.nextStatus,
    );

    if (normalizedStatus == 'approved') {
      return _showApproveConfirmationDialog();
    }

    if (normalizedStatus == 'completed') {
      return _showCompletedConfirmationDialog();
    }

    final decision = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AppAlertDialog(
          title: Text(_confirmationTitle(normalizedStatus)),
          content: Text(_confirmationMessage(normalizedStatus)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Keep Status'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF4A769E),
              ),
              child: Text(_confirmationButtonLabel(normalizedStatus)),
            ),
          ],
        );
      },
    );
    return decision ?? false;
  }

  Future<bool> _showCompletedConfirmationDialog() async {
    final String serviceType = _readValue(
      'service_type',
      fallback: 'this appointment',
    );
    final String formattedDate = _formatDate(
      widget.appointment['appointment_date']?.toString() ?? '',
    );

    final decision = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmationDialog(
        icon: Icons.task_alt_rounded,
        iconBackgroundColor: const Color(0xFFEAFBF0),
        iconColor: const Color(0xFF16A34A),
        title: 'Mark as Completed?',
        message:
            'Are you sure you want to mark this appointment as completed for '
            '$serviceType on $formattedDate?',
        secondaryLabel: 'No, Keep it',
        primaryLabel: 'Yes, Complete',
        primaryColor: const Color(0xFF16A34A),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    return decision ?? false;
  }

  Future<bool> _showApproveConfirmationDialog() async {
    final String serviceType = _readValue(
      'service_type',
      fallback: 'this appointment',
    );
    final String formattedDate = _formatDate(
      widget.appointment['appointment_date']?.toString() ?? '',
    );

    final decision = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AppConfirmationDialog(
        icon: Icons.check_rounded,
        iconBackgroundColor: const Color(0xFFEAF2FF),
        iconColor: const Color(0xFF2563EB),
        title: 'Approve Appointment?',
        message:
            'Are you sure you want to approve this appointment for '
            '$serviceType on $formattedDate?',
        secondaryLabel: 'No, Keep it',
        primaryLabel: 'Yes, Approve',
        primaryColor: const Color(0xFF2563EB),
        onSecondaryPressed: () => Navigator.of(dialogContext).pop(false),
        onPrimaryPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    );

    return decision ?? false;
  }

  Future<String?> _showCancelReasonDialog() async {
    final String serviceType = _readValue(
      'service_type',
      fallback: 'this appointment',
    );
    final String formattedDate = _formatDate(
      widget.appointment['appointment_date']?.toString() ?? '',
    );
    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => _CancellationReasonDialog(
        message:
            'Provide a reason for cancelling this appointment for '
            '$serviceType on $formattedDate.',
      ),
    );
  }

  String _confirmationTitle(String nextStatus) {
    return switch (nextStatus) {
      'approved' => 'Approve Appointment',
      'cancelled' => 'Cancel Appointment',
      'completed' => 'Mark Appointment as Completed',
      _ => 'Update Appointment',
    };
  }

  String _confirmationMessage(String nextStatus) {
    return switch (nextStatus) {
      'approved' => 'Are you sure you want to approve this appointment?',
      'cancelled' => 'Are you sure you want to cancel this appointment?',
      'completed' =>
        'Are you sure you want to mark this appointment as completed?',
      _ => 'Are you sure you want to update this appointment?',
    };
  }

  String _confirmationButtonLabel(String nextStatus) {
    return switch (nextStatus) {
      'approved' => 'Approve Appointment',
      'cancelled' => 'Cancel Appointment',
      'completed' => 'Mark as Completed',
      _ => 'Confirm Update',
    };
  }

  List<_AppointmentAction> _allowedActionsForAppointment(
    Map<String, dynamic> appointment,
    String actorRole,
  ) {
    final List<AppointmentAction> actions = resolveAppointmentActions(
      appointment,
      actorRole: actorRole,
    );
    return actions.map(_uiActionFor).toList();
  }

  _AppointmentAction _uiActionFor(AppointmentAction action) {
    return switch (action) {
      AppointmentAction.approve => const _AppointmentAction(
        label: 'Approve',
        nextStatus: 'approved',
        backgroundColor: Color(0xFFDCEBFF),
        foregroundColor: Color(0xFF1D4ED8),
      ),
      AppointmentAction.cancel => const _AppointmentAction(
        label: 'Cancel',
        nextStatus: 'cancelled',
        backgroundColor: Color(0xFFFFE1E1),
        foregroundColor: Color(0xFFDC2626),
      ),
      AppointmentAction.complete => const _AppointmentAction(
        label: 'Mark Completed',
        nextStatus: 'completed',
        backgroundColor: Color(0xFFDCF6E4),
        foregroundColor: Color(0xFF15803D),
      ),
    };
  }

  String _readValue(String key, {required String fallback}) {
    final value = widget.appointment[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _formatQueueNumber(dynamic value) {
    final queue = _parseQueueNumber(value);
    if (queue >= 9999) {
      return '--';
    }
    return queue.toString().padLeft(2, '0');
  }

  int _parseQueueNumber(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return 9999;
    }
    return int.tryParse(value.toString()) ?? 9999;
  }

  String _formatTime(String rawTime) {
    final trimmed = rawTime.trim();
    if (trimmed.isEmpty) {
      return '--:--';
    }
    final parts = trimmed.split(':');
    if (parts.length < 2) {
      return trimmed;
    }
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(String rawDate) {
    final trimmed = rawDate.trim();
    if (trimmed.isEmpty) {
      return 'N/A';
    }

    final parts = trimmed.split('-');
    if (parts.length == 3) {
      final year = parts[0];
      final monthIndex = int.tryParse(parts[1]);
      final day = int.tryParse(parts[2]);
      if (monthIndex != null &&
          day != null &&
          monthIndex >= 1 &&
          monthIndex <= 12) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[monthIndex - 1]} $day, $year';
      }
    }

    return trimmed;
  }

  String _formatDateTime(String rawDateTime) {
    final parsed = DateTime.tryParse(rawDateTime.trim());
    if (parsed == null) {
      return rawDateTime.trim();
    }

    final hour = parsed.hour == 0
        ? 12
        : parsed.hour > 12
        ? parsed.hour - 12
        : parsed.hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';

    return '${_formatDate(parsed.toIso8601String().split('T').first)} $hour:$minute $period';
  }
}

class _AppointmentLogsBlock extends StatelessWidget {
  const _AppointmentLogsBlock({required this.logs});

  final List<Map<String, dynamic>> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'APPOINTMENT LOGS',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),
          for (final log in logs.take(5)) ...[
            _AppointmentLogRow(log: log),
            if (log != logs.take(5).last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AppointmentLogRow extends StatelessWidget {
  const _AppointmentLogRow({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final action = log['action']?.toString().trim() ?? 'Appointment activity';
    final status =
        log['action_status']?.toString().trim() ??
        log['new_status']?.toString().trim() ??
        '';
    final actor = log['performed_by']?.toString().trim() ?? '';
    final actionAt = _formatLogDateTime(
      log['action_at']?.toString() ?? log['created_at']?.toString() ?? '',
    );
    final reason = log['cancellation_reason']?.toString().trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          status.isEmpty ? action : '$action • $status',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          [
            if (actor.isNotEmpty) 'By $actor',
            if (actionAt.isNotEmpty) actionAt,
          ].join(' • '),
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            'Reason: $reason',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  static String _formatLogDateTime(String rawDateTime) {
    final parsed = DateTime.tryParse(rawDateTime.trim());
    if (parsed == null) {
      return rawDateTime.trim();
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = parsed.toLocal();
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${months[local.month - 1]} ${local.day}, ${local.year} $hour:$minute $period';
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.config, required this.onTap});

  final _AppointmentAction config;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          backgroundColor: config.backgroundColor,
          foregroundColor: config.foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
        ),
        child: Text(config.label.toUpperCase()),
      ),
    );
  }
}

class _CancellationReasonDialog extends StatefulWidget {
  const _CancellationReasonDialog({required this.message});

  final String message;

  @override
  State<_CancellationReasonDialog> createState() =>
      _CancellationReasonDialogState();
}

class _CancellationReasonDialogState extends State<_CancellationReasonDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _fieldError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppAlertDialog(
      title: const Text('Cancel Appointment?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Cancellation reason',
              errorText: _fieldError,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('No, Keep it'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (value.isEmpty) {
              setState(() {
                _fieldError = 'Cancellation reason is required.';
              });
              return;
            }

            Navigator.of(context).pop(value);
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFFF4B4B),
          ),
          child: const Text('Yes, Cancel'),
        ),
      ],
    );
  }
}

class _AppointmentAction {
  const _AppointmentAction({
    required this.label,
    required this.nextStatus,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final String nextStatus;
  final Color backgroundColor;
  final Color foregroundColor;
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 16,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
