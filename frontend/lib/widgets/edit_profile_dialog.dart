import 'package:flutter/material.dart';

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> userInfo;

  const EditProfileDialog({super.key, required this.userInfo});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _addressController;
  late TextEditingController _contactNumberController;
  late TextEditingController _genderController;

  DateTime? _selectedBirthdate;

  @override
  void initState() {
    super.initState();
    
    // Attempt to split 'name' if separate first/last aren't provided
    String firstName = widget.userInfo['first_name']?.toString() ?? '';
    String middleName = widget.userInfo['middle_name']?.toString() ?? '';
    String lastName = widget.userInfo['last_name']?.toString() ?? '';
    
    if (firstName.isEmpty && lastName.isEmpty && widget.userInfo['name'] != null) {
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
    _addressController = TextEditingController(text: (widget.userInfo['address'] ?? widget.userInfo['location'])?.toString() ?? '');
    _contactNumberController = TextEditingController(text: (widget.userInfo['contact_number'] ?? widget.userInfo['phone_number'])?.toString() ?? '');
    _genderController = TextEditingController(text: widget.userInfo['gender']?.toString() ?? '');

    if (widget.userInfo['birthdate'] != null && widget.userInfo['birthdate'].toString().isNotEmpty) {
      try {
        _selectedBirthdate = DateTime.parse(widget.userInfo['birthdate'].toString());
      } catch (e) {
        // Handle parsing error
      }
    }
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

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      // Logic to save the updated profile info would go here (e.g. API call).
      // Since API integration is in another ticket, we just pop.
      Navigator.of(context).pop();
    }
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

  InputDecoration _inputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        borderSide: const BorderSide(color: Color(0xFF679B6A), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with Title
                    const Center(
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Avatar placeholder (Clickable to upload)
                    Center(
                      child: Column(
                        children: [
                          InkWell(
                            onTap: () {
                              // ScaffoldMessenger helps inform the user they tapped the upload button
                              // In the API integration phase, this will trigger the image_picker package
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile picture upload functionality will be implemented with the backend API.'),
                                  backgroundColor: Color(0xFF679B6A),
                                ),
                              );
                            },
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                                    color: const Color(0xFFF8FAFC),
                                  ),
                                  child: const Icon(Icons.person, size: 50, color: Colors.grey),
                                ),
                                Positioned(
                                  bottom: -5,
                                  right: -5,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF679B6A),
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
                          const SizedBox(height: 8),
                          const Text(
                            'PATIENT',
                            style: TextStyle(
                              color: Color(0xFF7E8CA0),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // First Name
                    _buildLabel('FIRST NAME'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: _inputDecoration(),
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Middle Name
                    _buildLabel('MIDDLE NAME'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _middleNameController,
                      decoration: _inputDecoration(),
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    // Last Name
                    _buildLabel('SURNAME'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: _inputDecoration(),
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Birthdate
                    _buildDateField(),
                    const SizedBox(height: 16),

                    // Address
                    _buildLabel('ADDRESS'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      decoration: _inputDecoration(),
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                      validator: (value) => value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Gender
                    _buildLabel('GENDER'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _genderController,
                      decoration: _inputDecoration(),
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    // Contact Number
                    _buildLabel('CONTACT NUMBER'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contactNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(),
                      style: const TextStyle(color: Color(0xFF2C3E50), fontSize: 16),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        // Validate contact number is numerical
                        if (double.tryParse(value.replaceAll('+', '').replaceAll('-', '').replaceAll(' ', '')) == null) {
                          return 'Must be a valid numerical contact number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF679B6A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: const Text(
                              'Save\nChanges',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFF1F5F9), // light gray
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 24), // matching height
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF475569),
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
          ),
          // Close button positioned top right
          Positioned(
            right: 16,
            top: 16,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close, color: Color(0xFF7E8CA0)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateField() {
    return FormField<DateTime>(
      validator: (val) {
        if (_selectedBirthdate == null) return 'Required';
        if (_selectedBirthdate!.isAfter(DateTime.now())) {
          return 'Birthdate cannot be in the future';
        }
        return null;
      },
      builder: (FormFieldState<DateTime> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('BIRTHDATE'),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedBirthdate ?? now.subtract(const Duration(days: 365 * 20)), // default 20 years ago
                  firstDate: DateTime(1900),
                  lastDate: now, // cannot be more than now
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: Color(0xFF679B6A),
                          onPrimary: Colors.white,
                          onSurface: Color(0xFF2C3E50),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF679B6A),
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (picked != null) {
                  setState(() {
                    _selectedBirthdate = picked;
                  });
                  state.didChange(picked);
                }
              },
              child: InputDecorator(
                decoration: _inputDecoration().copyWith(
                  errorText: state.errorText,
                  suffixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF1E293B), size: 18),
                ),
                isEmpty: _selectedBirthdate == null,
                child: Text(
                  _selectedBirthdate == null
                      ? 'dd/mm/yyyy'
                      : '${_selectedBirthdate!.day.toString().padLeft(2, '0')}/${_selectedBirthdate!.month.toString().padLeft(2, '0')}/${_selectedBirthdate!.year}',
                  style: TextStyle(
                    color: _selectedBirthdate == null ? const Color(0xFF94A3B8) : const Color(0xFF2C3E50),
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
