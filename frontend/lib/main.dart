import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'core/api_exception.dart';
import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/config.dart';
import 'core/token_storage.dart';
import 'services/base_service.dart';
import 'services/http_auth_service.dart';
import 'views/dashboard_view.dart';
import 'views/login_view.dart';
import 'views/register_view.dart';
import 'views/start_page_view.dart';

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
    return MaterialApp(
      title: 'SmartDentQueue',
      theme: buildSmartDentTheme(brightness: Brightness.light),
      darkTheme: buildSmartDentTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.light,
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
  String? _startupError;

  _AuthPage get _signedOutPage => kIsWeb ? _AuthPage.login : _AuthPage.start;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final String? token = await widget.tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _page = _signedOutPage;
        _startupError = null;
      });
      return;
    }

    try {
      await widget.authService.me();
      if (!mounted) return;
      setState(() {
        _page = _AuthPage.dashboard;
        _startupError = null;
      });
    } on ApiException {
      await widget.tokenStorage.clear();
      if (!mounted) return;
      setState(() {
        _page = _signedOutPage;
        _startupError =
            'Unable to reconnect to the server. Please sign in again.';
      });
    } catch (error, stackTrace) {
      debugPrint('Auto-login failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      await widget.tokenStorage.clear();
      if (!mounted) return;
      setState(() {
        _page = _signedOutPage;
        _startupError =
            'Unable to reach the server right now. Check your connection and try again.';
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
            _page = _signedOutPage;
          });
        },
      );
    }

    if (_page == _AuthPage.start) {
      return StartPageView(
        message: _startupError,
        onGetStarted: () {
          setState(() {
            _page = _AuthPage.login;
            _startupError = null;
          });
        },
      );
    }

    if (_page == _AuthPage.login) {
      return LoginView(
        authService: widget.authService,
        showRegisterPrompt: !kIsWeb,
        onSwitchToRegister: () {
          setState(() {
            _page = _AuthPage.register;
            _startupError = null;
          });
        },
        onLoginSuccess: () {
          setState(() {
            _page = _AuthPage.dashboard;
            _startupError = null;
          });
        },
      );
    }

    return RegisterView(
      authService: widget.authService,
      onSwitchToLogin: () {
        setState(() {
          _page = _AuthPage.login;
          _startupError = null;
        });
      },
      onRegisterSuccess: () {
        setState(() {
          _page = _AuthPage.dashboard;
          _startupError = null;
        });
      },
    );
  }
}
