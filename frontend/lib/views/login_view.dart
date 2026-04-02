import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/mobile_typography.dart';
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

  void _clearLoginError() {
    if (_loginError == null) return;
    setState(() {
      _loginError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width >= 880;
    final horizontalPadding = isDesktop
        ? 32.0
        : (size.width < 380 ? 20.0 : 24.0);
    final panelVerticalPadding = isDesktop ? 32.0 : 28.0;

    // Placeholder image resembling a dental clinic
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
                    height: isDesktop ? double.infinity : size.height * 0.65,
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
                          vertical: panelVerticalPadding,
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
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
                              SizedBox(height: isDesktop ? 48 : 36),

                              Text(
                                'Welcome Back!',
                                style: TextStyle(
                                  fontSize: MobileTypography.pageTitle(context),
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Please login to your account',
                                style: TextStyle(
                                  fontSize: MobileTypography.body(context),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: isDesktop ? 36 : 28),

                              if (_loginError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    _loginError!,
                                    style: const TextStyle(
                                      color: Color(0xFFFFA0A0),
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),

                              TextFormField(
                                controller: _usernameController,
                                onChanged: (_) => _clearLoginError(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                decoration: _inputDecoration(
                                  hintText: 'Enter your Username',
                                  suffixIcon: const Icon(
                                    Icons.email,
                                    color: Color(0xFF5E8E69),
                                  ),
                                ),
                                validator: (val) =>
                                    val == null || val.trim().isEmpty
                                    ? 'Username is required'
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              const SizedBox(height: 16),

                              TextFormField(
                                controller: _passwordController,
                                onChanged: (_) => _clearLoginError(),
                                obscureText: !_showPassword,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                                decoration: _inputDecoration(
                                  hintText: 'Enter your Password',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword
                                          ? Icons.lock_open
                                          : Icons.lock,
                                      color: const Color(0xFF5E8E69),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showPassword = !_showPassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (val) => val == null || val.isEmpty
                                    ? 'Password is required'
                                    : null,
                                onFieldSubmitted: (_) => _login(),
                                textInputAction: TextInputAction.done,
                              ),
                              const SizedBox(height: 16),

                              Wrap(
                                alignment: WrapAlignment.center,
                                children: [
                                  Text(
                                    'Dont have an account? ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: MobileTypography.bodySmall(
                                        context,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: widget.onSwitchToRegister,
                                    child: Text(
                                      'Click here',
                                      style: TextStyle(
                                        color: Color(0xFFD4AF37),
                                        fontWeight: FontWeight.w800,
                                        fontSize: MobileTypography.bodySmall(
                                          context,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isDesktop ? 36 : 28),

                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _submitting ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFE5EFE1),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _submitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.black,
                                          ),
                                        )
                                      : Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: MobileTypography.button(
                                              context,
                                            ),
                                            fontWeight: FontWeight.w900,
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
                ),
              ],
            ),
          ),
        ],
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
        fontSize: 16,
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
        fontSize: 13,
      ),
    );
  }
}
