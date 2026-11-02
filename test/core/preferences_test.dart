import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';

/// Reads the store the way `bootstrap()` does, so every test exercises the
/// real decoding path rather than the setters that wrote the value.
Future<PreferencesStore> _open() => PreferencesStore.load();

/// Lets the fire-and-forget disk write run.
///
/// The controllers apply the choice to memory first and persist without
/// awaiting, so a test that reads the store immediately after `select` would
/// race the write.
Future<void> _flushWrites() => Future<void>.delayed(Duration.zero);

void main() {
  // `SharedPreferences` reaches for a platform channel even when mocked.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('PreferencesStore', () {
    test('opens on the device defaults when nothing was ever chosen', () async {
      final PreferencesStore store = await _open();

      // Following the device is the honest default: the OS setting is a choice
      // the user already made once.
      expect(store.themeMode, ThemeMode.system);
      expect(store.locale, isNull);
    });

    test('round-trips a theme choice across a launch', () async {
      await (await _open()).setThemeMode(ThemeMode.dark);
      expect((await _open()).themeMode, ThemeMode.dark);

      await (await _open()).setThemeMode(ThemeMode.light);
      expect((await _open()).themeMode, ThemeMode.light);
    });

    test('round-trips a language choice, and can go back to the device', () async {
      await (await _open()).setLocale(const Locale('bn'));
      expect((await _open()).locale, const Locale('bn'));

      // Choosing "follow the device" again removes the key rather than storing
      // a sentinel, so a later device change is picked up.
      await (await _open()).setLocale(null);
      expect((await _open()).locale, isNull);
    });

    test('a stored value it cannot decode falls back instead of throwing', () async {
      // A downgrade, a hand-edited plist or a renamed constant must not turn
      // the next launch into a crash before the first frame.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'solovvo.themeMode': 'purple',
      });

      expect((await _open()).themeMode, ThemeMode.system);
    });

    test('stores enum names, not indices', () async {
      await (await _open()).setThemeMode(ThemeMode.dark);

      final SharedPreferences raw = await SharedPreferences.getInstance();
      expect(raw.getString('solovvo.themeMode'), 'dark');
    });
  });

  group('appearance controllers', () {
    late PreferencesStore store;
    late ProviderContainer container;

    setUp(() async {
      store = await _open();
      container = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('build from the stored choice rather than from a default', () async {
      await store.setThemeMode(ThemeMode.dark);
      await store.setLocale(const Locale('bn'));

      final ProviderContainer fresh = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(store)],
      );
      addTearDown(fresh.dispose);

      expect(fresh.read(themeModeProvider), ThemeMode.dark);
      expect(fresh.read(localeProvider), const Locale('bn'));
    });

    test('a theme choice is applied and persisted', () async {
      container.read(themeModeProvider.notifier).select(ThemeMode.light);

      expect(container.read(themeModeProvider), ThemeMode.light);
      await _flushWrites();
      expect(store.themeMode, ThemeMode.light);
    });

    test('a language choice is applied and persisted', () async {
      container.read(localeProvider.notifier).select(const Locale('bn'));

      expect(container.read(localeProvider), const Locale('bn'));
      await _flushWrites();
      expect(store.locale, const Locale('bn'));
    });

    test('re-selecting the current value does not notify or rewrite', () async {
      // Guards the sheet's taps: tapping the already-selected row must not
      // rebuild the whole app or touch the disk.
      container.read(themeModeProvider.notifier).select(ThemeMode.system);
      container.read(localeProvider.notifier).select(const Locale('en'));

      final List<ThemeMode> seen = <ThemeMode>[];
      final ProviderSubscription<ThemeMode> subscription = container
          .listen<ThemeMode>(
            themeModeProvider,
            (ThemeMode? _, ThemeMode next) => seen.add(next),
          );
      addTearDown(subscription.close);

      container.read(themeModeProvider.notifier).select(ThemeMode.system);
      // Same language in a different script subtag is the same choice.
      container.read(localeProvider.notifier).select(const Locale('en', 'GB'));

      expect(seen, isEmpty);
      expect(container.read(localeProvider), const Locale('en'));
    });

    test('an unoverridden store fails loudly instead of guessing', () {
      final ProviderContainer bare = ProviderContainer();
      addTearDown(bare.dispose);

      // Silently defaulting here would ship an app whose saved settings are
      // ignored, which is far harder to notice than a thrown message naming
      // the override that is missing. Riverpod re-wraps the error on read, so
      // the assertion is on the message rather than the exception type.
      expect(
        () => bare.read(themeModeProvider),
        throwsA(
          predicate<Object>(
            (Object error) => error.toString().contains('preferencesStoreProvider'),
            'names the missing override',
          ),
        ),
      );
    });
  });
}
