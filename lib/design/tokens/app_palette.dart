import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_colors.dart';

/// Semantic colour roles for one theme.
///
/// `AppColors` stays the raw brand ramp — burgundy is burgundy in every theme.
/// Everything that *changes* with the theme (a page that is cream by day and
/// near-black at night, a card that is white by day and charcoal at night) is a
/// role here, so a widget asks for "surface" instead of "white".
///
/// This is a [ThemeExtension] rather than a set of `switch (brightness)` helpers
/// for two reasons: the values interpolate when the theme animates, and a widget
/// that reads a role it forgot to define is a compile error rather than a
/// hard-coded colour someone has to notice.
@immutable
class SolovvoPalette extends ThemeExtension<SolovvoPalette> {
  const SolovvoPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.outline,
    required this.outlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.onBrand,
    required this.brandInk,
    required this.brandTint,
    required this.onBrandTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.glowTop,
    required this.glowBottom,
    required this.glowTopOpacity,
    required this.glowBottomOpacity,
    required this.shadowSoft,
    required this.shadowMedium,
    required this.shadowBrand,
    required this.brandGradient,
    required this.deepGradient,
    required this.dropGradient,
  });

  final Brightness brightness;

  /// Page background behind every screen.
  final Color background;

  /// Raised content: cards, filled text fields, sheets.
  final Color surface;

  /// Recessed or disabled fill, one step away from [surface].
  final Color surfaceMuted;

  final Color outline;
  final Color outlineStrong;

  /// Default text colour.
  final Color textPrimary;

  /// Supporting text, hints, labels and icons.
  final Color textSecondary;

  /// Text and icons drawn on the burgundy gradient.
  final Color onBrand;

  /// Brand colour used as *ink* on the page or a card: the wordmark, text
  /// buttons, links. In the dark theme the deep brand red is too dark to read,
  /// so it becomes a rose that still reads as brand.
  final Color brandInk;

  /// Soft brand wash used for chips and highlight cards.
  final Color brandTint;

  /// Text and icons on [brandTint]. Not `burgundy`: on a dark tint the deep
  /// brand red disappears, so the dark theme swaps in a rose that still reads as
  /// brand rather than as a different colour.
  final Color onBrandTint;

  // Status colours are brighter in the dark theme. The light-theme values are
  // dark greens and reds chosen to sit on white; on charcoal they fall below
  // readable contrast.
  final Color success;
  final Color warning;
  final Color danger;

  // The two radial glows behind the content. Opacities are per theme because a
  // 10% wash over cream is a different amount of light than 10% over charcoal.
  final Color glowTop;
  final Color glowBottom;
  final double glowTopOpacity;
  final double glowBottomOpacity;

  final Color shadowSoft;
  final Color shadowMedium;
  final Color shadowBrand;

  final LinearGradient brandGradient;
  final LinearGradient deepGradient;
  final LinearGradient dropGradient;

  bool get isDark => brightness == Brightness.dark;

  /// Resting card elevation.
  List<BoxShadow> get cardShadow => <BoxShadow>[
    BoxShadow(color: shadowSoft, blurRadius: 24, offset: const Offset(0, 10)),
  ];

  /// Floating surface, e.g. a sheet or the welcome medallion.
  List<BoxShadow> get floatingShadow => <BoxShadow>[
    BoxShadow(color: shadowMedium, blurRadius: 40, offset: const Offset(0, 18)),
  ];

  /// Brand-tinted glow under primary actions.
  List<BoxShadow> get brandShadow => <BoxShadow>[
    BoxShadow(color: shadowBrand, blurRadius: 24, offset: const Offset(0, 12)),
  ];

  static const SolovvoPalette light = SolovvoPalette(
    brightness: Brightness.light,
    background: AppColors.cream,
    surface: AppColors.card,
    surfaceMuted: AppColors.cream,
    outline: AppColors.outline,
    outlineStrong: AppColors.outlineStrong,
    textPrimary: AppColors.charcoal,
    textSecondary: AppColors.muted,
    onBrand: AppColors.onBrand,
    brandInk: AppColors.burgundy,
    brandTint: AppColors.lightPink,
    onBrandTint: AppColors.burgundyDeep,
    success: AppColors.success,
    warning: AppColors.warning,
    danger: AppColors.danger,
    glowTop: AppColors.burgundy,
    glowBottom: AppColors.rose,
    glowTopOpacity: 0.10,
    glowBottomOpacity: 0.14,
    shadowSoft: AppColors.shadowSoft,
    shadowMedium: AppColors.shadowMedium,
    shadowBrand: AppColors.shadowBrand,
    brandGradient: AppColors.brandGradient,
    deepGradient: AppColors.deepGradient,
    dropGradient: AppColors.dropGradient,
  );

  /// Warm charcoal rather than pure black, so the app reads as the same product
  /// at night instead of as a switched-off screen. The burgundy glows are
  /// slightly stronger because a dim accent on a dark page disappears.
  static const SolovvoPalette dark = SolovvoPalette(
    brightness: Brightness.dark,
    background: Color(0xFF14100F),
    surface: Color(0xFF1F1A18),
    surfaceMuted: Color(0xFF272120),
    outline: Color(0xFF372F2C),
    outlineStrong: Color(0xFF4A3F3A),
    textPrimary: Color(0xFFF7F0EA),
    textSecondary: Color(0xFFB6A79D),
    onBrand: AppColors.onBrand,
    brandInk: Color(0xFFF2A7B6),
    brandTint: Color(0xFF3A1620),
    onBrandTint: Color(0xFFFFB4C3),
    success: Color(0xFF57D68F),
    warning: Color(0xFFE9A93F),
    danger: Color(0xFFFF7A72),
    glowTop: AppColors.burgundy,
    glowBottom: AppColors.rose,
    glowTopOpacity: 0.22,
    glowBottomOpacity: 0.10,
    shadowSoft: Color(0x8C000000),
    shadowMedium: Color(0xA6000000),
    shadowBrand: Color(0x66A50024),
    brandGradient: AppColors.brandGradient,
    deepGradient: AppColors.deepGradient,
    dropGradient: AppColors.dropGradient,
  );

  @override
  SolovvoPalette copyWith({
    Brightness? brightness,
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? outline,
    Color? outlineStrong,
    Color? textPrimary,
    Color? textSecondary,
    Color? onBrand,
    Color? brandInk,
    Color? brandTint,
    Color? onBrandTint,
    Color? success,
    Color? warning,
    Color? danger,
    Color? glowTop,
    Color? glowBottom,
    double? glowTopOpacity,
    double? glowBottomOpacity,
    Color? shadowSoft,
    Color? shadowMedium,
    Color? shadowBrand,
    LinearGradient? brandGradient,
    LinearGradient? deepGradient,
    LinearGradient? dropGradient,
  }) {
    return SolovvoPalette(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      outline: outline ?? this.outline,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      onBrand: onBrand ?? this.onBrand,
      brandInk: brandInk ?? this.brandInk,
      brandTint: brandTint ?? this.brandTint,
      onBrandTint: onBrandTint ?? this.onBrandTint,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      glowTop: glowTop ?? this.glowTop,
      glowBottom: glowBottom ?? this.glowBottom,
      glowTopOpacity: glowTopOpacity ?? this.glowTopOpacity,
      glowBottomOpacity: glowBottomOpacity ?? this.glowBottomOpacity,
      shadowSoft: shadowSoft ?? this.shadowSoft,
      shadowMedium: shadowMedium ?? this.shadowMedium,
      shadowBrand: shadowBrand ?? this.shadowBrand,
      brandGradient: brandGradient ?? this.brandGradient,
      deepGradient: deepGradient ?? this.deepGradient,
      dropGradient: dropGradient ?? this.dropGradient,
    );
  }

  @override
  SolovvoPalette lerp(covariant SolovvoPalette? other, double t) {
    if (other == null) {
      return this;
    }
    // Gradients and shadow lists snap at the midpoint: interpolating a shadow
    // colour across a 200 ms theme change is invisible, and a half-lerped
    // gradient can pass through mud.
    final bool useOther = t >= 0.5;
    return SolovvoPalette(
      brightness: useOther ? other.brightness : brightness,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      brandInk: Color.lerp(brandInk, other.brandInk, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      onBrandTint: Color.lerp(onBrandTint, other.onBrandTint, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      glowTop: Color.lerp(glowTop, other.glowTop, t)!,
      glowBottom: Color.lerp(glowBottom, other.glowBottom, t)!,
      glowTopOpacity: lerpDouble(glowTopOpacity, other.glowTopOpacity, t),
      glowBottomOpacity: lerpDouble(
        glowBottomOpacity,
        other.glowBottomOpacity,
        t,
      ),
      shadowSoft: useOther ? other.shadowSoft : shadowSoft,
      shadowMedium: useOther ? other.shadowMedium : shadowMedium,
      shadowBrand: useOther ? other.shadowBrand : shadowBrand,
      brandGradient: useOther ? other.brandGradient : brandGradient,
      deepGradient: useOther ? other.deepGradient : deepGradient,
      dropGradient: useOther ? other.dropGradient : dropGradient,
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// `context.palette` — short enough to read inside a build method, and it falls
/// back to the light palette so a widget rendered outside the app's theme (a
/// test fixture, a preview) still draws rather than throwing.
extension SolovvoPaletteContext on BuildContext {
  SolovvoPalette get palette =>
      Theme.of(this).extension<SolovvoPalette>() ?? SolovvoPalette.light;
}
