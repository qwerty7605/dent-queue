import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class _DaySchedule {
  const _DaySchedule({required this.openingTime, required this.closingTime});

  final TimeOfDay? openingTime;
  final TimeOfDay? closingTime;

  _DaySchedule copyWith({TimeOfDay? openingTime, TimeOfDay? closingTime}) {
    return _DaySchedule(
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
    );
  }
}

class _AdminSettingsViewState extends State<AdminSettingsView> {
  static const Color _ink = Color(0xFF1A2F64);
  static const Color _muted = Color(0xFFA3AEC4);
  static const Color _border = Color(0xFFE6ECF7);
  static const Color _fieldFill = Color(0xFFF8FAFF);
  static const Color _mint = Color(0xFF1FBA8A);
  static const double _panelRadius = 38;
  static const List<String> _allDays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const Set<String> _defaultWorkingDays = <String>{
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
  };

  final Set<String> _selectedDays = Set<String>.from(_defaultWorkingDays);
  late final Map<String, _DaySchedule> _daySchedules = <String, _DaySchedule>{
    for (final String day in _allDays) day: _defaultDaySchedule(),
  };
  final TextEditingController _clinicTitleController = TextEditingController();
  final TextEditingController _practiceLicenseController =
      TextEditingController();
  final TextEditingController _operationalHotlineController =
      TextEditingController();
  final TextEditingController _clinicHeadquartersController =
      TextEditingController();
  final TextEditingController _unavailableReasonController =
      TextEditingController();
  DateTime? _unavailableDate;
  TimeOfDay? _unavailableStartTime;
  TimeOfDay? _unavailableEndTime;
  List<Map<String, dynamic>> _doctorUnavailability = <Map<String, dynamic>>[];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSavingUnavailable = false;
  String? _loadError;
  bool _isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  Color _surfaceColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF162033) : Colors.white;
  Color _surfaceAltColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF1B2740) : _fieldFill;
  Color _borderColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF30415F) : _border;
  Color _textColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFFEAF1FF) : _ink;
  Color _mutedTextColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFFAAB8D4) : _muted;
  Color _panelTintColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF18253A) : const Color(0xFFF3F6FE);
  Color _chipSurfaceColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF1A253A) : Colors.white;
  Color _iconPlateColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFF22314B) : Colors.white;
  Color _accentIconColor(BuildContext context) =>
      _isDarkMode(context) ? const Color(0xFFD7E4FF) : _ink;

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
    _clinicTitleController.dispose();
    _practiceLicenseController.dispose();
    _operationalHotlineController.dispose();
    _clinicHeadquartersController.dispose();
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
      final Map<String, dynamic> settings = await widget.adminSettingsService
          .getClinicSettings();
      final List<Map<String, dynamic>> doctorUnavailability = await widget
          .adminSettingsService
          .getDoctorUnavailability();

      if (!mounted) {
        return;
      }

      setState(() {
        _applySettings(settings);
        _doctorUnavailability = doctorUnavailability;
        _isLoading = false;
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

  void _applySettings(Map<String, dynamic> settings) {
    _clinicTitleController.text = settings['clinic_title']?.toString() ?? '';
    _practiceLicenseController.text =
        settings['practice_license_id']?.toString() ?? '';
    _operationalHotlineController.text =
        settings['operational_hotline']?.toString() ?? '';
    _clinicHeadquartersController.text =
        settings['clinic_headquarters']?.toString() ?? '';
    final Map<String, _DaySchedule> resolvedSchedules = _resolveDaySchedules(
      settings,
    );
    _selectedDays
      ..clear()
      ..addAll(
        resolvedSchedules.keys.isEmpty
            ? _defaultWorkingDays
            : resolvedSchedules.keys,
      );
    for (final String day in _allDays) {
      _daySchedules[day] = resolvedSchedules[day] ?? _defaultDaySchedule();
    }
  }

  Future<void> _pickTime({
    required String day,
    required bool isOpeningTime,
  }) async {
    final _DaySchedule currentSchedule =
        _daySchedules[day] ?? _defaultDaySchedule();
    final TimeOfDay initialTime = isOpeningTime
        ? (currentSchedule.openingTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (currentSchedule.closingTime ?? const TimeOfDay(hour: 17, minute: 0));

    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _ink,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
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
      _daySchedules[day] = isOpeningTime
          ? currentSchedule.copyWith(openingTime: selectedTime)
          : currentSchedule.copyWith(closingTime: selectedTime);
    });
  }

  Future<void> _pickGlobalTime({required bool isOpeningTime}) async {
    final List<String> days = _orderedSelectedDays();
    final String seedDay = days.isEmpty ? _allDays.first : days.first;
    await _pickTime(day: seedDay, isOpeningTime: isOpeningTime);

    if (!mounted) {
      return;
    }

    final _DaySchedule seedSchedule =
        _daySchedules[seedDay] ?? _defaultDaySchedule();
    setState(() {
      for (final String day in days) {
        _daySchedules[day] = isOpeningTime
            ? (_daySchedules[day] ?? _defaultDaySchedule()).copyWith(
                openingTime: seedSchedule.openingTime,
              )
            : (_daySchedules[day] ?? _defaultDaySchedule()).copyWith(
                closingTime: seedSchedule.closingTime,
              );
      }
    });
  }

  Future<void> _pickUnavailableDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _unavailableDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _unavailableDate = picked;
    });
  }

  Future<void> _pickUnavailableTime({required bool isStart}) async {
    final TimeOfDay initialTime = isStart
        ? (_unavailableStartTime ?? const TimeOfDay(hour: 8, minute: 0))
        : (_unavailableEndTime ?? const TimeOfDay(hour: 12, minute: 0));
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      if (isStart) {
        _unavailableStartTime = picked;
      } else {
        _unavailableEndTime = picked;
      }
    });
  }

  void _applyUnavailablePreset({required bool morningOnly}) {
    setState(() {
      _unavailableStartTime = morningOnly
          ? const TimeOfDay(hour: 8, minute: 0)
          : const TimeOfDay(hour: 13, minute: 0);
      _unavailableEndTime = morningOnly
          ? const TimeOfDay(hour: 12, minute: 0)
          : const TimeOfDay(hour: 17, minute: 0);
    });
  }

  void _applyWholeDayPreset() {
    setState(() {
      _unavailableStartTime = const TimeOfDay(hour: 8, minute: 0);
      _unavailableEndTime = const TimeOfDay(hour: 17, minute: 0);
    });
  }

  Future<void> _saveUnavailableRange() async {
    if (_unavailableDate == null) {
      _showSnackBar('Unavailable date is required.', isError: true);
      return;
    }
    if (_unavailableStartTime == null || _unavailableEndTime == null) {
      _showSnackBar('Start and end time are required.', isError: true);
      return;
    }
    if (_toMinutes(_unavailableEndTime!) <= _toMinutes(_unavailableStartTime!)) {
      _showSnackBar('End time must be later than start time.', isError: true);
      return;
    }

    setState(() {
      _isSavingUnavailable = true;
    });

    try {
      final List<Map<String, dynamic>> schedules = await widget
          .adminSettingsService
          .createDoctorUnavailability(<String, dynamic>{
            'unavailable_date': DateFormat('yyyy-MM-dd').format(
              _unavailableDate!,
            ),
            'start_time': _formatTimeForApi(_unavailableStartTime!),
            'end_time': _formatTimeForApi(_unavailableEndTime!),
            'reason': _nullableControllerValue(_unavailableReasonController),
          });

      if (!mounted) {
        return;
      }

      setState(() {
        _doctorUnavailability = schedules;
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
      _showSnackBar('Failed to save unavailable range.', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSavingUnavailable = false;
        });
      }
    }
  }

  Future<void> _deleteUnavailableRange(int id) async {
    try {
      await widget.adminSettingsService.deleteDoctorUnavailability(id);
      final List<Map<String, dynamic>> schedules = await widget
          .adminSettingsService
          .getDoctorUnavailability();
      if (!mounted) {
        return;
      }
      setState(() {
        _doctorUnavailability = schedules;
      });
      _showSnackBar('Unavailable range removed.');
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(_resolveApiErrorMessage(error), isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Failed to remove unavailable range.', isError: true);
    }
  }

  Future<void> _saveSettings() async {
    final String? validationMessage = _validateBeforeSave();
    if (validationMessage != null) {
      _showSnackBar(validationMessage, isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final Map<String, dynamic> response = await widget.adminSettingsService
          .saveClinicSettings(<String, dynamic>{
            'clinic_title': _nullableControllerValue(_clinicTitleController),
            'practice_license_id': _nullableControllerValue(
              _practiceLicenseController,
            ),
            'operational_hotline': _nullableControllerValue(
              _operationalHotlineController,
            ),
            'clinic_headquarters': _nullableControllerValue(
              _clinicHeadquartersController,
            ),
            'daily_operating_hours': _buildDailyOperatingHoursPayload(),
          });

      if (!mounted) {
        return;
      }

      final dynamic responseData = response['data'];
      if (responseData is Map) {
        setState(() {
          _applySettings(Map<String, dynamic>.from(responseData));
        });
      }

      final String message =
          response['message']?.toString().trim().isNotEmpty == true
          ? response['message'].toString().trim()
          : 'Clinic settings updated.';

      widget.onNotify?.call(
        'Clinic configuration updated',
        'Practice availability changes were saved successfully.',
      );
      _showSnackBar(message);
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

  String? _validateBeforeSave() {
    if (_selectedDays.isEmpty) {
      return 'At least one working day must be selected.';
    }

    for (final String day in _orderedSelectedDays()) {
      final _DaySchedule schedule = _daySchedules[day] ?? _defaultDaySchedule();

      if (schedule.openingTime == null) {
        return '$day opening time is required.';
      }

      if (schedule.closingTime == null) {
        return '$day closing time is required.';
      }

      if (_toMinutes(schedule.closingTime!) <=
          _toMinutes(schedule.openingTime!)) {
        return '$day closing time must be later than opening time.';
      }
    }

    return null;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? const Color(0xFFD32F2F) : _mint,
        ),
      );
  }

  TimeOfDay? _parseTimeOfDay(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final List<String> parts = value.trim().split(':');
    if (parts.length < 2) {
      return null;
    }

    final int? hour = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  List<String> _normalizeWorkingDays(dynamic rawWorkingDays) {
    if (rawWorkingDays is! List) {
      return <String>[];
    }

    final Set<String> selectedLookup = <String>{};
    for (final dynamic day in rawWorkingDays) {
      final String label = day?.toString().trim() ?? '';
      if (label.isNotEmpty) {
        selectedLookup.add(label);
      }
    }

    return _allDays.where(selectedLookup.contains).toList();
  }

  List<String> _orderedSelectedDays() {
    return _allDays.where(_selectedDays.contains).toList();
  }

  Map<String, dynamic> _buildDailyOperatingHoursPayload() {
    final Map<String, dynamic> payload = <String, dynamic>{};

    for (final String day in _orderedSelectedDays()) {
      final _DaySchedule schedule = _daySchedules[day] ?? _defaultDaySchedule();
      payload[day] = <String, dynamic>{
        'opening_time': _formatTimeForApi(schedule.openingTime!),
        'closing_time': _formatTimeForApi(schedule.closingTime!),
      };
    }

    return payload;
  }

  Map<String, _DaySchedule> _resolveDaySchedules(
    Map<String, dynamic> settings,
  ) {
    final dynamic rawDailyHours = settings['daily_operating_hours'];
    if (rawDailyHours is Map) {
      final Map<String, _DaySchedule> schedules = <String, _DaySchedule>{};
      for (final String day in _allDays) {
        final dynamic rawSchedule = rawDailyHours[day];
        if (rawSchedule is! Map) {
          continue;
        }

        schedules[day] = _DaySchedule(
          openingTime: _parseTimeOfDay(rawSchedule['opening_time']?.toString()),
          closingTime: _parseTimeOfDay(rawSchedule['closing_time']?.toString()),
        );
      }
      if (schedules.isNotEmpty) {
        return schedules;
      }
    }

    final TimeOfDay? openingTime = _parseTimeOfDay(
      settings['opening_time']?.toString(),
    );
    final TimeOfDay? closingTime = _parseTimeOfDay(
      settings['closing_time']?.toString(),
    );
    final List<String> resolvedDays = _normalizeWorkingDays(
      settings['working_days'],
    );

    if (openingTime == null || closingTime == null || resolvedDays.isEmpty) {
      return <String, _DaySchedule>{};
    }

    return <String, _DaySchedule>{
      for (final String day in resolvedDays)
        day: _DaySchedule(openingTime: openingTime, closingTime: closingTime),
    };
  }

  String _formatTimeForApi(TimeOfDay value) {
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  int _toMinutes(TimeOfDay value) {
    return value.hour * 60 + value.minute;
  }

  static _DaySchedule _defaultDaySchedule() {
    return const _DaySchedule(
      openingTime: TimeOfDay(hour: 8, minute: 0),
      closingTime: TimeOfDay(hour: 17, minute: 0),
    );
  }

  String? _nullableControllerValue(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String _resolveApiErrorMessage(ApiException error) {
    final Map<String, dynamic>? errors = error.errors;
    if (errors != null) {
      for (final dynamic value in errors.values) {
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
    final bool isPhone = MediaQuery.sizeOf(context).width < 1100;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        isPhone ? 16 : 28,
        18,
        isPhone ? 16 : 28,
        40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1220),
          child: _isLoading || _loadError != null
              ? _buildStateCard()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPageHeader(),
                    const SizedBox(height: 22),
                    _buildTopGrid(isPhone),
                    const SizedBox(height: 28),
                    _buildDoctorUnavailabilityCard(isPhone),
                    const SizedBox(height: 28),
                    _buildSavedSchedulesCard(),
                    const SizedBox(height: 36),
                    Center(child: _buildCommitButton()),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStateCard() {
    return _buildSettingsSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
        child: Column(
          children: [
            Icon(
              _loadError == null ? Icons.settings_outlined : Icons.lock_outline,
              size: 36,
              color: _textColor(context),
            ),
            const SizedBox(height: 16),
            Text(
              _loadError ?? 'Loading current clinic settings...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textColor(context),
              ),
            ),
            if (_loadError != null && widget.canManageSettings) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: _loadSettings,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textColor(context),
                  side: BorderSide(color: _textColor(context)),
                ),
                child: const Text('Retry'),
              ),
            ] else if (_loadError == null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.8,
                  color: _textColor(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clinic Settings',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: _textColor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MASTER CONFIGURATION FOR OPERATIONAL LOGIC, SCHEDULE BLOCKING, AND PRACTITIONER AVAILABILITY.',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: _mutedTextColor(context),
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }

  Widget _buildTopGrid(bool compact) {
    final Widget hoursCard = Expanded(child: _buildOperatingHoursCard());
    final Widget daysCard = Expanded(child: _buildWorkingDaysCard());

    if (compact) {
      return Column(
        children: [
          _buildOperatingHoursCard(),
          const SizedBox(height: 20),
          _buildWorkingDaysCard(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        hoursCard,
        const SizedBox(width: 20),
        daysCard,
      ],
    );
  }

  Widget _buildOperatingHoursCard() {
    final _DaySchedule schedule = _primaryDaySchedule();

    return _buildPanelCard(
      icon: Icons.access_time_rounded,
      title: 'Clinic Operating Hours',
      subtitle:
          'SET DAILY OPENING AND CLOSING TIME FOR APPOINTMENT VALIDATION.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 30),
        child: Wrap(
          spacing: 20,
          runSpacing: 18,
          children: [
            _buildLabeledTimeField(
              label: 'OPENING TIME',
              value: schedule.openingTime,
              helper: 'Patients can begin arriving at this time.',
              onTap: () => _pickGlobalTime(isOpeningTime: true),
            ),
            _buildLabeledTimeField(
              label: 'CLOSING TIME',
              value: schedule.closingTime,
              helper: 'The final slot ends strictly by this hour.',
              onTap: () => _pickGlobalTime(isOpeningTime: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingDaysCard() {
    return _buildPanelCard(
      icon: Icons.calendar_month_outlined,
      title: 'Working Days',
      subtitle: 'SELECT WHICH DAYS THE CLINIC ACCEPTS APPOINTMENTS.',
      trailing: TextButton(
        onPressed: () {
          setState(() {
            _selectedDays
              ..clear()
              ..addAll(_defaultWorkingDays);
          });
        },
        child: const Text('RESET'),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: _allDays.map(_buildDayChip).toList(),
            ),
            const SizedBox(height: 26),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: _surfaceAltColor(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _borderColor(context)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: _textColor(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'THE CLINIC IS CURRENTLY SET TO BE ACTIVE ON ${_selectedDays.length} DAYS PER WEEK.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _textColor(context),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorUnavailabilityCard(bool compact) {
    return _buildPanelCard(
      icon: Icons.calendar_today_outlined,
      title: 'Doctor Unavailability',
      subtitle: 'BLOCK DATES OR TIME RANGES WHEN THE DENTIST IS UNAVAILABLE.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
        child: compact
            ? Column(
                children: [
                  _buildDoctorUnavailabilityForm(),
                  const SizedBox(height: 20),
                  _buildScheduleBlockingPanel(),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildDoctorUnavailabilityForm()),
                  const SizedBox(width: 28),
                  Expanded(flex: 2, child: _buildScheduleBlockingPanel()),
                ],
              ),
      ),
    );
  }

  Widget _buildDoctorUnavailabilityForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            _buildLabeledInputField(
              label: 'UNAVAILABLE DATE',
              width: 348,
              child: _buildActionField(
                text: _unavailableDate == null
                    ? 'dd/mm/yyyy'
                    : DateFormat('dd/MM/yyyy').format(_unavailableDate!),
                leading: Icons.calendar_month_outlined,
                trailing: Icons.edit_calendar_outlined,
                onTap: _pickUnavailableDate,
              ),
            ),
            _buildLabeledInputField(
              label: 'REASON (OPTIONAL)',
              width: 348,
              child: TextField(
                controller: _unavailableReasonController,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _textColor(context),
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. Conference, Out of Town',
                  hintStyle: TextStyle(color: _mutedTextColor(context)),
                  prefixIcon: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: _mutedTextColor(context),
                  ),
                  filled: true,
                  fillColor: _chipSurfaceColor(context),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: _borderColor(context)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: _ink),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _buildLabeledInputField(
              label: 'START TIME',
              width: 166,
              child: _buildActionField(
                text: _formatTimeValue(_unavailableStartTime),
                leading: Icons.schedule_outlined,
                trailing: Icons.watch_later_outlined,
                onTap: () => _pickUnavailableTime(isStart: true),
              ),
            ),
            _buildLabeledInputField(
              label: 'END TIME',
              width: 166,
              child: _buildActionField(
                text: _formatTimeValue(_unavailableEndTime),
                leading: Icons.schedule_outlined,
                trailing: Icons.watch_later_outlined,
                onTap: () => _pickUnavailableTime(isStart: false),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildPresetButton(
                    label: 'MORNING\nONLY',
                    onTap: () => _applyUnavailablePreset(morningOnly: true),
                  ),
                  _buildPresetButton(
                    label: 'AFTERNOON\nONLY',
                    onTap: () => _applyUnavailablePreset(morningOnly: false),
                  ),
                  _buildPresetButton(
                    label: 'BLOCK\nWHOLE DAY',
                    onTap: _applyWholeDayPreset,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScheduleBlockingPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(26, 34, 26, 34),
      decoration: BoxDecoration(
        color: _panelTintColor(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: _iconPlateColor(context),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _ink.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: _accentIconColor(context),
              size: 36,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'SCHEDULE BLOCKING',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _textColor(context),
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'ONCE SAVED, PATIENTS CANNOT BOOK DURING THIS PERIOD ACROSS ANY CLINIC PORTAL.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _mutedTextColor(context),
              letterSpacing: 1.1,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isSavingUnavailable ? null : _saveUnavailableRange,
              style: ElevatedButton.styleFrom(
                backgroundColor: _ink,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: _isSavingUnavailable
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add, size: 18),
              label: const Text(
                'SAVE UNAVAILABLE RANGE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedSchedulesCard() {
    return _buildPanelCard(
      icon: Icons.history_toggle_off_rounded,
      title: 'Saved Unavailable Schedules',
      subtitle: '',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
        child: _doctorUnavailability.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Center(
                  child: Text(
                    'No unavailable schedules saved yet.',
                    style: TextStyle(
                      color: _mutedTextColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  _buildSavedSchedulesHeader(),
                  const SizedBox(height: 10),
                  for (final Map<String, dynamic> schedule
                      in _doctorUnavailability)
                    _buildSavedScheduleRow(schedule),
                ],
              ),
      ),
    );
  }

  Widget _buildPanelCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return _buildSettingsSurface(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 30, 32, 24),
            child: Row(
              children: [
                Icon(icon, color: _mutedTextColor(context), size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _textColor(context),
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _mutedTextColor(context),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ...?trailing == null ? null : <Widget>[trailing],
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: _borderColor(context)),
          child,
        ],
      ),
    );
  }

  Widget _buildTimePill(
    BuildContext context, {
    required TimeOfDay? value,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minWidth: 138),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: enabled
              ? _surfaceAltColor(context)
              : _surfaceColor(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value?.format(context) ?? '08:00 AM',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: enabled ? _textColor(context) : _mutedTextColor(context),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: enabled ? _textColor(context) : _mutedTextColor(context),
            ),
          ],
        ),
      ),
    );
  }

  _DaySchedule _primaryDaySchedule() {
    final List<String> selectedDays = _orderedSelectedDays();
    final String day = selectedDays.isEmpty ? _allDays.first : selectedDays.first;
    return _daySchedules[day] ?? _defaultDaySchedule();
  }

  Widget _buildLabeledTimeField({
    required String label,
    required TimeOfDay? value,
    required String helper,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _mutedTextColor(context),
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 12),
          _buildTimePill(
            context,
            value: value,
            enabled: true,
            onTap: onTap,
          ),
          const SizedBox(height: 10),
          Text(
            helper,
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: _mutedTextColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(String day) {
    final bool selected = _selectedDays.contains(day);
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedDays.remove(day);
          } else {
            _selectedDays.add(day);
          }
        });
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? _ink : _chipSurfaceColor(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _ink : _borderColor(context)),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _ink.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? Icons.check_circle_outline : Icons.circle_outlined,
              size: 16,
              color: selected ? Colors.white : _mutedTextColor(context),
            ),
            const SizedBox(width: 8),
            Text(
              day.substring(0, 3).toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : _textColor(context),
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledInputField({
    required String label,
    required double width,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: _mutedTextColor(context),
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildActionField({
    required String text,
    required IconData leading,
    required IconData trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: _chipSurfaceColor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Row(
          children: [
            Icon(leading, size: 18, color: _mutedTextColor(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: text.contains('dd/mm') || text.contains('--:--')
                      ? _mutedTextColor(context)
                      : _textColor(context),
                ),
              ),
            ),
            Icon(trailing, size: 18, color: _textColor(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: _chipSurfaceColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderColor(context)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: _textColor(context),
            letterSpacing: 1.4,
            height: 1.35,
          ),
        ),
      ),
    );
  }

  Widget _buildSavedSchedulesHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: const [
          Expanded(flex: 2, child: _ScheduleHeaderCell('DATE')),
          Expanded(flex: 2, child: _ScheduleHeaderCell('TIME RANGE')),
          Expanded(flex: 4, child: _ScheduleHeaderCell('STATUS / REASON')),
          Expanded(flex: 2, child: _ScheduleHeaderCell('TYPE')),
          SizedBox(width: 56, child: _ScheduleHeaderCell('ACTION')),
        ],
      ),
    );
  }

  Widget _buildSavedScheduleRow(Map<String, dynamic> schedule) {
    final int? id = schedule['id'] is int
        ? schedule['id'] as int
        : int.tryParse(schedule['id']?.toString() ?? '');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: _chipSurfaceColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderColor(context)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _formatScheduleDate(schedule['unavailable_date']?.toString()),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: _textColor(context),
                letterSpacing: 1.2,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatScheduleTimeRange(
                schedule['start_time']?.toString(),
                schedule['end_time']?.toString(),
              ),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textColor(context),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              (schedule['reason']?.toString().trim().isNotEmpty ?? false)
                  ? schedule['reason'].toString().toUpperCase()
                  : 'DOCTOR UNAVAILABLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _mutedTextColor(context),
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _resolveScheduleType(
                schedule['start_time']?.toString(),
                schedule['end_time']?.toString(),
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF23A7C6),
                letterSpacing: 1.3,
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: IconButton(
              onPressed: id == null ? null : () => _deleteUnavailableRange(id),
              icon: Icon(
                Icons.delete_outline_rounded,
                color: _mutedTextColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeValue(TimeOfDay? value) {
    return value == null ? '--:-- --' : value.format(context);
  }

  String _formatScheduleDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'N/A';
    }

    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(value)).toUpperCase();
    } catch (_) {
      return value.toUpperCase();
    }
  }

  String _formatScheduleTimeRange(String? start, String? end) {
    final TimeOfDay? startTime = _parseTimeOfDay(start);
    final TimeOfDay? endTime = _parseTimeOfDay(end);
    if (startTime == null || endTime == null) {
      return 'N/A';
    }
    return '${startTime.format(context)} - ${endTime.format(context)}';
  }

  String _resolveScheduleType(String? start, String? end) {
    final TimeOfDay? startTime = _parseTimeOfDay(start);
    final TimeOfDay? endTime = _parseTimeOfDay(end);
    if (startTime == null || endTime == null) {
      return 'CUSTOM';
    }

    final int startMinutes = _toMinutes(startTime);
    final int endMinutes = _toMinutes(endTime);
    if (startMinutes <= 8 * 60 && endMinutes <= 12 * 60) {
      return 'MORNING';
    }
    if (startMinutes >= 12 * 60) {
      return 'AFTERNOON';
    }
    if (startMinutes <= 8 * 60 && endMinutes >= 17 * 60) {
      return 'WHOLE DAY';
    }
    return 'CUSTOM';
  }

  Widget _buildCommitButton() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SizedBox(
          width: constraints.maxWidth < 420 ? double.infinity : 500,
          height: 66,
          child: ElevatedButton.icon(
            onPressed: (_isSaving || _isLoading) ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _ink.withValues(alpha: 0.46),
              elevation: 16,
              shadowColor: _ink.withValues(alpha: 0.26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined, size: 20),
            label: Text(
              _isSaving ? 'SAVING CHANGES' : 'SYNC CLINICAL PROTOCOLS',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingsSurface({required Widget child}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _surfaceColor(context),
        borderRadius: BorderRadius.circular(_panelRadius),
        border: Border.all(color: _borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: (_isDarkMode(context) ? Colors.black : _ink).withValues(
              alpha: _isDarkMode(context) ? 0.22 : 0.05,
            ),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ScheduleHeaderCell extends StatelessWidget {
  const _ScheduleHeaderCell(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFFA3AEC4),
        letterSpacing: 2.2,
      ),
    );
  }
}
