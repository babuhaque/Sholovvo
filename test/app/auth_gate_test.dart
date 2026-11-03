import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/auth_gate.dart';
import 'package:sholovvo_app/features/auth/presentation/verify_email_screen.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';
import 'package:sholovvo_app/features/splash/presentation/splash_screen.dart';
import 'package:sholovvo_app/features/welcome/presentation/welcome_screen.dart';

import '../support/auth_harness.dart';
import '../support/fake_auth_repository.dart';

void main() {
  group('AuthGate', () {
    testWidgets('holds the splash through the brand reveal', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);

      // Signed out already, but the two second reveal still runs.
      await tester.pump(const Duration(milliseconds: 1500));
      expect(find.byType(WelcomeScreen), findsNothing);

      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();
      expect(find.byType(SplashScreen), findsNothing);
      expect(find.byType(WelcomeScreen), findsOneWidget);
    });

    testWidgets('routes a signed-out session to the welcome screen', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.text('A Drop of Hope, Give Blood, Give Life'), findsOneWidget);
    });

    testWidgets('routes a verified session straight past the welcome screen', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: verifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Welcome, Ayesha'), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('routes an unverified session to the verification screen', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      expect(find.byType(VerifyEmailScreen), findsOneWidget);
      expect(find.text('rafiq@solovvo.app'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('keeps the splash up while the stored session resolves', (
      WidgetTester tester,
    ) async {
      final SilentAuthRepository repo = SilentAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      // Guessing "signed out" here would flash the welcome screen at a donor
      // whose token is one frame away from arriving.
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byType(WelcomeScreen), findsNothing);
    });

    testWidgets('surfaces a broken session stream with a retry', (
      WidgetTester tester,
    ) async {
      final BrokenAuthRepository repo = BrokenAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      expect(find.byType(AuthStreamErrorView), findsOneWidget);
      expect(find.text('Could not restore your session'), findsOneWidget);
      expect(find.text('network'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('returns to the welcome screen when the user signs out', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: verifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      // Since Stage 7 the only way out is Settings, so the test walks the path a
      // donor does: the profile tab, its gear, then the button.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pump();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await settleRoute(tester);

      // The settings page is taller than a phone screen, so the sign-out control
      // starts below the fold. A tap at an off-screen point hits nothing and
      // the sign-out would silently never be called.
      await tester.ensureVisible(find.text('Sign out'));
      await tester.pump();

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repo.signOutCalls, 1);
      expect(find.byType(WelcomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('switches to the home screen once the email is confirmed', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      )..verifyOnReload = true;
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);
      expect(find.byType(VerifyEmailScreen), findsOneWidget);

      await tester.tap(find.text("I've confirmed my email"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repo.reloadCalls, 1);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
