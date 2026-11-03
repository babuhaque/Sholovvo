import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';

Widget _host(Widget child, {ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    home: Scaffold(body: Center(child: child)),
  );
}

/// The disc the avatar paints when it has no photo.
DecoratedBox _disc(WidgetTester tester) {
  return tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(InitialsAvatar),
      matching: find.byType(DecoratedBox),
    ),
  );
}

BoxDecoration _decoration(WidgetTester tester) {
  return _disc(tester).decoration as BoxDecoration;
}

TextStyle _style(WidgetTester tester, String initials) {
  return tester.widget<Text>(find.text(initials)).style!;
}

void main() {
  group('InitialsAvatar: initials', () {
    testWidgets('takes the first letter of the first and last word', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Rahman')),
      );

      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('a single word gives a single letter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_host(const InitialsAvatar(name: 'Rahim')));

      expect(find.text('R'), findsOneWidget);
    });

    testWidgets('a middle name does not become the second initial', (
      WidgetTester tester,
    ) async {
      // "AB" for "Ayesha Begum Rahman" would hide the surname the dashboard
      // shows beside the mark.
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Begum Rahman')),
      );

      expect(find.text('AR'), findsOneWidget);
      expect(find.text('AB'), findsNothing);
    });

    testWidgets('stray whitespace is not a word', (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: '   Ayesha   Rahman   ')),
      );

      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('a Bengali name is cut at rune boundaries', (
      WidgetTester tester,
    ) async {
      // Slicing code units here would produce a broken glyph, not a letter.
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'আয়েশা রহমান')),
      );

      expect(find.text('আর'), findsOneWidget);
      expect(find.textContaining('\uFFFD'), findsNothing);
    });

    testWidgets('a nameless profile shows a person, never an invented letter', (
      WidgetTester tester,
    ) async {
      for (final String name in <String>['', '   ']) {
        await tester.pumpWidget(_host(InitialsAvatar(name: name)));

        expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
        expect(find.text('?'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(InitialsAvatar),
            matching: find.byType(Text),
          ),
          findsNothing,
        );
      }
    });
  });

  group('InitialsAvatar: brand variant (the default)', () {
    testWidgets('is a brand-tinted disc with a proportional mark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Rahman')),
      );

      final SolovvoPalette palette = AppTheme.light
          .extension<SolovvoPalette>()!;
      final TextStyle style = _style(tester, 'AR');

      expect(_decoration(tester).color, palette.brandTint);
      expect(_decoration(tester).shape, BoxShape.circle);
      expect(style.color, palette.onBrandTint);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, 0.5);
      // The brand disc scales its initials with the disc.
      expect(style.fontSize, closeTo(48 * 0.36, 0.01));
    });

    testWidgets('grows the initials with the disc', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Rahman', size: 64)),
      );

      expect(_style(tester, 'AR').fontSize, closeTo(64 * 0.36, 0.01));
    });
  });

  group('InitialsAvatar: muted variant', () {
    testWidgets('is the quieter card mark: muted fill and an outline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const InitialsAvatar(
            name: 'Ayesha Rahman',
            size: 40,
            variant: InitialsAvatarVariant.muted,
          ),
        ),
      );

      final SolovvoPalette palette = AppTheme.light
          .extension<SolovvoPalette>()!;
      final TextStyle style = _style(tester, 'AR');

      expect(_decoration(tester).color, palette.surfaceMuted);
      expect(_decoration(tester).border, isNotNull);
      expect(style.color, palette.textPrimary);
      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('keeps the theme type rather than scaling with the disc', (
      WidgetTester tester,
    ) async {
      // The reviewed dashboard mark is a 40 dp disc with labelMedium initials.
      // Scaling these with the disc would quietly change the approved card.
      await tester.pumpWidget(
        _host(
          const InitialsAvatar(
            name: 'Ayesha Rahman',
            size: 40,
            variant: InitialsAvatarVariant.muted,
          ),
        ),
      );

      final TextStyle style = _style(tester, 'AR');
      final TextStyle? label = AppTheme.light.textTheme.labelMedium;

      expect(style.fontSize, label?.fontSize);
      expect(style.fontSize, 12.5);
      expect(style.letterSpacing, 0);
    });

    testWidgets('a nameless profile uses the same person icon', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const InitialsAvatar(
            name: '',
            size: 40,
            variant: InitialsAvatarVariant.muted,
          ),
        ),
      );

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });
  });

  group('InitialsAvatar: photo and sizing', () {
    testWidgets('draws the photo when there is one', (
      WidgetTester tester,
    ) async {
      const String url = 'https://cdn.test/ayesha.jpg';
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Rahman', photoUrl: url)),
      );

      final Image image = tester.widget<Image>(
        find.descendant(
          of: find.byType(InitialsAvatar),
          matching: find.byType(Image),
        ),
      );

      expect((image.image as NetworkImage).url, url);
      expect(find.text('AR'), findsNothing);
    });

    testWidgets('a blank URL is treated as no photo at all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Rahman', photoUrl: '   ')),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.text('AR'), findsOneWidget);
    });

    testWidgets('is a square of the requested size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const InitialsAvatar(
            name: 'Ayesha Rahman',
            size: 40,
            variant: InitialsAvatarVariant.muted,
          ),
        ),
      );

      expect(tester.getSize(find.byType(InitialsAvatar)), const Size(40, 40));
    });

    testWidgets('defaults to the smaller of the two reviewed discs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(const InitialsAvatar(name: 'Ayesha Rahman')),
      );

      expect(tester.getSize(find.byType(InitialsAvatar)), const Size(48, 48));
    });
  });

  group('InitialsAvatar: theming', () {
    testWidgets('both variants take their colours from the active palette', (
      WidgetTester tester,
    ) async {
      for (final ThemeMode mode in <ThemeMode>[
        ThemeMode.light,
        ThemeMode.dark,
      ]) {
        final SolovvoPalette palette = mode == ThemeMode.dark
            ? AppTheme.dark.extension<SolovvoPalette>()!
            : AppTheme.light.extension<SolovvoPalette>()!;

        for (final InitialsAvatarVariant variant
            in InitialsAvatarVariant.values) {
          await tester.pumpWidget(
            _host(
              InitialsAvatar(name: 'Ayesha Rahman', variant: variant),
              themeMode: mode,
            ),
          );
          await tester.pumpAndSettle();

          expect(
            _decoration(tester).color,
            variant == InitialsAvatarVariant.muted
                ? palette.surfaceMuted
                : palette.brandTint,
          );
        }
      }
    });
  });
}
