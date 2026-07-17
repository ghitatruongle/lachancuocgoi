import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Spacing ───────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();
  static const double xxxs = 4;
  static const double xxs = 8;
  static const double xs = 12;
  static const double sm = 16;
  static const double md = 20;
  static const double lg = 24;
  static const double xl = 32;
}

// ─── BorderRadius ──────────────────────────────────────────────────────
class AppBorderRadius {
  AppBorderRadius._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

// ─── Light Colors ──────────────────────────────────────────────────────
const _lightPrimary = Color(0xFF1257C0);
const _lightOnPrimary = Color(0xFFFFFFFF);
const _lightPrimaryContainer = Color(0xFFD9E2FF);
const _lightOnPrimaryContainer = Color(0xFF001944);
const _lightSecondary = Color(0xFF4B5B7A);
const _lightOnSecondary = Color(0xFFFFFFFF);
const _lightSecondaryContainer = Color(0xFFEFF3FB);
const _lightOnSecondaryContainer = Color(0xFF24364F);
const _lightTertiary = Color(0xFF1C8A55);
const _lightOnTertiary = Color(0xFFFFFFFF);
const _lightBackground = Color(0xFFF6F8FC);
const _lightSurface = Color(0xFFFFFFFF);
const _lightOnSurface = Color(0xFF121826);
const _lightSurfaceVariant = Color(0xFFE8EDF5);
const _lightOnSurfaceVariant = Color(0xFF465366);
const _lightOutline = Color(0xFF748297);
const _lightError = Color(0xFFC53E3E);
const _lightOnError = Color(0xFFFFFFFF);
const _lightErrorContainer = Color(0xFFFFE1E0);
const _lightOnErrorContainer = Color(0xFF410002);
const _lightWarningContainer = Color(0xFFFFE8C4);
const _lightOnWarningContainer = Color(0xFF513A00);

// ─── Dark Colors ───────────────────────────────────────────────────────
const _darkPrimary = Color(0xFFADC6FF);
const _darkOnPrimary = Color(0xFF002C71);
const _darkPrimaryContainer = Color(0xFF00419F);
const _darkOnPrimaryContainer = Color(0xFFD9E2FF);
const _darkSecondary = Color(0xFFB3C4E6);
const _darkOnSecondary = Color(0xFF1C2D49);
const _darkSecondaryContainer = Color(0xFF203047);
const _darkOnSecondaryContainer = Color(0xFFD9E2FF);
const _darkTertiary = Color(0xFF84E0AE);
const _darkOnTertiary = Color(0xFF003920);
const _darkBackground = Color(0xFF0D1119);
const _darkSurface = Color(0xFF141A24);
const _darkOnSurface = Color(0xFFE3E8F2);
const _darkSurfaceVariant = Color(0xFF222B38);
const _darkOnSurfaceVariant = Color(0xFFBDC7D8);
const _darkOutline = Color(0xFF8E99AB);
const _darkError = Color(0xFFFFB4AB);
const _darkOnError = Color(0xFF690005);
const _darkErrorContainer = Color(0xFF93000A);
const _darkOnErrorContainer = Color(0xFFFFDAD6);
const _darkWarningContainer = Color(0xFF5D4300);
const _darkOnWarningContainer = Color(0xFFFFDEA0);

// ─── Color Schemes ─────────────────────────────────────────────────────
const _lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: _lightPrimary,
  onPrimary: _lightOnPrimary,
  primaryContainer: _lightPrimaryContainer,
  onPrimaryContainer: _lightOnPrimaryContainer,
  secondary: _lightSecondary,
  onSecondary: _lightOnSecondary,
  secondaryContainer: _lightSecondaryContainer,
  onSecondaryContainer: _lightOnSecondaryContainer,
  tertiary: _lightTertiary,
  onTertiary: _lightOnTertiary,
  tertiaryContainer: _lightWarningContainer,
  onTertiaryContainer: _lightOnWarningContainer,
  error: _lightError,
  onError: _lightOnError,
  errorContainer: _lightErrorContainer,
  onErrorContainer: _lightOnErrorContainer,
  surface: _lightSurface,
  onSurface: _lightOnSurface,
  surfaceContainerHighest: _lightSurfaceVariant,
  onSurfaceVariant: _lightOnSurfaceVariant,
  outline: _lightOutline,
);

const _darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: _darkPrimary,
  onPrimary: _darkOnPrimary,
  primaryContainer: _darkPrimaryContainer,
  onPrimaryContainer: _darkOnPrimaryContainer,
  secondary: _darkSecondary,
  onSecondary: _darkOnSecondary,
  secondaryContainer: _darkSecondaryContainer,
  onSecondaryContainer: _darkOnSecondaryContainer,
  tertiary: _darkTertiary,
  onTertiary: _darkOnTertiary,
  tertiaryContainer: _darkWarningContainer,
  onTertiaryContainer: _darkOnWarningContainer,
  error: _darkError,
  onError: _darkOnError,
  errorContainer: _darkErrorContainer,
  onErrorContainer: _darkOnErrorContainer,
  surface: _darkSurface,
  onSurface: _darkOnSurface,
  surfaceContainerHighest: _darkSurfaceVariant,
  onSurfaceVariant: _darkOnSurfaceVariant,
  outline: _darkOutline,
);

// ─── Typography ────────────────────────────────────────────────────────
const _appTypography = TextTheme(
  headlineSmall: TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 28,
    height: 34 / 28,
    letterSpacing: -0.2,
  ),
  titleLarge: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 22,
    height: 28 / 22,
  ),
  titleMedium: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 24 / 18,
  ),
  titleSmall: TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 15,
    height: 20 / 15,
  ),
  bodyLarge: TextStyle(
    fontWeight: FontWeight.normal,
    fontSize: 16,
    height: 24 / 16,
  ),
  bodyMedium: TextStyle(
    fontWeight: FontWeight.normal,
    fontSize: 14,
    height: 20 / 14,
  ),
  bodySmall: TextStyle(
    fontWeight: FontWeight.normal,
    fontSize: 12,
    height: 18 / 12,
  ),
  labelLarge: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.1,
  ),
  labelMedium: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.3,
  ),
  labelSmall: TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 11,
    height: 16 / 11,
    letterSpacing: 0.5,
  ),
);

// ─── Shapes ────────────────────────────────────────────────────────────
const _appShapes = ShapeBorderTheme(
  extraSmall: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(10)),
  ),
  small: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
  ),
  medium: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(18)),
  ),
  large: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(24)),
  ),
  extraLarge: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(28)),
  ),
);

/// Custom shape holder since Flutter doesn't expose all shape slots directly.
class ShapeBorderTheme {
  const ShapeBorderTheme({
    required this.extraSmall,
    required this.small,
    required this.medium,
    required this.large,
    required this.extraLarge,
  });
  final ShapeBorder extraSmall;
  final ShapeBorder small;
  final ShapeBorder medium;
  final ShapeBorder large;
  final ShapeBorder extraLarge;
}

// ─── Theme Data ────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static final ThemeData light = _build(_lightColorScheme);
  static final ThemeData dark = _build(_darkColorScheme);

  static ThemeData _build(ColorScheme colorScheme) {
    final bool isDark = colorScheme.brightness == Brightness.dark;
    final Color background = isDark ? _darkBackground : _lightBackground;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      textTheme: _appTypography,
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  /// Access shape definitions outside of ThemeData.
  static const ShapeBorderTheme shapes = _appShapes;
}
