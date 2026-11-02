import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';

/// Type scale.
///
/// Sizes, weights and tracking only — colour is applied per theme by
/// [textThemeFor], because a scale baked with charcoal text renders invisible on
/// the dark theme. The face itself is the platform default (Roboto on Android,
/// SF on iOS). No font is bundled: both platforms ship Bengali coverage
/// (Noto Sans Bengali, Kohinoor Bangla), so a bundled face would add megabytes
/// to change glyph shapes nobody asked about. The trade-off is documented in
/// `docs/ARCHITECTURE.md`: line metrics differ slightly between the two, which
/// is why every style pins its own `height`.
abstract final class AppTypography {
  static const TextTheme _base = TextTheme(
    displayLarge: TextStyle(
      fontSize: 40,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
    ),
    displayMedium: TextStyle(
      fontSize: 34,
      height: 1.15,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.6,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.4,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      height: 1.25,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
    ),
    headlineSmall: TextStyle(
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.55, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.55,
      fontWeight: FontWeight.w400,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      height: 1.5,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.6,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.2,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );

  /// The scale with [SolovvoPalette] colours applied.
  ///
  /// Headings and labels take the primary text colour; body copy and the small
  /// caps labels take the secondary one, which is the hierarchy the whole app is
  /// built on.
  static TextTheme textThemeFor(SolovvoPalette palette) {
    final TextTheme themed = _base.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    );
    return themed.copyWith(
      bodyMedium: themed.bodyMedium?.copyWith(color: palette.textSecondary),
      bodySmall: themed.bodySmall?.copyWith(color: palette.textSecondary),
      labelMedium: themed.labelMedium?.copyWith(color: palette.textSecondary),
      labelSmall: themed.labelSmall?.copyWith(color: palette.textSecondary),
    );
  }

  /// Wordmark styling: wide tracking so "Solovvo" reads as a logotype.
  static TextStyle wordmark(SolovvoPalette palette) => TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: palette.brandInk,
  );
}
