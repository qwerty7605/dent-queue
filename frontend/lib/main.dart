import 'package:flutter/foundation.dart';
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
import 'views/start_page_view.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) {
    debugPrint('API env=${AppConfig.env.name} baseUrl=${AppConfig.baseUrl}');
  }

  final tokenStorage = SecureTokenStorage();
  final apiClient = ApiClient(tokenStorage: tokenStorage);
  final baseService = BaseService(apiClient);
  final authService = HttpAuthService(baseService, tokenStorage);

  runApp(MyApp(authService: authService, tokenStorage: tokenStorage));
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
    final baseTextTheme = GoogleFonts.nunitoTextTheme();

    return MaterialApp(
      title: 'Frontend',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        textTheme: baseTextTheme.copyWith(
          headlineMedium: baseTextTheme.headlineMedium?.copyWith(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(
            fontSize: 16,
            height: 1.45,
          ),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.45,
          ),
          bodySmall: baseTextTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.4,
          ),
          labelLarge: baseTextTheme.labelLarge?.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          labelMedium: baseTextTheme.labelMedium?.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          labelSmall: baseTextTheme.labelSmall?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
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

enum _AuthPage { loading, start, login, register, dashboard }

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
        _page = _AuthPage.start;
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
        _page = _AuthPage.start;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_page == _AuthPage.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_page == _AuthPage.dashboard) {
      return DashboardView(
        authService: widget.authService,
        tokenStorage: widget.tokenStorage,
        onLoggedOut: () {
          setState(() {
            _page = _AuthPage.start;
          });
        },
      );
    }

    if (_page == _AuthPage.start) {
      return StartPageView(
        onGetStarted: () {
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
