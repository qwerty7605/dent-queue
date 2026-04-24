import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const Color _buttonPrimary = Color(0xFFF59E0B);
const Color _buttonPrimaryHover = Color(0xFFD97706);
const Color _buttonPrimaryPressed = Color(0xFFB45309);
const Color _buttonSecondaryLight = Color(0xFFE1E9FF);
const Color _buttonSecondaryDark = Color(0xFF24324B);
const Color _buttonOutlineLight = Color(0xFF9CB5E8);
const Color _buttonOutlineDark = Color(0xFF4C618E);
const Color _buttonDisabledLight = Color(0xFFCFD6E6);
const Color _buttonDisabledDark = Color(0xFF34415C);
const double _buttonHeight = 48;
const double _buttonRadius = 12;

ThemeData buildSmartDentTheme({required Brightness brightness}) {
  final bool isDark = brightness == Brightness.dark;
  final TextTheme baseTextTheme = GoogleFonts.poppinsTextTheme(
    ThemeData(brightness: brightness).textTheme,
  );
  final ColorScheme seededScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1A2F64),
    brightness: brightness,
  );
  final ColorScheme colorScheme = seededScheme.copyWith(
    primary: _buttonPrimary,
    onPrimary: const Color(0xFF1E293B),
    secondary: isDark ? _buttonSecondaryDark : _buttonSecondaryLight,
    onSecondary: isDark ? const Color(0xFFEAF1FF) : const Color(0xFF0A1833),
    surface: isDark ? const Color(0xFF141C2E) : Colors.white,
    onSurface: isDark ? const Color(0xFFEAF1FF) : const Color(0xFF1D3264),
    surfaceContainerHighest: isDark
        ? const Color(0xFF1A253A)
        : const Color(0xFFEFF3FA),
    outline: isDark ? _buttonOutlineDark : _buttonOutlineLight,
    onSurfaceVariant: isDark
        ? const Color(0xFFAAB8D4)
        : const Color(0xFF64748B),
  );

  final TextTheme textTheme = baseTextTheme
      .copyWith(
        headlineMedium: baseTextTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: colorScheme.onSurface,
        ),
        titleLarge: baseTextTheme.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        titleMedium: baseTextTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        bodyLarge: baseTextTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.45,
          color: colorScheme.onSurface,
        ),
        bodyMedium: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 15,
          height: 1.45,
          color: colorScheme.onSurface,
        ),
        bodySmall: baseTextTheme.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.4,
          color: colorScheme.onSurfaceVariant,
        ),
        labelLarge: baseTextTheme.labelLarge?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: colorScheme.onSurface,
        ),
        labelMedium: baseTextTheme.labelMedium?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
        ),
        labelSmall: baseTextTheme.labelSmall?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurfaceVariant,
        ),
      )
      .apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      );

  return ThemeData(
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark
        ? const Color(0xFF0C1220)
        : const Color(0xFFF3F6FC),
    canvasColor: isDark ? const Color(0xFF0C1220) : const Color(0xFFF3F6FC),
    cardColor: colorScheme.surface,
    dividerColor: colorScheme.outline,
    useMaterial3: true,
    textTheme: textTheme,
    fontFamily: GoogleFonts.poppins().fontFamily,
    iconTheme: IconThemeData(color: colorScheme.onSurface),
    primaryIconTheme: IconThemeData(color: colorScheme.onSurface),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: _primaryButtonStyle(colorScheme, isDark),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: _primaryButtonStyle(colorScheme, isDark),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: _outlinedButtonStyle(colorScheme, isDark),
    ),
    textButtonTheme: TextButtonThemeData(
      style: _textButtonStyle(colorScheme, isDark),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1A253A) : Colors.white,
      hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      prefixIconColor: colorScheme.onSurfaceVariant,
      suffixIconColor: colorScheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? _buttonDisabledDark : _buttonDisabledLight,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      surfaceTintColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    ),
  );
}

ButtonStyle _primaryButtonStyle(ColorScheme colorScheme, bool isDark) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, _buttonHeight)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle>(
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800),
    ),
    shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    ),
    elevation: WidgetStateProperty.resolveWith<double>((states) {
      if (states.contains(WidgetState.disabled) ||
          states.contains(WidgetState.pressed)) {
        return 0;
      }
      return 1;
    }),
    shadowColor: WidgetStatePropertyAll<Color>(
      isDark ? const Color(0x40000000) : const Color(0x1A163321),
    ),
    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return isDark ? _buttonDisabledDark : _buttonDisabledLight;
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
        return isDark ? const Color(0xFF93A3C3) : const Color(0x661E293B);
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

ButtonStyle _outlinedButtonStyle(ColorScheme colorScheme, bool isDark) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, _buttonHeight)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle>(
      GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800),
    ),
    shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    ),
    side: WidgetStateProperty.resolveWith<BorderSide>((states) {
      if (states.contains(WidgetState.disabled)) {
        return BorderSide(
          color: isDark ? _buttonDisabledDark : _buttonDisabledLight,
          width: 1.25,
        );
      }
      if (states.contains(WidgetState.pressed)) {
        return const BorderSide(color: _buttonPrimaryPressed, width: 1.5);
      }
      return BorderSide(color: colorScheme.outline, width: 1.25);
    }),
    backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return Colors.transparent;
      }
      if (states.contains(WidgetState.pressed)) {
        return isDark ? const Color(0xFF202D44) : const Color(0xFFD8E1F8);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return isDark ? const Color(0xFF1A253A) : const Color(0xFFEFF3FA);
      }
      return Colors.transparent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return isDark ? const Color(0xFF7584A4) : const Color(0xFF94A1C8);
      }
      if (states.contains(WidgetState.pressed)) {
        return _buttonPrimaryPressed;
      }
      return isDark ? const Color(0xFFEAF1FF) : colorScheme.primary;
    }),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: 0.08);
      }
      return null;
    }),
  );
}

ButtonStyle _textButtonStyle(ColorScheme colorScheme, bool isDark) {
  return ButtonStyle(
    minimumSize: const WidgetStatePropertyAll<Size>(Size(0, _buttonHeight)),
    padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
      EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    ),
    textStyle: WidgetStatePropertyAll<TextStyle>(
      GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800),
    ),
    shape: WidgetStatePropertyAll<RoundedRectangleBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_buttonRadius),
      ),
    ),
    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return isDark ? const Color(0xFF7584A4) : const Color(0xFF94A1C8);
      }
      if (states.contains(WidgetState.pressed)) {
        return _buttonPrimaryPressed;
      }
      return isDark ? const Color(0xFFEAF1FF) : colorScheme.primary;
    }),
    overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.06);
      }
      if (states.contains(WidgetState.pressed)) {
        return colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.1);
      }
      return null;
    }),
  );
}
