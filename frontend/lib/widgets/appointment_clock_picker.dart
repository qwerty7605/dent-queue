import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: slots.map((Map<String, dynamic> slot) {
        final bool disabled = isSlotDisabled(slot);
        final bool selected = selectedTimeSlot == slot['time']?.toString();
        final String label =
            slot['time_label']?.toString() ?? slot['time']?.toString() ?? '--';

        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: disabled ? null : (_) => onSelected(slot['time'].toString()),
        );
      }).toList(),
    );
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
  final String? availabilitySummary = _buildAvailabilitySummary(
    slots: slots,
    availableSlots: availableSlots,
  );

  if (availableSlots.isEmpty) {
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final bool isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return AppDialogScaffold(
          title: title,
          maxWidth: 420,
          backgroundColor: isDark ? const Color(0xFF101A2C) : Colors.white,
          onClose: () => Navigator.of(dialogContext).pop(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                availabilitySummary ?? errorText ?? emptyMessage,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFAAB7CD) : const Color(0xFF475569),
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
                  final String reason =
                      range['reason']?.toString().trim().isNotEmpty == true
                      ? range['reason'].toString()
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
    if (!context.mounted) return null;
    return null;
  }

  int initialIndex = availableSlots.indexWhere(
    (Map<String, dynamic> slot) => slot['time']?.toString() == selectedTimeSlot,
  );
  if (initialIndex < 0) {
    initialIndex = 0;
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      final bool isDark = theme.brightness == Brightness.dark;
      int selectedIndex = initialIndex;

      return StatefulBuilder(
        builder: (BuildContext context, void Function(void Function()) setModalState) {
          final Map<String, dynamic> selected = availableSlots[selectedIndex];
          final List<String> pieces = _slotPieces(selected['time']?.toString());

          void moveSelection(int direction) {
            setModalState(() {
              selectedIndex =
                  (selectedIndex + direction + availableSlots.length) %
                  availableSlots.length;
            });
          }

          return AppDialogScaffold(
            maxWidth: 420,
            backgroundColor: isDark ? const Color(0xFF101A2C) : Colors.white,
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            bodyPadding: EdgeInsets.zero,
            headerContent: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF324662) : const Color(0xFFE7EBF5),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Choose Appointment Time',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF1F3763),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PROFESSIONAL DENTAL SCHEDULE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFAAB7CD) : const Color(0xFF9AA3B2),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (availabilitySummary != null) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF17243A) : const Color(0xFFF8FAFE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      availabilitySummary,
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFAAB7CD)
                            : const Color(0xFF5F6D84),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSelectorColumn(
                      value: pieces[0],
                      onIncrement: () => moveSelection(1),
                      onDecrement: () => moveSelection(-1),
                      isDark: isDark,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        ':',
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFFAAB7CD)
                              : const Color(0xFFD1D6E1),
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _buildSelectorColumn(
                      value: pieces[1],
                      onIncrement: () => moveSelection(1),
                      onDecrement: () => moveSelection(-1),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 14),
                    Column(
                      children: [
                        _buildAmPmChip(
                          label: 'AM',
                          selected: pieces[2] == 'AM',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 8),
                        _buildAmPmChip(
                          label: 'PM',
                          selected: pieces[2] == 'PM',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF17243A) : const Color(0xFFF7F9FE),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: isDark
                            ? const Color(0xFFAAB7CD)
                            : const Color(0xFFA0A9B9),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SELECTED TIME: ${selected['time_label']?.toString().toUpperCase() ?? _slotDisplay(selected['time']?.toString())}',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF3A4B68),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorText,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: isDark
                              ? const Color(0xFF17243A)
                              : const Color(0xFFF8FAFE),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF2E405A)
                                : const Color(0xFFE6EBF4),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF3A4B68),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(selected['time'].toString()),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF233D78),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: const Text(
                          'Set Time',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
                if (unavailableRanges.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Unavailable ranges: ${unavailableRanges.length}',
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFF3D57B)
                            : const Color(0xFFB88617),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _buildSelectorColumn({
  required String value,
  required VoidCallback onIncrement,
  required VoidCallback onDecrement,
  required bool isDark,
}) {
  return Column(
    children: [
      IconButton(
        onPressed: onIncrement,
        icon: const Icon(Icons.add_rounded),
        color: isDark ? Colors.white : const Color(0xFF1F3763),
      ),
      Container(
        width: 72,
        height: 92,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17243A) : const Color(0xFFF9FBFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF2E405A) : const Color(0xFFE2E7F1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1F3763),
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
      IconButton(
        onPressed: onDecrement,
        icon: const Icon(Icons.remove_rounded),
        color: isDark ? Colors.white : const Color(0xFF1F3763),
      ),
    ],
  );
}

Widget _buildAmPmChip({
  required String label,
  required bool selected,
  required bool isDark,
}) {
  return Container(
    width: 58,
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      color: selected
          ? const Color(0xFF233D78)
          : (isDark ? const Color(0xFF17243A) : const Color(0xFFF7F9FE)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: selected
            ? Colors.white
            : (isDark ? const Color(0xFFAAB7CD) : const Color(0xFFB4BDCD)),
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

String? _buildAvailabilitySummary({
  required List<Map<String, dynamic>> slots,
  required List<Map<String, dynamic>> availableSlots,
}) {
  final int doctorUnavailableCount = slots.where((Map<String, dynamic> slot) {
    return slot['status']?.toString() == 'doctor_unavailable';
  }).length;

  if (doctorUnavailableCount == 0) {
    return null;
  }

  if (availableSlots.isEmpty) {
    return 'Doctor is unavailable for this day.';
  }

  final List<int> availableHours = availableSlots
      .map((Map<String, dynamic> slot) => _parseHour(slot['time']?.toString()))
      .whereType<int>()
      .toList();

  if (availableHours.isEmpty) {
    return null;
  }

  final bool onlyMorning = availableHours.every((int hour) => hour < 12);
  final bool onlyAfternoon = availableHours.every((int hour) => hour >= 12);

  if (onlyMorning) {
    return 'Doctor is only available this morning.';
  }

  if (onlyAfternoon) {
    return 'Doctor is only available this afternoon.';
  }

  return 'Some schedules are unavailable because the doctor is unavailable during part of the day.';
}

int? _parseHour(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }

  final List<String> parts = value.split(':');
  return int.tryParse(parts.first);
}

List<String> _slotPieces(String? value) {
  if (value == null || value.isEmpty) {
    return <String>['09', '10', 'AM'];
  }

  try {
    final DateFormat parser = DateFormat('HH:mm');
    final DateFormat formatter = DateFormat('hh mm a');
    return formatter.format(parser.parse(value)).split(' ');
  } catch (_) {
    return <String>['09', '10', 'AM'];
  }
}

String _slotDisplay(String? value) {
  final List<String> parts = _slotPieces(value);
  return '${parts[0]}:${parts[1]} ${parts[2]}';
}

class _ClockStateNotice extends StatelessWidget {
  const _ClockStateNotice({required this.message, this.errorText});

  final String message;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17243A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Text(
            message,
            style: TextStyle(
              color: isDark ? const Color(0xFFAAB7CD) : const Color(0xFF475569),
              fontSize: 14,
            ),
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
