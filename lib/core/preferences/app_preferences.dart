import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted appearance and language choices.
///
/// Reads are synchronous because [load] runs once before the first frame: the
/// app then opens directly in the chosen theme and language instead of
/// painting the default and correcting itself a frame later.
///
/// Only two values are stored, and both store an *enum name*, not an index.
/// Renaming a constant is then a compile error, while reusing an index would
/// silently turn a stored "dark" into "light" the next time the list changes.
class PreferencesStore {
  PreferencesStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _themeModeKey = 'solovvo.themeMode';
  static const String _localeCodeKey = 'solovvo.localeCode';

  /// Opens the store. Called from `bootstrap()` so no widget has to await it.
  static Future<PreferencesStore> load() async {
    return PreferencesStore(await SharedPreferences.getInstance());
  }

  /// `system` when nothing was ever stored, which is the honest default: the
  /// device setting is the one the user already chose once.
  ThemeMode get themeMode => switch (_prefs.getString(_themeModeKey)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  Future<void> setThemeMode(ThemeMode mode) {
    return _prefs.setString(_themeModeKey, mode.name);
  }

  /// `null` means "follow the device", so a Bengali phone starts in Bengali
  /// without the user having to find the language sheet first.
  Locale? get locale {
    final String? code = _prefs.getString(_localeCodeKey);
    return code == null ? null : Locale(code);
  }

  Future<void> setLocale(Locale? locale) {
    return locale == null
        ? _prefs.remove(_localeCodeKey)
        : _prefs.setString(_localeCodeKey, locale.languageCode);
  }
}

/// Overridden in `bootstrap()` with the instance loaded before `runApp`.
final Provider<PreferencesStore> preferencesStoreProvider =
    Provider<PreferencesStore>(
      (Ref ref) => throw UnimplementedError(
        'preferencesStoreProvider must be overridden in bootstrap() with '
        'await PreferencesStore.load().',
      ),
    );

/// The theme the user picked. Never `null`: "no preference" *is* [ThemeMode.system].
final NotifierProvider<ThemeModeController, ThemeMode> themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(preferencesStoreProvider).themeMode;

  void select(ThemeMode mode) {
    if (mode == state) {
      return;
    }
    state = mode;
    _persist(ref.read(preferencesStoreProvider).setThemeMode(mode));
  }
}

/// The chosen language, or `null` to follow the device locale.
final NotifierProvider<LocaleController, Locale?> localeProvider =
    NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => ref.read(preferencesStoreProvider).locale;

  void select(Locale? locale) {
    if (locale?.languageCode == state?.languageCode) {
      return;
    }
    state = locale;
    _persist(ref.read(preferencesStoreProvider).setLocale(locale));
  }
}

/// Writes to disk without letting a failed write break the UI.
///
/// The choice is already applied in memory, so the worst case for a failed
/// write is that the next launch forgets it — not that tapping "Dark" throws.
void _persist(Future<void> write) {
  write.ignore();
}
