import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_form_validators.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../services/appointment_service.dart';
import '../widgets/appointment_success_dialog.dart';

class StaffWalkInView extends StatefulWidget {
  const StaffWalkInView({
    super.key,
    required this.appointmentService,
    required this.onWalkInSuccess,
  });

  final AppointmentService appointmentService;
  final VoidCallback onWalkInSuccess;

  @override
  State<StaffWalkInView> createState() => _StaffWalkInViewState();
}

class _StaffWalkInViewState extends State<StaffWalkInView> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'first_name': <String>['first_name'],
        'surname': <String>['surname', 'last_name'],
        'middle_name': <String>['middle_name'],
        'address': <String>['address', 'location'],
        'gender': <String>['gender'],
        'contact_number': <String>['contact_number', 'phone_number'],
        'service_type': <String>['service_type', 'service_id'],
        'appointment_date': <String>['appointment_date'],
        'appointment_time': <String>['appointment_time', 'time_slot'],
      };

  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();

  String? _gender;
  String? _serviceType;

  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isLoadingAvailability = false;
  List<Map<String, dynamic>> _availabilitySlots = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _unavailableRanges = <Map<String, dynamic>>[];

  bool _isSubmitting = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _serviceTypes = [
    'Teeth Cleaning',
    'Dental Check-up',
    'Dental Panoramic X-ray',
    'Root Canal',
    'Teeth Whitening',
  ];

  @override
  void dispose() {
    _firstNameController.dispose();
    _surnameController.dispose();
    _middleNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  void _clearFieldError(String fieldKey) {
    if (!_fieldErrors.containsKey(fieldKey) && _formErrorText == null) return;
    setState(() {
      _fieldErrors.remove(fieldKey);
      _formErrorText = null;
    });
  }

  void _setFieldError(String fieldKey, String message) {
    setState(() {
      _fieldErrors[fieldKey] = message;
      _formErrorText = null;
      _autoValidateMode = AutovalidateMode.always;
    });
    _formKey.currentState?.validate();
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
        fieldErrors['appointment_time'] =
            'This schedule is already booked. Please choose another schedule.';
      } else if (message.contains('daily limit')) {
        fieldErrors['appointment_date'] =
            'The daily limit of 50 patients has been reached for this date.';
      } else if (message.contains('Sunday')) {
        fieldErrors['appointment_date'] = 'Sunday bookings are not allowed.';
      } else if (message.contains('Past dates') ||
          message.contains('in the past')) {
        fieldErrors['appointment_date'] =
            'Cannot book an appointment in the past.';
      } else if (message.contains('Doctor Unavailable')) {
        fieldErrors['appointment_time'] = message;
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

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final bool isSunday = now.weekday == DateTime.sunday;
    final initial =
        _selectedDate ?? (isSunday ? now.add(const Duration(days: 1)) : now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      selectableDayPredicate: (DateTime val) => val.weekday != DateTime.sunday,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF679B6A), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF2C3E50), // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF679B6A), // button text color
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
      _clearFieldError('appointment_date');
      _clearFieldError('appointment_time');
      _formKey.currentState?.validate();
      _loadAvailabilityForSelectedDate();
    }
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      _setFieldError('appointment_date', 'Please select a date first.');
      return;
    }
    if (_availabilitySlots.isEmpty) {
      await _loadAvailabilityForSelectedDate();
    }
  }

  Future<void> _submit() async {
    setState(() {
      _fieldErrors = <String, String>{};
      _formErrorText = null;
    });

    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final payload = {
        'first_name': _firstNameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'address': _addressController.text.trim(),
        'gender': _gender,
        'contact_number': _contactNumberController.text.trim(),
        'service_type': _serviceType,
        'appointment_date': dateStr,
        'appointment_time': _selectedTimeSlot,
      };

      try {
        await widget.appointmentService.createWalkInAppointment(payload);

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

        _formKey.currentState!.reset();
        _firstNameController.clear();
        _surnameController.clear();
        _middleNameController.clear();
        _addressController.clear();
        _contactNumberController.clear();
        setState(() {
          _gender = null;
          _serviceType = null;
          _selectedDate = null;
          _selectedTimeSlot = null;
          _availabilitySlots = <Map<String, dynamic>>[];
          _unavailableRanges = <Map<String, dynamic>>[];
        });

        widget.onWalkInSuccess();
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _applyApiErrors(e);
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _formErrorText = 'An unexpected error occurred: $e';
        });
      }
    } else {
      setState(() => _autoValidateMode = AutovalidateMode.always);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth < 440 ? 14.0 : 22.0;
        final maxWidth = constraints.maxWidth > 1024 ? 600.0 : double.infinity;

        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            16,
            horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Form(
                key: _formKey,
                autovalidateMode: _autoValidateMode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Walk-in Patients',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_formErrorText != null) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1F1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          _formErrorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'FIRST NAME',
                            hint: 'First Name',
                            fieldKey: 'first_name',
                            controller: _firstNameController,
                            validator: (val) => _mergeFieldError(
                              'first_name',
                              AppFormValidators.requiredName(
                                val,
                                fieldLabel: 'First name',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'SURNAME',
                            hint: 'Surname',
                            fieldKey: 'surname',
                            controller: _surnameController,
                            validator: (val) => _mergeFieldError(
                              'surname',
                              AppFormValidators.requiredName(
                                val,
                                fieldLabel: 'Surname',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'MIDDLE NAME',
                      hint: 'Middle Name',
                      fieldKey: 'middle_name',
                      controller: _middleNameController,
                      validator: (val) => _mergeFieldError(
                        'middle_name',
                        AppFormValidators.optionalName(
                          val,
                          fieldLabel: 'Middle name',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'ADDRESS',
                      hint: 'Address',
                      fieldKey: 'address',
                      controller: _addressController,
                      validator: (val) => _mergeFieldError(
                        'address',
                        AppFormValidators.address(
                          val,
                          fieldLabel: 'Address',
                          required: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Gender',
                      hint: 'Gender',
                      fieldKey: 'gender',
                      value: _gender,
                      items: _genders,
                      onChanged: (val) {
                        setState(() => _gender = val);
                        _clearFieldError('gender');
                      },
                      validator: (val) => _mergeFieldError(
                        'gender',
                        AppFormValidators.gender(val, required: true),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Contact Number',
                      hint: 'Contact Number',
                      fieldKey: 'contact_number',
                      controller: _contactNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters:
                          AppFormValidators.contactNumberInputFormatters(),
                      validator: (val) => _mergeFieldError(
                        'contact_number',
                        AppFormValidators.contactNumber(val),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Divider(color: Color(0xFF679B6A), thickness: 3),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'APPOINTMENT DETAILS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _buildDropdownField(
                      label: 'SERVICE TYPE',
                      hint: 'Select Service',
                      fieldKey: 'service_type',
                      value: _serviceType,
                      items: _serviceTypes,
                      onChanged: (val) {
                        setState(() => _serviceType = val);
                        _clearFieldError('service_type');
                      },
                      validator: (val) => _mergeFieldError(
                        'service_type',
                        val == null ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDatePickerField(
                            label: 'APPT DATE',
                            hint: 'DD/MM/YYYY',
                            fieldKey: 'appointment_date',
                            value: _selectedDate != null
                                ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                                : null,
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTimePickerField(
                            label: 'APPT TIME',
                            hint: '--:-- --',
                            fieldKey: 'appointment_time',
                            value: _selectedTimeLabel(),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF679B6A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Add To Patient record',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String fieldKey,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          onChanged: (_) => _clearFieldError(fieldKey),
          validator: validator,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: _inputDecoration(hint),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String fieldKey,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: (value) {
            onChanged(value);
            _clearFieldError(fieldKey);
          },
          validator: validator,
          decoration: _inputDecoration(hint),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required String hint,
    required String fieldKey,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        FormField<String>(
          validator: (val) =>
              _mergeFieldError(fieldKey, value == null ? 'Required' : null),
          builder: (state) {
            return InkWell(
              onTap: onTap,
              child: InputDecorator(
                decoration: _inputDecoration('').copyWith(
                  suffixIcon: const Icon(
                    Icons.calendar_today,
                    size: 20,
                    color: Colors.black54,
                  ),
                  errorText: state.errorText,
                ),
                child: Text(
                  value ?? hint,
                  style: TextStyle(
                    color: value == null ? Colors.black38 : Colors.black87,
                    fontSize: 16,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTimePickerField({
    required String label,
    required String hint,
    required String fieldKey,
    required String? value,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        FormField<String>(
          validator: (val) =>
              _mergeFieldError(fieldKey, value == null ? 'Required' : null),
          builder: (state) {
            return InkWell(
              onTap: onTap,
              child: InputDecorator(
                decoration: _inputDecoration('').copyWith(
                  suffixIcon: const Icon(
                    Icons.access_time,
                    size: 20,
                    color: Colors.black54,
                  ),
                  errorText: state.errorText,
                ),
                child: _buildAvailabilityContent(value ?? hint),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildAvailabilityContent(String fallbackText) {
    if (_selectedDate == null) {
      return Text(
        fallbackText,
        style: const TextStyle(color: Colors.black38, fontSize: 16),
      );
    }

    if (_isLoadingAvailability) {
      return const SizedBox(
        height: 44,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_availabilitySlots.isEmpty) {
      return const Text(
        'No slots available',
        style: TextStyle(color: Colors.black54, fontSize: 16),
      );
    }

    final List<Map<String, dynamic>> blockedSlots = _availabilitySlots
        .where(
          (Map<String, dynamic> slot) =>
              _effectiveSlotStatus(slot) == 'doctor_unavailable',
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availabilitySlots.map((slot) {
            final bool disabled = _isSlotDisabled(slot);
            final bool selected = _selectedTimeSlot == slot['time'];

            return ChoiceChip(
              label: Text(
                slot['time_label']?.toString() ?? slot['time'].toString(),
              ),
              selected: selected,
              onSelected: disabled
                  ? null
                  : (_) {
                      setState(
                        () => _selectedTimeSlot = slot['time']?.toString(),
                      );
                      _clearFieldError('appointment_time');
                      _formKey.currentState?.validate();
                    },
              disabledColor: _slotDisabledColor(slot),
              selectedColor: const Color(0xFF679B6A),
              labelStyle: TextStyle(
                color: selected
                    ? Colors.white
                    : disabled
                    ? const Color(0xFF475569)
                    : const Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
            );
          }).toList(),
        ),
        if (_selectedTimeSlot != null) ...[
          const SizedBox(height: 8),
          Text(
            'Selected: ${_selectedTimeLabel() ?? _selectedTimeSlot!}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
        if (blockedSlots.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Doctor Unavailable',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFB45309),
            ),
          ),
          const SizedBox(height: 2),
          ..._unavailableRanges.map((Map<String, dynamic> range) {
            final String start = range['start_time']?.toString() ?? '--:--';
            final String end = range['end_time']?.toString() ?? '--:--';
            final String rawReason = range['reason']?.toString().trim() ?? '';
            final String reason = rawReason.isNotEmpty
                ? rawReason
                : 'Doctor Unavailable';

            return Text(
              '$start - $end: $reason',
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            );
          }),
        ],
      ],
    );
  }

  Future<void> _loadAvailabilityForSelectedDate() async {
    if (_selectedDate == null) {
      return;
    }

    setState(() => _isLoadingAvailability = true);

    try {
      final payload = await widget.appointmentService.getAvailabilitySlots(
        _selectedDate!.toIso8601String().split('T')[0],
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
        _isLoadingAvailability = false;
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
        _fieldErrors['appointment_time'] = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoadingAvailability = false;
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
      });
    }
  }

  String? _selectedTimeLabel() {
    if (_selectedTimeSlot == null) {
      return null;
    }

    final slot = _availabilitySlots.cast<Map<String, dynamic>?>().firstWhere(
      (item) => item?['time'] == _selectedTimeSlot,
      orElse: () => null,
    );

    return slot?['time_label']?.toString() ?? _selectedTimeSlot;
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

  Color _slotDisabledColor(Map<String, dynamic> slot) {
    switch (_effectiveSlotStatus(slot)) {
      case 'doctor_unavailable':
        return const Color(0xFFFDE68A);
      case 'booked':
        return const Color(0xFFE2E8F0);
      case 'past':
        return const Color(0xFFE5E7EB);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        borderSide: const BorderSide(color: Color(0xFF679B6A), width: 1.5),
      ),
      errorStyle: const TextStyle(height: 0.8),
    );
  }
}
