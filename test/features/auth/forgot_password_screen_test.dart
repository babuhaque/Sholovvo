import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/presentation/forgot_password_screen.dart';

import '../../support/auth_harness.dart';
import '../../support/fake_auth_repository.dart';

Finder get _submit => find.widgetWithText(SolovvoButton, 'Send reset link');

void main() {
  group('ForgotPasswordScreen', () {
    testWidgets('requires an address before sending', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const ForgotPasswordScreen()),
      );
      await tester.pump();

      await tester.tap(_submit);
      await tester.pump();

      expect(find.text('Enter your email address'), findsOneWidget);
      expect(repo.resetCalls, 0);
    });

    testWidgets('confirms without disclosing whether the account exists', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const ForgotPasswordScreen()),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'rafiq@solovvo.app');
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repo.resetCalls, 1);
      expect(repo.lastEmail, 'rafiq@solovvo.app');
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
      expect(find.textContaining('rafiq@solovvo.app'), findsOneWidget);
    });

    testWidgets('surfaces a delivery failure instead of a false success', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository()
        ..resetFailure = const NetworkFailure(debugMessage: 'offline');
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        authHarness(repository: repo, home: const ForgotPasswordScreen()),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'rafiq@solovvo.app');
      await tester.tap(_submit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('No connection'), findsOneWidget);
      expect(find.text('Check your inbox'), findsNothing);
    });
  });
}
