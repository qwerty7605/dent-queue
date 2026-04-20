import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/admin_settings_service.dart';

class AdminSettingsView extends StatefulWidget {
  const AdminSettingsView({
    super.key,
    required this.adminSettingsService,
    required this.canManageSettings,
    this.onNotify,
  });

  final AdminSettingsService adminSettingsService;
  final bool canManageSettings;
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
  DateTime? _unavailableDate;
  TimeOfDay? _unavailableStartTime;
  TimeOfDay? _unavailableEndTime;
  final TextEditingController _unavailableReasonController =
      TextEditingController();
  List<Map<String, dynamic>> _doctorUnavailability = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingUnavailable = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    if (!widget.canManageSettings) {
      _isLoading = false;
      _loadError = 'Only admin accounts can manage clinic settings.';
      return;
    }

    _loadSettings();
  }

  @override
  void dispose() {
    _unavailableReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final settings = await widget.adminSettingsService.getClinicSettings();
      final doctorUnavailability = await widget.adminSettingsService
          .getDoctorUnavailability();

      if (!mounted) {
        return;
      }

      setState(() {
        _applySettings(settings);
        _doctorUnavailability = doctorUnavailability;
        _isLoading = false;
        _loadError = null;
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = _resolveApiErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _loadError = 'Failed to load clinic settings.';
      });
    }
  }

  Future<void> _pickUnavailableDate() async {
    final DateTime initialDate = _unavailableDate ?? DateTime.now();
    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      _unavailableDate = selectedDate;
    });
  }

  Future<void> _pickUnavailableTime({required bool isStart}) async {
    final TimeOfDay initialTime = isStart
        ? (_unavailableStartTime ??
              (_openingTime ?? const TimeOfDay(hour: 8, minute: 0)))
        : (_unavailableEndTime ??
              (_closingTime ?? const TimeOfDay(hour: 17, minute: 0)));

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _unavailableStartTime = selectedTime;
      } else {
        _unavailableEndTime = selectedTime;
      }
    });
  }

  void _applySettings(Map<String, dynamic> settings) {
    _openingTime = _parseTimeOfDay(settings['opening_time']?.toString());
    _closingTime = _parseTimeOfDay(settings['closing_time']?.toString());

    final resolvedDays = _normalizeWorkingDays(settings['working_days']);
    _selectedDays
      ..clear()
      ..addAll(resolvedDays.isEmpty ? _defaultWorkingDays : resolvedDays);
  }

  Future<void> _pickTime({required bool isOpeningTime}) async {
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
    final validationMessage = _validateBeforeSave();
    if (validationMessage != null) {
      _showSnackBar(validationMessage, isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final response = await widget.adminSettingsService.saveClinicSettings({
        'opening_time': _formatTimeForApi(_openingTime!),
        'closing_time': _formatTimeForApi(_closingTime!),
        'working_days': _orderedSelectedDays(),
      });

      if (!mounted) {
        return;
      }

      final responseData = response['data'];
      if (responseData is Map) {
        setState(() {
          _applySettings(Map<String, dynamic>.from(responseData));
        });
      }

      final message = response['message']?.toString().trim();
      final resolvedMessage = message == null || message.isEmpty
          ? 'Clinic settings updated.'
          : message;

      widget.onNotify?.call(
        'Clinic settings updated',
        'Opening hours and working days were saved successfully.',
      );

      _showSnackBar(resolvedMessage);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(_resolveApiErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Failed to save clinic settings.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveDoctorUnavailability() async {
    final String? validationMessage = _validateUnavailableBeforeSave();
    if (validationMessage != null) {
      _showSnackBar(validationMessage, isError: true);
      return;
    }

    setState(() {
      _isSavingUnavailable = true;
    });

    try {
      final List<Map<String, dynamic>> result = await widget
          .adminSettingsService
          .createDoctorUnavailability(<String, dynamic>{
            'unavailable_date': _formatDateForApi(_unavailableDate!),
            'start_time': _formatTimeForApi(_unavailableStartTime!),
            'end_time': _formatTimeForApi(_unavailableEndTime!),
            'reason': _unavailableReasonController.text.trim(),
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _doctorUnavailability = result;
        _unavailableDate = null;
        _unavailableStartTime = null;
        _unavailableEndTime = null;
        _unavailableReasonController.clear();
      });

      _showSnackBar('Doctor unavailability saved successfully.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(_resolveApiErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Failed to save doctor unavailability.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUnavailable = false;
        });
      }
    }
  }

  Future<void> _deleteDoctorUnavailability(int id) async {
    try {
      await widget.adminSettingsService.deleteDoctorUnavailability(id);

      if (!mounted) {
        return;
      }

      setState(() {
        _doctorUnavailability.removeWhere(
          (Map<String, dynamic> item) => item['id'] == id,
        );
      });

      _showSnackBar('Doctor unavailability removed successfully.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showSnackBar(_resolveApiErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showSnackBar('Failed to remove doctor unavailability.', isError: true);
    }
  }

  String? _validateBeforeSave() {
    if (_openingTime == null) {
      return 'Opening time is required.';
    }

    if (_closingTime == null) {
      return 'Closing time is required.';
    }

    if (_selectedDays.isEmpty) {
      return 'At least one working day must be selected.';
    }

    if (_toMinutes(_closingTime!) <= _toMinutes(_openingTime!)) {
      return 'Closing time must be later than opening time.';
    }

    return null;
  }

  String? _validateUnavailableBeforeSave() {
    if (_unavailableDate == null) {
      return 'Unavailable date is required.';
    }

    if (_unavailableStartTime == null) {
      return 'Unavailable start time is required.';
    }

    if (_unavailableEndTime == null) {
      return 'Unavailable end time is required.';
    }

    if (_toMinutes(_unavailableEndTime!) <=
        _toMinutes(_unavailableStartTime!)) {
      return 'Unavailable end time must be later than start time.';
    }

    return null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFD32F2F)
              : const Color(0xFF497A52),
        ),
      );
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final parts = value.trim().split(':');
    if (parts.length < 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  List<String> _normalizeWorkingDays(dynamic rawWorkingDays) {
    if (rawWorkingDays is! List) {
      return <String>[];
    }

    final selectedLookup = <String>{};
    for (final day in rawWorkingDays) {
      final label = day?.toString().trim() ?? '';
      if (label.isNotEmpty) {
        selectedLookup.add(label);
      }
    }

    return _allDays.where(selectedLookup.contains).toList();
  }

  List<String> _orderedSelectedDays() {
    return _allDays.where(_selectedDays.contains).toList();
  }

  String _formatTimeForApi(TimeOfDay value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _formatDateForApi(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  int _toMinutes(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }

  String _resolveApiErrorMessage(ApiException error) {
    final errors = error.errors;
    if (errors != null) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }

        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    return error.message;
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF5D8A72), width: 8),
                          bottom: BorderSide(
                            color: Color(0xFF6B6B6B),
                            width: 1,
                          ),
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
                    _buildCardBody(context),
                    Container(height: 10, color: const Color(0xFF5D8A72)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardBody(BuildContext context) {
    if (_isLoading) {
      return _buildStatusState(
        icon: Icons.settings_outlined,
        message: 'Loading current clinic settings...',
        actionLabel: null,
      );
    }

    if (_loadError != null) {
      return _buildStatusState(
        icon: Icons.lock_outline,
        message: _loadError!,
        actionLabel: widget.canManageSettings ? 'Retry' : null,
        onAction: widget.canManageSettings ? _loadSettings : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        _buildFieldSection(
          label: 'Doctor Unavailability',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildDateActionField(
                    label: 'Unavailable Date',
                    value: _unavailableDate == null
                        ? null
                        : _formatDateForApi(_unavailableDate!),
                    placeholder: 'Select Date',
                    onTap: _pickUnavailableDate,
                  ),
                  _buildDateActionField(
                    label: 'Start Time',
                    value: _unavailableStartTime?.format(context),
                    placeholder: 'Start Time',
                    onTap: () => _pickUnavailableTime(isStart: true),
                  ),
                  _buildDateActionField(
                    label: 'End Time',
                    value: _unavailableEndTime?.format(context),
                    placeholder: 'End Time',
                    onTap: () => _pickUnavailableTime(isStart: false),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _unavailableReasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 255,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildPresetButton(
                    label: 'Morning Only',
                    onTap: () => _applyUnavailablePreset(blockMorning: false),
                  ),
                  _buildPresetButton(
                    label: 'Afternoon Only',
                    onTap: () => _applyUnavailablePreset(blockMorning: true),
                  ),
                  _buildPresetButton(
                    label: 'Block Whole Day',
                    onTap: _applyWholeDayPreset,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _isSavingUnavailable
                      ? null
                      : _saveDoctorUnavailability,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB45309),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSavingUnavailable
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Unavailable Range'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Saved unavailable schedules',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              if (_doctorUnavailability.isEmpty)
                const Text(
                  'No blocked schedules yet.',
                  style: TextStyle(color: Color(0xFF64748B)),
                )
              else
                Column(
                  children: _doctorUnavailability.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Text(
                          '${item['unavailable_date']}  ${item['start_time']} - ${item['end_time']}',
                        ),
                        subtitle: Text(
                          (item['reason']?.toString().trim().isNotEmpty ??
                                  false)
                              ? item['reason'].toString()
                              : 'Doctor Unavailable',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteDoctorUnavailability(
                            (item['id'] as num).toInt(),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          child: Center(
            child: SizedBox(
              width: 280,
              height: 58,
              child: ElevatedButton(
                onPressed: (_isSaving || _isLoading) ? null : _saveSettings,
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
      ],
    );
  }

  Widget _buildStatusState({
    required IconData icon,
    required String message,
    required String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 38, color: const Color(0xFF497A52)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF39453D),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1A2F64),
                side: const BorderSide(color: Color(0xFF1A2F64)),
              ),
              child: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldSection({required String label, required Widget child}) {
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
        Padding(padding: const EdgeInsets.all(18), child: child),
      ],
    );
  }

  Widget _buildDateActionField({
    required String label,
    required String? value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: onTap,
            child: InputDecorator(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.edit_calendar),
              ),
              child: Text(value ?? placeholder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton(onPressed: onTap, child: Text(label));
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
                    color: hasValue
                        ? const Color(0xFF1D2A20)
                        : const Color(0xFF7A7A7A),
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
              color: isSelected
                  ? const Color(0xFF15311B)
                  : const Color(0xFF5E5E5E),
            ),
          ),
        ),
      ),
    );
  }

  void _applyUnavailablePreset({required bool blockMorning}) {
    final TimeOfDay opening =
        _openingTime ?? const TimeOfDay(hour: 7, minute: 30);
    final TimeOfDay closing =
        _closingTime ?? const TimeOfDay(hour: 18, minute: 0);
    final TimeOfDay midday = const TimeOfDay(hour: 12, minute: 0);

    setState(() {
      _unavailableDate ??= DateTime.now();
      if (blockMorning) {
        _unavailableStartTime = opening;
        _unavailableEndTime = midday;
        _unavailableReasonController.text =
            'Doctor available in the afternoon only';
      } else {
        _unavailableStartTime = midday;
        _unavailableEndTime = closing;
        _unavailableReasonController.text =
            'Doctor available in the morning only';
      }
    });
  }

  void _applyWholeDayPreset() {
    final TimeOfDay opening =
        _openingTime ?? const TimeOfDay(hour: 7, minute: 30);
    final TimeOfDay closing =
        _closingTime ?? const TimeOfDay(hour: 18, minute: 0);

    setState(() {
      _unavailableDate ??= DateTime.now();
      _unavailableStartTime = opening;
      _unavailableEndTime = closing;
      _unavailableReasonController.text =
          'Doctor unavailable for the whole day';
    });
  }
}
