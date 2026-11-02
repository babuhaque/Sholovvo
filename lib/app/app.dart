import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/bootstrap_gate.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Root application widget.
///
/// The two things a user can change about the app itself — theme and language —
/// are read here and nowhere else. Every screen below this point sees only the
/// result: `Theme.of(context)` and `context.l10n`.
class SolovvoApp extends ConsumerWidget {
  const SolovvoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeMode themeMode = ref.watch(themeModeProvider);
    final Locale? locale = ref.watch(localeProvider);

    return MaterialApp(
      title: AppBrand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // A `null` locale lets Flutter resolve against [supportedLocales], so a
      // Bengali device opens in Bengali before the user chooses anything.
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: AppRouter.onGenerateRoute,
      home: const BootstrapGate(),
    );
  }
}
