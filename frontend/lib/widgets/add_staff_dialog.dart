import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/mobile_typography.dart';

class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key, required this.onSubmit});

  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
  onSubmit;

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  static const String _bgImageUrl =
      'https://images.unsplash.com/photo-1606811841689-23dfddce3e95?q=80&w=800&auto=format&fit=crop';

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  int _currentStep = 0;

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _middleNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _selectedGender;
  String _selectedRole = 'staff';
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (!_formKey.currentState!.validate()) return;
    if (_currentStep == 0 && _selectedGender == null) {
      _showSnack('Please select a gender.');
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _prevStep() {
    if (_currentStep == 0) return;
    setState(() {
      _currentStep--;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGender == null) {
      _showSnack('Please select a gender.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final Map<String, dynamic> response = await widget.onSubmit(
        <String, dynamic>{
          'first_name': _firstNameController.text.trim(),
          'middle_name': _middleNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'gender': _selectedGender!.toLowerCase(),
          'address': _addressController.text.trim(),
          'contact_number': _contactController.text.trim(),
          'role': _selectedRole,
          'username': _usernameController.text.trim(),
          'password': _passwordController.text,
          'password_confirmation': _confirmPasswordController.text,
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(response);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool isDesktop = size.width >= 880;
    final double dialogWidth = isDesktop ? 980 : size.width * 0.94;
    final double dialogHeight = isDesktop ? 640 : size.height * 0.82;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      backgroundColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Form(
          key: _formKey,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x40000000),
                    blurRadius: 36,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: isDesktop ? _buildDesktopLayout() : _buildMobileLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: <Widget>[
        Expanded(
          flex: 9,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                bottomLeft: Radius.circular(30),
              ),
              image: DecorationImage(
                image: NetworkImage(_bgImageUrl),
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
          flex: 11,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF356042),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: _buildFormShell(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: <Widget>[
        Container(
          height: 132,
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: NetworkImage(_bgImageUrl),
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(
                Color(0x60356042),
                BlendMode.srcOver,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            width: double.infinity,
            color: const Color(0xFF356042),
            child: _buildFormShell(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormShell({required EdgeInsets padding}) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 58,
                  height: 58,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.shield, color: Colors.white, size: 58),
                  ),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      'SMART',
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFD4AF37),
                        height: 1.0,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'DentQueue',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: <Widget>[
                if (_currentStep > 0)
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _isSubmitting ? null : _prevStep,
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                Expanded(
                  child: Text(
                    'Create an Account',
                    style: TextStyle(
                      fontSize: MobileTypography.pageTitle(context),
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_currentStep == 0) _buildStep0(),
            if (_currentStep == 1) _buildStep1(),
            if (_currentStep == 2) _buildStep2(),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildSectionLabel('Enter your Name'),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'First Name',
          child: _buildTextField(
            controller: _firstNameController,
            validator: _requiredValidator,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Middle Name',
          child: _buildTextField(
            controller: _middleNameController,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Last Name',
          child: _buildTextField(
            controller: _lastNameController,
            validator: _requiredValidator,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _nextStep(),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Gender',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
            decoration: _inputDecoration(),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (String? value) {
              setState(() {
                _selectedGender = value;
              });
            },
            validator: (String? value) => value == null ? 'Required' : null,
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
      children: <Widget>[
        _buildSectionLabel('Basic Information'),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Contact Number',
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
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
                  children: <Widget>[
                    Image.network(
                      'https://flagcdn.com/w20/ph.png',
                      width: 20,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.flag, size: 20),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: _contactController,
                  keyboardType: TextInputType.phone,
                  validator: (String? value) {
                    final String trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) return 'Required';
                    if (!RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
                      return 'Enter an 11-digit number starting with 09';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Address',
          child: _buildTextField(
            controller: _addressController,
            maxLines: 2,
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
      children: <Widget>[
        _buildSectionLabel('Account Access'),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Role',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _buildRoleCard(
                role: 'staff',
                title: 'Staff',
                subtitle: 'Full clinic workflow access',
                icon: Icons.medical_services_outlined,
              ),
              _buildRoleCard(
                role: 'intern',
                title: 'Intern',
                subtitle: 'Read-only operational account',
                icon: Icons.school_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Username',
          child: _buildTextField(
            controller: _usernameController,
            validator: _requiredValidator,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Password',
          child: _buildTextField(
            controller: _passwordController,
            validator: (String? value) {
              final String text = value ?? '';
              if (text.isEmpty) return 'Required';
              if (text.length < 8) return 'Min 8 chars';
              return null;
            },
            obscureText: !_showPassword,
            textInputAction: TextInputAction.next,
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
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Confirm Password',
          child: _buildTextField(
            controller: _confirmPasswordController,
            validator: (String? value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
            obscureText: !_showConfirmPassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleSubmit(),
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
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Text(
            'This account will be created as ${_selectedRole == 'staff' ? 'Staff' : 'Intern'} for $_previewName.',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimaryButton(
          label: 'Register',
          onPressed: _isSubmitting ? null : _handleSubmit,
          submitting: _isSubmitting,
        ),
      ],
    );
  }

  Widget _buildLabeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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

  Widget _buildRoleCard({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool isSelected = _selectedRole == role;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedRole = role;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE5EFE1)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFD4AF37)
                : Colors.white.withValues(alpha: 0.18),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              icon,
              size: 24,
              color: isSelected ? const Color(0xFF356042) : Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.black87 : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? Colors.black54
                    : Colors.white.withValues(alpha: 0.78),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    int maxLines = 1,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
      decoration: _inputDecoration(suffixIcon: suffixIcon),
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

  InputDecoration _inputDecoration({Widget? suffixIcon}) {
    return InputDecoration(
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

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: MobileTypography.sectionTitle(context),
        fontWeight: FontWeight.w600,
        color: const Color(0xFFD4AF37),
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if ((value?.trim() ?? '').isEmpty) {
      return 'Required';
    }
    return null;
  }

  String get _previewName {
    final List<String> parts = <String>[
      _firstNameController.text.trim(),
      _middleNameController.text.trim(),
      _lastNameController.text.trim(),
    ].where((String part) => part.isNotEmpty).toList();

    if (parts.isEmpty) {
      return 'this user';
    }

    return parts.join(' ');
  }
}
