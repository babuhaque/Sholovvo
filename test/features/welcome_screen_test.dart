import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/presentation/login_screen.dart';
import 'package:sholovvo_app/features/auth/presentation/register_screen.dart';
import 'package:sholovvo_app/features/welcome/presentation/welcome_screen.dart';

import '../support/fake_auth_repository.dart';
import '../support/test_app.dart';

const String _headline = 'A Drop of Hope, Give Blood, Give Life';

Widget _app(FakeAuthRepository repo) {
  return ProviderScope(
    overrides: [authRepositoryProvider.overrideWithValue(repo)],
    child: testApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const WelcomeScreen(),
    ),
  );
}

/// The welcome screen runs a continuous ambient animation, so
/// `pumpAndSettle` would never return. Advance explicit frames instead.
Future<void> _settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('WelcomeScreen', () {
    testWidgets('shows the headline, subtitle and primary action', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(_app(repo));
      await tester.pump(const Duration(milliseconds: 900));

      expect(find.text(_headline), findsOneWidget);
      expect(find.textContaining('One donation can be'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Already have an account?'), findsOneWidget);
    });

    testWidgets('Get Started opens account creation', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(_app(repo));
      await tester.pump(const Duration(milliseconds: 900));

      await tester.tap(find.text('Get Started'));
      await _settleRoute(tester);

      // A first-time visitor starts at registration, not at a sign-in form they
      // cannot use yet.
      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('Sign in opens the login form', (WidgetTester tester) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(_app(repo));
      await tester.pump(const Duration(milliseconds: 900));

      await tester.tap(find.text('Sign in'));
      await _settleRoute(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    group('layout', () {
      testWidgets('fits a small phone (320x568) without overflow', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final FakeAuthRepository repo = FakeAuthRepository();
        addTearDown(repo.dispose);

        await tester.pumpWidget(_app(repo));
        await tester.pump(const Duration(milliseconds: 900));

        expect(tester.takeException(), isNull);
        expect(find.text(_headline), findsOneWidget);
        expect(find.byType(SolovvoButton), findsOneWidget);
      });

      testWidgets('fits a large phone (430x932) without overflow', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final FakeAuthRepository repo = FakeAuthRepository();
        addTearDown(repo.dispose);

        await tester.pumpWidget(_app(repo));
        await tester.pump(const Duration(milliseconds: 900));

        expect(tester.takeException(), isNull);
        expect(find.text(_headline), findsOneWidget);
      });

      testWidgets('survives an extreme narrow width (280x653)', (
        WidgetTester tester,
      ) async {
        tester.view.physicalSize = const Size(280, 653);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final FakeAuthRepository repo = FakeAuthRepository();
        addTearDown(repo.dispose);

        await tester.pumpWidget(_app(repo));
        await tester.pump(const Duration(milliseconds: 900));

        // Scrolling is acceptable; a hard RenderFlex overflow is not.
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps both actions above the fold on a short window', (
        WidgetTester tester,
      ) async {
        // A landscape phone or a short desktop window: the hero may have to
        // scroll, but the two actions must stay tappable.
        tester.view.physicalSize = const Size(700, 420);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final FakeAuthRepository repo = FakeAuthRepository();
        addTearDown(repo.dispose);

        await tester.pumpWidget(_app(repo));
        await tester.pump(const Duration(milliseconds: 900));

        const Rect screen = Rect.fromLTWH(0, 0, 700, 420);
        expect(
          screen.contains(tester.getRect(find.text('Get Started')).center),
          isTrue,
        );
        expect(
          screen.contains(tester.getRect(find.text('Sign in')).center),
          isTrue,
        );
        // The decorated medallion is dropped in this band, but the message
        // must still be on screen.
        expect(
          screen.contains(tester.getRect(find.text(_headline)).center),
          isTrue,
        );
      });
    });
  });
}
