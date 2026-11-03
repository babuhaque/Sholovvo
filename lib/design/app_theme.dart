import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_colors.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_typography.dart';

/// Assembles [ThemeData] from the design tokens.
///
/// There is exactly one builder here and it runs twice: light and dark differ in
/// [SolovvoPalette] only. Component-specific decoration lives in the Solovvo
/// widgets rather than in sprawling sub-themes, so there is one place to look
/// when changing how a button or field looks.
abstract final class AppTheme {
  static ThemeData get light => _build(SolovvoPalette.light);

  static ThemeData get dark => _build(SolovvoPalette.dark);

  static ThemeData _build(SolovvoPalette palette) {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.burgundy,
      brightness: palette.brightness,
    ).copyWith(
      // Brand *ink* rather than the raw brand red: on a charcoal page the deep
      // burgundy used on cream falls below readable contrast.
      primary: palette.brandInk,
      // In the dark theme [primary] is a light rose, so its label has to be
      // dark; on light it is deep burgundy and takes the light text colour.
      onPrimary: palette.isDark ? const Color(0xFF3A0B14) : palette.onBrand,
      primaryContainer: palette.brandTint,
      onPrimaryContainer: palette.onBrandTint,
      secondary: AppColors.bloodRed,
      onSecondary: palette.onBrand,
      secondaryContainer: palette.brandTint,
      onSecondaryContainer: palette.onBrandTint,
      surface: palette.surface,
      onSurface: palette.textPrimary,
      onSurfaceVariant: palette.textSecondary,
      outline: palette.outlineStrong,
      outlineVariant: palette.outline,
      error: palette.danger,
      // On the dark theme the error red is a bright salmon, so its label has to
      // be dark; on light it is a deep red and takes the light text colour.
      onError: palette.isDark ? const Color(0xFF2A0A08) : palette.onBrand,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: palette.brightness,
      colorScheme: scheme,
      extensions: <ThemeExtension<dynamic>>[palette],
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: AppTypography.textThemeFor(palette),
      visualDensity: VisualDensity.standard,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: palette.brandInk,
        selectionColor: palette.brandTint,
        selectionHandleColor: palette.brandInk,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: palette.textPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(color: palette.outline, space: 1),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: palette.surface,
        modalBarrierColor: Colors.black.withValues(alpha: 0.45),
        dragHandleColor: palette.outlineStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brandInk,
          foregroundColor: palette.isDark
              ? const Color(0xFF3A0B14)
              : palette.onBrand,
          minimumSize: const Size(0, 52),
          textStyle: AppTypography.textThemeFor(palette).labelLarge,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.pillRadius,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brandInk,
          textStyle: AppTypography.textThemeFor(palette).labelLarge,
          minimumSize: const Size(0, 44),
        ),
      ),
      iconTheme: IconThemeData(color: palette.textSecondary),
      // The shell's two navigation surfaces. Both sit on the raised surface with
      // no elevation: on a cream page a shadowed bar reads as a second layer,
      // and the brand tint already marks the selected destination.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: palette.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: palette.brandTint,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((Set<WidgetState> states) {
          return IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? palette.brandInk
                : palette.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? palette.brandInk
                : palette.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: palette.surface,
        indicatorColor: palette.brandTint,
        selectedIconTheme: IconThemeData(size: 24, color: palette.brandInk),
        unselectedIconTheme: IconThemeData(
          size: 24,
          color: palette.textSecondary,
        ),
        selectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: palette.brandInk,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: palette.textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        // Inverted against the page in both themes, so a toast reads as an
        // overlay rather than as another card.
        backgroundColor: palette.isDark
            ? palette.surfaceMuted
            : AppColors.charcoal,
        contentTextStyle: TextStyle(
          fontSize: 14,
          height: 1.55,
          color: palette.isDark ? palette.textPrimary : palette.onBrand,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
