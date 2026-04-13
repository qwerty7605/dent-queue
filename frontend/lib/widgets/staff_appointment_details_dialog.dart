import 'package:flutter/material.dart';

import '../core/appointment_status.dart';
import 'app_alert_dialog.dart';
import 'app_dialog_scaffold.dart';
import 'appointment_status_badge.dart';

typedef StaffAppointmentStatusUpdater =
    Future<bool> Function(String nextStatus);

class StaffAppointmentDetailsDialog extends StatefulWidget {
  const StaffAppointmentDetailsDialog({
    super.key,
    required this.appointment,
    this.onStatusUpdate,
    this.showStatusActions = true,
  });

  final Map<String, dynamic> appointment;
  final StaffAppointmentStatusUpdater? onStatusUpdate;
  final bool showStatusActions;

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
    final status = normalizeAppointmentStatus(widget.appointment['status']);
    final queueNumber = _formatQueueNumber(widget.appointment['queue_number']);
    final actions = widget.showStatusActions && widget.onStatusUpdate != null
        ? _allowedActionsForStatus(status)
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
          _DetailBlock(label: 'SERVICE TYPE', value: serviceType),
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
        ],
      ),
    );
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
    final confirmed = await _showConfirmationDialog(action);
    if (!confirmed || !mounted) {
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

    final success = await updater(action.nextStatus);
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
                backgroundColor: const Color(0xFF679B6A),
              ),
              child: Text(_confirmationButtonLabel(normalizedStatus)),
            ),
          ],
        );
      },
    );
    return decision ?? false;
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

  List<_AppointmentAction> _allowedActionsForStatus(String status) {
    return switch (status) {
      'pending' => [
        const _AppointmentAction(
          label: 'Approve',
          nextStatus: 'approved',
          backgroundColor: Color(0xFFDCEBFF),
          foregroundColor: Color(0xFF1D4ED8),
        ),
        const _AppointmentAction(
          label: 'Cancel',
          nextStatus: 'cancelled',
          backgroundColor: Color(0xFFFFE1E1),
          foregroundColor: Color(0xFFDC2626),
        ),
      ],
      'approved' => [
        const _AppointmentAction(
          label: 'Mark Completed',
          nextStatus: 'completed',
          backgroundColor: Color(0xFFDCF6E4),
          foregroundColor: Color(0xFF15803D),
        ),
        const _AppointmentAction(
          label: 'Cancel',
          nextStatus: 'cancelled',
          backgroundColor: Color(0xFFFFE1E1),
          foregroundColor: Color(0xFFDC2626),
        ),
      ],
      _ => const <_AppointmentAction>[],
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
