import 'package:flutter/material.dart';

import '../core/api_exception.dart';
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
  static const _headerImageUrl =
      'https://api.builder.io/api/v1/image/assets/TEMP/28e563928262ae2b992ee1331225ba24ccdde4c0?width=824';
  static const _logoImageUrl =
      'https://api.builder.io/api/v1/image/assets/TEMP/f92c034757dbd92e4f4b2bb61cf4019eb03b031b?width=384';

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _gender;

  bool _submitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _locationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    try {
      await widget.authService.register({
        'first_name': _firstNameController.text.trim(),
        'middle_name': _middleNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'location': _locationController.text.trim(),
        'gender': _gender,
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
      });

      if (!mounted) return;
      widget.onRegisterSuccess?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF599566),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.network(
                      _headerImageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF6F5F1),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -60),
                              child: SizedBox(
                                width: 176,
                                child: Image.network(_logoImageUrl),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SMART',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFA08434),
                                  ),
                                ),
                                Text(
                                  'DentQueue',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'REGISTRATION',
                              style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _RegisterInput(
                              controller: _firstNameController,
                              hint: 'Enter First Name',
                              icon: Icons.person,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'First name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _RegisterInput(
                              controller: _middleNameController,
                              hint: 'Enter Middle Name',
                              icon: Icons.person,
                            ),
                            const SizedBox(height: 10),
                            _RegisterInput(
                              controller: _lastNameController,
                              hint: 'Enter Last Name',
                              icon: Icons.person,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Last name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _RegisterInput(
                              controller: _locationController,
                              hint: 'Enter Location',
                              icon: Icons.location_on,
                            ),
                            const SizedBox(height: 10),
                            _GenderSelect(
                              value: _gender,
                              onChanged: (value) {
                                setState(() {
                                  _gender = value;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFF356042),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'CREATE ACCOUNT',
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _RegisterInput(
                              controller: _usernameController,
                              hint: 'Create Username',
                              icon: Icons.mail,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Username is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _RegisterInput(
                              controller: _passwordController,
                              hint: 'Create Password',
                              obscureText: !_showPassword,
                              suffix: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                icon: Icon(
                                  _showPassword ? Icons.visibility : Icons.visibility_off,
                                  color: const Color(0xFF606060),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            _RegisterInput(
                              controller: _confirmPasswordController,
                              hint: 'Confirm Password',
                              obscureText: !_showConfirmPassword,
                              suffix: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showConfirmPassword = !_showConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  _showConfirmPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF606060),
                                ),
                              ),
                              validator: (value) {
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Already have an Account? ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF929191),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: widget.onSwitchToLogin,
                                  child: const Text(
                                    'Click here',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFA08434),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: 170,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF599566),
                                  disabledBackgroundColor: const Color(0xFF8CB396),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFF8B8B8B)),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.3,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Sign up'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RegisterInput extends StatelessWidget {
  const _RegisterInput({
    required this.controller,
    required this.hint,
    this.icon,
    this.suffix,
    this.validator,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9D9B9B),
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        suffixIcon: suffix ?? (icon != null ? Icon(icon, color: Colors.black) : null),
        filled: true,
        fillColor: const Color(0xFFF6F5F1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B8B8B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B8B8B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF599566), width: 1.5),
        ),
        errorStyle: const TextStyle(height: 0.9),
      ),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: Colors.black,
      ),
    );
  }
}

class _GenderSelect extends StatelessWidget {
  const _GenderSelect({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      icon: const Icon(Icons.task_alt, color: Colors.black),
      decoration: InputDecoration(
        hintText: 'Enter Gender',
        hintStyle: const TextStyle(
          color: Color(0xFF9D9B9B),
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
        filled: true,
        fillColor: const Color(0xFFF6F5F1),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B8B8B)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B8B8B)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF599566), width: 1.5),
        ),
      ),
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 22,
        color: Colors.black,
      ),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
        DropdownMenuItem(value: 'other', child: Text('Other')),
        DropdownMenuItem(value: 'prefer_not', child: Text('Prefer not to say')),
      ],
    );
  }
}
