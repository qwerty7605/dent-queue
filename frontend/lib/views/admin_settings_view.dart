import 'package:flutter/material.dart';

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({
    super.key,
    this.onNotify,
  });

  final void Function(String title, String message)? onNotify;

  @override
  State<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  static const List<String> _allDays = <String>[
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  ];

  static const Set<String> _defaultWorkingDays = <String>{
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  };

  TimeOfDay? _openingTime;
  TimeOfDay? _closingTime;
  final Set<String> _selectedDays = Set<String>.from(_defaultWorkingDays);
  bool _isSaving = false;

  Future<void> _pickTime({
    required bool isOpeningTime,
  }) async {
    final initialTime = isOpeningTime
        ? (_openingTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_closingTime ?? const TimeOfDay(hour: 17, minute: 0));

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF497A52),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1D2A20),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      if (isOpeningTime) {
        _openingTime = selectedTime;
      } else {
        _closingTime = selectedTime;
      }
    });
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 320));

    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    widget.onNotify?.call(
      'Clinic settings updated',
      'Operational hours and working days were updated from the admin settings page.',
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Clinic settings updated.'),
          backgroundColor: Color(0xFF497A52),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Clinic Settings',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F5F2),
                  border: Border.all(color: const Color(0xFF6B6B6B), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF5D8A72), width: 8),
                          bottom: BorderSide(color: Color(0xFF6B6B6B), width: 1),
                        ),
                      ),
                      child: const Text(
                        'Manage Operational Hours',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF555555),
                        ),
                      ),
                    ),
                    _buildFieldSection(
                      label: 'Opening Time',
                      child: _buildTimeField(
                        label: 'Enter Opening Time',
                        value: _openingTime,
                        onTap: () => _pickTime(isOpeningTime: true),
                      ),
                    ),
                    _buildFieldSection(
                      label: 'Closing Time',
                      child: _buildTimeField(
                        label: 'Enter Closing Time',
                        value: _closingTime,
                        onTap: () => _pickTime(isOpeningTime: false),
                      ),
                    ),
                    _buildFieldSection(
                      label: 'Working Days',
                      child: Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: _allDays.map(_buildDayChip).toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
                      child: Center(
                        child: SizedBox(
                          width: 280,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveSettings,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF497A52),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xFF7EA386),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Settings'),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      height: 10,
                      color: const Color(0xFF5D8A72),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldSection({
    required String label,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF6B6B6B), width: 1),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: child,
        ),
      ],
    );
  }

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? value,
    required VoidCallback onTap,
  }) {
    final hasValue = value != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF919191), width: 1.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  hasValue ? value.format(context) : label,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: hasValue ? FontWeight.w700 : FontWeight.w500,
                    color: hasValue ? const Color(0xFF1D2A20) : const Color(0xFF7A7A7A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFF111111),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayChip(String day) {
    final isSelected = _selectedDays.contains(day);

    return InkWell(
      onTap: () => _toggleDay(day),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 128,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFA4CCA9) : const Color(0xFFBDBDBD),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF497A52).withValues(alpha: 0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            day,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: isSelected ? const Color(0xFF15311B) : const Color(0xFF5E5E5E),
            ),
          ),
        ),
      ),
    );
  }
}
