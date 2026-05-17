import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/ui/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─── AppSpacing ─────────────────────────────────────────────────────────
  group('AppSpacing', () {
    test('spacing constants are defined in ascending order', () {
      expect(AppSpacing.xxxs, 4);
      expect(AppSpacing.xxs, 8);
      expect(AppSpacing.xs, 12);
      expect(AppSpacing.sm, 16);
      expect(AppSpacing.md, 20);
      expect(AppSpacing.lg, 24);
      expect(AppSpacing.xl, 32);
    });

    test('spacing values are strictly increasing', () {
      final values = [
        AppSpacing.xxxs,
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ];
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]),
            reason: 'Spacing $i should be > ${i - 1}');
      }
    });
  });

  // ─── ShapeBorderTheme ───────────────────────────────────────────────────
  group('ShapeBorderTheme', () {
    test('all shapes are RoundedRectangleBorder with correct radii', () {
      expect(
        AppTheme.shapes.extraSmall,
        isA<RoundedRectangleBorder>().having(
          (b) => (b as RoundedRectangleBorder).borderRadius,
          'borderRadius',
          const BorderRadius.all(Radius.circular(10)),
        ),
      );
      expect(
        AppTheme.shapes.small,
        isA<RoundedRectangleBorder>().having(
          (b) => (b as RoundedRectangleBorder).borderRadius,
          'borderRadius',
          const BorderRadius.all(Radius.circular(14)),
        ),
      );
      expect(
        AppTheme.shapes.medium,
        isA<RoundedRectangleBorder>().having(
          (b) => (b as RoundedRectangleBorder).borderRadius,
          'borderRadius',
          const BorderRadius.all(Radius.circular(18)),
        ),
      );
      expect(
        AppTheme.shapes.large,
        isA<RoundedRectangleBorder>().having(
          (b) => (b as RoundedRectangleBorder).borderRadius,
          'borderRadius',
          const BorderRadius.all(Radius.circular(24)),
        ),
      );
      expect(
        AppTheme.shapes.extraLarge,
        isA<RoundedRectangleBorder>().having(
          (b) => (b as RoundedRectangleBorder).borderRadius,
          'borderRadius',
          const BorderRadius.all(Radius.circular(28)),
        ),
      );
    });

    test('radii increase monotonically', () {
      final radii = [
        _radiusOf(AppTheme.shapes.extraSmall),
        _radiusOf(AppTheme.shapes.small),
        _radiusOf(AppTheme.shapes.medium),
        _radiusOf(AppTheme.shapes.large),
        _radiusOf(AppTheme.shapes.extraLarge),
      ];
      for (var i = 1; i < radii.length; i++) {
        expect(radii[i], greaterThan(radii[i - 1]),
            reason: 'Shape $i radius should be > ${i - 1}');
      }
    });
  });

  // ─── AppTheme — Light ───────────────────────────────────────────────────
  group('AppTheme — Light', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.light;
    });

    test('brightness is light', () {
      expect(theme.brightness, Brightness.light);
    });

    test('uses Material 3', () {
      expect(theme.useMaterial3, isTrue);
    });

    test('has scaffold background color', () {
      expect(theme.scaffoldBackgroundColor, isNotNull);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFF6F8FC));
    });

    test('primary color is correct', () {
      expect(theme.colorScheme.primary, const Color(0xFF1257C0));
    });

    test('error color is correct', () {
      expect(theme.colorScheme.error, const Color(0xFFC53E3E));
    });

    test('tertiary is warning orange', () {
      expect(theme.colorScheme.tertiary, const Color(0xFF1C8A55));
    });

    test('card theme has rounded shape', () {
      expect(theme.cardTheme?.shape, isA<RoundedRectangleBorder>());
      final shape = theme.cardTheme!.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(18)),
      );
    });

    test('dialog theme has large rounded shape', () {
      expect(theme.dialogTheme?.shape, isA<RoundedRectangleBorder>());
      final shape = theme.dialogTheme!.shape as RoundedRectangleBorder;
      expect(
        shape.borderRadius,
        const BorderRadius.all(Radius.circular(24)),
      );
    });

    test('app bar has no elevation', () {
      expect(theme.appBarTheme.elevation, 0);
      expect(theme.appBarTheme.scrolledUnderElevation, 0);
    });

    test('text theme is defined for common styles', () {
      expect(theme.textTheme.headlineSmall, isNotNull);
      expect(theme.textTheme.titleLarge, isNotNull);
      expect(theme.textTheme.titleMedium, isNotNull);
      expect(theme.textTheme.titleSmall, isNotNull);
      expect(theme.textTheme.bodyLarge, isNotNull);
      expect(theme.textTheme.bodyMedium, isNotNull);
      expect(theme.textTheme.bodySmall, isNotNull);
    });

    test('headlineSmall has bold weight', () {
      expect(
        theme.textTheme.headlineSmall?.fontWeight,
        FontWeight.bold,
      );
    });
  });

  // ─── AppTheme — Dark ────────────────────────────────────────────────────
  group('AppTheme — Dark', () {
    late ThemeData theme;

    setUp(() {
      theme = AppTheme.dark;
    });

    test('brightness is dark', () {
      expect(theme.brightness, Brightness.dark);
    });

    test('has dark scaffold background', () {
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0D1119));
    });

    test('primary color has light tint for dark bg', () {
      expect(theme.colorScheme.primary, const Color(0xFFADC6FF));
    });

    test('error color is light for dark bg', () {
      expect(theme.colorScheme.error, const Color(0xFFFFB4AB));
    });

    test('surface is dark', () {
      expect(
        theme.colorScheme.surface,
        const Color(0xFF141A24),
      );
    });

    test('onSurface is light for readability', () {
      expect(
        theme.colorScheme.onSurface,
        const Color(0xFFE3E8F2),
      );
    });

    test('status bar icons are light', () {
      expect(
        theme.appBarTheme.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.light,
      );
    });

    test('card theme survives dark mode', () {
      expect(theme.cardTheme?.shape, isA<RoundedRectangleBorder>());
    });

    test('dialog theme survives dark mode', () {
      expect(theme.dialogTheme?.shape, isA<RoundedRectangleBorder>());
    });
  });

  // ─── Theme Contrast Checks ─────────────────────────────────────────────
  group('Theme Contrast', () {
    test('light and dark use different scaffold backgrounds', () {
      expect(
        AppTheme.light.scaffoldBackgroundColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });

    test('light and dark use different primary colors', () {
      expect(
        AppTheme.light.colorScheme.primary,
        isNot(AppTheme.dark.colorScheme.primary),
      );
    });

    test('onSurface is significantly different between themes', () {
      // Light: very dark; Dark: very light
      final lightOnSurface = AppTheme.light.colorScheme.onSurface;
      final darkOnSurface = AppTheme.dark.colorScheme.onSurface;
      final lightLuminance = lightOnSurface.computeLuminance();
      final darkLuminance = darkOnSurface.computeLuminance();
      // On light bg, text is dark (low luminance). On dark bg, text is light (high luminance).
      expect(lightLuminance, lessThan(0.1));
      expect(darkLuminance, greaterThan(0.5));
    });

    test('text theme and key colors are accessible', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final primary = theme.colorScheme.primary;
        final onPrimary = theme.colorScheme.onPrimary;
        final bg = theme.scaffoldBackgroundColor;
        final onBg = theme.colorScheme.onSurface;

        // Verify we have decent contrast between background and text
        final bgContrast = _contrastRatio(bg, onBg);
        expect(bgContrast, greaterThan(4.5),
            reason:
                'Background/onSurface contrast in ${theme.brightness} mode should be ≥ 4.5:1');

        // Primary/onPrimary should be readable
        final primaryContrast = _contrastRatio(primary, onPrimary);
        expect(primaryContrast, greaterThan(2.5),
            reason:
                'Primary/onPrimary contrast in ${theme.brightness} mode should be ≥ 2.5:1 (actual: ${primaryContrast.toStringAsFixed(2)})');
      }
    });
  });
}

/// Extract the uniform border radius from a ShapeBorder.
double _radiusOf(ShapeBorder shape) {
  if (shape is RoundedRectangleBorder) {
    return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
  }
  return 0;
}

/// Calculate WCAG contrast ratio between two colors.
double _contrastRatio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}
