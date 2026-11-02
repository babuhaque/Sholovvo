import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sholovvo_app/app/app.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/firebase/firebase_bootstrap.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/presentation/register_screen.dart';
import 'package:sholovvo_app/features/welcome/presentation/welcome_screen.dart';

import '../support/auth_harness.dart' show passSplash, settleRoute;
import '../support/fake_auth_repository.dart';

const String _englishHeadline = 'A Drop of Hope, Give Blood, Give Life';
const String _banglaHeadline = 'এক ফোঁটা আশা, রক্ত দিন, জীবন দিন';
const String _banglaTagline = 'জীবন বাঁচান • হৃদয় জুড়ুন';

/// The real root widget over a fake identity backend, so the checks below run
/// through `SolovvoApp` and the bootstrap override rather than past them.
Future<PreferencesStore> _launch(
  WidgetTester tester, {
  FakeAuthRepository? repository,
  Map<String, Object> stored = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(stored);
  final PreferencesStore preferences = await PreferencesStore.load();
  final FakeAuthRepository repo = repository ?? FakeAuthRepository();
  addTearDown(repo.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(flavor: AppFlavor.staging),
        ),
        firebaseBootstrapProvider.overrideWithValue(
          const FirebaseReady(
            appName: '[DEFAULT]',
            projectId: 'sholovvo-blood-donation',
          ),
        ),
        authRepositoryProvider.overrideWithValue(repo),
        preferencesStoreProvider.overrideWithValue(preferences),
      ],
      child: const SolovvoApp(),
    ),
  );

  return preferences;
}

Future<void> _openAppearance(WidgetTester tester) async {
  await tester.tap(find.byType(AppearanceButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Taps the dimmed area above the sheet, which dismisses it.
Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(12, 12));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  group('SolovvoApp personalisation', () {
    testWidgets('a language chosen at the door follows the visitor inside', (
      WidgetTester tester,
    ) async {
      final PreferencesStore preferences = await _launch(tester);
      await passSplash(tester);

      expect(find.text(_englishHeadline), findsOneWidget);

      await _openAppearance(tester);
      await tester.tap(find.text('বাংলা'));
      await tester.pump();
      expect(preferences.locale, const Locale('bn'));

      await _dismissSheet(tester);

      // The welcome screen behind the sheet has already switched, and the
      // language carries into the pushed sign-up form as well.
      expect(find.text(_banglaHeadline), findsOneWidget);
      expect(find.text(_englishHeadline), findsNothing);

      await tester.tap(find.text('শুরু করুন'));
      await settleRoute(tester);

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Solovvo-তে যুক্ত হোন'), findsOneWidget);
      expect(find.text('রক্তের গ্রুপ আর দূরত্ব অনুযায়ী ডোনারদের মিলানো হয়। নিবন্ধনে এক মিনিটও লাগবে না।'), findsOneWidget);
    });

    testWidgets('a dark choice repaints the whole app, not just the sheet', (
      WidgetTester tester,
    ) async {
      final PreferencesStore preferences = await _launch(tester);
      await passSplash(tester);

      await _openAppearance(tester);
      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(preferences.themeMode, ThemeMode.dark);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );

      await _dismissSheet(tester);

      final BuildContext welcome = tester.element(find.byType(WelcomeScreen));
      expect(welcome.palette.isDark, isTrue);
      expect(
        Theme.of(welcome).brightness,
        Brightness.dark,
        reason: 'the screen below the navigator must see the dark theme',
      );
    });

    testWidgets('a saved choice is in effect on the very first frame', (
      WidgetTester tester,
    ) async {
      // The brand reveal runs for two seconds before anything else, which is
      // exactly where an un-persisted setting would show up as an English
      // flash followed by a correction.
      await _launch(
        tester,
        stored: <String, Object>{
          'solovvo.themeMode': 'dark',
          'solovvo.localeCode': 'bn',
        },
      );
      await tester.pump();

      expect(find.text(_banglaTagline), findsOneWidget);

      final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);
      expect(app.locale, const Locale('bn'));

      await passSplash(tester);
      expect(find.text(_banglaHeadline), findsOneWidget);
      expect(find.text(_englishHeadline), findsNothing);
    });

    testWidgets('both choices survive a relaunch', (WidgetTester tester) async {
      await _launch(tester);
      await passSplash(tester);

      await _openAppearance(tester);
      await tester.tap(find.text('বাংলা'));
      await tester.pump();
      await tester.tap(find.text('গাঢ়'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Read back from the platform store rather than from the in-memory
      // object, so this proves the write happened and not just the setState.
      final SharedPreferences raw = await SharedPreferences.getInstance();
      expect(raw.getString('solovvo.localeCode'), 'bn');
      expect(raw.getString('solovvo.themeMode'), 'dark');
    });

    testWidgets('the appearance control stays reachable while signed out', (
      WidgetTester tester,
    ) async {
      // The point of putting it on the welcome screen: a Bengali speaker can
      // change the language *before* being asked to read a sign-up form.
      await _launch(tester);
      await passSplash(tester);

      expect(find.byType(AppearanceButton), findsOneWidget);
      await _openAppearance(tester);

      expect(find.byType(AppearanceSheet), findsOneWidget);
      expect(find.text('Appearance & language'), findsOneWidget);
    });

    testWidgets('the light palette is used when the device is light', (
      WidgetTester tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _launch(tester);
      await passSplash(tester);

      final BuildContext welcome = tester.element(find.byType(WelcomeScreen));
      expect(welcome.palette.isDark, isFalse);
      expect(welcome.palette.surface, SolovvoPalette.light.surface);
    });

    testWidgets('the dark palette is used when the device is dark', (
      WidgetTester tester,
    ) async {
      // Nothing stored means "follow the device", which is the default the
      // sheet offers first.
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await _launch(tester);
      await passSplash(tester);

      final BuildContext welcome = tester.element(find.byType(WelcomeScreen));
      expect(welcome.palette.isDark, isTrue);
      expect(welcome.palette.surface, SolovvoPalette.dark.surface);
    });
  });
}
