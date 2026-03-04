import 'package:flutter/material.dart';

class BookAppointmentDialog extends StatefulWidget {
  const BookAppointmentDialog({super.key});

  @override
  State<BookAppointmentDialog> createState() => _BookAppointmentDialogState();
}

class _BookAppointmentDialogState extends State<BookAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  final TextEditingController _notesController = TextEditingController();

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
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      // Close dialog successfully, here we would normally pass the data back or call an API
      Navigator.of(context).pop();
    }
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: Color(0xFF7E8CA0),
        letterSpacing: 0.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Title and Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24), // Balance the close button
                    const Expanded(
                      child: Text(
                        'Book Appointment',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close, color: Color(0xFF7E8CA0)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Service Type Dropdown
                _buildLabel('SERVICE TYPE'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      borderSide: const BorderSide(color: Color(0xFF679B6A), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  hint: const Text('Select Service', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF1E293B), size: 28),
                  isExpanded: true,
                  value: _selectedService,
                  items: _services.map((service) {
                    return DropdownMenuItem(
                      value: service,
                      child: Text(
                        service,
                        style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedService = val;
                      _formKey.currentState?.validate();
                    });
                  },
                  validator: (value) => value == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Date and Time Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 12,
                      child: _buildDateField(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 11,
                      child: _buildTimeField(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Additional Notes
                _buildLabel('ADDITIONAL NOTES'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Any concerns?',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
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
                      borderSide: const BorderSide(color: Color(0xFF679B6A), width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                  style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 32),

                // Confirm Booking Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF679B6A),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontSize: 16,
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
  }

  Widget _buildDateField() {
    return FormField<DateTime>(
      validator: (val) => _selectedDate == null ? 'Required' : null,
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
                final initial = isSunday ? now.add(const Duration(days: 1)) : now;
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
                  });
                  state.didChange(picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF1E293B), size: 18),
                ),
                isEmpty: _selectedDate == null,
                child: Text(
                  _selectedDate == null
                      ? 'dd/mm/yyyy'
                      : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}',
                  style: TextStyle(
                    color: _selectedDate == null ? const Color(0xFF94A3B8) : const Color(0xFF2C3E50),
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
    return FormField<TimeOfDay>(
      validator: (val) {
        if (_selectedTime == null) return 'Required';
        
        // Final validation before submit just in case
        if (_selectedDate != null) {
          final now = DateTime.now();
          final isToday = _selectedDate!.year == now.year &&
                          _selectedDate!.month == now.month &&
                          _selectedDate!.day == now.day;
                          
          if (isToday) {
            final double timeInDouble = _selectedTime!.hour + _selectedTime!.minute / 60.0;
            final double nowInDouble = now.hour + now.minute / 60.0;
            if (timeInDouble <= nowInDouble) {
              return 'Invalid Time';
            }
          }
        }
        return null;
      },
      builder: (FormFieldState<TimeOfDay> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('TIME'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                if (_selectedDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a date first'),
                      backgroundColor: Colors.redAccent,
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
                  final double timeInDouble = picked.hour + picked.minute / 60.0;
                  
                  // Rule 1: Prevent time selection outside 7:30 AM (7.5) - 6:00 PM (18.0)
                  if (timeInDouble < 7.5 || timeInDouble > 18.0) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a time between 7:30 AM and 6:00 PM'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }

                  // Rule 2: If selecting today, prevent selecting past time
                  final now = DateTime.now();
                  final isToday = _selectedDate!.year == now.year &&
                                  _selectedDate!.month == now.month &&
                                  _selectedDate!.day == now.day;
                                  
                  if (isToday) {
                    final double nowInDouble = now.hour + now.minute / 60.0;
                    if (timeInDouble <= nowInDouble) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Cannot book an appointment in the past'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }
                  }

                  setState(() {
                    _selectedTime = picked;
                  });
                  state.didChange(picked);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                  suffixIcon: const Icon(Icons.access_time_outlined, color: Color(0xFF1E293B), size: 18),
                ),
                isEmpty: _selectedTime == null,
                child: Text(
                  _selectedTime == null
                      ? '--:-- --'
                      : _selectedTime!.format(context),
                  style: TextStyle(
                    color: _selectedTime == null ? const Color(0xFF94A3B8) : const Color(0xFF2C3E50),
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
}
