import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import 'app_dialog_scaffold.dart';
import 'appointment_clock_picker.dart';
import 'appointment_success_dialog.dart';

class RescheduleAppointmentDialog extends StatefulWidget {
  const RescheduleAppointmentDialog({
    super.key,
    required this.appointment,
    this.appointmentService,
  });

  final Map<String, dynamic> appointment;
  final AppointmentService? appointmentService;

  @override
  State<RescheduleAppointmentDialog> createState() =>
      _RescheduleAppointmentDialogState();
}

class _RescheduleAppointmentDialogState
    extends State<RescheduleAppointmentDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'date': <String>['appointment_date'],
        'time': <String>['time_slot', 'appointment_time'],
      };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final AppointmentService _appointmentService;
  late DateTime _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoading = false;
  bool _isLoadingAvailability = false;
  List<Map<String, dynamic>> _availabilitySlots = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _unavailableRanges = <Map<String, dynamic>>[];
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    _appointmentService =
        widget.appointmentService ??
        AppointmentService(
          BaseService(ApiClient(tokenStorage: SecureTokenStorage())),
        );

    final parts = (widget.appointment['appointment_date']?.toString() ?? '')
        .split('-');
    _selectedDate = parts.length == 3
        ? DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          )
        : DateTime.now();
    _selectedTimeSlot = widget.appointment['appointment_time']?.toString();
    _loadAvailabilityForSelectedDate();
  }

  void _clearFieldError(String fieldKey) {
    if (!_fieldErrors.containsKey(fieldKey) && _formErrorText == null) return;
    setState(() {
      _fieldErrors.remove(fieldKey);
      _formErrorText = null;
    });
  }

  String? _mergeFieldError(String fieldKey, String? localError) {
    return localError ?? _fieldErrors[fieldKey];
  }

  void _applyApiErrors(ApiException exception) {
    final Map<String, String> fieldErrors = collectApiFieldErrors(
      exception.errors,
      _apiFieldMappings,
    );
    final String? formError = firstUnhandledApiError(
      exception.errors,
      handledKeys: flattenApiErrorKeys(_apiFieldMappings),
    );

    setState(() {
      _fieldErrors = fieldErrors;
      _formErrorText = formError ?? exception.message;
      _autoValidateMode = AutovalidateMode.always;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _loadAvailabilityForSelectedDate() async {
    setState(() {
      _isLoadingAvailability = true;
      _fieldErrors.remove('time');
    });

    try {
      final payload = await _appointmentService.getAvailabilitySlots(
        _formatSelectedDate(),
        ignoreAppointmentId: (widget.appointment['id'] as num?)?.toInt(),
      );

      if (!mounted) return;

      final List<Map<String, dynamic>> slots =
          ((payload['slots'] as List?) ?? const <dynamic>[])
              .whereType<Map>()
              .map((dynamic item) => Map<String, dynamic>.from(item as Map))
              .toList();

      final bool currentSelectionStillValid = slots.any(
        (slot) =>
            slot['time']?.toString() == _selectedTimeSlot &&
            !_isSlotDisabled(slot),
      );

      setState(() {
        _availabilitySlots = slots;
        _unavailableRanges =
            ((payload['unavailable_ranges'] as List?) ?? const <dynamic>[])
                .whereType<Map>()
                .map((dynamic item) => Map<String, dynamic>.from(item as Map))
                .toList();
        _selectedTimeSlot = currentSelectionStillValid
            ? _selectedTimeSlot
            : null;
        _isLoadingAvailability = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
        _selectedTimeSlot = null;
        _isLoadingAvailability = false;
        _fieldErrors['time'] = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
        _selectedTimeSlot = null;
        _isLoadingAvailability = false;
        _formErrorText = 'Unable to load available slots right now.';
      });
    }
  }

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _selectedTimeSlot = null;
    });
    _clearFieldError('date');
    await _loadAvailabilityForSelectedDate();
  }

  Future<void> _submit() async {
    if (!_hasScheduleChanged()) {
      setState(() {
        _formErrorText =
            'Select a different date or time slot before rescheduling.';
      });
      return;
    }

    setState(() {
      _fieldErrors = <String, String>{};
      _formErrorText = null;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _appointmentService.rescheduleAppointment(
        (widget.appointment['id'] as num).toInt(),
        <String, dynamic>{
          'appointment_date': _formatSelectedDate(),
          'time_slot': _selectedTimeSlot,
          'notes': widget.appointment['notes']?.toString() ?? '',
        },
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      await showAppointmentSuccessDialog(
        context,
        title: 'Appointment Rescheduled\nSuccessfully!',
        message:
            'Your updated appointment schedule has been saved successfully.',
        buttonLabel: 'Return to Dashboard',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _applyApiErrors(error);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _formErrorText = 'Failed to reschedule appointment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: AppDialogScaffold(
        title: 'Reschedule Appointment',
        titleTextStyle: TextStyle(
          fontSize: MobileTypography.sectionTitle(context),
          fontWeight: FontWeight.w900,
          color: const Color(0xFF2C3E50),
        ),
        onClose: _isLoading ? null : () => Navigator.of(context).pop(),
        footer: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading || !_hasScheduleChanged() ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2F64),
              foregroundColor: Colors.white,
              elevation: 0,
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Confirm New Schedule'),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formErrorText != null) ...[
              _buildErrorBanner(_formErrorText!),
              const SizedBox(height: 16),
            ],
            Text(
              'Current schedule: ${widget.appointment['appointment_date']} at ${_formatTimeLabel(widget.appointment['appointment_time']?.toString() ?? '--')}',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _buildLabel('NEW DATE'),
            const SizedBox(height: 8),
            FormField<DateTime>(
              validator: (_) => _mergeFieldError('date', null),
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _isLoading ? null : _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: state.hasError
                              ? Colors.redAccent
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatDateLabel(_selectedDate),
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (state.errorText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.errorText!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildLabel('AVAILABLE TIME SLOTS'),
            const SizedBox(height: 8),
            FormField<String>(
              validator: (_) {
                if (_selectedTimeSlot == null) {
                  return _mergeFieldError('time', 'Please select a time slot.');
                }

                return _mergeFieldError('time', null);
              },
              builder: (state) => _buildTimeField(state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(FormFieldState<String> state) {
    return InkWell(
      onTap: _isLoading ? null : () => _openTimePicker(state),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1A2F64), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
          errorText: state.errorText,
          suffixIcon: _isLoadingAvailability
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF64748B),
                  size: 18,
                ),
        ),
        child: Text(
          _timeFieldLabel(),
          style: TextStyle(
            color: _selectedTimeSlot == null
                ? const Color(0xFF94A3B8)
                : const Color(0xFF1E293B),
            fontWeight: _selectedTimeSlot == null
                ? FontWeight.w500
                : FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _openTimePicker(FormFieldState<String> state) async {
    final String? selected = await showAppointmentTimePickerModal(
      context: context,
      slots: _availabilitySlots,
      selectedTimeSlot: _selectedTimeSlot,
      isSlotDisabled: _isSlotDisabled,
      unavailableRanges: _unavailableRanges,
      errorText: state.errorText,
      title: 'Choose New Time',
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedTimeSlot = selected;
    });
    _clearFieldError('time');
    state.didChange(selected);
  }

  String _timeFieldLabel() {
    if (_isLoadingAvailability) {
      return 'Loading available times...';
    }

    if (_selectedTimeSlot == null) {
      return _availabilitySlots.isEmpty
          ? 'Tap to view available times'
          : 'Tap to choose a new time';
    }

    return _formatTimeLabel(_selectedTimeSlot!);
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Color(0xFF7E8CA0),
        letterSpacing: 0.5,
      ),
    );
  }

  String _formatSelectedDate() {
    return '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
  }

  bool _hasScheduleChanged() {
    return _formatSelectedDate() !=
            (widget.appointment['appointment_date']?.toString() ?? '') ||
        _selectedTimeSlot != widget.appointment['appointment_time']?.toString();
  }

  String _formatDateLabel(DateTime value) {
    const months = <String>[
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

    return '${months[value.month - 1]} ${value.day}, ${value.year}';
  }

  String _formatTimeLabel(String time) {
    final Map<String, dynamic>? slot = _availabilitySlots
        .cast<Map<String, dynamic>?>()
        .firstWhere(
          (item) => item?['time']?.toString() == time,
          orElse: () => null,
        );
    if (slot != null && slot['time_label'] != null) {
      return slot['time_label']!.toString();
    }

    try {
      final parts = time.split(':');
      final int hour = int.parse(parts[0]);
      final String minute = parts.length > 1 ? parts[1] : '00';
      final String amPm = hour >= 12 ? 'PM' : 'AM';
      final int displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $amPm';
    } catch (_) {
      return time;
    }
  }

  String _effectiveSlotStatus(Map<String, dynamic> slot) {
    final String status = slot['status']?.toString() ?? 'available';
    if (status != 'available') {
      return status;
    }

    final String slotTime = slot['time']?.toString() ?? '';
    for (final range in _unavailableRanges) {
      final String start = range['start_time']?.toString() ?? '';
      final String end = range['end_time']?.toString() ?? '';
      if (slotTime.compareTo(start) >= 0 && slotTime.compareTo(end) < 0) {
        return 'doctor_unavailable';
      }
    }

    return status;
  }

  bool _isSlotDisabled(Map<String, dynamic> slot) {
    return _effectiveSlotStatus(slot) != 'available';
  }

}
