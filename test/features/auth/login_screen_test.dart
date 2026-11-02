import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:sholovvo_app/features/auth/presentation/login_screen.dart';
import 'package:sholovvo_app/features/auth/presentation/register_screen.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';

import '../../support/auth_harness.dart';
import '../../support/fake_auth_repository.dart';

Finder get _fields => find.byType(TextField);
Finder get _submit => find.widgetWithText(SolovvoButton, 'Sign in');

void main() {
  group('LoginScreen', () {
    testWidgets('rejects an empty form without calling the backend', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const LoginScreen()),
      );
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(find.text('Enter your password'), findsOneWidget);
      expect(repo.signInCalls, 0);
    });

    testWidgets('rejects a malformed address before the network', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const LoginScreen()),
      );
      await tester.pump();

      await tester.enterText(_fields.at(0), 'donor@');
      await tester.enterText(_fields.at(1), 'secret123');
      await tester.tap(_submit);
      await tester.pump();

      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(repo.signInCalls, 0);
    });

    testWidgets('reports a rejected sign-in and stays on the form', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository()
        ..signInFailure = const AuthFailure(
          reason: AuthFailureReason.invalidCredentials,
        );
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const LoginScreen()),
      );
      await tester.pump();

      await tester.enterText(_fields.at(0), 'donor@solovvo.app');
      await tester.enterText(_fields.at(1), 'wrong-password');
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('do not match'),
        findsOneWidget,
        reason: 'the failure must be rendered, not swallowed',
      );
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(repo.signInCalls, 1);
    });

    testWidgets('a successful sign-in hands over to the gate', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(authHarness(repository: repo));
      await passSplash(tester);

      await tester.tap(find.text('Sign in'));
      await settleRoute(tester);
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(_fields.at(0), 'donor@solovvo.app');
      await tester.enterText(_fields.at(1), 'secret123');
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(repo.signInCalls, 1);
      expect(repo.lastEmail, 'donor@solovvo.app');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
    });

    testWidgets('forgot password opens the reset form', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const LoginScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Forgot password?'));
      await settleRoute(tester);

      expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    });

    testWidgets('create an account opens the registration form', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const LoginScreen()),
      );
      await tester.pump();

      await tester.tap(find.text('Create an account'));
      await settleRoute(tester);

      expect(find.byType(RegisterScreen), findsOneWidget);
    });
  });
}
