import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../services/appointment_service.dart';
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
  TimeOfDay? _selectedTime;

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  bool _isSubmitting = false;
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
    _timeController.dispose();
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
      });
      _clearFieldError('date');
      _clearFieldError('time');
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        final format = DateFormat('hh:mm a');
        final timeString = format.format(
          DateTime(2020, 1, 1, picked.hour, picked.minute),
        );
        _timeController.text = timeString;
      });
      _clearFieldError('time');
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
      'appointment_time':
          '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}',
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
        buttonLabel: 'DONE',
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            autovalidateMode: _autoValidateMode,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                if (_formErrorText != null) ...[
                  _buildErrorBanner(),
                  const SizedBox(height: 16),
                ],
                _buildServiceTypeDropdown(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildDateInput()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTimeInput()),
                  ],
                ),
                const SizedBox(height: 16),
                _buildNotesInput(),
                const SizedBox(height: 24),
                _buildConfirmButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            'Book Appointment',
            style: TextStyle(
              fontSize: MobileTypography.sectionTitle(context),
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: Color(0xFF94A3B8), size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: Color(0xFF64748B),
          letterSpacing: 0.5,
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
          decoration: _inputDecoration(),
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
        TextFormField(
          controller: _timeController,
          readOnly: true,
          onTap: _pickTime,
          validator: (value) => _mergeFieldError(
            'time',
            value == null || value.isEmpty ? 'Required' : null,
          ),
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
          decoration: _inputDecoration(
            hint: '--:-- --',
            suffixIcon: Icons.access_time,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel('ADDITIONAL NOTES'),
        TextFormField(
          controller: _notesController,
          onChanged: (_) => _clearFieldError('notes'),
          maxLines: 4,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
          decoration: _inputDecoration(hint: 'Any concerns?'),
          validator: (value) => _mergeFieldError('notes', null),
        ),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF679B6A),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF679B6A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      suffixIcon: suffixIcon != null
          ? Icon(suffixIcon, color: const Color(0xFF475569), size: 20)
          : null,
    );
  }
}
