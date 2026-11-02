import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A `MaterialApp` wired the way the real app wires one — both themes, both
/// supported locales, the same delegates.
///
/// Widget tests go through this instead of a bare `MaterialApp` so they
/// exercise the same localisation resolution a user gets. A test that forgot
/// the delegates would fail with "No MaterialLocalizations found" only once the
/// first screen read `context.l10n`, which is easy to miss when adding screens.
Widget testApp({
  required Widget home,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
  RouteFactory? onGenerateRoute,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: themeMode,
    // Pinned rather than left null: the test binding's default locale is
    // `en_US`, and pinning makes a Bangla test explicit at the call site.
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    onGenerateRoute: onGenerateRoute,
    home: home,
  );
}

/// The English catalogue, for tests that assert a sentence without a widget
/// tree (message mapping, for example).
final AppLocalizations english = lookupAppLocalizations(const Locale('en'));

/// The Bangla catalogue, for the same purpose.
final AppLocalizations bangla = lookupAppLocalizations(const Locale('bn'));
