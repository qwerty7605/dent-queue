import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_form_validators.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';
import '../core/form_error_helpers.dart';
import '../core/token_storage.dart';
import '../services/base_service.dart';
import '../services/profile_service.dart';
import 'app_dialog_scaffold.dart';

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> userInfo;
  final ProfileService? profileService;

  const EditProfileDialog({
    super.key,
    required this.userInfo,
    this.profileService,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  static const Map<String, List<String>> _apiFieldMappings =
      <String, List<String>>{
        'first_name': <String>['first_name'],
        'middle_name': <String>['middle_name'],
        'last_name': <String>['last_name'],
        'address': <String>['address', 'location'],
        'gender': <String>['gender'],
        'contact_number': <String>['contact_number', 'phone_number'],
        'profile_picture': <String>['profile_picture'],
      };

  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _addressController;
  late TextEditingController _contactNumberController;
  late TextEditingController _genderController;

  File? _selectedImage;
  bool _isLoading = false;
  late final ProfileService _profileService;
  Map<String, String> _fieldErrors = <String, String>{};
  String? _formErrorText;

  @override
  void initState() {
    super.initState();

    // Attempt to split 'name' if separate first/last aren't provided
    String firstName = widget.userInfo['first_name']?.toString() ?? '';
    String middleName = widget.userInfo['middle_name']?.toString() ?? '';
    String lastName = widget.userInfo['last_name']?.toString() ?? '';

    if (firstName.isEmpty &&
        lastName.isEmpty &&
        widget.userInfo['name'] != null) {
      List<String> parts = widget.userInfo['name'].toString().split(' ');
      if (parts.isNotEmpty) {
        firstName = parts.first;
        if (parts.length > 2) {
          lastName = parts.last;
          middleName = parts.sublist(1, parts.length - 1).join(' ');
        } else if (parts.length == 2) {
          lastName = parts.last;
        }
      }
    }

    _firstNameController = TextEditingController(text: firstName);
    _middleNameController = TextEditingController(text: middleName);
    _lastNameController = TextEditingController(text: lastName);

    // Fallback to location if address isn't present
    _addressController = TextEditingController(
      text:
          (widget.userInfo['address'] ?? widget.userInfo['location'])
              ?.toString() ??
          '',
    );
    _contactNumberController = TextEditingController(
      text:
          (widget.userInfo['contact_number'] ?? widget.userInfo['phone_number'])
              ?.toString() ??
          '',
    );
    _genderController = TextEditingController(
      text: widget.userInfo['gender']?.toString() ?? '',
    );

    _profileService =
        widget.profileService ??
        ProfileService(
          BaseService(ApiClient(tokenStorage: SecureTokenStorage())),
        );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _fieldErrors.remove('profile_picture');
        _formErrorText = null;
      });
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

  void _applyApiErrors(ApiException exception) {
    final Map<String, String> fieldErrors = collectApiFieldErrors(
      exception.errors,
      _apiFieldMappings,
    );
    final String? formError =
        firstUnhandledApiError(
          exception.errors,
          handledKeys: flattenApiErrorKeys(_apiFieldMappings),
        ) ??
        (fieldErrors.isEmpty ? exception.message : null);

    setState(() {
      _fieldErrors = fieldErrors;
      _formErrorText = formError;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _fieldErrors = <String, String>{};
        _formErrorText = null;
      });
      try {
        final userId = widget.userInfo['id'] as int;
        final role = _resolveRole(widget.userInfo['role']);

        // Assemble fields
        final Map<String, String> fields = {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
        };

        if (_middleNameController.text.trim().isNotEmpty) {
          fields['middle_name'] = _middleNameController.text.trim();
        }
        if (_addressController.text.trim().isNotEmpty) {
          fields['address'] = _addressController.text.trim();
        }
        if (_contactNumberController.text.trim().isNotEmpty) {
          fields['contact_number'] = _contactNumberController.text.trim();
        }
        if (_genderController.text.trim().isNotEmpty) {
          fields['gender'] = _genderController.text.trim();
        }
        final response = await _profileService.updateProfile(
          userId,
          fields: fields,
          role: role,
          profilePicture: _selectedImage,
        );

        // Update token storage with new user info
        final tokenStorage = SecureTokenStorage();
        final updatedUserInfo = _normalizeUserInfo(response['user']);
        if (response['user'] != null) {
          await tokenStorage.writeUserInfo(updatedUserInfo);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully.'),
              backgroundColor: Color(0xFF4A769E),
            ),
          );
          Navigator.of(context).pop(updatedUserInfo);
        }
      } on ApiException catch (e) {
        if (mounted) {
          _applyApiErrors(e);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _formErrorText = 'Failed to update profile: $e';
          });
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  String _resolveRole(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim().toLowerCase();
    }

    if (value is Map<String, dynamic>) {
      final roleName = value['name']?.toString().trim().toLowerCase();
      if (roleName != null && roleName.isNotEmpty) {
        return roleName;
      }
    }

    return 'patient';
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'staff':
        return 'STAFF';
      case 'admin':
        return 'ADMIN';
      default:
        return 'PATIENT';
    }
  }

  Map<String, dynamic> _normalizeUserInfo(dynamic rawUser) {
    final original = Map<String, dynamic>.from(widget.userInfo);
    if (rawUser is! Map<String, dynamic>) {
      return original;
    }

    final firstName =
        rawUser['first_name']?.toString() ??
        original['first_name']?.toString() ??
        '';
    final middleName =
        rawUser['middle_name']?.toString() ??
        original['middle_name']?.toString() ??
        '';
    final lastName =
        rawUser['last_name']?.toString() ??
        original['last_name']?.toString() ??
        '';
    final role = _resolveRole(rawUser['role'] ?? original['role']);
    final name = [
      firstName,
      middleName,
      lastName,
    ].where((part) => part.trim().isNotEmpty).join(' ').trim();
    final location =
        rawUser['location']?.toString() ??
        rawUser['address']?.toString() ??
        original['location']?.toString() ??
        original['address']?.toString() ??
        '';
    final phoneNumber =
        rawUser['phone_number']?.toString() ??
        rawUser['contact_number']?.toString() ??
        original['phone_number']?.toString() ??
        original['contact_number']?.toString() ??
        '';

    return {
      ...original,
      'id': rawUser['id'] ?? original['id'],
      'name': name.isNotEmpty
          ? name
          : (rawUser['name']?.toString() ??
                original['name']?.toString() ??
                'User'),
      'role': role,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'location': location,
      'address': location,
      'gender': rawUser['gender'] ?? original['gender'],
      'phone_number': phoneNumber,
      'contact_number': phoneNumber,
      'profile_picture':
          rawUser['profile_picture'] ?? original['profile_picture'],
      'email': rawUser['email'] ?? original['email'],
    };
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: Color(0xFF7E8CA0),
        letterSpacing: 0.5,
      ),
    );
  }

  InputDecoration _inputDecoration({String? helperText}) {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      helperText: helperText,
      helperStyle: const TextStyle(
        color: Color(0xFF7E8CA0),
        fontWeight: FontWeight.w600,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4A769E), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = _resolveRole(widget.userInfo['role']);

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: AppDialogScaffold(
        title: 'Edit Profile',
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          color: Color(0xFF2C3E50),
        ),
        maxWidth: 540,
        onClose: _isLoading ? null : () => Navigator.of(context).pop(),
        footer: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A769E),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
        showFooterDivider: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_formErrorText != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
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
            Center(
              child: Column(
                children: [
                  InkWell(
                    onTap: _pickImage,
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 2,
                            ),
                            color: const Color(0xFFF8FAFC),
                          ),
                          child: _selectedImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : (widget.userInfo['profile_picture'] != null &&
                                    widget.userInfo['profile_picture']
                                        .toString()
                                        .trim()
                                        .isNotEmpty &&
                                    widget.userInfo['profile_picture']
                                            .toString() !=
                                        'null' &&
                                    widget.userInfo['profile_picture']
                                            .toString() !=
                                        '/storage/')
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    '${AppConfig.baseUrl}${widget.userInfo['profile_picture']}',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                  ),
                                )
                              : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF4A769E),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _roleLabel(role),
                    style: const TextStyle(
                      color: Color(0xFF7E8CA0),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (_fieldErrors['profile_picture'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _fieldErrors['profile_picture']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildLabel('FIRST NAME'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _firstNameController,
              onChanged: (_) => _clearFieldError('first_name'),
              inputFormatters: AppFormValidators.nameInputFormatters(),
              decoration: _inputDecoration(),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError(
                'first_name',
                AppFormValidators.requiredName(value, fieldLabel: 'First name'),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('MIDDLE NAME'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _middleNameController,
              onChanged: (_) => _clearFieldError('middle_name'),
              inputFormatters: AppFormValidators.nameInputFormatters(),
              decoration: _inputDecoration(),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError(
                'middle_name',
                AppFormValidators.optionalName(
                  value,
                  fieldLabel: 'Middle name',
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('SURNAME'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _lastNameController,
              onChanged: (_) => _clearFieldError('last_name'),
              inputFormatters: AppFormValidators.nameInputFormatters(),
              decoration: _inputDecoration(),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError(
                'last_name',
                AppFormValidators.requiredName(value, fieldLabel: 'Last name'),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('ADDRESS'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              onChanged: (_) => _clearFieldError('address'),
              inputFormatters: AppFormValidators.maxLengthInputFormatters(
                AppFormValidators.addressMaxLength,
              ),
              decoration: _inputDecoration(
                helperText:
                    'Up to ${AppFormValidators.addressMaxLength} characters',
              ),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError(
                'address',
                AppFormValidators.address(
                  value,
                  fieldLabel: 'Address',
                  required: true,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('GENDER'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _genderController,
              onChanged: (_) => _clearFieldError('gender'),
              inputFormatters: AppFormValidators.maxLengthInputFormatters(10),
              decoration: _inputDecoration(
                helperText: 'Male, female, or other',
              ),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError(
                'gender',
                AppFormValidators.gender(value, required: false),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('CONTACT NUMBER'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactNumberController,
              onChanged: (_) => _clearFieldError('contact_number'),
              inputFormatters: AppFormValidators.contactNumberInputFormatters(),
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(
                helperText: 'Use an 11-digit PH mobile number',
              ),
              style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
              validator: (value) => _mergeFieldError(
                'contact_number',
                AppFormValidators.contactNumber(value),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
