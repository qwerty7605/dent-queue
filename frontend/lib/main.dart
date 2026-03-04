import 'dart:io';
import 'package:flutter/material.dart';

import 'core/api_exception.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/token_storage.dart';
import 'services/base_service.dart';
import 'services/http_auth_service.dart';
import 'views/dashboard_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // pick network base URL based on running environment
  // default to emulator for development; adjust as needed for device or prod
  if (AppConfig.env == AppEnvironment.mock) {
    // avoid overriding if already set via --dart-define on build
    if (Platform.isAndroid) {
      AppConfig.env = AppEnvironment.androidEmulator;
    }
    // TODO: handle iOS simulator/provider if needed
  }

  final tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final baseService = BaseService(apiClient);
  final authService = HttpAuthService(baseService, tokenStorage);

  runApp(
    MyApp(
      authService: authService,
      tokenStorage: tokenStorage,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.authService,
    required this.tokenStorage,
  });

  final HttpAuthService authService;
  final TokenStorage tokenStorage;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frontend',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        textTheme: GoogleFonts.nunitoTextTheme(),
        fontFamily: GoogleFonts.nunito().fontFamily,
      ),
      home: AuthSwitcherView(
        authService: authService,
        tokenStorage: tokenStorage,
      ),
    );
  }
}

class AuthSwitcherView extends StatefulWidget {
  const AuthSwitcherView({
    super.key,
    required this.authService,
    required this.tokenStorage,
  });

  final HttpAuthService authService;
  final TokenStorage tokenStorage;

  @override
  State<AuthSwitcherView> createState() => _AuthSwitcherViewState();
}

enum _AuthPage { loading, login, register, dashboard }

class _AuthSwitcherViewState extends State<AuthSwitcherView> {
  _AuthPage _page = _AuthPage.loading;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final token = await widget.tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _page = _AuthPage.login;
      });
      return;
    }

    try {
      await widget.authService.me();
      if (!mounted) return;
      setState(() {
        _page = _AuthPage.dashboard;
      });
    } on ApiException {
      await widget.tokenStorage.clear();
      if (!mounted) return;
      setState(() {
        _page = _AuthPage.login;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_page == _AuthPage.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_page == _AuthPage.dashboard) {
      return DashboardView(
        authService: widget.authService,
        tokenStorage: widget.tokenStorage,
        onLoggedOut: () {
          setState(() {
            _page = _AuthPage.login;
          });
        },
      );
    }

    if (_page == _AuthPage.login) {
      return LoginView(
        authService: widget.authService,
        onSwitchToRegister: () {
          setState(() {
            _page = _AuthPage.register;
          });
        },
        onLoginSuccess: () {
          setState(() {
            _page = _AuthPage.dashboard;
          });
        },
      );
    }

    return RegisterView(
      authService: widget.authService,
      onSwitchToLogin: () {
        setState(() {
          _page = _AuthPage.login;
        });
      },
      onRegisterSuccess: () {
        setState(() {
          _page = _AuthPage.dashboard;
        });
      },
    );
  }
}
