import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/presentation/login_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

import '../../support/auth_harness.dart' show usePhoneSurface;
import '../../support/fake_auth_repository.dart';

/// The real `MaterialApp` wiring, unlike the fixed-locale harness: the shell
/// rebuilds when the language changes, which is what lets a test watch a
/// sentence already on screen change language.
class _Shell extends ConsumerWidget {
  const _Shell({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
  }
}

Future<PreferencesStore> _pumpLogin(
  WidgetTester tester, {
  FakeAuthRepository? repository,
  Locale? locale,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'solovvo.themeMode': themeMode.name,
    if (locale != null) 'solovvo.localeCode': locale.languageCode,
  });
  final PreferencesStore preferences = await PreferencesStore.load();
  final FakeAuthRepository repo = repository ?? FakeAuthRepository();
  addTearDown(repo.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        preferencesStoreProvider.overrideWithValue(preferences),
      ],
      child: const _Shell(home: LoginScreen()),
    ),
  );
  await tester.pump();
  return preferences;
}

Future<void> _submit(WidgetTester tester) async {
  await tester.tap(find.byType(SolovvoButton));
  await tester.pump();
}

void main() {
  group('a localised sign-in form', () {
    testWidgets('opens in Bengali, copy and all', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await _pumpLogin(tester, locale: const Locale('bn'));

      expect(find.text('আবার স্বাগতম'), findsOneWidget);
      expect(find.text('সাইন ইন'), findsOneWidget);
      expect(find.text('পাসওয়ার্ড ভুলে গেছেন?'), findsOneWidget);
    });

    testWidgets('validates in Bengali', (WidgetTester tester) async {
      usePhoneSurface(tester);
      await _pumpLogin(tester, locale: const Locale('bn'));

      await _submit(tester);

      expect(find.text('আপনার ইমেইল ঠিকানা লিখুন'), findsOneWidget);
      expect(find.text('আপনার পাসওয়ার্ড লিখুন'), findsOneWidget);
      // The English sentence must not survive anywhere in the tree.
      expect(find.text('Enter your email address'), findsNothing);
    });

    testWidgets('reports a rejected sign-in in Bengali', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      final FakeAuthRepository repo = FakeAuthRepository()
        ..signInFailure = const AuthFailure(
          reason: AuthFailureReason.invalidCredentials,
        );
      await _pumpLogin(
        tester,
        repository: repo,
        locale: const Locale('bn'),
      );

      await tester.enterText(find.byType(TextField).at(0), 'donor@solovvo.app');
      await tester.enterText(find.byType(TextField).at(1), 'wrong-password');
      await _submit(tester);
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('ইমেইল আর পাসওয়ার্ড মিলছে না। দুটোই দেখে আবার চেষ্টা করুন।'),
        findsOneWidget,
      );
    });

    testWidgets('an error already on screen follows a language change', (
      WidgetTester tester,
    ) async {
      // The form stores the *rule* it broke, not the sentence it rendered, so
      // switching language re-renders the pending error instead of leaving an
      // English complaint on a Bengali form until the next submit.
      usePhoneSurface(tester);
      await _pumpLogin(tester);

      await _submit(tester);
      expect(find.text('Enter your email address'), findsOneWidget);

      tester.container().read(localeProvider.notifier).select(const Locale('bn'));
      await tester.pump();

      expect(find.text('আপনার ইমেইল ঠিকানা লিখুন'), findsOneWidget);
      expect(find.text('Enter your email address'), findsNothing);
    });

    testWidgets('renders on the dark palette without losing contrast', (
      WidgetTester tester,
    ) async {
      usePhoneSurface(tester);
      await _pumpLogin(tester, themeMode: ThemeMode.dark);

      final BuildContext context = tester.element(find.byType(LoginScreen));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(context.palette.isDark, isTrue);

      // The field still paints a readable label: a dark theme that keeps a
      // light surface behind light text is the classic failure here.
      final Text label = tester.widget<Text>(
        find.descendant(
          of: find.byType(LoginScreen),
          matching: find.text('EMAIL'),
        ).first,
      );
      expect(label.style?.color, isNot(SolovvoPalette.dark.surface));
    });
  });
}
