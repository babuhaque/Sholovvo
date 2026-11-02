import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/tokens/app_colors.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/tokens/app_typography.dart';

void main() {
  group('AppTheme.light', () {
    final ThemeData theme = AppTheme.light;

    test('uses the brand burgundy as primary', () {
      expect(theme.colorScheme.primary, AppColors.burgundy);
      expect(theme.colorScheme.onPrimary, AppColors.onBrand);
    });

    test('uses soft cream as the scaffold background', () {
      expect(theme.scaffoldBackgroundColor, AppColors.cream);
    });

    test('uses charcoal for body text rather than pure black', () {
      expect(theme.colorScheme.onSurface, AppColors.charcoal);
      expect(theme.textTheme.bodyLarge?.color, AppColors.charcoal);
    });

    test('ships the token type scale', () {
      expect(theme.textTheme.displaySmall?.fontSize, 28);
      expect(theme.textTheme.bodyLarge?.fontSize, 16);
      expect(
        theme.textTheme.displayLarge?.fontWeight,
        AppTypography.textThemeFor(
          SolovvoPalette.light,
        ).displayLarge?.fontWeight,
      );
    });

    test('keeps error visually distinct from the brand red', () {
      expect(theme.colorScheme.error, AppColors.danger);
      expect(theme.colorScheme.error, isNot(AppColors.burgundy));
    });

    test('carries the light palette as a theme extension', () {
      expect(theme.extension<SolovvoPalette>(), SolovvoPalette.light);
      expect(theme.brightness, Brightness.light);
    });
  });

  group('AppTheme.dark', () {
    final ThemeData theme = AppTheme.dark;
    const SolovvoPalette palette = SolovvoPalette.dark;

    test('is actually dark and flips the surfaces', () {
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, palette.background);
      // A dark page must not be the cream one with grey text on it.
      expect(theme.scaffoldBackgroundColor, isNot(AppColors.cream));
      expect(palette.surface, isNot(AppColors.card));
    });

    test('swaps the brand ink for a rose that reads on charcoal', () {
      // The raw burgundy on #14100F is roughly 2:1, far below any readable
      // ratio, so the dark theme must not simply reuse it.
      expect(theme.colorScheme.primary, isNot(AppColors.burgundy));
      expect(theme.colorScheme.primary, palette.brandInk);
    });

    test('keeps status colours readable, not the light-theme values', () {
      expect(theme.colorScheme.error, isNot(AppColors.danger));
      expect(palette.success, isNot(AppColors.success));
      expect(palette.danger, isNot(AppColors.danger));
    });

    test('points body text at the light end of the ramp', () {
      expect(theme.textTheme.bodyLarge?.color, palette.textPrimary);
      expect(theme.colorScheme.onSurface, palette.textPrimary);
    });

    test('ships the dark palette as a theme extension', () {
      expect(theme.extension<SolovvoPalette>(), palette);
      expect(palette.isDark, isTrue);
    });
  });

  group('SolovvoPalette', () {
    test('lerp swaps the surfaces at the midpoint', () {
      final SolovvoPalette early = SolovvoPalette.light.lerp(
        SolovvoPalette.dark,
        0.2,
      );
      final SolovvoPalette late = SolovvoPalette.light.lerp(
        SolovvoPalette.dark,
        0.8,
      );

      expect(early.surface, isNot(SolovvoPalette.light.surface));
      expect(early.brightness, Brightness.light);
      expect(late.brightness, Brightness.dark);
      // Gradients snap rather than pass through a half-blended colour.
      expect(early.brandGradient, SolovvoPalette.light.brandGradient);
      expect(late.brandGradient, SolovvoPalette.dark.brandGradient);
    });

    test('copyWith leaves untouched roles alone', () {
      final SolovvoPalette next = SolovvoPalette.light.copyWith(
        danger: const Color(0xFF112233),
      );
      expect(next.danger, const Color(0xFF112233));
      expect(next.surface, SolovvoPalette.light.surface);
      expect(next.brandGradient, SolovvoPalette.light.brandGradient);
    });
  });

  group('tokens', () {
    test('spacing scale is strictly ascending on the 4pt grid', () {
      const List<double> scale = <double>[
        AppSpacing.xxs,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
        AppSpacing.xxxl,
        AppSpacing.huge,
      ];

      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
        expect(scale[i] % 4, 0);
      }
    });

    test('radius scale is ascending and pill is effectively circular', () {
      const List<double> scale = <double>[
        AppRadius.xs,
        AppRadius.sm,
        AppRadius.md,
        AppRadius.lg,
        AppRadius.xl,
      ];

      for (int i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
      expect(AppRadius.pill, greaterThan(AppRadius.xl));
      expect(AppRadius.pillRadius.topLeft.x, AppRadius.pill);
    });

    test('brand gradient runs from burgundy to blood red', () {
      expect(AppColors.brandGradient.colors.first, AppColors.burgundy);
      expect(AppColors.brandGradient.colors.last, AppColors.bloodRed);
    });
  });
}
