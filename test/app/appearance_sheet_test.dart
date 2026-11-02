import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A miniature `SolovvoApp`: the same providers in the same `MaterialApp`
/// slots, so the sheet can be tested without the splash screen, Firebase or a
/// signed-in session in the way.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(themeModeProvider),
      locale: ref.watch(localeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: AppearanceButton(),
          ),
        ),
      ),
    );
  }
}

/// [locale] is the *stored* choice; `null` means the user follows the device,
/// which is the state the sheet has to resolve correctly.
Future<PreferencesStore> _pumpHost(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.system,
  Locale? locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    'solovvo.themeMode': themeMode.name,
    if (locale != null) 'solovvo.localeCode': locale.languageCode,
  });
  final PreferencesStore store = await PreferencesStore.load();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [preferencesStoreProvider.overrideWithValue(store)],
      child: const _Host(),
    ),
  );
  return store;
}

/// The bottom sheet slides in, so the first frame finds it off screen.
Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byType(AppearanceButton));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Whether the option with [label] is announced and drawn as the active one.
bool _isSelected(WidgetTester tester, String label) {
  return tester.widgetList<Semantics>(find.byType(Semantics)).any(
    (Semantics node) =>
        node.properties.label == label && node.properties.selected == true,
  );
}

void main() {
  setUp(() => TestWidgetsFlutterBinding.ensureInitialized());

  group('AppearanceSheet', () {
    testWidgets('offers both languages and all three theme modes', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester);
      await _openSheet(tester);

      expect(find.text('Appearance & language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('বাংলা'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);
    });

    testWidgets('marks the active language and theme, not the default', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester, themeMode: ThemeMode.dark);
      await _openSheet(tester);

      expect(_isSelected(tester, 'English'), isTrue);
      expect(_isSelected(tester, 'বাংলা'), isFalse);
      expect(_isSelected(tester, 'Dark'), isTrue);
      expect(_isSelected(tester, 'Light'), isFalse);
      expect(_isSelected(tester, 'System'), isFalse);
    });

    testWidgets('choosing Bengali re-renders the open sheet in Bengali', (
      WidgetTester tester,
    ) async {
      final PreferencesStore store = await _pumpHost(tester);
      await _openSheet(tester);

      await tester.tap(find.text('বাংলা'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The sheet is still open, so the copy around the choices has to switch
      // with them rather than after a reopen.
      expect(find.text('রূপ ও ভাষা'), findsOneWidget);
      expect(find.text('থিম'), findsOneWidget);
      expect(find.text('গাঢ়'), findsOneWidget);
      expect(_isSelected(tester, 'বাংলা'), isTrue);
      expect(store.locale, const Locale('bn'));
    });

    testWidgets('choosing Dark repaints the app behind the sheet', (
      WidgetTester tester,
    ) async {
      final PreferencesStore store = await _pumpHost(tester);
      await _openSheet(tester);

      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      // Themed *through the palette*, not just by flag: the sheet is now
      // reading the dark surface rather than the light one.
      final BuildContext context = tester.element(find.byType(AppearanceSheet));
      expect(context.palette.isDark, isTrue);
      expect(context.palette.surface, SolovvoPalette.dark.surface);
      expect(store.themeMode, ThemeMode.dark);
    });

    testWidgets('choosing Dark repaints the sheet itself, not just behind it', (
      WidgetTester tester,
    ) async {
      await _pumpHost(tester);
      await _openSheet(tester);

      // The colour that actually gets painted under the sheet's content.
      Color? painted() => tester
          .widget<BottomSheet>(find.byType(BottomSheet))
          .backgroundColor;
      expect(painted(), SolovvoPalette.light.surface);

      await tester.tap(find.text('Dark'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // The route paints the sheet background, not the sheet's own content, so
      // a colour captured when the sheet opened survives the switch and leaves
      // pale dark-mode text on a cream card — in the one place users change
      // the theme. It has to come from the theme, which does follow.
      expect(painted(), SolovvoPalette.dark.surface);
    });

    testWidgets('a Bengali device that follows it opens the sheet in Bengali', (
      WidgetTester tester,
    ) async {
      // Nothing stored, so the locale is `null` and Flutter resolves against
      // the device. The sheet must read the *resolved* locale to highlight the
      // right row, otherwise a first launch highlights English.
      // `locales`, not `locale`: localisation resolution reads the list, and
      // setting the singular value leaves the list untouched.
      tester.platformDispatcher.localesTestValue = <Locale>[const Locale('bn')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await _pumpHost(tester, locale: null);
      await _openSheet(tester);

      expect(_isSelected(tester, 'বাংলা'), isTrue);
      expect(_isSelected(tester, 'English'), isFalse);
      expect(find.text('রূপ ও ভাষা'), findsOneWidget);
    });

    testWidgets('stays one sheet wide on a tablet', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpHost(tester);
      await _openSheet(tester);

      // Capped so the two language choices do not end up a hand-width apart.
      expect(tester.getSize(find.byType(AppearanceSheet)).width, lessThanOrEqualTo(520));
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a narrow phone without overflowing', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(280, 653);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpHost(tester);
      await _openSheet(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('বাংলা'), findsOneWidget);
    });
  });
}
