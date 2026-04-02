import 'package:flutter/material.dart';

import '../core/api_exception.dart';

class AddStaffDialog extends StatefulWidget {
  const AddStaffDialog({super.key, required this.onSubmit});

  final Future<Map<String, dynamic>> Function(Map<String, dynamic> data)
  onSubmit;

  @override
  State<AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  String _selectedRole = 'staff';
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _firstNameController.dispose();
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

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'gender': _selectedGender!.toLowerCase(),
        'address': _addressController.text.trim(),
        'contact_number': _contactController.text.trim(),
        'role': _selectedRole,
        'username': _usernameController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
      };

      final response = await widget.onSubmit(payload);
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
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final dialogWidth = width > 920 ? 760.0 : width * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _formKey,
          child: Container(
            color: const Color(0xFF356042),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_currentStep > 0)
                        IconButton(
                          onPressed: _prevStep,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),
                      if (_currentStep > 0) const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Create Staff or Intern',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentStep == 0
                        ? 'Basic Information'
                        : _currentStep == 1
                        ? 'Account Type'
                        : 'Create Account',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_currentStep == 0) _buildStep0(),
                  if (_currentStep == 1) _buildStep1(),
                  if (_currentStep == 2) _buildStep2(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Gender',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGender,
            decoration: _inputDecoration(hintText: 'Select Gender'),
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Other', child: Text('Other')),
            ],
            onChanged: (val) => setState(() => _selectedGender = val),
            validator: (val) => val == null ? 'Required' : null,
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Address',
          child: TextFormField(
            controller: _addressController,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Address'),
          ),
        ),
        const SizedBox(height: 16),
        _buildLabeledField(
          label: 'Contact Number',
          child: TextFormField(
            controller: _contactController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Contact Number'),
            validator: (val) {
              final trimmed = val?.trim() ?? '';
              if (trimmed.isEmpty) return 'Required';
              if (!RegExp(r'^09\d{9}$').hasMatch(trimmed)) {
                return 'Enter an 11-digit number starting with 09';
              }
              return null;
            },
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
        _buildLabeledField(
          label: 'Account Role',
          child: DropdownButtonFormField<String>(
            initialValue: _selectedRole,
            decoration: _inputDecoration(hintText: 'Select Role'),
            dropdownColor: Colors.white,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            items: const [
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
              DropdownMenuItem(value: 'intern', child: Text('Intern')),
            ],
            onChanged: (val) {
              if (val == null) return;
              setState(() {
                _selectedRole = val;
              });
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFE5EFE1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _selectedRole == 'intern'
                ? 'Intern accounts can sign in, but remain restricted from current admin and staff write actions by default.'
                : 'Staff accounts are intended for operational users with staff-approved workflows.',
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
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
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            decoration: _inputDecoration(hintText: 'Enter Username'),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Required' : null,
          ),
        ),
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
              hintText: 'Enter Password',
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
