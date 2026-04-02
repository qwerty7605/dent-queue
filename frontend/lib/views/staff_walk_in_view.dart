import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_exception.dart';
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
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactNumberController = TextEditingController();

  String? _gender;
  String? _serviceType;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isSubmitting = false;

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
      setState(() => _selectedDate = picked);
      _formKey.currentState?.validate(); // Re-validate
    }
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF679B6A), // indicator and header
              onPrimary: Colors.white, // header text color
              onSurface: Color(0xFF2C3E50), // dial numbers
              surface: Colors.white, // dial background
              surfaceContainerHighest: Color(
                0xFFE2E8F0,
              ), // unselected boxes background
            ),
            timePickerTheme: TimePickerThemeData(
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Color(0xFF679B6A)
                    : Colors.transparent,
              ),
              dayPeriodTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : const Color(0xFF2C3E50),
              ),
              hourMinuteColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? const Color(0xFF679B6A)
                    : const Color(0xFFE2E8F0),
              ),
              hourMinuteTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : const Color(0xFF2C3E50),
              ),
              dialHandColor: const Color(0xFF679B6A),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF679B6A), // button text color
              ),
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );
    if (picked != null) {
      final double timeInDouble = picked.hour + picked.minute / 60.0;

      // Rule 1: Prevent time selection outside 7:30 AM (7.5) - 6:00 PM (18.0)
      if (timeInDouble < 7.5 || timeInDouble > 18.0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a time between 7:30 AM and 6:00 PM'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Rule 2: If selecting today, prevent selecting past time
      final now = DateTime.now();
      final isToday =
          _selectedDate!.year == now.year &&
          _selectedDate!.month == now.month &&
          _selectedDate!.day == now.day;

      if (isToday) {
        final double nowInDouble = now.hour + now.minute / 60.0;
        if (timeInDouble <= nowInDouble) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot book an appointment in the past'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }

      setState(() => _selectedTime = picked);
      _formKey.currentState?.validate(); // Re-validate
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final timeStr =
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}';

      final payload = {
        'first_name': _firstNameController.text.trim(),
        'surname': _surnameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'address': _addressController.text.trim(),
        'gender': _gender,
        'contact_number': _contactNumberController.text.trim(),
        'service_type': _serviceType,
        'appointment_date': dateStr,
        'appointment_time': timeStr,
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
          buttonLabel: 'DONE',
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
          _selectedTime = null;
        });

        widget.onWalkInSuccess();
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);

        String errorMessage = e.message;
        if (e.errors != null && e.errors!.isNotEmpty) {
          errorMessage = e.errors!.values.first.first;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'FIRST NAME',
                            hint: 'First Name',
                            controller: _firstNameController,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'SURNAME',
                            hint: 'Surname',
                            controller: _surnameController,
                            validator: (val) =>
                                val == null || val.trim().isEmpty
                                ? 'Required'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'MIDDLE NAME',
                      hint: 'Middle Name',
                      controller: _middleNameController,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'ADDRESS',
                      hint: 'Address',
                      controller: _addressController,
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildDropdownField(
                      label: 'Gender',
                      hint: 'Gender',
                      value: _gender,
                      items: _genders,
                      onChanged: (val) => setState(() => _gender = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Contact Number',
                      hint: 'Contact Number',
                      controller: _contactNumberController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (val) {
                        final trimmed = val?.trim() ?? '';
                        if (trimmed.isEmpty) return 'Required';
                        if (!RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
                          return 'Enter an 11-digit number starting with 09';
                        }
                        return null;
                      },
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
                      value: _serviceType,
                      items: _serviceTypes,
                      onChanged: (val) => setState(() => _serviceType = val),
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildDatePickerField(
                            label: 'APPT DATE',
                            hint: 'DD/MM/YYYY',
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
                            value: _selectedTime != null
                                ? '${_selectedTime!.hourOfPeriod == 0 ? 12 : _selectedTime!.hourOfPeriod}:${_selectedTime!.minute.toString().padLeft(2, '0')} ${_selectedTime!.period == DayPeriod.am ? 'AM' : 'PM'}'
                                : null,
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
          onChanged: onChanged,
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
          validator: (val) => value == null ? 'Required' : null,
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
          validator: (val) => value == null ? 'Required' : null,
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
