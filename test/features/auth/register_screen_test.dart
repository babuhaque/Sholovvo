import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/presentation/register_screen.dart';
import 'package:sholovvo_app/features/auth/presentation/verify_email_screen.dart';

import '../../support/auth_harness.dart';
import '../../support/fake_auth_repository.dart';

Finder get _fields => find.byType(TextField);
Finder get _submit => find.widgetWithText(SolovvoButton, 'Create account');

void main() {
  group('RegisterScreen', () {
    testWidgets('reports every empty field at once', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester, size: const Size(400, 1200));
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const RegisterScreen()),
      );
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(find.text('Enter your name'), findsOneWidget);
      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Choose a password'), findsOneWidget);
      expect(find.text('Repeat your password'), findsOneWidget);
      expect(repo.registerCalls, 0);
    });

    testWidgets('enforces password composition and confirmation', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester, size: const Size(400, 1200));
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const RegisterScreen()),
      );
      await tester.pump();

      await tester.enterText(_fields.at(0), 'Rafiq Hasan');
      await tester.enterText(_fields.at(1), 'rafiq@solovvo.app');
      await tester.enterText(_fields.at(2), 'short');
      await tester.enterText(_fields.at(3), 'short');
      await tester.tap(_submit);
      await tester.pump();

      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(repo.registerCalls, 0);
    });

    testWidgets('reports an address that is already registered', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester, size: const Size(400, 1200));
      final FakeAuthRepository repo = FakeAuthRepository()
        ..registerFailure = const AuthFailure(
          reason: AuthFailureReason.emailAlreadyInUse,
        );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const RegisterScreen()),
      );
      await tester.pump();

      await tester.enterText(_fields.at(0), 'Rafiq Hasan');
      await tester.enterText(_fields.at(1), 'rafiq@solovvo.app');
      await tester.enterText(_fields.at(2), 'strong-pass1');
      await tester.enterText(_fields.at(3), 'strong-pass1');
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('An account already exists'), findsOneWidget);
      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('a new account lands on the verification screen', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester, size: const Size(400, 1200));
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      await tester.tap(find.text('Get Started'));
      await settleRoute(tester);
      expect(find.byType(RegisterScreen), findsOneWidget);

      await tester.enterText(_fields.at(0), 'Rafiq Hasan');
      await tester.enterText(_fields.at(1), 'rafiq@solovvo.app');
      await tester.enterText(_fields.at(2), 'strong-pass1');
      await tester.enterText(_fields.at(3), 'strong-pass1');
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repo.registerCalls, 1);
      expect(repo.lastDisplayName, 'Rafiq Hasan');
      // Unverified, so the gate must not let the new account through to home.
      expect(find.byType(VerifyEmailScreen), findsOneWidget);
    });
  });
}
