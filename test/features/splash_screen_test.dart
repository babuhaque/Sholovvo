import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/features/splash/presentation/splash_screen.dart';

import '../support/test_app.dart';

Widget _app({VoidCallback? onReveal}) {
  return testApp(home: SplashScreen(onRevealComplete: onReveal));
}

void main() {
  group('SplashScreen', () {
    testWidgets('shows brand identity immediately', (WidgetTester tester) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text(AppBrand.name), findsOneWidget);
      expect(find.text(AppBrand.tagline), findsOneWidget);
      expect(find.byType(BloodDropMark), findsWidgets);
    });

    testWidgets('reports completion once, after the two second reveal', (
      WidgetTester tester,
    ) async {
      // The screen owns no destination: it tells whoever built it that the
      // reveal is over, and stays put otherwise. That is what lets the gate hold
      // it while a stored session resolves.
      int revealed = 0;
      await tester.pumpWidget(_app(onReveal: () => revealed++));

      await tester.pump(const Duration(milliseconds: 1900));
      expect(revealed, 0);

      await tester.pump(const Duration(milliseconds: 200));
      expect(revealed, 1);

      await tester.pump(const Duration(seconds: 2));
      expect(revealed, 1, reason: 'the callback must not repeat');
      expect(find.byType(SplashScreen), findsOneWidget);
    });

    testWidgets('stays up indefinitely when nobody takes over', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump(AppMotion.splash);
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reveals without throwing during the animation', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app());

      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('centres the brand block horizontally', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 900));

      // Regression: a loose Stack let the column shrink-wrap to its widest
      // child, leaving the whole lockup pinned to the left edge.
      const double screenCentre = 390 / 2;
      expect(
        tester.getCenter(find.text(AppBrand.name)).dx,
        closeTo(screenCentre, 1),
      );
      expect(
        tester.getCenter(find.text(AppBrand.tagline)).dx,
        closeTo(screenCentre, 1),
      );
    });

    testWidgets('the loading rule is visible and advances', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pump(const Duration(milliseconds: 500));

      // The FractionallySizedBox fills the rule; its child is the moving fill.
      final Finder fill = find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(DecoratedBox),
      );
      expect(fill, findsOneWidget);

      // Regression: unpositioned children of a loose Stack collapse to zero
      // height, which made the whole rule invisible.
      final Size early = tester.getSize(fill);
      expect(early.height, 4);
      expect(early.width, greaterThan(0));

      await tester.pump(const Duration(milliseconds: 1100));
      expect(tester.getSize(fill).width, greaterThan(early.width));
    });
  });
}
