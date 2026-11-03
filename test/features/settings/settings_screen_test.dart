import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:sholovvo_app/features/settings/presentation/settings_screen.dart';
import 'package:sholovvo_app/features/settings/presentation/widgets/settings_tile.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/test_app.dart';

const Size _tallPhone = Size(430, 1400);

/// Mounts Settings the way the profile tab opens it.
///
/// [flavor] is overridden rather than injected: `appConfigProvider` throws
/// outside a real bootstrap, which is the behaviour its own tests pin, so the
/// About card can only be rendered by supplying the value a build would have.
Future<FakeAuthRepository> _pumpSettings(
  WidgetTester tester, {
  AppFlavor flavor = AppFlavor.staging,
  Locale locale = const Locale('en'),
  Size size = _tallPhone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{});
  final PreferencesStore store = await PreferencesStore.load();
  final FakeAuthRepository repo = FakeAuthRepository(initialUser: verifiedUser);
  addTearDown(repo.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig(flavor: flavor)),
        preferencesStoreProvider.overrideWithValue(store),
        authRepositoryProvider.overrideWithValue(repo),
      ],
      child: testApp(
        home: const SettingsScreen(user: verifiedUser),
        locale: locale,
      ),
    ),
  );
  await tester.pump();
  return repo;
}

void main() {
  group('SettingsScreen', () {
    testWidgets('names the address the session signs in with', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester);

      expect(find.text('ayesha@solovvo.app'), findsOneWidget);
      // Read-only, and it says why rather than showing a disabled field.
      expect(find.text('Managed by your sign-in account'), findsOneWidget);
    });

    testWidgets('names the build it is running as', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester);

      expect(find.text('Build'), findsOneWidget);
      expect(find.text('Staging'), findsOneWidget);
      // Brand copy, not translated prose.
      expect(find.text('Solovvo'), findsOneWidget);
    });

    testWidgets('opens the one appearance sheet, not a copy', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(tester);

      expect(find.byType(SettingsTile), findsOneWidget);
      await tester.tap(find.byType(SettingsTile));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AppearanceSheet), findsOneWidget);
      // The same three theme modes and two languages the Welcome screen offers.
      expect(find.text('System'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);
    });

    testWidgets('signing out asks the repository once', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = await _pumpSettings(tester);

      final Finder button = find.widgetWithText(SolovvoButton, 'Sign out');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(repo.signOutCalls, 1);
      expect(tester.takeException(), isNull);
    });

    // Moved here from the dashboard in Stage 7, with the button it belongs to.
    testWidgets('a rejected sign-out is reported and the screen stays', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = await _pumpSettings(tester);
      repo.signOutFailure = const NetworkFailure(debugMessage: 'offline');

      final Finder button = find.widgetWithText(SolovvoButton, 'Sign out');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();

      expect(repo.signOutCalls, 1);
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('renders in Bangla', (WidgetTester tester) async {
      await _pumpSettings(tester, locale: const Locale('bn'));

      expect(find.text('সেটিংস'), findsOneWidget);
      expect(find.text('অ্যাকাউন্ট'), findsOneWidget);
      expect(find.widgetWithText(SolovvoButton, 'সাইন আউট'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits the narrowest phone in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpSettings(
        tester,
        locale: const Locale('bn'),
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
