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
  final _emailController = TextEditingController();
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
    _emailController.dispose();
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
        'email': _emailController.text.trim(),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
            final useTwoColumns = screenWidth >= 560;

            final maxCardWidth = isTablet ? 760.0 : 520.0;
            final outerHorizontalPadding = isTablet ? 28.0 : 0.0;
            final outerVerticalPadding = isTablet ? (isLandscape ? 12.0 : 16.0) : 0.0;
            final cardRadius = isTablet ? 30.0 : 0.0;
            final headerHeight = (screenHeight * (isLandscape ? 0.2 : 0.24))
                .clamp(isSmallPhone ? 130.0 : 150.0, 220.0)
                .toDouble();
            final formPadding = isTablet ? 36.0 : (isSmallPhone ? 18.0 : 24.0);
            final logoWidth = isTablet ? 176.0 : (isSmallPhone ? 136.0 : 160.0);
            final brandFontSize = isTablet
                ? 30.0
                : (isSmallPhone ? 22.0 : 28.0);
            final titleFontSize = isTablet
                ? 36.0
                : (isSmallPhone ? 26.0 : 34.0);
            final sectionFontSize = isTablet
                ? 25.0
                : (isSmallPhone ? 18.0 : 23.0);
            final inputFontSize = isTablet
                ? 20.0
                : (isSmallPhone ? 16.0 : 18.0);
            final fieldSpacing = isTablet ? 14.0 : 10.0;
            final fieldGap = isTablet ? 14.0 : 10.0;
            final buttonFontSize = isTablet
                ? 30.0
                : (isSmallPhone ? 22.0 : 26.0);
            final buttonHeight = isTablet ? 52.0 : 48.0;
            final maxButtonWidth = isTablet ? 250.0 : 220.0;
            final fieldVerticalPadding = isTablet ? 12.0 : 8.0;

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
                      color: const Color(0xFFF6F5F1),
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
                            formPadding,
                            isTablet ? 26 : 18,
                            formPadding,
                            isTablet ? 28 : 24,
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
                                          fontSize: brandFontSize,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFA08434),
                                        ),
                                      ),
                                      Text(
                                        'DentQueue',
                                        style: TextStyle(
                                          fontSize: brandFontSize,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: isTablet ? 8 : 6),
                                Text(
                                  'REGISTRATION',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: titleFontSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: isTablet ? 18 : 14),
                                if (useTwoColumns) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _firstNameController,
                                          hint: 'Enter First Name',
                                          icon: Icons.person,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'First name is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: fieldGap),
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _middleNameController,
                                          hint: 'Enter Middle Name',
                                          icon: Icons.person,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _lastNameController,
                                          hint: 'Enter Last Name',
                                          icon: Icons.person,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Last name is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: fieldGap),
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _locationController,
                                          hint: 'Enter Location',
                                          icon: Icons.location_on,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _emailController,
                                          hint: 'Enter Email',
                                          icon: Icons.email,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Email is required';
                                            }
                                            if (!RegExp(
                                              r"^[^@]+@[^@]+\.[^@]+$",
                                            ).hasMatch(value)) {
                                              return 'Invalid email address';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: fieldGap),
                                      Expanded(
                                        child: _GenderSelect(
                                          value: _gender,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                          onChanged: (value) {
                                            setState(() {
                                              _gender = value;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  _RegisterInput(
                                    controller: _firstNameController,
                                    hint: 'Enter First Name',
                                    icon: Icons.person,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'First name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _middleNameController,
                                    hint: 'Enter Middle Name',
                                    icon: Icons.person,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _lastNameController,
                                    hint: 'Enter Last Name',
                                    icon: Icons.person,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Last name is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _locationController,
                                    hint: 'Enter Location',
                                    icon: Icons.location_on,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _emailController,
                                    hint: 'Enter Email',
                                    icon: Icons.email,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Email is required';
                                      }
                                      if (!RegExp(
                                        r"^[^@]+@[^@]+\.[^@]+$",
                                      ).hasMatch(value)) {
                                        return 'Invalid email address';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _GenderSelect(
                                    value: _gender,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    onChanged: (value) {
                                      setState(() {
                                        _gender = value;
                                      });
                                    },
                                  ),
                                ],
                                SizedBox(height: fieldSpacing + 2),
                                Container(
                                  height: 8,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF356042),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                SizedBox(height: fieldSpacing),
                                Text(
                                  'CREATE ACCOUNT',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: sectionFontSize,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: fieldSpacing),
                                if (useTwoColumns) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _usernameController,
                                          hint: 'Create Username',
                                          icon: Icons.mail,
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Username is required';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      SizedBox(width: fieldGap),
                                      Expanded(
                                        child: _RegisterInput(
                                          controller: _passwordController,
                                          hint: 'Create Password',
                                          fontSize: inputFontSize,
                                          verticalPadding: fieldVerticalPadding,
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
                                            if (value == null ||
                                                value.length < 8) {
                                              return 'Password must be at least 8 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _confirmPasswordController,
                                    hint: 'Confirm Password',
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    obscureText: !_showConfirmPassword,
                                    suffix: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _showConfirmPassword =
                                              !_showConfirmPassword;
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
                                ] else ...[
                                  _RegisterInput(
                                    controller: _usernameController,
                                    hint: 'Create Username',
                                    icon: Icons.mail,
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Username is required';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _passwordController,
                                    hint: 'Create Password',
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
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
                                      if (value == null || value.length < 8) {
                                        return 'Password must be at least 8 characters';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: fieldSpacing),
                                  _RegisterInput(
                                    controller: _confirmPasswordController,
                                    hint: 'Confirm Password',
                                    fontSize: inputFontSize,
                                    verticalPadding: fieldVerticalPadding,
                                    obscureText: !_showConfirmPassword,
                                    suffix: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _showConfirmPassword =
                                              !_showConfirmPassword;
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
                                ],
                                SizedBox(height: fieldSpacing + 4),
                                Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Already have an Account?',
                                          style: TextStyle(
                                            fontSize: isSmallPhone ? 12 : 13,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF929191),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        GestureDetector(
                                          onTap: widget.onSwitchToLogin,
                                          child: Text(
                                            'Click here',
                                            style: TextStyle(
                                              fontSize: isSmallPhone ? 12 : 13,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFFA08434),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(height: fieldSpacing + 2),
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
                                                  : _register,
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
                                                    color: Color(0xFF8B8B8B),
                                                  ),
                                                ),
                                                textStyle: TextStyle(
                                                  fontSize: buttonFontSize,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              child: _submitting
                                                  ? const SizedBox(
                                                      width: 22,
                                                      height: 22,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2.3,
                                                            color: Colors.white,
                                                          ),
                                                    )
                                                  : const Text('Sign up'),
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

class _RegisterInput extends StatelessWidget {
  const _RegisterInput({
    required this.controller,
    required this.hint,
    this.icon,
    this.suffix,
    this.validator,
    this.obscureText = false,
    this.fontSize = 22,
    this.verticalPadding = 8,
  });

  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final bool obscureText;
  final double fontSize;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF9D9B9B),
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
        suffixIcon:
            suffix ?? (icon != null ? Icon(icon, color: Colors.black) : null),
        filled: true,
        fillColor: const Color(0xFFF6F5F1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: verticalPadding,
        ),
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
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
        color: Colors.black,
      ),
    );
  }
}

class _GenderSelect extends StatelessWidget {
  const _GenderSelect({
    required this.value,
    required this.onChanged,
    this.fontSize = 22,
    this.verticalPadding = 8,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final double fontSize;
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      icon: const Icon(Icons.task_alt, color: Colors.black),
      decoration: InputDecoration(
        hintText: 'Enter Gender',
        hintStyle: TextStyle(
          color: const Color(0xFF9D9B9B),
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
        filled: true,
        fillColor: const Color(0xFFF6F5F1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: verticalPadding,
        ),
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
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
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
