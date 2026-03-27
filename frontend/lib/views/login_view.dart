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
  String? _loginError;

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
      _loginError = null;
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
      setState(() {
        _loginError = e.message;
      });
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
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF599566),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isTablet = screenWidth >= 700;
            final isSmallPhone = screenWidth < 360;
            final isLandscape = media.orientation == Orientation.landscape;

            final maxCardWidth = isTablet ? 620.0 : 500.0;
            final outerHorizontalPadding = isTablet ? 28.0 : 0.0;
            final outerVerticalPadding = isTablet ? (isLandscape ? 12.0 : 16.0) : 0.0;
            final cardRadius = isTablet ? 30.0 : 0.0;
            final headerHeight = (screenHeight * (isLandscape ? 0.28 : 0.3))
                .clamp(isSmallPhone ? 130.0 : 150.0, 250.0)
                .toDouble();
            final cardPadding = isTablet ? 40.0 : (isSmallPhone ? 18.0 : 28.0);
            final logoWidth = isTablet ? 180.0 : (isSmallPhone ? 136.0 : 160.0);
            final brandFontSize = isTablet
                ? 34.0
                : (isSmallPhone ? 24.0 : 31.0);
            final headingFontSize = isTablet
                ? 28.0
                : (isSmallPhone ? 20.0 : 24.0);
            final subtitleFontSize = isTablet
                ? 21.0
                : (isSmallPhone ? 16.0 : 20.0);
            final inputFontSize = isTablet
                ? 22.0
                : (isSmallPhone ? 17.0 : 20.0);
            final buttonFontSize = isTablet
                ? 32.0
                : (isSmallPhone ? 24.0 : 30.0);
            final buttonHeight = isTablet ? 60.0 : 56.0;
            final maxButtonWidth = isTablet ? 240.0 : 190.0;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                outerHorizontalPadding,
                outerVerticalPadding,
                outerHorizontalPadding,
                isTablet ? 20 : 0,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxCardWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6E4),
                      borderRadius: BorderRadius.circular(cardRadius),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        SizedBox(
                          height: headerHeight,
                          width: double.infinity,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(_headerImageUrl, fit: BoxFit.cover),
                              Container(color: const Color(0x33599566)),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            cardPadding,
                            isTablet ? 30 : 24,
                            cardPadding,
                            isTablet ? 40 : 34,
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: SizedBox(
                                    width: logoWidth,
                                    height: logoWidth * 0.7,
                                    child: Image.network(
                                      _logoImageUrl,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                SizedBox(height: isTablet ? 8 : 4),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'SMART',
                                        style: TextStyle(
                                          color: const Color(0xFFE1C158),
                                          fontSize: brandFontSize,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'DentQueue',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: brandFontSize,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isTablet ? 16 : 12),
                                Text(
                                  'Welcome Back!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: headingFontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Please login to your account',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: subtitleFontSize,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: isTablet ? 32 : 26),
                                _LoginInput(
                                  controller: _usernameController,
                                  hint: 'Username or Email',
                                  fontSize: inputFontSize,
                                  errorText: _loginError,
                                  onChanged: (_) {
                                    if (_loginError != null) {
                                      setState(() {
                                        _loginError = null;
                                      });
                                    }
                                  },
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
                                SizedBox(height: isTablet ? 18 : 14),
                                _LoginInput(
                                  controller: _passwordController,
                                  hint: 'Enter your Password',
                                  fontSize: inputFontSize,
                                  obscureText: !_showPassword,
                                  errorText: _loginError,
                                  onChanged: (_) {
                                    if (_loginError != null) {
                                      setState(() {
                                        _loginError = null;
                                      });
                                    }
                                  },
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
                                SizedBox(height: isTablet ? 24 : 20),
                                Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Dont have an account?',
                                          style: TextStyle(
                                            color: const Color(0xFF929191),
                                            fontSize: isSmallPhone ? 13 : 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: widget.onSwitchToRegister,
                                          child: Text(
                                            'Click here',
                                            style: TextStyle(
                                              color: const Color(0xFFE1C158),
                                              fontSize: isSmallPhone ? 13 : 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: isTablet ? 30 : 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: maxButtonWidth,
                                          ),
                                          child: SizedBox(
                                            height: buttonHeight,
                                            child: ElevatedButton(
                                              onPressed: _submitting
                                                  ? null
                                                  : _login,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF599566,
                                                ),
                                                disabledBackgroundColor:
                                                    const Color(0xFF8CB396),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  side: const BorderSide(
                                                    color: Color(0xFF777676),
                                                  ),
                                                ),
                                                textStyle: TextStyle(
                                                  fontSize: buttonFontSize,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              child: _submitting
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.4,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Text('Log In'),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
            );
          },
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
    this.errorText,
    this.onChanged,
    this.obscureText = false,
    this.fontSize = 20,
  });

  final TextEditingController controller;
  final String hint;
  final Widget suffix;
  final String? Function(String?)? validator;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool obscureText;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    const errorColor = Color(0xFFD32F2F);

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(
        color: const Color(0xFF9D9B9B),
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF9D9B9B),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: const Color(0xFFFFF3F3),
        suffixIcon: suffix,
        errorText: errorText,
        errorStyle: TextStyle(
          color: errorColor,
          fontSize: fontSize >= 20 ? 14 : 12,
          fontWeight: FontWeight.w700,
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: fontSize >= 20 ? 14 : 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF777676)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? errorColor : const Color(0xFF777676),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? errorColor : const Color(0xFF599566),
            width: 1.6,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.6),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.8),
        ),
      ),
    );
  }
}
