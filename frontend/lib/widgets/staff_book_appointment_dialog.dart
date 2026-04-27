import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../services/appointment_service.dart';
import 'app_dialog_scaffold.dart';
import 'appointment_clock_picker.dart';
import 'appointment_success_dialog.dart';

class StaffBookAppointmentDialog extends StatefulWidget {
  const StaffBookAppointmentDialog({
    super.key,
    required this.patient,
    required this.appointmentService,
  });

  final Map<String, String> patient;
  final AppointmentService appointmentService;

  @override
  State<StaffBookAppointmentDialog> createState() =>
      _StaffBookAppointmentDialogState();
}

class _StaffBookAppointmentDialogState
    extends State<StaffBookAppointmentDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'service': <String>['service_type', 'service_id'],
        'date': <String>['appointment_date'],
        'time': <String>['appointment_time', 'time_slot'],
        'notes': <String>['notes'],
      };

  final _formKey = GlobalKey<FormState>();

  String? _selectedService = 'Dental Check-up';
  DateTime? _selectedDate;
  String? _selectedTimeSlot;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoadingAvailability = false;
  List<Map<String, dynamic>> _availabilitySlots = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _unavailableRanges = <Map<String, dynamic>>[];
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  final List<String> _services = [
    'Dental Check-up',
    'Dental Panoramic X-ray',
    'Root Canal',
    'Teeth Cleaning',
    'Teeth Whitening',
    'Tooth Extraction',
  ];

  @override
  void dispose() {
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
        _selectedTimeSlot = null;
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
      });
      _clearFieldError('date');
      _clearFieldError('time');
      await _loadAvailabilityForSelectedDate();
    }
  }

  Future<void> _loadAvailabilityForSelectedDate() async {
    if (_selectedDate == null) {
      return;
    }

    setState(() {
      _isLoadingAvailability = true;
      _fieldErrors.remove('time');
    });

    try {
      final payload = await widget.appointmentService.getAvailabilitySlots(
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
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
      final String message = exception.message.trim();
      if (message.contains('This schedule is already booked')) {
        fieldErrors['time'] =
            'This schedule is already booked. Please choose another schedule.';
      } else if (message.contains('already have a booking for this date')) {
        fieldErrors['date'] =
            'This patient already has a booking for this date.';
      } else if (message.contains('already booked') ||
          message.contains('time slot')) {
        fieldErrors['time'] =
            'The selected time is unavailable. Please choose another schedule.';
      } else if (message.contains('daily limit')) {
        fieldErrors['date'] =
            'The daily limit of 50 patients has been reached for this date.';
      } else {
        formError = message.isNotEmpty ? message : null;
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

    if (!_formKey.currentState!.validate()) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      return;
    }

    final patientId = int.tryParse(widget.patient['id'] ?? '');
    if (patientId == null) {
      setState(() {
        _formErrorText = 'Unable to book appointment for this patient.';
      });
      return;
    }

    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'patient_id': patientId,
      'service_type': _selectedService,
      'appointment_date':
          '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
      'appointment_time': _selectedTimeSlot,
      'notes': _notesController.text.trim(),
    };

    try {
      await widget.appointmentService.createAdminAppointment(payload);
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      await showAppointmentSuccessDialog(
        context,
        title: 'Appointment Booked\nSuccessfully!',
        message:
            'The appointment has been successfully scheduled for the patient.',
        buttonLabel: 'Return to Appointments',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      _applyApiErrors(e);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formErrorText =
            'Unable to book the appointment right now. Please try again.';
      });
    }
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
          color: const Color(0xFF1A2F64),
        ),
        maxWidth: 420,
        onClose: _isSubmitting ? null : () => Navigator.of(context).pop(),
        subtitle: 'FOR ${widget.patient['name']?.toUpperCase() ?? 'PATIENT'}',
        footer: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A2F64),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Confirm Booking',
                    style: TextStyle(
                      fontSize: MobileTypography.button(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formErrorText != null) ...[
              _buildErrorBanner(),
              const SizedBox(height: 16),
            ],
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildServiceTypeDropdown(),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildDateInput()),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTimeInput()),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFFA2ABBB),
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _buildServiceTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('SERVICE TYPE'),
        DropdownButtonFormField<String>(
          initialValue: _selectedService,
          decoration: _inputDecoration(
            prefixIcon: const Icon(
              Icons.task_alt_outlined,
              color: Color(0xFFB9C2D2),
            ),
          ),
          items: _services.map((service) {
            return DropdownMenuItem(
              value: service,
              child: Text(
                service,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedService = value;
            });
            _clearFieldError('service');
          },
          validator: (value) =>
              _mergeFieldError('service', value == null ? 'Required' : null),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
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
    );
  }

  Widget _buildDateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('DATE'),
        TextFormField(
          controller: _dateController,
          readOnly: true,
          onTap: _pickDate,
          validator: (value) => _mergeFieldError(
            'date',
            value == null || value.isEmpty ? 'Required' : null,
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          decoration: _inputDecoration(
            hint: 'dd/mm/yyyy',
            prefixIcon: const Icon(
              Icons.calendar_today_outlined,
              color: Color(0xFFB9C2D2),
            ),
            suffixIcon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('TIME'),
        const SizedBox(height: 8),
        FormField<String>(
          validator: (_) => _mergeFieldError(
            'time',
            _selectedTimeSlot == null ? 'Required' : null,
          ),
          builder: (state) {
            return InkWell(
              onTap: _isSubmitting ? null : () => _openTimePicker(state),
              borderRadius: BorderRadius.circular(10),
              child: InputDecorator(
                decoration:
                    _inputDecoration(
                      prefixIcon: const Icon(
                        Icons.access_time_rounded,
                        color: Color(0xFFB9C2D2),
                      ),
                      suffixIcon: _isLoadingAvailability
                          ? null
                          : Icons.access_time_rounded,
                    ).copyWith(
                      errorText: state.errorText,
                      suffixIcon: _isLoadingAvailability
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.access_time_rounded,
                              color: Color(0xFF475569),
                              size: 20,
                            ),
                    ),
                child: Text(
                  _timeFieldLabel(),
                  style: TextStyle(
                    color: _selectedTimeSlot == null
                        ? const Color(0xFF9CA3AF)
                        : const Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: _selectedTimeSlot == null
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _openTimePicker(FormFieldState<String> state) async {
    if (_selectedDate == null) {
      setState(() {
        _fieldErrors['date'] = 'Required';
      });
      state.validate();
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

  InputDecoration _inputDecoration({
    String? hint,
    IconData? suffixIcon,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFBFC8D6),
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
      filled: true,
      fillColor: Colors.white,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFF1A2F64), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: const Color(0xFF475569), size: 20)
          : null,
    );
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
