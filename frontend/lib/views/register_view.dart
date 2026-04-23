import 'package:flutter/material.dart';

import '../core/app_form_validators.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../services/auth_service.dart';

class RegisterView extends StatefulWidget {
  const RegisterView({
    super.key,
    required this.authService,
    this.onSwitchToLogin,
    this.onRegisterSuccess,
  });

  final AuthService authService;
  final VoidCallback? onSwitchToLogin;
  final VoidCallback? onRegisterSuccess;

  @override
  State<RegisterView> createState() => _RegisterViewState();
}

class _RegisterViewState extends State<RegisterView> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'first_name': <String>['first_name'],
        'middle_name': <String>['middle_name'],
        'last_name': <String>['last_name'],
        'contact_number': <String>['contact_number', 'phone_number'],
        'gender': <String>['gender'],
        'location': <String>['location', 'address'],
        'email': <String>['email'],
        'username': <String>['username'],
        'password': <String>['password'],
        'password_confirmation': <String>['password_confirmation'],
      };
  static const Map<String, int> _fieldSteps = <String, int>{
    'first_name': 0,
    'middle_name': 0,
    'last_name': 0,
    'contact_number': 1,
    'gender': 1,
    'location': 1,
    'email': 1,
    'username': 2,
    'password': 2,
    'password_confirmation': 2,
  };

  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // 0: Name, 1: Basic Info, 2: Account

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _locationController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _gender;
  bool _submitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.onUserInteraction;
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _contactNumberController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

  int _resolveStepForErrors(Map<String, String> fieldErrors) {
    int? step;

    for (final String field in fieldErrors.keys) {
      final int? candidate = _fieldSteps[field];
      if (candidate == null) {
        continue;
      }

      if (step == null || candidate < step) {
        step = candidate;
      }
    }

    return step ?? _currentStep;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autoValidateMode = AutovalidateMode.always;
      });
      return;
    }

    setState(() {
      _fieldErrors = <String, String>{};
      _formErrorText = null;
      _submitting = true;
    });

    try {
      await widget.authService.register({
        'first_name': _firstNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'location': _locationController.text.trim(),
        'gender': _gender,
        'contact_number': _contactNumberController.text.trim(),
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
      });

      if (!mounted) return;
      widget.onRegisterSuccess?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      final Map<String, String> fieldErrors = collectApiFieldErrors(
        e.errors,
        _apiFieldMappings,
      );
      final String? formError =
          firstUnhandledApiError(
            e.errors,
            handledKeys: flattenApiErrorKeys(_apiFieldMappings),
          ) ??
          (fieldErrors.isEmpty ? e.message : null);

      setState(() {
        _fieldErrors = fieldErrors;
        _formErrorText = formError;
        _currentStep = _resolveStepForErrors(fieldErrors);
        _autoValidateMode = AutovalidateMode.always;
      });
      _formKey.currentState?.validate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _formKey.currentState?.validate();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autoValidateMode = AutovalidateMode.always;
      });
      return;
    }
    setState(() {
      _currentStep++;
    });
  }

  void _prevStep() {
    setState(() {
      _currentStep--;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 880;
    final horizontalPadding = isDesktop
        ? 32.0
        : (size.width < 380 ? 20.0 : 24.0);

    const bgImageUrl =
        'https://images.unsplash.com/photo-1606811841689-23dfddce3e95?q=80&w=800&auto=format&fit=crop';

    return Scaffold(
      backgroundColor: const Color(0xFF1A2F64),
      body: Row(
        children: [
          if (isDesktop)
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(bgImageUrl),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Color(0x801A2F64),
                      BlendMode.srcOver,
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                if (!isDesktop)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: size.height * 0.45,
                    child: Container(
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(bgImageUrl),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Color(0x601A2F64),
                            BlendMode.srcOver,
                          ),
                        ),
                      ),
                    ),
                  ),

                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: isDesktop ? double.infinity : size.height * 0.75,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2F64),
                      borderRadius: isDesktop
                          ? null
                          : const BorderRadius.only(
                              topLeft: Radius.circular(30),
                              topRight: Radius.circular(30),
                            ),
                      boxShadow: isDesktop
                          ? null
                          : [
                              const BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, -5),
                              ),
                            ],
                    ),
                    child: SafeArea(
                      top: isDesktop,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 28,
                        ),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: _autoValidateMode,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/logo_blue.png',
                                    height: 86,
                                    errorBuilder: (_, error, stackTrace) =>
                                        const Icon(
                                          Icons.shield,
                                          color: Colors.white,
                                          size: 86,
                                        ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'SMART',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 36 : 32,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF9CB5E8),
                                          height: 1.1,
                                        ),
                                      ),
                                      Text(
                                        'DentQueue',
                                        style: TextStyle(
                                          fontSize: isDesktop ? 26 : 24,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              SizedBox(height: isDesktop ? 36 : 28),

                              Row(
                                children: [
                                  if (_currentStep > 0)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.white,
                                      ),
                                      onPressed: _prevStep,
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                    ),
                                  Expanded(
                                    child: Text(
                                      'Create an Account',
                                      style: TextStyle(
                                        fontSize: MobileTypography.pageTitle(
                                          context,
                                        ),
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (_formErrorText != null) ...[
                                Text(
                                  _formErrorText!,
                                  style: const TextStyle(
                                    color: Color(0xFFFFA0A0),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              if (_currentStep == 0) _buildStep0(),
                              if (_currentStep == 1) _buildStep1(),
                              if (_currentStep == 2) _buildStep2(),

                              const SizedBox(height: 32),

                              if (_currentStep == 0)
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: MobileTypography.bodySmall(
                                            context,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: widget.onSwitchToLogin,
                                        child: Text(
                                          'Sign in',
                                          style: TextStyle(
                                            color: Color(0xFF9CB5E8),
                                            fontWeight: FontWeight.w800,
                                            fontSize:
                                                MobileTypography.bodySmall(
                                                  context,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your Name',
          style: TextStyle(
            fontSize: MobileTypography.sectionTitle(context),
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CB5E8),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'First Name',
          child: TextFormField(
            controller: _firstNameController,
            forceErrorText: _fieldErrors['first_name'],
            onChanged: (_) => _clearFieldError('first_name'),
            inputFormatters: AppFormValidators.nameInputFormatters(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter First Name'),
            validator: (val) => _mergeFieldError(
              'first_name',
              AppFormValidators.requiredName(val, fieldLabel: 'First name'),
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Middle Name',
          child: TextFormField(
            controller: _middleNameController,
            forceErrorText: _fieldErrors['middle_name'],
            onChanged: (_) => _clearFieldError('middle_name'),
            inputFormatters: AppFormValidators.nameInputFormatters(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Middle Name'),
            validator: (val) => _mergeFieldError(
              'middle_name',
              AppFormValidators.optionalName(val, fieldLabel: 'Middle name'),
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Last Name',
          child: TextFormField(
            controller: _lastNameController,
            forceErrorText: _fieldErrors['last_name'],
            onChanged: (_) => _clearFieldError('last_name'),
            inputFormatters: AppFormValidators.nameInputFormatters(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Last Name'),
            validator: (val) => _mergeFieldError(
              'last_name',
              AppFormValidators.requiredName(val, fieldLabel: 'Last name'),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _nextStep(),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Next',
          onPressed: _nextStep,
          submitting: false,
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Basic Information',
          style: TextStyle(
            fontSize: MobileTypography.sectionTitle(context),
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CB5E8),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Contact Number',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 15,
                ),
                child: Row(
                  children: [
                    Image.network(
                      'https://flagcdn.com/w20/ph.png',
                      width: 20,
                      errorBuilder: (_, error, stackTrace) =>
                          const Icon(Icons.flag, size: 20),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _contactNumberController,
                  forceErrorText: _fieldErrors['contact_number'],
                  onChanged: (_) => _clearFieldError('contact_number'),
                  inputFormatters:
                      AppFormValidators.contactNumberInputFormatters(),
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  decoration: _inputDecoration(
                    hintText: '09XXXXXXXXX',
                    helperText: 'Use an 11-digit PH mobile number',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => _mergeFieldError(
                    'contact_number',
                    AppFormValidators.contactNumber(value),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Gender',
          child: DropdownButtonFormField<String>(
            initialValue: _gender,
            forceErrorText: _fieldErrors['gender'],
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
            decoration: _inputDecoration(hintText: 'Enter Gender'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            items: const [
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
              DropdownMenuItem(
                value: 'prefer_not',
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _gender = val;
              });
              _clearFieldError('gender');
            },
            validator: (val) => _mergeFieldError(
              'gender',
              AppFormValidators.gender(val, required: true),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Location',
          child: TextFormField(
            controller: _locationController,
            forceErrorText: _fieldErrors['location'],
            onChanged: (_) => _clearFieldError('location'),
            inputFormatters: AppFormValidators.maxLengthInputFormatters(
              AppFormValidators.addressMaxLength,
            ),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(
              hintText: 'Enter Location',
              helperText:
                  'Up to ${AppFormValidators.addressMaxLength} characters',
            ),
            validator: (value) => _mergeFieldError(
              'location',
              AppFormValidators.address(value, fieldLabel: 'Location'),
            ),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Email',
          child: TextFormField(
            controller: _emailController,
            forceErrorText: _fieldErrors['email'],
            onChanged: (_) => _clearFieldError('email'),
            inputFormatters: AppFormValidators.maxLengthInputFormatters(
              AppFormValidators.emailMaxLength,
            ),
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Email'),
            validator: (value) =>
                _mergeFieldError('email', AppFormValidators.email(value)),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _nextStep(),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Next',
          onPressed: _nextStep,
          submitting: false,
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledField(
          label: 'Username',
          child: TextFormField(
            controller: _usernameController,
            forceErrorText: _fieldErrors['username'],
            onChanged: (_) => _clearFieldError('username'),
            inputFormatters: AppFormValidators.usernameInputFormatters(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(
              hintText: 'Enter your Username',
              helperText: 'Letters, numbers, dots, hyphens, underscores',
            ),
            validator: (value) =>
                _mergeFieldError('username', AppFormValidators.username(value)),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Password',
          child: TextFormField(
            controller: _passwordController,
            forceErrorText: _fieldErrors['password'],
            onChanged: (_) => _clearFieldError('password'),
            obscureText: !_showPassword,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(
              hintText: 'Enter your Password',
              helperText:
                  'Minimum ${AppFormValidators.passwordMinLength} characters',
              suffixIcon: IconButton(
                icon: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.black45,
                ),
                onPressed: () {
                  setState(() {
                    _showPassword = !_showPassword;
                  });
                },
              ),
            ),
            validator: (value) =>
                _mergeFieldError('password', AppFormValidators.password(value)),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Confirm Password',
          child: TextFormField(
            controller: _confirmPasswordController,
            forceErrorText: _fieldErrors['password_confirmation'],
            onChanged: (_) => _clearFieldError('password_confirmation'),
            obscureText: !_showConfirmPassword,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(
              hintText: 'Confirm Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _showConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: Colors.black45,
                ),
                onPressed: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
              ),
            ),
            validator: (val) => _mergeFieldError(
              'password_confirmation',
              AppFormValidators.confirmPassword(val, _passwordController.text),
            ),
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _register(),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Sign Up',
          onPressed: _submitting ? null : _register,
          submitting: _submitting,
        ),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    required bool submitting,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        child: submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFFA5B4D3),
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      filled: true,
      fillColor: const Color(0xFFF0F4FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      suffixIcon: suffixIcon,
      helperText: helperText,
      helperStyle: const TextStyle(
        color: Color(0xFFE1E9FF),
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF9CB5E8), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 2),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFFA0A0),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
