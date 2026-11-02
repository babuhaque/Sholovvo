import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/bootstrap_gate.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/firebase/firebase_bootstrap.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/splash/presentation/splash_screen.dart';

import '../support/fake_auth_repository.dart';
import '../support/test_app.dart';

/// Builds the gate with an injected bootstrap outcome.
///
/// The Firebase SDK itself is not stubbed: what is pinned here is the gate's
/// contract — render the brand reveal only for a real success, and surface the
/// classified failure otherwise. The identity backend is faked so a signed-out
/// session resolves without a Firebase project.
Widget _harness(FirebaseBootstrapResult result, FakeAuthRepository repository) {
  return ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(
        const AppConfig(flavor: AppFlavor.staging),
      ),
      firebaseBootstrapProvider.overrideWithValue(result),
      authRepositoryProvider.overrideWithValue(repository),
    ],
    child: testApp(
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const BootstrapGate(),
    ),
  );
}

void main() {
  group('BootstrapGate', () {
    testWidgets('hands over to the auth gate when Firebase is ready', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _harness(
          const FirebaseReady(
            appName: '[DEFAULT]',
            projectId: 'sholovvo-blood-donation',
          ),
          repo,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      // The gate opens on the brand reveal; the destination is decided once the
      // session resolves.
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('Firebase unavailable'), findsNothing);
    });

    testWidgets('surfaces the classified failure instead of faking success', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = FakeAuthRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        _harness(
          const FirebaseUnavailable(
            failure: NetworkFailure(debugMessage: 'device offline'),
          ),
          repo,
        ),
      );
      await tester.pump();

      expect(find.text('Firebase unavailable'), findsOneWidget);
      expect(find.text('network'), findsOneWidget);
      expect(find.text('device offline'), findsOneWidget);
      expect(find.text('sholovvo-blood-donation'), findsOneWidget);
      expect(find.text('staging'), findsOneWidget);
      expect(find.byType(SplashScreen), findsNothing);
    });
  });
}
