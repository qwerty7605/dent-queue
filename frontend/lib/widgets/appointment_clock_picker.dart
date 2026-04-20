import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_dialog_scaffold.dart';

class AppointmentClockPicker extends StatelessWidget {
  const AppointmentClockPicker({
    super.key,
    required this.slots,
    required this.selectedTimeSlot,
    required this.isSlotDisabled,
    required this.onSelected,
    this.isLoading = false,
    this.errorText,
    this.emptyMessage = 'No slots available for this date.',
  });

  final List<Map<String, dynamic>> slots;
  final String? selectedTimeSlot;
  final bool Function(Map<String, dynamic> slot) isSlotDisabled;
  final ValueChanged<String> onSelected;
  final bool isLoading;
  final String? errorText;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (slots.isEmpty) {
      return _ClockStateNotice(message: emptyMessage, errorText: errorText);
    }

    final Map<String, dynamic>? selectedSlot = slots.cast<Map<String, dynamic>?>()
        .firstWhere(
          (Map<String, dynamic>? slot) =>
              slot?['time']?.toString() == selectedTimeSlot,
          orElse: () => null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: AspectRatio(
              aspectRatio: 1,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double size = constraints.biggest.shortestSide;
                  final double outerRadius = size * 0.39;
                  final double innerRadius = size * 0.26;
                  final int innerCount = slots.length > 12 ? slots.length ~/ 2 : 0;
                  final List<Map<String, dynamic>> innerSlots = slots
                      .take(innerCount)
                      .toList();
                  final List<Map<String, dynamic>> outerSlots = slots
                      .skip(innerCount)
                      .toList();

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: <Color>[
                                Color(0xFFF8FBFF),
                                Color(0xFFE6EEF7),
                              ],
                            ),
                            border: Border.all(
                              color: const Color(0xFFD4E1ED),
                              width: 1.5,
                            ),
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x120F172A),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _ClockFacePainter(
                            accentColor: const Color(0xFF4A769E),
                          ),
                        ),
                      ),
                      Align(
                        child: _ClockCenterLabel(
                          label:
                              selectedSlot?['time_label']?.toString() ??
                              'Pick a\nschedule',
                        ),
                      ),
                      ..._buildRing(
                        size: size,
                        ringRadius: innerRadius,
                        items: innerSlots,
                      ),
                      ..._buildRing(
                        size: size,
                        ringRadius: outerRadius,
                        items: outerSlots,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (selectedSlot != null) ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Selected: ${selectedSlot['time_label'] ?? selectedSlot['time'] ?? '--'}',
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (errorText != null) ...[
          const SizedBox(height: 10),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildRing({
    required double size,
    required double ringRadius,
    required List<Map<String, dynamic>> items,
  }) {
    if (items.isEmpty) {
      return const <Widget>[];
    }

    final double center = size / 2;
    final double buttonSize = items.length > 12 ? 36 : 42;

    return List<Widget>.generate(items.length, (int index) {
      final Map<String, dynamic> slot = items[index];
      final bool disabled = isSlotDisabled(slot);
      final bool selected = selectedTimeSlot == slot['time']?.toString();
      final double angle = (-math.pi / 2) + ((2 * math.pi * index) / items.length);
      final double x = center + ringRadius * math.cos(angle) - (buttonSize / 2);
      final double y = center + ringRadius * math.sin(angle) - (buttonSize / 2);
      final String label = slot['time_label']?.toString() ?? slot['time']?.toString() ?? '--';

      return Positioned(
        left: x,
        top: y,
        width: buttonSize,
        height: buttonSize,
        child: Tooltip(
          message: label,
          child: FilledButton(
            onPressed: disabled ? null : () => onSelected(slot['time'].toString()),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              elevation: selected ? 2 : 0,
              backgroundColor: selected
                  ? const Color(0xFF4A769E)
                  : disabled
                  ? const Color(0xFFE2E8F0)
                  : Colors.white,
              disabledBackgroundColor: const Color(0xFFE2E8F0),
              foregroundColor: selected
                  ? Colors.white
                  : disabled
                  ? const Color(0xFF64748B)
                  : const Color(0xFF1E293B),
              side: BorderSide(
                color: selected
                    ? const Color(0xFF4A769E)
                    : const Color(0xFFD4E1ED),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  _compactLabel(label),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: items.length > 12 ? 9 : 10,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                    color: selected
                        ? Colors.white
                        : disabled
                        ? const Color(0xFF64748B)
                        : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  String _compactLabel(String label) {
    final List<String> parts = label.split(' ');
    if (parts.length < 2) {
      return label;
    }

    return '${parts.first}\n${parts.sublist(1).join(' ')}';
  }
}

Future<String?> showAppointmentTimePickerModal({
  required BuildContext context,
  required List<Map<String, dynamic>> slots,
  required String? selectedTimeSlot,
  required bool Function(Map<String, dynamic> slot) isSlotDisabled,
  required List<Map<String, dynamic>> unavailableRanges,
  String title = 'Select Time',
  String emptyMessage = 'No slots available for this date.',
  String? errorText,
}) async {
  final List<Map<String, dynamic>> availableSlots = slots
      .where((Map<String, dynamic> slot) => !isSlotDisabled(slot))
      .toList();

  if (availableSlots.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AppDialogScaffold(
          title: title,
          maxWidth: 420,
          onClose: () => Navigator.of(dialogContext).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                errorText ?? emptyMessage,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              if (unavailableRanges.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'Doctor Unavailable',
                  style: TextStyle(
                    color: Color(0xFFB45309),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                ...unavailableRanges.map((Map<String, dynamic> range) {
                  final String start =
                      range['start_time']?.toString() ?? '--:--';
                  final String end = range['end_time']?.toString() ?? '--:--';
                  final String rawReason =
                      range['reason']?.toString().trim() ?? '';
                  final String reason = rawReason.isNotEmpty
                      ? rawReason
                      : 'Doctor Unavailable';

                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '$start - $end: $reason',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );

    if (!context.mounted) {
      return null;
    }

    return null;
  }

  final String initialSlot = availableSlots.any(
        (Map<String, dynamic> slot) =>
            slot['time']?.toString() == selectedTimeSlot,
      )
      ? selectedTimeSlot!
      : availableSlots.first['time'].toString();

  final TimeOfDay? picked = await showTimePicker(
    context: context,
    initialTime: _parseTimeOfDay(initialSlot),
    helpText: title,
    initialEntryMode: TimePickerEntryMode.dialOnly,
    builder: (BuildContext context, Widget? child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF4A769E),
            onPrimary: Colors.white,
            surface: Colors.white,
            onSurface: Color(0xFF1E293B),
          ),
        ),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );

  if (picked == null) {
    return null;
  }

  if (!context.mounted) {
    return null;
  }

  final String selectedTime = _to24HourString(picked);
  final Map<String, dynamic>? matchingSlot = availableSlots
      .cast<Map<String, dynamic>?>()
      .firstWhere(
        (Map<String, dynamic>? slot) => slot?['time']?.toString() == selectedTime,
        orElse: () => null,
      );

  if (matchingSlot != null) {
    return matchingSlot['time']?.toString();
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AppDialogScaffold(
        title: 'Available Times',
        maxWidth: 420,
        onClose: () => Navigator.of(dialogContext).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'That time is not available for this appointment date. Choose one of the available schedules below.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSlots.map((Map<String, dynamic> slot) {
                return ActionChip(
                  label: Text(
                    slot['time_label']?.toString() ??
                        slot['time']?.toString() ??
                        '--',
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                );
              }).toList(),
            ),
          ],
        ),
      );
    },
  );

  if (!context.mounted) {
    return null;
  }

  return null;
}

TimeOfDay _parseTimeOfDay(String value) {
  final List<String> parts = value.split(':');
  final int hour = int.tryParse(parts.first) ?? 0;
  final int minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour, minute: minute);
}

String _to24HourString(TimeOfDay value) {
  final String hour = value.hour.toString().padLeft(2, '0');
  final String minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _ClockCenterLabel extends StatelessWidget {
  const _ClockCenterLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.92),
        border: Border.all(color: const Color(0xFFD4E1ED)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 18,
            color: Color(0xFF4A769E),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClockStateNotice extends StatelessWidget {
  const _ClockStateNotice({required this.message, this.errorText});

  final String message;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            errorText!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _ClockFacePainter extends CustomPainter {
  const _ClockFacePainter({required this.accentColor});

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;
    final Paint tickPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.28)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final double angle = (-math.pi / 2) + ((2 * math.pi * i) / 12);
      final Offset start = Offset(
        center.dx + (radius * 0.72) * math.cos(angle),
        center.dy + (radius * 0.72) * math.sin(angle),
      );
      final Offset end = Offset(
        center.dx + (radius * 0.8) * math.cos(angle),
        center.dy + (radius * 0.8) * math.sin(angle),
      );
      canvas.drawLine(start, end, tickPaint);
    }

    final Paint handPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.24)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(center.dx, center.dy - radius * 0.22),
      handPaint,
    );
    canvas.drawCircle(center, 5, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant _ClockFacePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}
