import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StaffBookAppointmentDialog extends StatefulWidget {
  const StaffBookAppointmentDialog({
    super.key,
    required this.patient,
  });

  final Map<String, String> patient;

  @override
  State<StaffBookAppointmentDialog> createState() => _StaffBookAppointmentDialogState();
}

class _StaffBookAppointmentDialogState extends State<StaffBookAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String? _selectedService = 'Dental Panoramic X-ray';
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final List<String> _services = [
    'Dental Panoramic X-ray',
    'Teeth Cleaning',
    'Tooth Extraction',
    'Consultation',
    'Braces Adjustment',
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
        final timeString = format.format(DateTime(2020, 1, 1, picked.hour, picked.minute));
        _timeController.text = timeString;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Logic to actually book the appointment will go here
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
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
        const Align(
          alignment: Alignment.center,
          child: Text(
            'Book Appointment',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(
              Icons.close,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
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
          fontSize: 12,
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
                  fontSize: 15,
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
          },
        ),
      ],
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
          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
          style: const TextStyle(
            fontSize: 15,
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
          validator: (value) => value == null || value.isEmpty ? 'Required' : null,
          style: const TextStyle(
            fontSize: 15,
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
          maxLines: 4,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Color(0xFF1E293B),
          ),
          decoration: _inputDecoration(
            hint: 'Any concerns?',
          ),
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
        onPressed: _submit,
        child: const Text(
          'Confirm Booking',
          style: TextStyle(
            fontSize: 16,
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
        fontSize: 15,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
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
      suffixIcon: suffixIcon != null
          ? Icon(
              suffixIcon,
              color: const Color(0xFF475569),
              size: 20,
            )
          : null,
    );
  }
}
