import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../services/base_service.dart';
import '../services/appointment_service.dart';
import 'app_dialog_scaffold.dart';
import 'appointment_clock_picker.dart';
import 'appointment_success_dialog.dart';

class BookAppointmentDialog extends StatefulWidget {
  const BookAppointmentDialog({super.key, this.appointmentService});

  final AppointmentService? appointmentService;

  @override
  State<BookAppointmentDialog> createState() => _BookAppointmentDialogState();
}

class _BookAppointmentDialogState extends State<BookAppointmentDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'service': <String>['service_id', 'service_type'],
        'date': <String>['appointment_date'],
        'time': <String>['time_slot', 'appointment_time'],
        'notes': <String>['notes'],
      };

  final _formKey = GlobalKey<FormState>();

  late final AppointmentService _appointmentService;
  bool _isLoading = false;
  bool _isLoadingAvailability = false;

  String? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  final TextEditingController _notesController = TextEditingController();
  List<Map<String, dynamic>> _availabilitySlots = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _unavailableRanges = <Map<String, dynamic>>[];

  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  final List<Map<String, dynamic>> _services = [
    {'id': 1, 'name': 'Dental Check-up'},
    {'id': 2, 'name': 'Dental Panoramic X-ray'},
    {'id': 3, 'name': 'Root Canal'},
    {'id': 4, 'name': 'Teeth Cleaning'},
    {'id': 5, 'name': 'Teeth Whitening'},
    {'id': 6, 'name': 'Tooth Extraction'},
  ];

  @override
  void initState() {
    super.initState();
    _appointmentService =
        widget.appointmentService ??
        AppointmentService(
          BaseService(ApiClient(tokenStorage: SecureTokenStorage())),
        );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
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
    String? formError = firstUnhandledApiError(
      exception.errors,
      handledKeys: flattenApiErrorKeys(_apiFieldMappings),
    );

    if (fieldErrors.isEmpty) {
      final String normalizedMessage = exception.message.trim();
      if (normalizedMessage.contains('This schedule is already booked')) {
        fieldErrors['time'] =
            'This schedule is already booked. Please choose another schedule.';
      } else if (normalizedMessage.contains(
        'already have a booking for this time slot',
      )) {
        fieldErrors['time'] = 'You already have a booking for this time slot.';
      } else if (normalizedMessage.contains(
        'already have a booking for this date',
      )) {
        fieldErrors['date'] = 'You already have a booking for this date.';
      } else if (normalizedMessage.contains('daily limit')) {
        fieldErrors['date'] =
            'The daily limit of 50 patients has been reached for this date.';
      } else if (normalizedMessage.contains('Sunday')) {
        fieldErrors['date'] = 'Sunday bookings are not allowed.';
      } else if (normalizedMessage.contains('Past dates') ||
          normalizedMessage.contains('in the past')) {
        fieldErrors['date'] = 'Cannot book an appointment in the past.';
      } else if (normalizedMessage.contains('Doctor Unavailable')) {
        fieldErrors['time'] = normalizedMessage;
      } else {
        formError = normalizedMessage.isNotEmpty ? normalizedMessage : null;
      }
    }

    setState(() {
      _fieldErrors = fieldErrors;
      _formErrorText = formError;
      _autoValidateMode = AutovalidateMode.always;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = <String, String>{};
      _formErrorText = null;
    });
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final payload = {
          'service_id': int.parse(_selectedService!),
          'appointment_date': _formatSelectedDate(),
          'time_slot': _selectedTimeSlot!,
          'notes': _notesController.text.trim(),
        };
        await _appointmentService.createAppointment(payload);

        if (!mounted) return;
        setState(() => _isLoading = false);

        await showAppointmentSuccessDialog(
          context,
          title: 'Appointment Booked\nSuccessfully!',
          message:
              'Your appointment request has been successfully submitted and scheduled.',
          buttonLabel: 'Return to Dashboard',
        );

        if (!mounted) return;
        Navigator.of(context).pop(true);
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _applyApiErrors(e);
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _formErrorText = 'Failed to book appointment.';
        });
      }
    } else {
      setState(() => _autoValidateMode = AutovalidateMode.always);
    }
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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: AppDialogScaffold(
        title: 'Book Appointment',
        titleTextStyle: TextStyle(
          fontSize: MobileTypography.sectionTitle(context),
          fontWeight: FontWeight.w900,
          color: const Color(0xFF2C3E50),
        ),
        onClose: _isLoading ? null : () => Navigator.of(context).pop(),
        footer: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A769E),
              elevation: 0,
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
                : const Text('Confirm Booking'),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formErrorText != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _formErrorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            _buildLabel('SERVICE TYPE'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
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
                  borderSide: const BorderSide(
                    color: Color(0xFF4A769E),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
              hint: const Text(
                'Select Service',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF1E293B),
                size: 28,
              ),
              isExpanded: true,
              initialValue: _selectedService,
              items: _services.map((service) {
                return DropdownMenuItem<String>(
                  value: service['id'].toString(),
                  child: Text(
                    service['name'].toString(),
                    style: const TextStyle(
                      color: Color(0xFF2C3E50),
                      fontSize: 16,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedService = val;
                  _autoValidateMode = AutovalidateMode.always;
                });
                _clearFieldError('service');
                _formKey.currentState?.validate();
              },
              validator: (value) => _mergeFieldError(
                'service',
                value == null ? 'Required' : null,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 12, child: _buildDateField()),
                const SizedBox(width: 8),
                Expanded(flex: 11, child: _buildTimeField()),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabel('ADDITIONAL NOTES'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              onChanged: (_) => _clearFieldError('notes'),
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Any concerns?',
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                ),
                contentPadding: const EdgeInsets.all(16),
                alignLabelWithHint: true,
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
                  borderSide: const BorderSide(
                    color: Color(0xFF4A769E),
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
              ),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError('notes', null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return FormField<DateTime>(
      validator: (val) =>
          _mergeFieldError('date', _selectedDate == null ? 'Required' : null),
      builder: (FormFieldState<DateTime> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('DATE'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final bool isSunday = now.weekday == DateTime.sunday;
                final initial = isSunday
                    ? now.add(const Duration(days: 1))
                    : now;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: now,
                  lastDate: now.add(const Duration(days: 365)),
                  selectableDayPredicate: (DateTime val) =>
                      val.weekday != DateTime.sunday,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF4A769E), // header background color
                          onPrimary: Colors.white, // header text color
                          onSurface: Color(0xFF2C3E50), // body text color
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(
                              0xFF4A769E,
                            ), // button text color
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _selectedDate = picked;
                    _selectedTimeSlot = null;
                    _availabilitySlots = <Map<String, dynamic>>[];
                    _unavailableRanges = <Map<String, dynamic>>[];
                  });
                  _clearFieldError('date');
                  _clearFieldError('time');
                  state.didChange(picked);
                  _loadAvailabilityForSelectedDate();
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),
                  errorText: state.errorText,
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF1E293B),
                    size: 18,
                  ),
                ),
                isEmpty: _selectedDate == null,
                child: Text(
                  _selectedDate == null
                      ? 'dd/mm/yyyy'
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF2C3E50),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimeField() {
    return FormField<String>(
      validator: (val) {
        final String? externalError = _fieldErrors['time'];
        if (externalError != null) {
          return externalError;
        }

        return _selectedTimeSlot == null ? 'Required' : null;
      },
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('TIME'),
            const SizedBox(height: 8),
            InkWell(
              onTap: _isLoading ? null : () => _openTimePicker(state),
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
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
                    borderSide: const BorderSide(
                      color: Color(0xFF4A769E),
                      width: 2,
                    ),
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
                          color: Color(0xFF1E293B),
                          size: 18,
                        ),
                ),
                child: Text(
                  _timeFieldLabel(),
                  style: TextStyle(
                    color: _selectedTimeSlot == null
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF2C3E50),
                    fontSize: 14,
                    fontWeight: _selectedTimeSlot == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openTimePicker(FormFieldState<String> state) async {
    if (_selectedDate == null) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      _formKey.currentState?.validate();
      return;
    }

    if (_availabilitySlots.isEmpty && !_isLoadingAvailability) {
      await _loadAvailabilityForSelectedDate();
    }

    if (!mounted) {
      return;
    }

    final String? selected = await showAppointmentTimePickerModal(
      context: context,
      slots: _availabilitySlots,
      selectedTimeSlot: _selectedTimeSlot,
      isSlotDisabled: _isSlotDisabled,
      unavailableRanges: _unavailableRanges,
      errorText: state.errorText,
      title: 'Choose Appointment Time',
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
    if (_selectedDate == null) {
      return 'Select a date first';
    }

    if (_selectedTimeSlot == null) {
      if (_isLoadingAvailability) {
        return 'Loading available times...';
      }

      if (_availabilitySlots.isEmpty) {
        return 'Tap to view available times';
      }

      return 'Tap to choose a time';
    }

    final Map<String, dynamic> slot = _availabilitySlots.firstWhere(
      (Map<String, dynamic> item) => item['time'] == _selectedTimeSlot,
      orElse: () => <String, dynamic>{'time_label': _selectedTimeSlot},
    );

    return slot['time_label']?.toString() ?? _selectedTimeSlot!;
  }

  Future<void> _loadAvailabilityForSelectedDate() async {
    if (_selectedDate == null) {
      return;
    }

    setState(() {
      _isLoadingAvailability = true;
    });

    try {
      final payload = await _appointmentService.getAvailabilitySlots(
        _formatSelectedDate(),
      );

      if (!mounted) return;

      setState(() {
        _availabilitySlots = ((payload['slots'] as List?) ?? const <dynamic>[])
            .whereType<Map>()
            .map((dynamic item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _unavailableRanges =
            ((payload['unavailable_ranges'] as List?) ?? const <dynamic>[])
                .whereType<Map>()
                .map((dynamic item) => Map<String, dynamic>.from(item as Map))
                .toList();
        _isLoadingAvailability = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;

      setState(() {
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
        _isLoadingAvailability = false;
        _fieldErrors['time'] = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
        _isLoadingAvailability = false;
      });
    }
  }

  String _formatSelectedDate() {
    return '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
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
    final status = _effectiveSlotStatus(slot);
    return status != 'available';
  }

}
