import 'package:flutter/material.dart';

/// Brand palette — the single source of truth for colour.
///
/// Every widget reads colour from here or from `Theme.of(context).colorScheme`,
/// never from a literal. Changing the brand means editing this file.
abstract final class AppColors {
  // Brand ramp, darkest to lightest.
  static const Color burgundyNight = Color(0xFF4E0011);
  static const Color burgundyDeep = Color(0xFF7A001B);

  /// Primary brand colour from the product brief.
  static const Color burgundy = Color(0xFFA50024);

  /// Secondary — the brighter "blood red" used in gradients and accents.
  static const Color bloodRed = Color(0xFFD7263D);

  /// Accent tint for chips, highlights and soft fills.
  static const Color lightPink = Color(0xFFFBE7EC);

  /// Muted rose, for secondary iconography on brand surfaces.
  static const Color rose = Color(0xFFE8A1B0);

  // Surfaces.
  static const Color cream = Color(0xFFFBF7F2);
  static const Color card = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFEFE4DA);
  static const Color outlineStrong = Color(0xFFE0D2C6);

  // Text.
  static const Color charcoal = Color(0xFF2B2622);
  static const Color muted = Color(0xFF7B6F67);
  static const Color onBrand = Color(0xFFFFFBF8);

  // Status. Deliberately distinct from brand red so "error" never reads as
  // "brand" — critical when a red card could mean either.
  static const Color success = Color(0xFF1B7F3B);
  static const Color warning = Color(0xFFC07A12);
  static const Color danger = Color(0xFFB3261E);

  // Shadows are baked into const values so elevation tokens stay const.
  static const Color shadowSoft = Color(0x0F2B2622);
  static const Color shadowMedium = Color(0x142B2622);
  static const Color shadowBrand = Color(0x33A50024);

  static const LinearGradient brandGradient = LinearGradient(
    colors: <Color>[burgundy, bloodRed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Deep ramp for hero surfaces that sit behind a light mark. Starts at
  /// [burgundyDeep] rather than [burgundyNight] so the surface still reads as
  /// burgundy on a cream page instead of collapsing towards black.
  static const LinearGradient deepGradient = LinearGradient(
    colors: <Color>[burgundyDeep, burgundy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dropGradient = LinearGradient(
    colors: <Color>[bloodRed, burgundy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
