import 'package:flutter/material.dart';

import '../core/api_exception.dart';
import '../core/token_storage.dart';
import '../services/auth_service.dart';
import 'patient_dashboard_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({
    super.key,
    required this.authService,
    required this.tokenStorage,
    this.onLoggedOut,
  });

  final AuthService authService;
  final TokenStorage tokenStorage;
  final VoidCallback? onLoggedOut;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Map<String, dynamic>? _userInfo;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final userInfo = await widget.tokenStorage.readUserInfo();
    if (!mounted) return;
    setState(() {
      _userInfo = userInfo;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _loggingOut = true;
    });
    try {
      await widget.authService.logout();
      if (!mounted) return;
      widget.onLoggedOut?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_userInfo == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = _userInfo?['name']?.toString() ?? 'User';
    final email = _userInfo?['email']?.toString() ?? '-';
    final role = (_userInfo?['role']?.toString() ?? 'user').toLowerCase();

    if (role == 'patient') {
      return PatientDashboardView(
        userInfo: _userInfo,
        onLogout: () => _logout(),
        loggingOut: _loggingOut,
      );
    }

    final title = '${_capitalize(role)} Dashboard';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _loggingOut ? null : _logout,
            icon: _loggingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, $name',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text('Email: $email'),
            const SizedBox(height: 8),
            Text('Role: $role'),
          ],
        ),
      ),
    );
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}
