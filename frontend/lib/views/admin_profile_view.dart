import 'package:flutter/material.dart';
import '../core/app_form_validators.dart';
import '../core/api_exception.dart';
import '../core/form_error_helpers.dart';
import '../core/mobile_typography.dart';
import '../core/token_storage.dart';
import '../core/api_client.dart';
import '../services/base_service.dart';
import '../services/admin_profile_service.dart';

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
        'username': <String>['username'],
        'password': <String>['password'],
      };

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(
    text: '********',
  );

  late AdminProfileService _adminProfileService;

  bool _isEditingUsername = false;
  bool _isEditingPassword = false;
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
      _usernameController.text = widget.activeUser!['username'] ?? '';
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
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

      if (_firstNameController.text.isNotEmpty) {
        payload['first_name'] = _firstNameController.text;
      }
      if (_lastNameController.text.isNotEmpty) {
        payload['last_name'] = _lastNameController.text;
      }
      if (_usernameController.text.isNotEmpty) {
        payload['username'] = _usernameController.text;
      }

      if (_isEditingPassword &&
          _passwordController.text.isNotEmpty &&
          _passwordController.text != '********') {
        payload['password'] = _passwordController.text;
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
        _isEditingPassword = false;
        _isEditingUsername = false;
        _passwordController.text = '********';
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
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildAccountField(
                                    'Username',
                                    _usernameController,
                                    _isEditingUsername
                                        ? 'LOCK'
                                        : 'CHANGE USERNAME',
                                    fieldKey: 'username',
                                    readOnly: !_isEditingUsername,
                                    validator: (value) => !_isEditingUsername
                                        ? null
                                        : _mergeFieldError(
                                            'username',
                                            AppFormValidators.username(value),
                                          ),
                                    onActionTap: () {
                                      setState(() {
                                        _fieldErrors.remove('username');
                                        _formErrorText = null;
                                        _isEditingUsername =
                                            !_isEditingUsername;
                                      });
                                    },
                                  ),
                                ),
                                const Spacer(flex: 1),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildAccountField(
                                    'Password',
                                    _passwordController,
                                    _isEditingPassword
                                        ? 'LOCK'
                                        : 'CHANGE PASSWORD',
                                    fieldKey: 'password',
                                    obscureText: !_isEditingPassword,
                                    readOnly: !_isEditingPassword,
                                    validator: (value) => !_isEditingPassword
                                        ? null
                                        : _mergeFieldError(
                                            'password',
                                            AppFormValidators.password(value),
                                          ),
                                    onActionTap: () {
                                      setState(() {
                                        _fieldErrors.remove('password');
                                        _formErrorText = null;
                                        _isEditingPassword =
                                            !_isEditingPassword;
                                        if (_isEditingPassword) {
                                          _passwordController.clear();
                                        } else {
                                          _passwordController.text = '********';
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const Spacer(flex: 1),
                                if (_isEditingProfile ||
                                    _isEditingUsername ||
                                    _isEditingPassword)
                                  ElevatedButton.icon(
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
                                            Icons.download_for_offline,
                                            size: 24,
                                          ),
                                  ),
                              ],
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

  Widget _buildAccountField(
    String label,
    TextEditingController controller,
    String actionText, {
    required String fieldKey,
    bool obscureText = false,
    bool readOnly = true,
    String? Function(String?)? validator,
    required VoidCallback onActionTap,
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
          obscureText: obscureText,
          readOnly: readOnly,
          validator: validator,
          decoration: InputDecoration(
            filled: !readOnly,
            fillColor: _surfaceAltColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
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
            suffixIcon: TextButton(
              onPressed: onActionTap,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  color: Color(0xFF436B46),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
