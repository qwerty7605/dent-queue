import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../services/auth_service.dart';

class LoginView extends StatefulWidget {
  const LoginView({
    super.key,
    required this.authService,
    this.onSwitchToRegister,
    this.onLoginSuccess,
  });

  final AuthService authService;
  final VoidCallback? onSwitchToRegister;
  final VoidCallback? onLoginSuccess;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  static const _headerImageUrl =
      'https://api.builder.io/api/v1/image/assets/TEMP/28e563928262ae2b992ee1331225ba24ccdde4c0?width=824';
  static const _logoImageUrl =
      'https://api.builder.io/api/v1/image/assets/TEMP/f92c034757dbd92e4f4b2bb61cf4019eb03b031b?width=384';

  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _submitting = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
    });

    try {
      await widget.authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      widget.onLoginSuccess?.call();
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
              child: Stack(
                children: [
                  SizedBox(
                    height: 220,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(_headerImageUrl, fit: BoxFit.cover),
                        Container(color: const Color(0x33599566)),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 196),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6E4),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 36),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            SizedBox(
                              width: 160,
                              height: 112,
                              child: Image.network(
                                _logoImageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'SMART',
                                  style: TextStyle(
                                    color: Color(0xFFE1C158),
                                    fontSize: 31,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'DentQueue',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 31,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              'Welcome Back!',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Please login to your account',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 28),
                            _LoginInput(
                              controller: _usernameController,
                              hint: 'Username or Email',
                              suffix: const Icon(
                                Icons.person,
                                color: Color(0xFF606060),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Identifier is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            _LoginInput(
                              controller: _passwordController,
                              hint: 'Enter your Password',
                              obscureText: !_showPassword,
                              suffix: IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showPassword = !_showPassword;
                                  });
                                },
                                icon: Icon(
                                  _showPassword
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  color: const Color(0xFF606060),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Password is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 22),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Dont have an account?',
                                  style: TextStyle(
                                    color: Color(0xFF929191),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: widget.onSwitchToRegister,
                                  child: const Text(
                                    'Click here',
                                    style: TextStyle(
                                      color: Color(0xFFE1C158),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: 170,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _submitting ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF599566),
                                  disabledBackgroundColor: const Color(0xFF8CB396),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Color(0xFF777676)),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Log In'),
                              ),
                            ),
                          ],
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

class _LoginInput extends StatelessWidget {
  const _LoginInput({
    required this.controller,
    required this.hint,
    required this.suffix,
    this.validator,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String hint;
  final Widget suffix;
  final String? Function(String?)? validator;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF9D9B9B),
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9D9B9B),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFFFF3F3),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF777676)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF777676)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF599566)),
        ),
      ),
    );
  }
}
