import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';

Widget _host(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    home: Scaffold(body: Center(child: child)),
  );
}

/// The single surface the badge paints.
Container _surface(WidgetTester tester) {
  return tester.widget<Container>(
    find.descendant(
      of: find.byType(BloodGroupBadge),
      matching: find.byType(Container),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester) {
  return _surface(tester).decoration! as BoxDecoration;
}

TextStyle _style(WidgetTester tester, String group) {
  return tester.widget<Text>(find.text(group)).style!;
}

void main() {
  group('BloodGroupBadge: pill (the default)', () {
    testWidgets('draws a fully rounded label', (WidgetTester tester) async {
      await tester.pumpWidget(_host(const BloodGroupBadge(bloodGroup: 'O+')));

      final Container surface = _surface(tester);

      expect(_decoration(tester).borderRadius, AppRadius.pillRadius);
      expect(
        surface.padding,
        const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      );
      expect(_style(tester, 'O+').fontSize, 13);
    });

    testWidgets('the large pill grows without changing its shape', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const BloodGroupBadge(bloodGroup: 'AB-', large: true)),
      );

      expect(_decoration(tester).borderRadius, AppRadius.pillRadius);
      expect(
        _surface(tester).padding,
        const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      );
      expect(_style(tester, 'AB-').fontSize, 20);
    });

    testWidgets('is sized by its text rather than by a fixed width', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const BloodGroupBadge(bloodGroup: 'O+')));

      // A pill stretched to 44 dp would leave a gap beside a two-letter group.
      expect(tester.getSize(find.byType(BloodGroupBadge)).width, lessThan(44));
    });
  });

  group('BloodGroupBadge: square', () {
    testWidgets('is the reviewed 44 dp tile with the medium radius', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BloodGroupBadge(
            bloodGroup: 'B+',
            variant: BloodGroupBadgeVariant.square,
          ),
        ),
      );

      expect(tester.getSize(find.byType(BloodGroupBadge)), const Size(44, 44));
      expect(_decoration(tester).borderRadius, AppRadius.mdRadius);
      expect(BloodGroupBadge.defaultSquareSize, 44);
    });

    testWidgets('accepts a different size for a denser list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BloodGroupBadge(
            bloodGroup: 'B+',
            variant: BloodGroupBadgeVariant.square,
            size: 36,
          ),
        ),
      );

      expect(tester.getSize(find.byType(BloodGroupBadge)), const Size(36, 36));
    });

    testWidgets('keeps the dashboard type, not the pill type', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const BloodGroupBadge(
            bloodGroup: 'B+',
            variant: BloodGroupBadgeVariant.square,
            large: true,
          ),
        ),
      );

      // `large` belongs to the pill. The tile's mark is the theme's titleMedium
      // at w700, which is what the dashboard was reviewed with.
      expect(_style(tester, 'B+').fontWeight, FontWeight.w700);
      expect(_style(tester, 'B+').fontSize, isNot(20));
    });
  });

  group('BloodGroupBadge: theming', () {
    testWidgets('takes both colours from the active palette', (
      WidgetTester tester,
    ) async {
      for (final ThemeMode mode in <ThemeMode>[
        ThemeMode.light,
        ThemeMode.dark,
      ]) {
        await tester.pumpWidget(
          _host(
            const BloodGroupBadge(
              bloodGroup: 'A+',
              variant: BloodGroupBadgeVariant.square,
            ),
            themeMode: mode,
          ),
        );
        await tester.pumpAndSettle();

        final SolovvoPalette palette = mode == ThemeMode.dark
            ? AppTheme.dark.extension<SolovvoPalette>()!
            : AppTheme.light.extension<SolovvoPalette>()!;

        expect(_decoration(tester).color, palette.brandTint);
        expect(_style(tester, 'A+').color, palette.onBrandTint);
      }
    });
  });
}
