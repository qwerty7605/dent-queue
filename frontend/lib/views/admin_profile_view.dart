import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_form_validators.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../core/api_client.dart';
import '../services/base_service.dart';
import '../services/admin_profile_service.dart';
import '../widgets/app_alert_dialog.dart';

class AdminProfileView extends StatefulWidget {
  const AdminProfileView({
    super.key,
    required this.activeUser,
    required this.tokenStorage,
    this.onProfileUpdated,
    this.adminProfileService,
  });

  final Map<String, dynamic>? activeUser;
  final TokenStorage tokenStorage;
  final ValueChanged<Map<String, dynamic>>? onProfileUpdated;
  final AdminProfileService? adminProfileService;

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'first_name': <String>['first_name'],
        'last_name': <String>['last_name'],
      };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  late AdminProfileService _adminProfileService;

  bool _isEditingProfile = false;
  bool _isLoading = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;
  bool get _isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get _surfaceColor =>
      _isDarkMode ? const Color(0xFF162033) : Colors.white;
  Color get _surfaceAltColor => _isDarkMode
      ? const Color(0xFF1B2740)
      : Colors.green.withValues(alpha: 0.05);
  Color get _borderColor =>
      _isDarkMode ? const Color(0xFF30415F) : Colors.black26;
  Color get _textColor =>
      _isDarkMode ? const Color(0xFFEAF1FF) : Colors.black87;
  Color get _mutedTextColor =>
      _isDarkMode ? const Color(0xFFAAB8D4) : Colors.black38;
  bool get _hasPendingEdit => _isEditingProfile;
  String get _currentUsername {
    final String username =
        widget.activeUser?['username']?.toString().trim() ?? '';
    return username.isEmpty ? 'Not set' : username;
  }

  @override
  void initState() {
    super.initState();
    _adminProfileService =
        widget.adminProfileService ??
        AdminProfileService(
          BaseService(ApiClient(tokenStorage: widget.tokenStorage)),
        );

    _populateFields();
    _refreshFromStorage();
  }

  Future<void> _refreshFromStorage() async {
    final storedUser = await widget.tokenStorage.readUserInfo();
    if (storedUser != null && mounted) {
      setState(() {
        if (widget.activeUser != null) {
          widget.activeUser!.addAll(storedUser);
        }
        _populateFields();
      });
    }
  }

  @override
  void didUpdateWidget(AdminProfileView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeUser != oldWidget.activeUser) {
      _populateFields();
    }
  }

  void _populateFields() {
    if (widget.activeUser != null) {
      _firstNameController.text = widget.activeUser!['first_name'] ?? '';
      _lastNameController.text = widget.activeUser!['last_name'] ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autoValidateMode = AutovalidateMode.always;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors = <String, String>{};
      _formErrorText = null;
    });

    try {
      final payload = <String, dynamic>{};

      if (_isEditingProfile && _firstNameController.text.isNotEmpty) {
        payload['first_name'] = _firstNameController.text;
      }
      if (_isEditingProfile && _lastNameController.text.isNotEmpty) {
        payload['last_name'] = _lastNameController.text;
      }

      final response = await _adminProfileService.updateProfile(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        _isEditingProfile = false;
      });

      if (widget.onProfileUpdated != null && response['user'] != null) {
        widget.onProfileUpdated!(response['user'] as Map<String, dynamic>);
      }
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
        _autoValidateMode = AutovalidateMode.always;
      });
      _formKey.currentState?.validate();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _formErrorText = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  Future<void> _openChangeUsernameDialog() async {
    final Map<String, dynamic>? updatedUser =
        await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) => _ChangeUsernameDialog(
            currentUsername: _currentUsername,
            adminProfileService: _adminProfileService,
          ),
        );

    if (updatedUser == null || !mounted) {
      return;
    }

    setState(() {
      widget.activeUser?.addAll(updatedUser);
      _populateFields();
    });

    widget.onProfileUpdated?.call(updatedUser);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Username updated successfully.'),
          backgroundColor: Color(0xFF436B46),
        ),
      );
  }

  Future<void> _openChangePasswordDialog() async {
    final bool? didUpdate = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) =>
          _ChangePasswordDialog(adminProfileService: _adminProfileService),
    );

    if (didUpdate != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully.'),
          backgroundColor: Color(0xFF436B46),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = MobileTypography.isPhone(context);
    final bool compactHeader = MediaQuery.sizeOf(context).width < 980;
    final Widget title = Text(
      'Admin Profile',
      style: TextStyle(
        fontSize: MobileTypography.pageTitle(context),
        fontWeight: FontWeight.bold,
        color: _isDarkMode ? const Color(0xFFEAF1FF) : Colors.black,
      ),
    );

    final Widget? action = !_isEditingProfile
        ? ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _fieldErrors = <String, String>{};
                _formErrorText = null;
                _isEditingProfile = true;
                _autoValidateMode = AutovalidateMode.disabled;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A769E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            icon: const Icon(Icons.edit, size: 20),
            label: Text(
              'Edit Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: MobileTypography.button(context),
              ),
            ),
          )
        : null;

    return Padding(
      padding: MobileTypography.screenPadding(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (compactHeader)
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  if (action != null) ...[const SizedBox(height: 16), action],
                ],
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [title, if (action case final Widget button) button],
            ),
          SizedBox(height: isPhone ? 16 : 24),
          Expanded(
            child: Container(
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: const Border(
                  top: BorderSide(color: Color(0xFF4A769E), width: 6.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isDarkMode ? 0.24 : 0.05,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Interactive Form content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isPhone ? 16.0 : 24.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _autoValidateMode,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_formErrorText != null) ...[
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isDarkMode
                                      ? const Color(0xFF3A2026)
                                      : const Color(0xFFFFF1F1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  _formErrorText!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: MobileTypography.sectionTitle(
                                  context,
                                ),
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (isPhone)
                              Column(
                                children: [
                                  _buildTextField(
                                    'First name',
                                    'Enter First name',
                                    _firstNameController,
                                    fieldKey: 'first_name',
                                    readOnly: !_isEditingProfile,
                                    inputFormatters:
                                        AppFormValidators.nameInputFormatters(),
                                    validator: (value) => !_isEditingProfile
                                        ? null
                                        : _mergeFieldError(
                                            'first_name',
                                            AppFormValidators.requiredName(
                                              value,
                                              fieldLabel: 'First name',
                                            ),
                                          ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTextField(
                                    'Last Name',
                                    'Enter Last name',
                                    _lastNameController,
                                    fieldKey: 'last_name',
                                    readOnly: !_isEditingProfile,
                                    inputFormatters:
                                        AppFormValidators.nameInputFormatters(),
                                    validator: (value) => !_isEditingProfile
                                        ? null
                                        : _mergeFieldError(
                                            'last_name',
                                            AppFormValidators.requiredName(
                                              value,
                                              fieldLabel: 'Last name',
                                            ),
                                          ),
                                  ),
                                ],
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTextField(
                                      'First name',
                                      'Enter First name',
                                      _firstNameController,
                                      fieldKey: 'first_name',
                                      readOnly: !_isEditingProfile,
                                      inputFormatters:
                                          AppFormValidators.nameInputFormatters(),
                                      validator: (value) => !_isEditingProfile
                                          ? null
                                          : _mergeFieldError(
                                              'first_name',
                                              AppFormValidators.requiredName(
                                                value,
                                                fieldLabel: 'First name',
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  Expanded(
                                    child: _buildTextField(
                                      'Last Name',
                                      'Enter Last name',
                                      _lastNameController,
                                      fieldKey: 'last_name',
                                      readOnly: !_isEditingProfile,
                                      inputFormatters:
                                          AppFormValidators.nameInputFormatters(),
                                      validator: (value) => !_isEditingProfile
                                          ? null
                                          : _mergeFieldError(
                                              'last_name',
                                              AppFormValidators.requiredName(
                                                value,
                                                fieldLabel: 'Last name',
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 32),
                            Text(
                              'Account Information',
                              style: TextStyle(
                                fontSize: MobileTypography.sectionTitle(
                                  context,
                                ),
                                fontWeight: FontWeight.bold,
                                color: _textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildAccountSecuritySection(isPhone: isPhone),
                            if (_hasPendingEdit) ...[
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF436B46),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  label: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Save Changes',
                                          style: TextStyle(
                                            fontSize: MobileTypography.button(
                                              context,
                                            ),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                  icon: _isLoading
                                      ? const SizedBox.shrink()
                                      : const Icon(
                                          Icons.save_rounded,
                                          size: 22,
                                        ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String hint,
    TextEditingController controller, {
    required String fieldKey,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _textColor,
            fontSize: MobileTypography.label(context),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: (_) => _clearFieldError(fieldKey),
          readOnly: readOnly,
          inputFormatters: inputFormatters,
          validator: validator,
          decoration: InputDecoration(
            filled: !readOnly,
            fillColor: _surfaceAltColor,
            hintText: hint,
            hintStyle: TextStyle(color: _mutedTextColor),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: readOnly ? _borderColor : const Color(0xFF436B46),
                width: readOnly ? 1.0 : 2.0,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(
                color: readOnly ? _borderColor : const Color(0xFF436B46),
                width: readOnly ? 1.0 : 2.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(
                color: Color(0xFF4A769E),
                width: 2.0,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountSecuritySection({required bool isPhone}) {
    final Widget usernameCard = _buildSecureAccountCard(
      icon: Icons.account_circle_outlined,
      title: 'Username',
      summary: 'Hidden until confirmed',
      buttonLabel: 'Change Username',
      onPressed: _openChangeUsernameDialog,
      editor: null,
    );

    final Widget passwordCard = _buildSecureAccountCard(
      icon: Icons.lock_outline_rounded,
      title: 'Password',
      summary: 'Hidden credential',
      buttonLabel: 'Change Password',
      onPressed: _openChangePasswordDialog,
      editor: null,
    );

    if (isPhone) {
      return Column(
        children: <Widget>[
          usernameCard,
          const SizedBox(height: 14),
          passwordCard,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: usernameCard),
        const SizedBox(width: 18),
        Expanded(child: passwordCard),
      ],
    );
  }

  Widget _buildSecureAccountCard({
    required IconData icon,
    required String title,
    required String summary,
    required String buttonLabel,
    required VoidCallback onPressed,
    required Widget? editor,
  }) {
    final Color iconBackground = _isDarkMode
        ? const Color(0xFF21304B)
        : const Color(0xFFEAF2FA);
    final Color cardBackground = _isDarkMode
        ? const Color(0xFF141C2E)
        : const Color(0xFFF9FBFE);
    final Color cardBorder = _isDarkMode
        ? const Color(0xFF2B3956)
        : const Color(0xFFE3EAF6);

    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF4A769E), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: MobileTypography.label(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mutedTextColor,
                        fontSize: MobileTypography.caption(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF436B46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: Icon(
                  editor == null ? Icons.edit_rounded : Icons.close_rounded,
                  size: 18,
                ),
                label: Text(
                  buttonLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          if (editor != null) ...<Widget>[const SizedBox(height: 16), editor],
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.adminProfileService});

  final AdminProfileService adminProfileService;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'current_password': <String>['current_password'],
        'password': <String>['password'],
        'password_confirmation': <String>['password_confirmation'],
      };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSaving = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autoValidateMode = AutovalidateMode.always;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _fieldErrors = <String, String>{};
      _formErrorText = null;
    });

    try {
      await widget.adminProfileService.updateProfile(<String, dynamic>{
        'current_password': _currentPasswordController.text,
        'password': _newPasswordController.text,
        'password_confirmation': _confirmPasswordController.text,
      });

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

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
        _autoValidateMode = AutovalidateMode.always;
      });
      _formKey.currentState?.validate();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _formErrorText = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _clearFieldError(String fieldKey) {
    if (!_fieldErrors.containsKey(fieldKey) && _formErrorText == null) {
      return;
    }

    setState(() {
      _fieldErrors.remove(fieldKey);
      _formErrorText = null;
    });
  }

  String? _mergeFieldError(String fieldKey, String? localError) {
    return localError ?? _fieldErrors[fieldKey];
  }

  String? _validateCurrentPassword(String? value) {
    final String password = value ?? '';
    if (password.isEmpty) {
      return 'Current password is required';
    }
    return _mergeFieldError('current_password', null);
  }

  String? _validateNewPassword(String? value) {
    return _mergeFieldError('password', AppFormValidators.password(value));
  }

  String? _validateConfirmPassword(String? value) {
    return _mergeFieldError(
      'password_confirmation',
      AppFormValidators.confirmPassword(value, _newPasswordController.text),
    );
  }

  Widget _buildPasswordField({
    required Key fieldKey,
    required Key toggleKey,
    required TextEditingController controller,
    required String labelText,
    required String fieldErrorKey,
    required bool isVisible,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      key: fieldKey,
      controller: controller,
      onChanged: (_) {
        _clearFieldError(fieldErrorKey);
        if (fieldErrorKey == 'password') {
          _clearFieldError('password_confirmation');
        }
      },
      obscureText: !isVisible,
      enableSuggestions: false,
      autocorrect: false,
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          key: toggleKey,
          tooltip: isVisible ? 'Hide password' : 'Show password',
          onPressed: onToggle,
          icon: Icon(
            isVisible
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AppAlertDialog(
      scrollable: true,
      title: const Text('Change Password'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_formErrorText != null) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A2026)
                        : const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _formErrorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              _buildPasswordField(
                fieldKey: const Key('admin-profile-current-password-field'),
                toggleKey: const Key('admin-profile-current-password-toggle'),
                controller: _currentPasswordController,
                labelText: 'Current password',
                fieldErrorKey: 'current_password',
                isVisible: _showCurrentPassword,
                onToggle: () {
                  setState(() {
                    _showCurrentPassword = !_showCurrentPassword;
                  });
                },
                validator: _validateCurrentPassword,
              ),
              const SizedBox(height: 14),
              _buildPasswordField(
                fieldKey: const Key('admin-profile-new-password-field'),
                toggleKey: const Key('admin-profile-new-password-toggle'),
                controller: _newPasswordController,
                labelText: 'New password',
                fieldErrorKey: 'password',
                isVisible: _showNewPassword,
                onToggle: () {
                  setState(() {
                    _showNewPassword = !_showNewPassword;
                  });
                },
                validator: _validateNewPassword,
              ),
              const SizedBox(height: 14),
              _buildPasswordField(
                fieldKey: const Key('admin-profile-confirm-password-field'),
                toggleKey: const Key('admin-profile-confirm-password-toggle'),
                controller: _confirmPasswordController,
                labelText: 'Confirm new password',
                fieldErrorKey: 'password_confirmation',
                isVisible: _showConfirmPassword,
                onToggle: () {
                  setState(() {
                    _showConfirmPassword = !_showConfirmPassword;
                  });
                },
                validator: _validateConfirmPassword,
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset_outlined, size: 18),
          label: Text(_isSaving ? 'Saving' : 'Save Password'),
        ),
      ],
    );
  }
}

class _ChangeUsernameDialog extends StatefulWidget {
  const _ChangeUsernameDialog({
    required this.currentUsername,
    required this.adminProfileService,
  });

  final String currentUsername;
  final AdminProfileService adminProfileService;

  @override
  State<_ChangeUsernameDialog> createState() => _ChangeUsernameDialogState();
}

class _ChangeUsernameDialogState extends State<_ChangeUsernameDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'username': <String>['username'],
        'current_password': <String>['current_password'],
      };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _newUsernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSaving = false;
  AutovalidateMode _autoValidateMode = AutovalidateMode.disabled;
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;

  @override
  void dispose() {
    _newUsernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autoValidateMode = AutovalidateMode.always;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _fieldErrors = <String, String>{};
      _formErrorText = null;
    });

    try {
      final Map<String, dynamic> response = await widget.adminProfileService
          .updateProfile(<String, dynamic>{
            'username': _newUsernameController.text.trim(),
            'current_password': _passwordController.text,
          });

      if (!mounted) {
        return;
      }

      final dynamic user = response['user'];
      Navigator.of(context).pop(
        user is Map ? Map<String, dynamic>.from(user) : <String, dynamic>{},
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

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
        _autoValidateMode = AutovalidateMode.always;
      });
      _formKey.currentState?.validate();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _formErrorText = 'Error: ${e.toString().replaceAll('Exception: ', '')}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _clearFieldError(String fieldKey) {
    if (!_fieldErrors.containsKey(fieldKey) && _formErrorText == null) {
      return;
    }

    setState(() {
      _fieldErrors.remove(fieldKey);
      _formErrorText = null;
    });
  }

  String? _mergeFieldError(String fieldKey, String? localError) {
    return localError ?? _fieldErrors[fieldKey];
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark
        ? const Color(0xFF1B2740)
        : const Color(0xFFF6F9FD);
    final Color borderColor = isDark
        ? const Color(0xFF2B3956)
        : const Color(0xFFE3EAF6);
    final Color textColor = isDark
        ? const Color(0xFFEAF1FF)
        : const Color(0xFF1D3264);
    final Color mutedColor = isDark
        ? const Color(0xFFAAB8D4)
        : const Color(0xFF667792);

    return AppAlertDialog(
      scrollable: true,
      title: const Text('Change Username'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: _autoValidateMode,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_formErrorText != null) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF3A2026)
                        : const Color(0xFFFFF1F1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    _formErrorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.account_circle_outlined,
                      color: Color(0xFF4A769E),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Current username',
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.currentUsername,
                            key: const Key(
                              'admin-profile-current-username-label',
                            ),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('admin-profile-change-username-field'),
                controller: _newUsernameController,
                onChanged: (_) => _clearFieldError('username'),
                inputFormatters: AppFormValidators.usernameInputFormatters(),
                validator: (String? value) => _mergeFieldError(
                  'username',
                  AppFormValidators.username(value),
                ),
                decoration: const InputDecoration(
                  labelText: 'New username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('admin-profile-change-username-password-field'),
                controller: _passwordController,
                onChanged: (_) => _clearFieldError('current_password'),
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                validator: (String? value) {
                  final String password = value ?? '';
                  if (password.isEmpty) {
                    return 'Password is required';
                  }
                  return _mergeFieldError('current_password', null);
                },
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _submit,
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.verified_user_outlined, size: 18),
          label: Text(_isSaving ? 'Saving' : 'Save Username'),
        ),
      ],
    );
  }
}
