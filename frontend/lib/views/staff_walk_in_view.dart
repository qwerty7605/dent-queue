import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_form_validators.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../services/appointment_service.dart';
import '../widgets/appointment_clock_picker.dart';
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
  int _currentStep = 0;

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
              primary: Color(0xFF4A769E), // header background color
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF2C3E50), // body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF4A769E), // button text color
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
          _currentStep = 0;
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
            18,
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
                    _buildPageTitle(),
                    const SizedBox(height: 18),
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1A2F64,
                            ).withValues(alpha: 0.10),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCurrentStepContent(),
                            const SizedBox(height: 24),
                            if (_formErrorText != null) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F1),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.25,
                                    ),
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
                            _buildStepActions(),
                          ],
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

  Widget _buildPageTitle() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A2F64).withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF1A2F64),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Walk-in Patients',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A2F64),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'CLINIC INTAKE PROCESS',
                style: TextStyle(
                  color: Color(0xFFA0AABF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    final List<_WalkInStepMeta> steps = <_WalkInStepMeta>[
      const _WalkInStepMeta(
        title: 'PERSONAL',
        icon: Icons.person_outline,
        completedIcon: Icons.check_circle_outline,
      ),
      const _WalkInStepMeta(
        title: 'CONTACT',
        icon: Icons.call_outlined,
        completedIcon: Icons.check_circle_outline,
      ),
      const _WalkInStepMeta(
        title: 'APPOINTMENT',
        icon: Icons.calendar_today_outlined,
        completedIcon: Icons.check_circle_outline,
      ),
    ];

    return Row(
      children: List<Widget>.generate(steps.length * 2 - 1, (int index) {
        if (index.isOdd) {
          final bool activeConnector = _currentStep > (index ~/ 2);
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 22),
              color: activeConnector
                  ? const Color(0xFF1A2F64)
                  : const Color(0xFFE6EBF4),
            ),
          );
        }

        final int stepIndex = index ~/ 2;
        final _WalkInStepMeta step = steps[stepIndex];
        final bool isActive = _currentStep == stepIndex;
        final bool isCompleted = _currentStep > stepIndex;

        return SizedBox(
          width: 92,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isActive || isCompleted
                      ? const Color(0xFF1A2F64)
                      : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isActive ? 0.14 : 0.05,
                      ),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  isCompleted ? step.completedIcon : step.icon,
                  color: isActive || isCompleted
                      ? Colors.white
                      : const Color(0xFFD0D7E6),
                  size: 20,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isActive || isCompleted
                      ? const Color(0xFF1A2F64)
                      : const Color(0xFFD0D7E6),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildContactStep();
      default:
        return _buildAppointmentStep();
    }
  }

  Widget _buildStepCardHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FE),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF1A2F64), size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A2F64),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepCardHeader(
          icon: Icons.person_outline,
          title: 'Personal Information',
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'FIRST NAME',
          hint: 'e.g. John',
          fieldKey: 'first_name',
          controller: _firstNameController,
          validator: (val) => _mergeFieldError(
            'first_name',
            AppFormValidators.requiredName(val, fieldLabel: 'First name'),
          ),
        ),
        const SizedBox(height: 18),
        _buildTextField(
          label: 'MIDDLE NAME (OPTIONAL)',
          hint: 'e.g. Quio',
          fieldKey: 'middle_name',
          controller: _middleNameController,
          validator: (val) => _mergeFieldError(
            'middle_name',
            AppFormValidators.optionalName(val, fieldLabel: 'Middle name'),
          ),
        ),
        const SizedBox(height: 18),
        _buildTextField(
          label: 'SURNAME',
          hint: 'e.g. Doe',
          fieldKey: 'surname',
          controller: _surnameController,
          validator: (val) => _mergeFieldError(
            'surname',
            AppFormValidators.requiredName(val, fieldLabel: 'Surname'),
          ),
        ),
        const SizedBox(height: 18),
        _buildDropdownField(
          label: 'GENDER',
          hint: 'Select Gender',
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
      ],
    );
  }

  Widget _buildContactStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepCardHeader(
          icon: Icons.call_outlined,
          title: 'Contact Information',
        ),
        const SizedBox(height: 24),
        _buildTextField(
          label: 'CONTACT NUMBER',
          hint: '09XXXXXXXXX',
          fieldKey: 'contact_number',
          controller: _contactNumberController,
          keyboardType: TextInputType.number,
          inputFormatters: AppFormValidators.contactNumberInputFormatters(),
          validator: (val) => _mergeFieldError(
            'contact_number',
            AppFormValidators.contactNumber(val),
          ),
        ),
        const SizedBox(height: 18),
        _buildTextField(
          label: 'FULL ADDRESS',
          hint: 'Unit/House No., Street,\nBrgy, City',
          fieldKey: 'address',
          controller: _addressController,
          maxLines: 3,
          prefixIcon: const Icon(
            Icons.location_on_outlined,
            color: Color(0xFFB4BDCC),
          ),
          validator: (val) => _mergeFieldError(
            'address',
            AppFormValidators.address(
              val,
              fieldLabel: 'Address',
              required: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepCardHeader(
          icon: Icons.calendar_today_outlined,
          title: 'Appointment Details',
        ),
        const SizedBox(height: 24),
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
          validator: (val) =>
              _mergeFieldError('service_type', val == null ? 'Required' : null),
        ),
        const SizedBox(height: 18),
        _buildDatePickerField(
          label: 'APPOINTMENT DATE',
          hint: 'dd/mm/yyyy',
          fieldKey: 'appointment_date',
          value: _selectedDate != null
              ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
              : null,
          onTap: _pickDate,
        ),
        const SizedBox(height: 18),
        _buildTimePickerField(
          label: 'APPOINTMENT TIME',
          hint: '--:-- --',
          fieldKey: 'appointment_time',
          value: _selectedTimeLabel(),
          onTap: _pickTime,
        ),
      ],
    );
  }

  Widget _buildStepActions() {
    final bool isLastStep = _currentStep == 2;
    final bool showBack = _currentStep > 0;

    return Row(
      children: [
        if (showBack)
          Expanded(
            child: SizedBox(
              height: 58,
              child: OutlinedButton(
                onPressed: _isSubmitting
                    ? null
                    : () {
                        setState(() {
                          _currentStep -= 1;
                          _autoValidateMode = AutovalidateMode.disabled;
                        });
                      },
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF76839A),
                  side: const BorderSide(color: Color(0xFFF0F3F8)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'BACK',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ),
          ),
        if (showBack) const SizedBox(width: 14),
        Expanded(
          flex: showBack ? 2 : 1,
          child: SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: _isSubmitting
                  ? null
                  : isLastStep
                  ? _submit
                  : _goToNextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A2F64),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 6,
                shadowColor: const Color(0xFF1A2F64).withValues(alpha: 0.30),
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
                  : Text(
                      isLastStep ? 'ADD TO PATIENT\nRECORD' : 'NEXT STEP',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _goToNextStep() {
    final bool valid = _currentStep == 0
        ? _validatePersonalStep()
        : _validateContactStep();

    if (!valid) {
      setState(() => _autoValidateMode = AutovalidateMode.always);
      return;
    }

    setState(() {
      _currentStep += 1;
      _autoValidateMode = AutovalidateMode.disabled;
    });
  }

  bool _validatePersonalStep() {
    final String? firstNameError = _mergeFieldError(
      'first_name',
      AppFormValidators.requiredName(
        _firstNameController.text,
        fieldLabel: 'First name',
      ),
    );
    final String? middleNameError = _mergeFieldError(
      'middle_name',
      AppFormValidators.optionalName(
        _middleNameController.text,
        fieldLabel: 'Middle name',
      ),
    );
    final String? surnameError = _mergeFieldError(
      'surname',
      AppFormValidators.requiredName(
        _surnameController.text,
        fieldLabel: 'Surname',
      ),
    );
    final String? genderError = _mergeFieldError(
      'gender',
      AppFormValidators.gender(_gender, required: true),
    );

    setState(() {
      _fieldErrors
        ..remove('first_name')
        ..remove('middle_name')
        ..remove('surname')
        ..remove('gender');
      if (firstNameError != null) {
        _fieldErrors['first_name'] = firstNameError;
      }
      if (middleNameError != null) {
        _fieldErrors['middle_name'] = middleNameError;
      }
      if (surnameError != null) {
        _fieldErrors['surname'] = surnameError;
      }
      if (genderError != null) {
        _fieldErrors['gender'] = genderError;
      }
    });
    _formKey.currentState?.validate();
    return firstNameError == null &&
        middleNameError == null &&
        surnameError == null &&
        genderError == null;
  }

  bool _validateContactStep() {
    final String? contactError = _mergeFieldError(
      'contact_number',
      AppFormValidators.contactNumber(_contactNumberController.text),
    );
    final String? addressError = _mergeFieldError(
      'address',
      AppFormValidators.address(
        _addressController.text,
        fieldLabel: 'Address',
        required: true,
      ),
    );

    setState(() {
      _fieldErrors
        ..remove('contact_number')
        ..remove('address');
      if (contactError != null) _fieldErrors['contact_number'] = contactError;
      if (addressError != null) _fieldErrors['address'] = addressError;
    });
    _formKey.currentState?.validate();
    return contactError == null && addressError == null;
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String fieldKey,
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    Widget? prefixIcon,
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
          maxLines: maxLines,
          decoration: _inputDecoration(hint).copyWith(prefixIcon: prefixIcon),
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
              onTap: () => _openTimePicker(state, onTap),
              child: InputDecorator(
                decoration: _inputDecoration('').copyWith(
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
                          Icons.access_time,
                          size: 20,
                          color: Colors.black54,
                        ),
                  errorText: state.errorText,
                ),
                child: Text(
                  _timeFieldLabel(value ?? hint),
                  style: TextStyle(
                    color: value == null
                        ? const Color(0xFFBFC8D6)
                        : Colors.black87,
                    fontSize: 16,
                    fontWeight: value == null
                        ? FontWeight.w600
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

  Future<void> _openTimePicker(
    FormFieldState<String> state,
    VoidCallback onTap,
  ) async {
    onTap();

    if (_selectedDate == null || !mounted) {
      return;
    }

    final String? selected = await showAppointmentTimePickerModal(
      context: context,
      slots: _availabilitySlots,
      selectedTimeSlot: _selectedTimeSlot,
      isSlotDisabled: _isSlotDisabled,
      unavailableRanges: _unavailableRanges,
      title: 'Choose Appointment Time',
      errorText: state.errorText,
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedTimeSlot = selected;
    });
    _clearFieldError('appointment_time');
    state.didChange(selected);
  }

  String _timeFieldLabel(String fallbackText) {
    if (_selectedDate == null) {
      return 'Select a date first';
    }

    if (_isLoadingAvailability) {
      return 'Loading available times...';
    }

    if (_selectedTimeSlot == null) {
      return _availabilitySlots.isEmpty
          ? 'Tap to view available times'
          : fallbackText;
    }

    return _selectedTimeLabel() ?? _selectedTimeSlot!;
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFFD6DCE7),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF1A2F64), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFDC2626)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
      ),
      errorStyle: const TextStyle(height: 0.8),
    );
  }
}

class _WalkInStepMeta {
  const _WalkInStepMeta({
    required this.title,
    required this.icon,
    required this.completedIcon,
  });

  final String title;
  final IconData icon;
  final IconData completedIcon;
}
