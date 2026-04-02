import 'package:flutter/material.dart';

import '../core/api_exception.dart';
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
  String? _emailErrorText;
  String? _usernameErrorText;
  bool _submitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearEmailError);
    _usernameController.addListener(_clearUsernameError);
  }

  @override
  void dispose() {
    _emailController.removeListener(_clearEmailError);
    _usernameController.removeListener(_clearUsernameError);
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

  void _clearEmailError() {
    if (_emailErrorText == null) return;
    setState(() {
      _emailErrorText = null;
    });
  }

  void _clearUsernameError() {
    if (_usernameErrorText == null) return;
    setState(() {
      _usernameErrorText = null;
    });
  }

  String? _firstErrorMessage(dynamic value) {
    if (value is List && value.isNotEmpty) {
      final first = value.first;
      if (first is String && first.trim().isNotEmpty) {
        return first;
      }
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return null;
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _emailErrorText = null;
      _usernameErrorText = null;
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
      final emailError = _firstErrorMessage(e.errors?['email']);
      final usernameError = _firstErrorMessage(e.errors?['username']);

      setState(() {
        _emailErrorText = emailError;
        _usernameErrorText = usernameError;
      });

      if (emailError == null && usernameError == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
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
      backgroundColor: const Color(0xFF356042),
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
                      Color(0x80356042),
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
                            Color(0x60356042),
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
                      color: const Color(0xFF356042),
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.network(
                                    'https://api.builder.io/api/v1/image/assets/TEMP/f92c034757dbd92e4f4b2bb61cf4019eb03b031b?width=384',
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
                                          color: Color(0xFFD4AF37),
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
                                            color: Color(0xFFD4AF37),
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
            color: Color(0xFFD4AF37),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'First Name',
          child: TextFormField(
            controller: _firstNameController,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter First Name'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Required' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Middle Name',
          child: TextFormField(
            controller: _middleNameController,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Middle Name'),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Last Name',
          child: TextFormField(
            controller: _lastNameController,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Last Name'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Required' : null,
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
            color: Color(0xFFD4AF37),
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
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  decoration: _inputDecoration(hintText: '09XXXXXXXXX'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Required';
                    if (!RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
                      return 'Enter an 11-digit number starting with 09';
                    }
                    return null;
                  },
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
            },
            validator: (val) => val == null ? 'Required' : null,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Location',
          child: TextFormField(
            controller: _locationController,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Location'),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Email',
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) {
                return 'Invalid email';
              }
              return null;
            },
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _nextStep(),
          ),
        ),
        if (_emailErrorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _emailErrorText!,
            style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter your Username'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Required' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        if (_usernameErrorText != null) ...[
          const SizedBox(height: 6),
          Text(
            _usernameErrorText!,
            style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Password',
          child: TextFormField(
            controller: _passwordController,
            obscureText: !_showPassword,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(
              hintText: 'Enter your Password',
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
            validator: (val) =>
                val == null || val.length < 8 ? 'Min 8 chars' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Confirm Password',
          child: TextFormField(
            controller: _confirmPasswordController,
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
            validator: (val) => val != _passwordController.text
                ? 'Passwords do not match'
                : null,
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
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE5EFE1),
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: submitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
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
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9EAFAA),
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      filled: true,
      fillColor: const Color(0xFFFFF0F5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
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
