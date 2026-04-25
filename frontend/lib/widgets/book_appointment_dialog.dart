import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../services/appointment_service.dart';
import '../services/base_service.dart';
import 'app_dialog_scaffold.dart';
import 'navigation_chrome.dart';
import 'appointment_clock_picker.dart';
import 'appointment_success_dialog.dart';

class BookAppointmentDialog extends StatefulWidget {
  const BookAppointmentDialog({
    super.key,
    this.appointmentService,
    this.asPage = false,
  });

  final AppointmentService? appointmentService;
  final bool asPage;

  @override
  State<BookAppointmentDialog> createState() => _BookAppointmentDialogState();
}

class _BookAppointmentDialogState extends State<BookAppointmentDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'service': <String>['service_id', 'service_type'],
        'date': <String>['appointment_date'],
        'time': <String>['time_slot', 'appointment_time'],
        'notes': <String>['notes'],
      };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();

  late final AppointmentService _appointmentService;

  bool _isLoading = false;
  bool _isLoadingAvailability = false;
  int _currentStep = 1;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  String? _selectedService;
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  List<Map<String, dynamic>> _availabilitySlots = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _unavailableRanges = <Map<String, dynamic>>[];

  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;

  final List<Map<String, dynamic>> _services = <Map<String, dynamic>>[
    <String, dynamic>{
      'id': 1,
      'name': 'Dental Check-up',
      'description': 'Comprehensive examination of your teeth and gums.',
      'icon': Icons.mood_outlined,
      'accent': const Color(0xFF8CA4D6),
    },
    <String, dynamic>{
      'id': 2,
      'name': 'Dental Panoramic X-ray',
      'description': 'Wide-view X-ray of your upper and lower jaw.',
      'icon': Icons.verified_user_outlined,
      'accent': const Color(0xFFA6B7DA),
    },
    <String, dynamic>{
      'id': 3,
      'name': 'Root Canal',
      'description': 'Treatment to repair and save a badly damaged tooth.',
      'icon': Icons.medical_services_outlined,
      'accent': const Color(0xFF9AAED8),
    },
    <String, dynamic>{
      'id': 4,
      'name': 'Teeth Cleaning',
      'description': 'Professional removal of plaque and tartar.',
      'icon': Icons.sentiment_satisfied_alt_outlined,
      'accent': const Color(0xFF92AAD7),
    },
    <String, dynamic>{
      'id': 5,
      'name': 'Teeth Whitening',
      'description': 'Brighten your smile with professional whitening.',
      'icon': Icons.mood_outlined,
      'accent': const Color(0xFFF1B43B),
    },
    <String, dynamic>{
      'id': 6,
      'name': 'Tooth Extraction',
      'description': 'Safe removal of a damaged or problematic tooth.',
      'icon': Icons.medical_services_outlined,
      'accent': const Color(0xFFE46F6F),
    },
  ];

  @override
  void initState() {
    super.initState();
    _appointmentService =
        widget.appointmentService ??
        AppointmentService(
          BaseService(ApiClient(tokenStorage: SecureTokenStorage())),
        );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _canMoveForward {
    switch (_currentStep) {
      case 1:
        return _selectedService != null;
      case 2:
        return _selectedDate != null;
      case 3:
        return _selectedTimeSlot != null;
      default:
        return !_isLoading;
    }
  }

  String get _footerLabel {
    switch (_currentStep) {
      case 1:
        return 'Continue to Date';
      case 2:
        return 'Continue to Time';
      case 3:
        return 'Review Booking';
      default:
        return 'Confirm Booking';
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
      final String normalizedMessage = exception.message.trim();
      if (normalizedMessage.contains('This schedule is already booked')) {
        fieldErrors['time'] =
            'This schedule is already booked. Please choose another schedule.';
      } else if (normalizedMessage.contains(
        'already have a booking for this time slot',
      )) {
        fieldErrors['time'] = 'You already have a booking for this time slot.';
      } else if (normalizedMessage.contains(
        'already have a booking for this date',
      )) {
        fieldErrors['date'] = 'You already have a booking for this date.';
      } else if (normalizedMessage.contains('daily limit')) {
        fieldErrors['date'] =
            'The daily limit of 50 patients has been reached for this date.';
      } else if (normalizedMessage.contains('Sunday')) {
        fieldErrors['date'] = 'Sunday bookings are not allowed.';
      } else if (normalizedMessage.contains('Past dates') ||
          normalizedMessage.contains('in the past')) {
        fieldErrors['date'] = 'Cannot book an appointment in the past.';
      } else if (normalizedMessage.contains('Doctor Unavailable')) {
        fieldErrors['time'] = normalizedMessage;
      } else {
        formError = normalizedMessage.isNotEmpty ? normalizedMessage : null;
      }
    }

    setState(() {
      _fieldErrors = fieldErrors;
      _formErrorText = formError;
      _autoValidateMode = AutovalidateMode.always;
    });
    _formKey.currentState?.validate();
  }

  void _goToPreviousStep() {
    if (_currentStep == 1) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _currentStep -= 1;
      _autoValidateMode = AutovalidateMode.disabled;
    });
  }

  Future<void> _handlePrimaryAction() async {
    if (_currentStep < 4) {
      if (_formKey.currentState!.validate() && _canMoveForward) {
        setState(() {
          _currentStep += 1;
          _autoValidateMode = AutovalidateMode.disabled;
        });
      } else {
        setState(() {
          _autoValidateMode = AutovalidateMode.always;
        });
      }
      return;
    }

    await _submit();
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

    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> payload = <String, dynamic>{
        'service_id': int.parse(_selectedService!),
        'appointment_date': _formatSelectedDate(),
        'time_slot': _selectedTimeSlot!,
        'notes': _notesController.text.trim(),
      };
      await _appointmentService.createAppointment(payload);

      if (!mounted) return;
      setState(() => _isLoading = false);

      final String serviceName =
          _services.firstWhere(
                (s) => s['id'].toString() == _selectedService,
                orElse: () => <String, dynamic>{'name': 'your service'},
              )['name']
              as String;

      await showAppointmentSuccessDialog(
        context,
        title: 'Appointment Requested',
        message:
            'Your booking for $serviceName has been submitted. Please wait for staff approval.',
        buttonLabel: 'Go to My Appointments',
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _applyApiErrors(error);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _formErrorText = 'Failed to book appointment.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color surfaceColor = isDark ? const Color(0xFF101A2C) : Colors.white;
    final Color panelColor = isDark ? const Color(0xFF17243A) : Colors.white;
    final Color sectionColor = isDark
        ? const Color(0xFF1C2A43)
        : const Color(0xFFF1F5FF);
    final Color headlineColor = isDark ? Colors.white : const Color(0xFF1E3763);
    final Color mutedText = isDark
        ? const Color(0xFFAAB7CD)
        : const Color(0xFF8E99AB);

    final Widget content = Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (_formErrorText != null) _buildErrorBanner(isDark),
          _buildStepIntroCard(sectionColor, headlineColor, mutedText, isDark),
          const SizedBox(height: 20),
          if (_currentStep == 1)
            _buildServiceStep(panelColor, headlineColor, mutedText, isDark),
          if (_currentStep == 2)
            _buildDateStep(panelColor, headlineColor, mutedText, isDark),
          if (_currentStep == 3)
            _buildTimeStep(panelColor, headlineColor, mutedText, isDark),
          if (_currentStep == 4)
            _buildReviewStep(panelColor, headlineColor, mutedText, isDark),
        ],
      ),
    );

    if (widget.asPage) {
      return Scaffold(
        backgroundColor: AppNavigationTheme.background,
        appBar: AppHeaderBar(
          titleWidget: const AppBrandLockup(logoSize: 40, spacing: 4),
          titleSpacing: -8,
          showBottomAccent: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepHeader(headlineColor, mutedText, isDark),
                      const SizedBox(height: 18),
                      content,
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                child: _buildFooterActions(headlineColor, isDark),
              ),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      autovalidateMode: _autoValidateMode,
      child: AppDialogScaffold(
        maxWidth: 460,
        maxHeightFactor: 0.92,
        backgroundColor: surfaceColor,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        bodyPadding: const EdgeInsets.only(top: 18),
        headerContent: _buildStepHeader(headlineColor, mutedText, isDark),
        onClose: _isLoading ? null : () => Navigator.of(context).pop(),
        footer: _buildFooterActions(headlineColor, isDark),
        child: content,
      ),
    );
  }

  Widget _buildFooterActions(Color headlineColor, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: <Widget>[
          if (_currentStep > 1) ...<Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _goToPreviousStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: headlineColor,
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF334760)
                        : const Color(0xFFD8DFEB),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text(
                  'Back',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading || !_canMoveForward
                  ? null
                  : _handlePrimaryAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF233D78),
                disabledBackgroundColor: const Color(0xFF9CA8C4),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _footerLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepHeader(Color headlineColor, Color mutedText, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            InkWell(
              onTap: _isLoading ? null : _goToPreviousStep,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF17243A)
                      : const Color(0xFFF9FBFF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF293A57)
                        : const Color(0xFFE6EBF4),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: headlineColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Book Appointment',
                    style: TextStyle(
                      fontSize: MobileTypography.sectionTitle(context),
                      fontWeight: FontWeight.w900,
                      color: headlineColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'STEP $_currentStep OF 4',
                    style: TextStyle(
                      color: mutedText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: _currentStep / 4,
            backgroundColor: isDark
                ? const Color(0xFF25354E)
                : const Color(0xFFE8EDF7),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF233D78)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1E27) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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

  Widget _buildStepIntroCard(
    Color cardColor,
    Color headlineColor,
    Color mutedText,
    bool isDark,
  ) {
    final Map<String, dynamic> stepData = switch (_currentStep) {
      1 => <String, dynamic>{
        'title': 'Select Service',
        'subtitle': 'Pick the dental procedure you need',
        'icon': Icons.medical_services_outlined,
      },
      2 => <String, dynamic>{
        'title': 'Select Date',
        'subtitle': 'Clinic operates Mon-Sat (7:30 AM - 6:00 PM)',
        'icon': Icons.calendar_month_outlined,
      },
      3 => <String, dynamic>{
        'title': 'Select Time Slot',
        'subtitle': 'Available from 7:30 AM to 6:00 PM',
        'icon': Icons.access_time_rounded,
      },
      _ => <String, dynamic>{
        'title': 'Review Booking',
        'subtitle': 'Confirm your appointment details before saving',
        'icon': Icons.assignment_turned_in_outlined,
      },
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22314D) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF30445F)
                    : const Color(0xFFE4EAF6),
              ),
            ),
            child: Icon(
              stepData['icon'] as IconData,
              color: const Color(0xFF8CA4D6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  stepData['title'] as String,
                  style: TextStyle(
                    color: headlineColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  stepData['subtitle'] as String,
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceStep(
    Color cardColor,
    Color headlineColor,
    Color mutedText,
    bool isDark,
  ) {
    return Column(
      children: _services.map((Map<String, dynamic> service) {
        final bool isSelected = _selectedService == service['id'].toString();
        final Color accent = service['accent'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF233D78)
                  : isDark
                  ? const Color(0xFF2A3A55)
                  : const Color(0xFFE8ECF4),
              width: isSelected ? 1.8 : 1,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              _clearFieldError('service');
              setState(() {
                _selectedService = service['id'].toString();
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(service['icon'] as IconData, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          service['name'] as String,
                          style: TextStyle(
                            color: headlineColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          service['description'] as String,
                          style: TextStyle(
                            color: mutedText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFF233D78)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF233D78)
                            : isDark
                            ? const Color(0xFF425472)
                            : const Color(0xFFD9DFEA),
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDateStep(
    Color cardColor,
    Color headlineColor,
    Color mutedText,
    bool isDark,
  ) {
    final DateTime monthStart = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
    );
    final DateTime gridStart = monthStart.subtract(
      Duration(days: monthStart.weekday - 1),
    );
    final List<DateTime> days = List<DateTime>.generate(
      42,
      (int index) => gridStart.add(Duration(days: index)),
    );
    final DateTime now = DateTime.now();
    final DateTime startOfToday = DateTime(now.year, now.month, now.day);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE8ECF4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                DateFormat('MMMM yyyy').format(monthStart),
                style: TextStyle(
                  color: headlineColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              _buildCalendarNavButton(
                icon: Icons.chevron_left_rounded,
                enabled: !_isBeforeCurrentMonth(monthStart),
                onTap: () {
                  if (_isBeforeCurrentMonth(monthStart)) return;
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month - 1,
                    );
                  });
                },
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildCalendarNavButton(
                icon: Icons.chevron_right_rounded,
                enabled: true,
                onTap: () {
                  setState(() {
                    _visibleMonth = DateTime(
                      _visibleMonth.year,
                      _visibleMonth.month + 1,
                    );
                  });
                },
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: const <String>['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map(
                  (String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Color(0xFF99A5B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemBuilder: (BuildContext context, int index) {
              final DateTime day = days[index];
              final DateTime normalized = DateTime(
                day.year,
                day.month,
                day.day,
              );
              final bool isInMonth = day.month == monthStart.month;
              final bool isPast = normalized.isBefore(startOfToday);
              final bool isSunday = day.weekday == DateTime.sunday;
              final bool isDisabled = !isInMonth || isPast || isSunday;
              final bool isSelected =
                  _selectedDate != null &&
                  _selectedDate!.year == day.year &&
                  _selectedDate!.month == day.month &&
                  _selectedDate!.day == day.day;

              return InkWell(
                onTap: isDisabled
                    ? null
                    : () {
                        setState(() {
                          _selectedDate = day;
                          _selectedTimeSlot = null;
                          _availabilitySlots = <Map<String, dynamic>>[];
                          _unavailableRanges = <Map<String, dynamic>>[];
                          _fieldErrors.remove('date');
                          _fieldErrors.remove('time');
                        });
                        _loadAvailabilityForSelectedDate();
                      },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF233D78)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : isDisabled
                            ? (isDark
                                  ? const Color(0xFF5B6A84)
                                  : const Color(0xFFD1D8E4))
                            : headlineColor,
                        fontSize: 18,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_mergeFieldError('date', null) != null) ...<Widget>[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _mergeFieldError('date', null)!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendarNavButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF22314D) : const Color(0xFFF7F9FD),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: enabled ? const Color(0xFF233D78) : const Color(0xFFA7B2C4),
        ),
      ),
    );
  }

  Widget _buildTimeStep(
    Color cardColor,
    Color headlineColor,
    Color mutedText,
    bool isDark,
  ) {
    final List<String> pieces = _slotPieces(_selectedTimeSlot);

    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE8ECF4),
            ),
          ),
          child: Column(
            children: <Widget>[
              Text(
                'SELECTED APPOINTMENT TIME',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 12,
                  letterSpacing: 1.7,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _buildTimeBox(pieces[0], headlineColor, isDark),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        color: mutedText,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildTimeBox(pieces[1], headlineColor, isDark),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF233D78),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      pieces[2],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              TextButton.icon(
                onPressed: _isLoading ? null : _openTimePicker,
                icon: _isLoadingAvailability
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(
                  _selectedTimeSlot == null
                      ? 'Tap to choose time'
                      : 'Tap to change time',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8CA4D6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF17243A) : const Color(0xFFF9FBFF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE8ECF4),
            ),
          ),
          child: Text(
            _selectedDate == null
                ? 'Choose a date first to see available time slots.'
                : _timeFieldLabel(),
            style: TextStyle(
              color: mutedText,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (_mergeFieldError('time', null) != null) ...<Widget>[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _mergeFieldError('time', null)!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeBox(String value, Color headlineColor, bool isDark) {
    return Container(
      height: 84,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1B2941) : const Color(0xFFF9FBFF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF314561) : const Color(0xFFE2E8F2),
        ),
      ),
      child: Center(
        child: Text(
          value,
          style: TextStyle(
            color: headlineColor,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewStep(
    Color cardColor,
    Color headlineColor,
    Color mutedText,
    bool isDark,
  ) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark ? const Color(0xFF2A3A55) : const Color(0xFFE8ECF4),
            ),
          ),
          child: Column(
            children: <Widget>[
              _buildReviewRow(
                'Service',
                _selectedServiceName(),
                headlineColor,
                mutedText,
              ),
              const SizedBox(height: 12),
              _buildReviewRow(
                'Date',
                _selectedDate == null
                    ? 'Not selected'
                    : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                headlineColor,
                mutedText,
              ),
              const SizedBox(height: 12),
              _buildReviewRow(
                'Time',
                _timeFieldLabel(),
                headlineColor,
                mutedText,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _notesController,
          onChanged: (_) => _clearFieldError('notes'),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Any concerns?',
            hintStyle: TextStyle(color: mutedText, fontSize: 15),
            filled: true,
            fillColor: isDark
                ? const Color(0xFF17243A)
                : const Color(0xFFF9FBFF),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2A3A55)
                    : const Color(0xFFE8ECF4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF2A3A55)
                    : const Color(0xFFE8ECF4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: Color(0xFF233D78), width: 2),
            ),
          ),
          style: TextStyle(color: headlineColor, fontSize: 16),
          validator: (String? value) => _mergeFieldError('notes', null),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2B2517) : const Color(0xFFFBF7EF),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF4A3D1B) : const Color(0xFFF0E3B8),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFDAA032),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Submission of this request does not guarantee instant scheduling. Please wait for the clinic staff to review and approve your slot.',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFF3D57B)
                        : const Color(0xFFB88617),
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewRow(
    String label,
    String value,
    Color headlineColor,
    Color mutedText,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: TextStyle(
              color: mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: headlineColor,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  String _selectedServiceName() {
    for (final Map<String, dynamic> service in _services) {
      if (service['id'].toString() == _selectedService) {
        return service['name'].toString();
      }
    }
    return 'Not selected';
  }

  bool _isBeforeCurrentMonth(DateTime month) {
    final DateTime now = DateTime.now();
    final DateTime currentMonth = DateTime(now.year, now.month);
    return DateTime(month.year, month.month - 1).isBefore(currentMonth);
  }

  List<String> _slotPieces(String? value) {
    if (value == null || value.isEmpty) {
      return <String>['07', '30', 'AM'];
    }

    try {
      final DateFormat parser = DateFormat('HH:mm');
      final DateFormat formatter = DateFormat('hh mm a');
      return formatter.format(parser.parse(value)).split(' ');
    } catch (_) {
      return <String>['07', '30', 'AM'];
    }
  }

  Future<void> _openTimePicker() async {
    _clearFieldError('time');
    if (_selectedDate == null) {
      setState(() {
        _fieldErrors['date'] = 'Required';
      });
      return;
    }

    if (_availabilitySlots.isEmpty && !_isLoadingAvailability) {
      await _loadAvailabilityForSelectedDate();
    }

    if (!mounted) return;

    final String? selected = await showAppointmentTimePickerModal(
      context: context,
      slots: _availabilitySlots,
      selectedTimeSlot: _selectedTimeSlot,
      isSlotDisabled: _isSlotDisabled,
      unavailableRanges: _unavailableRanges,
      errorText: _fieldErrors['time'],
      title: 'Choose Appointment Time',
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _selectedTimeSlot = selected;
    });
  }

  String _timeFieldLabel() {
    if (_selectedDate == null) {
      return 'Select a date first.';
    }

    if (_selectedTimeSlot == null) {
      if (_isLoadingAvailability) {
        return 'Loading available times...';
      }

      if (_availabilitySlots.isEmpty) {
        return 'Tap to view available times.';
      }

      return 'Tap to choose a time.';
    }

    final Map<String, dynamic> slot = _availabilitySlots.firstWhere(
      (Map<String, dynamic> item) => item['time'] == _selectedTimeSlot,
      orElse: () => <String, dynamic>{'time_label': _selectedTimeSlot},
    );

    return slot['time_label']?.toString() ?? _selectedTimeSlot!;
  }

  Future<void> _loadAvailabilityForSelectedDate() async {
    if (_selectedDate == null) {
      return;
    }

    setState(() {
      _isLoadingAvailability = true;
    });

    try {
      final dynamic payload = await _appointmentService.getAvailabilitySlots(
        _formatSelectedDate(),
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
        _isLoadingAvailability = false;
        _fieldErrors['time'] = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _availabilitySlots = <Map<String, dynamic>>[];
        _unavailableRanges = <Map<String, dynamic>>[];
        _isLoadingAvailability = false;
      });
    }
  }

  String _formatSelectedDate() {
    return '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';
  }

  String _effectiveSlotStatus(Map<String, dynamic> slot) {
    final String status = slot['status']?.toString() ?? 'available';
    if (status != 'available') {
      return status;
    }

    final String slotTime = slot['time']?.toString() ?? '';
    for (final Map<String, dynamic> range in _unavailableRanges) {
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
