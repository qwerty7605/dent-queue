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

  static const Color _buttonPrimary = Color(0xFF356042);
  static const Color _buttonPrimaryHover = Color(0xFF2C5238);
  static const Color _buttonPrimaryPressed = Color(0xFF24442E);
  static const Color _buttonSecondary = Color(0xFFE5EFE1);
  static const Color _buttonOutline = Color(0xFF4E7A57);
  static const Color _buttonDisabled = Color(0xFFD5DED1);
  static const double _buttonHeight = 48;
  static const double _buttonRadius = 12;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.nunitoTextTheme();
    final baseScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB));
    final colorScheme = baseScheme.copyWith(
      primary: _buttonPrimary,
      onPrimary: Colors.white,
      secondary: _buttonSecondary,
      onSecondary: const Color(0xFF163321),
      outline: _buttonOutline,
      surfaceContainerHighest: const Color(0xFFF1F5F2),
    );

    return MaterialApp(
      title: 'Frontend',
      theme: ThemeData(
        colorScheme: colorScheme,
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
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _primaryButtonStyle(colorScheme),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: _primaryButtonStyle(colorScheme),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _outlinedButtonStyle(colorScheme),
        ),
        textButtonTheme: TextButtonThemeData(
          style: _textButtonStyle(colorScheme),
        ),
      ),
      home: AuthSwitcherView(
        authService: authService,
        tokenStorage: tokenStorage,
      ),
    );
  }

  static ButtonStyle _primaryButtonStyle(ColorScheme colorScheme) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size.fromHeight(_buttonHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
      ),
      elevation: WidgetStateProperty.resolveWith<double>((states) {
        if (states.contains(WidgetState.disabled)) {
          return 0;
        }
        if (states.contains(WidgetState.pressed)) {
          return 0;
        }
        return 1;
      }),
      shadowColor: const WidgetStatePropertyAll<Color>(Color(0x1A163321)),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return _buttonDisabled;
        }
        if (states.contains(WidgetState.pressed)) {
          return _buttonPrimaryPressed;
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return _buttonPrimaryHover;
        }
        return colorScheme.primary;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white70;
        }
        return colorScheme.onPrimary;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.black.withValues(alpha: 0.08);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.white.withValues(alpha: 0.04);
        }
        return null;
      }),
    );
  }

  static ButtonStyle _outlinedButtonStyle(ColorScheme colorScheme) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size.fromHeight(_buttonHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
      ),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: _buttonDisabled, width: 1.25);
        }
        if (states.contains(WidgetState.pressed)) {
          return BorderSide(color: _buttonPrimaryPressed, width: 1.5);
        }
        return BorderSide(color: colorScheme.outline, width: 1.25);
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.transparent;
        }
        if (states.contains(WidgetState.pressed)) {
          return const Color(0xFFE2EBDF);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return const Color(0xFFF1F5F2);
        }
        return Colors.transparent;
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Color(0xFF8BA08D);
        }
        if (states.contains(WidgetState.pressed)) {
          return _buttonPrimaryPressed;
        }
        return colorScheme.primary;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.pressed)) {
          return colorScheme.primary.withValues(alpha: 0.08);
        }
        return null;
      }),
    );
  }

  static ButtonStyle _textButtonStyle(ColorScheme colorScheme) {
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(
        Size(0, _buttonHeight),
      ),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll<TextStyle>(
        GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
      ),
      shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_buttonRadius),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const Color(0xFF8BA08D);
        }
        if (states.contains(WidgetState.pressed)) {
          return _buttonPrimaryPressed;
        }
        return colorScheme.primary;
      }),
      overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return colorScheme.primary.withValues(alpha: 0.06);
        }
        if (states.contains(WidgetState.pressed)) {
          return colorScheme.primary.withValues(alpha: 0.1);
        }
        return null;
      }),
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
