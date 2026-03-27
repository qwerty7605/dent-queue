import 'package:flutter/material.dart';
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
  });

  final Map<String, dynamic>? activeUser;
  final TokenStorage tokenStorage;
  final ValueChanged<Map<String, dynamic>>? onProfileUpdated;

  @override
  State<AdminProfileView> createState() => _AdminProfileViewState();
}

class _AdminProfileViewState extends State<AdminProfileView> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController(text: '********');

  late AdminProfileService _adminProfileService;
  
  bool _isEditingUsername = false;
  bool _isEditingPassword = false;
  bool _isEditingProfile = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final apiClient = ApiClient(tokenStorage: widget.tokenStorage);
    final baseService = BaseService(apiClient);
    _adminProfileService = AdminProfileService(baseService);

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

    setState(() {
      _isLoading = true;
    });

    try {
      final payload = <String, dynamic>{};
      
      if (_firstNameController.text.isNotEmpty) payload['first_name'] = _firstNameController.text;
      if (_lastNameController.text.isNotEmpty) payload['last_name'] = _lastNameController.text;
      if (_usernameController.text.isNotEmpty) payload['username'] = _usernameController.text;

      if (_isEditingPassword && _passwordController.text.isNotEmpty && _passwordController.text != '********') {
        payload['password'] = _passwordController.text;
      }

      final response = await _adminProfileService.updateProfile(payload);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: Colors.green),
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

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Admin Profile',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              if (!_isEditingProfile)
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditingProfile = true;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF679B6A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.edit, size: 20),
                  label: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(
                  top: BorderSide(
                    color: Color(0xFF679B6A),
                    width: 6.0,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Personal Information',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildTextField('First name', 'Enter First name', _firstNameController, readOnly: !_isEditingProfile)),
                              const SizedBox(width: 24),
                              Expanded(child: _buildTextField('Last Name', 'Enter Last name', _lastNameController, readOnly: !_isEditingProfile)),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'Account Information',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildAccountField(
                                  'Username',
                                  _usernameController,
                                  _isEditingUsername ? 'LOCK' : 'CHANGE USERNAME',
                                  readOnly: !_isEditingUsername,
                                  onActionTap: () {
                                    setState(() {
                                      _isEditingUsername = !_isEditingUsername;
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
                                  _isEditingPassword ? 'LOCK' : 'CHANGE PASSWORD',
                                  obscureText: !_isEditingPassword,
                                  readOnly: !_isEditingPassword,
                                  onActionTap: () {
                                    setState(() {
                                      _isEditingPassword = !_isEditingPassword;
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
                              if (_isEditingProfile || _isEditingUsername || _isEditingPassword)
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _saveChanges,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF436B46),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  label: _isLoading 
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  icon: _isLoading ? const SizedBox.shrink() : const Icon(Icons.download_for_offline, size: 24),
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
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          readOnly: readOnly,
          decoration: InputDecoration(
            filled: !readOnly,
            fillColor: Colors.green.withValues(alpha: 0.05),
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.black38),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: readOnly ? Colors.black26 : const Color(0xFF436B46), width: readOnly ? 1.0 : 2.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: readOnly ? Colors.black26 : const Color(0xFF436B46), width: readOnly ? 1.0 : 2.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF679B6A), width: 2.0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountField(
      String label, TextEditingController controller, String actionText,
      {bool obscureText = false, bool readOnly = true, required VoidCallback onActionTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
           decoration: InputDecoration(
            filled: !readOnly,
            fillColor: Colors.green.withValues(alpha: 0.05),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: readOnly ? Colors.black26 : const Color(0xFF436B46), width: readOnly ? 1.0 : 2.0),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: readOnly ? Colors.black26 : const Color(0xFF436B46), width: readOnly ? 1.0 : 2.0),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF679B6A), width: 2.0),
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
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
