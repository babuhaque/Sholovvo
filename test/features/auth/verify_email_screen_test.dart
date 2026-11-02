import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/auth/presentation/verify_email_screen.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';

import '../../support/auth_harness.dart';
import '../../support/fake_auth_repository.dart';

Widget _verifyScreen() => const VerifyEmailScreen(user: unverifiedUser);

void main() {
  group('VerifyEmailScreen', () {
    testWidgets('names the address that is waiting for confirmation', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: _verifyScreen()),
      );
      await tester.pump();

      expect(find.text('rafiq@solovvo.app'), findsOneWidget);
      expect(find.text("I've confirmed my email"), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('resend asks for a new link and then holds off', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: _verifyScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Resend email'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.verifyCalls, 1);
      expect(find.text('A fresh link is on its way.'), findsOneWidget);
      // Cooldown starts at 60 and ticks down, so consecutive taps cannot turn
      // into a burst of throttled requests.
      expect(find.text('Resend in 60s'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend in 59s'), findsOneWidget);
    });

    testWidgets('a still-unverified check explains what to do', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: _verifyScreen()),
      );
      await tester.pump();

      await tester.tap(find.text("I've confirmed my email"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.reloadCalls, 1);
      expect(find.textContaining('Not confirmed yet'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('surfaces a failed profile refresh', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      )..reloadFailure = const NetworkFailure(debugMessage: 'offline');
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: _verifyScreen()),
      );
      await tester.pump();

      await tester.tap(find.text("I've confirmed my email"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('No connection'), findsOneWidget);
    });

    testWidgets('sign out reaches the repository', (WidgetTester tester) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository(
        initialUser: unverifiedUser,
      );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: _verifyScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Sign out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.signOutCalls, 1);
    });
  });
}
