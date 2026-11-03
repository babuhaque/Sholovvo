import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sholovvo_app/app/app_shell.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/app_theme.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/presentation/login_screen.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_screen.dart';
import 'package:sholovvo_app/features/home/application/home_providers.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/features/profile/application/profile_photo_providers.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_edit_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_photo_sheet.dart';
import 'package:sholovvo_app/features/settings/presentation/settings_screen.dart';
import 'package:sholovvo_app/features/welcome/presentation/welcome_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_feed.dart';
import '../support/fake_photo_services.dart';
import '../support/fake_profile_repository.dart';

/// Renders the shipped screens to PNG so the light/dark × English/Bengali
/// matrix can actually be *looked at*.
///
/// This is not part of the test suite and is skipped unless
/// `SOLOVVO_VISUAL_REVIEW=1` is set, because it writes files and depends on a
/// Windows system font. Run it with:
///
/// ```
/// $env:SOLOVVO_VISUAL_REVIEW=1; flutter test test/review/visual_review_test.dart
/// ```
///
/// It differs from a golden test in two ways on purpose: it asserts nothing
/// (there is nothing to compare against yet), and it loads a real font. The
/// test renderer's default is a box-drawing placeholder, which is exactly the
/// one thing a Bengali layout review cannot use.
const String _fontFamily = 'ReviewSans';
const String _regularFont = r'C:\Windows\Fonts\Nirmala.ttf';
const String _boldFont = r'C:\Windows\Fonts\NirmalaB.ttf';

/// Icons are a font too, and the test renderer has none. Without this every
/// `Icon` comes out as a hollow box.
String get _iconFont {
  final String root = Platform.environment['FLUTTER_ROOT'] ?? r'C:\flutter';
  return '$root/bin/cache/artifacts/material_fonts/materialicons-regular.otf';
}

/// Phone-sized, so the review sees the layout most users get.
const Size _phone = Size(430, 932);

final GlobalKey _root = GlobalKey();

bool get _enabled =>
    Platform.environment['SOLOVVO_VISUAL_REVIEW'] == '1' &&
    File(_regularFont).existsSync();

Future<void> _loadFonts() async {
  final FontLoader loader = FontLoader(_fontFamily);
  for (final String path in <String>[_regularFont, _boldFont]) {
    loader.addFont(_read(path));
  }
  await loader.load();

  final FontLoader icons = FontLoader('MaterialIcons');
  if (File(_iconFont).existsSync()) {
    icons.addFont(_read(_iconFont));
    await icons.load();
  }
}

Future<ByteData> _read(String path) async {
  return ByteData.view((await File(path).readAsBytes()).buffer);
}

/// The shipped theme with the review font applied, so Bengali shapes and the
/// line heights the real font produces are visible.
///
/// The button themes carry *resolved* text styles built at theme-construction
/// time, so applying a family to `textTheme` alone leaves those labels in the
/// placeholder font. They are patched here for the same reason.
ThemeData _reviewed(ThemeData base) {
  TextStyle? withFamily(TextStyle? style) =>
      style?.copyWith(fontFamily: _fontFamily);

  WidgetStateProperty<TextStyle?>? patch(ButtonStyle? style) {
    final TextStyle? resolved = style?.textStyle?.resolve(<WidgetState>{});
    return WidgetStatePropertyAll<TextStyle?>(withFamily(resolved));
  }

  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: _fontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _fontFamily),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: patch(base.filledButtonTheme.style),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: base.textButtonTheme.style?.copyWith(
        textStyle: patch(base.textButtonTheme.style),
      ),
    ),
    // The app bar carries its own resolved title style, for the same reason the
    // buttons do: it is built at theme-construction time, so `textTheme.apply`
    // never reaches it and the title would render as placeholder boxes.
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: withFamily(base.appBarTheme.titleTextStyle),
      toolbarTextStyle: withFamily(base.appBarTheme.toolbarTextStyle),
    ),
  );
}

Future<PreferencesStore> _pump(
  WidgetTester tester, {
  required Widget home,
  required ThemeMode themeMode,
  required Locale locale,
  FakeAuthRepository? repository,
  Size size = _phone,
  DonorSnapshot? donor,
  UserProfile? profile,
  DonationHistory? history,
  List<NearbyRequestSummary>? requests,
  List<FeedPostPreview>? feed,
  FeedRepository? feedRepository,
  bool? photoConfigured,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues(<String, Object>{
    'solovvo.themeMode': themeMode.name,
    'solovvo.localeCode': locale.languageCode,
  });
  final PreferencesStore store = await PreferencesStore.load();
  final FakeAuthRepository repo = repository ?? FakeAuthRepository();
  addTearDown(repo.dispose);
  final FakeProfileRepository profiles = FakeProfileRepository(
    profile: profile,
    history: history ?? DonationHistory.empty,
  );
  addTearDown(profiles.dispose);

  await tester.pumpWidget(
    RepaintBoundary(
      key: _root,
      child: ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          profileRepositoryProvider.overrideWithValue(profiles),
          preferencesStoreProvider.overrideWithValue(store),
          // Settings reads the flavour to name the build it is showing; without
          // this the screen would throw instead of rendering the About card.
          appConfigProvider.overrideWithValue(
            const AppConfig(flavor: AppFlavor.staging),
          ),
          // Both photo seams are stubbed together, so opening the sheet never
          // reaches a Supabase project or a platform channel.
          if (photoConfigured != null)
            profilePhotoStorageProvider.overrideWithValue(
              FakePhotoStorage(isConfigured: photoConfigured),
            ),
          if (photoConfigured != null)
            photoPickerProvider.overrideWithValue(FakePhotoPicker()),
          if (donor != null) donorSnapshotProvider.overrideWithValue(donor),
          if (requests != null)
            nearbyRequestsProvider.overrideWithValue(requests),
          if (feed != null) feedPreviewProvider.overrideWithValue(feed),
          if (feedRepository != null)
            feedRepositoryProvider.overrideWithValue(feedRepository),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _reviewed(AppTheme.light),
          darkTheme: _reviewed(AppTheme.dark),
          themeMode: themeMode,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: home,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  return store;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(_root));

  // `toImage` needs the real event loop: inside the test's fake-async zone the
  // engine never gets to produce the layer tree, and the future never
  // completes.
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 2);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    final File output = File('build/review/$name.png');
    output.parent.createSync(recursive: true);
    output.writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${output.absolute.path}');
  });
}

void main() {
  setUpAll(_loadFonts);

  group('light/dark x en/bn', () {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final Locale locale in <Locale>[
        const Locale('en'),
        const Locale('bn'),
      ]) {
        final String tag = '${mode.name}-${locale.languageCode}';

        testWidgets('welcome, $tag', (WidgetTester tester) async {
          await _pump(
            tester,
            home: const WelcomeScreen(),
            themeMode: mode,
            locale: locale,
          );
          await _capture(tester, 'welcome-$tag');
        }, skip: !_enabled);

        testWidgets('appearance sheet, $tag', (WidgetTester tester) async {
          await _pump(
            tester,
            home: const WelcomeScreen(),
            themeMode: mode,
            locale: locale,
          );
          await tester.tap(find.byType(AppearanceButton));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          await _capture(tester, 'sheet-$tag');
        }, skip: !_enabled);
      }
    }

    testWidgets('sign-in form with validation errors, dark bn', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: const LoginScreen(),
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
      );
      await tester.tap(find.byType(SolovvoButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _capture(tester, 'login-errors-dark-bn');
    }, skip: !_enabled);

    testWidgets('sign-in form with validation errors, light en', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: const LoginScreen(),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
      );
      await tester.tap(find.byType(SolovvoButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await _capture(tester, 'login-errors-light-en');
    }, skip: !_enabled);
  });

  group('home dashboard', () {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final Locale locale in <Locale>[
        const Locale('en'),
        const Locale('bn'),
      ]) {
        final String tag = '${mode.name}-${locale.languageCode}';

        testWidgets('home, empty, $tag', (WidgetTester tester) async {
          await _pump(
            tester,
            home: const AppShell(user: verifiedUser),
            themeMode: mode,
            locale: locale,
          );
          await _capture(tester, 'home-empty-$tag');
        }, skip: !_enabled);
      }
    }

    testWidgets('home, populated, light en', (WidgetTester tester) async {
      await _pump(
        tester,
        home: const AppShell(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        donor: _donor(),
        requests: _requests(bengali: false),
        feed: _feed(bengali: false),
      );
      await _capture(tester, 'home-populated-light-en');
    }, skip: !_enabled);

    testWidgets('home, populated, dark bn', (WidgetTester tester) async {
      await _pump(
        tester,
        home: const AppShell(user: verifiedUser),
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
        donor: _donor(),
        requests: _requests(bengali: true),
        feed: _feed(bengali: true),
      );
      await _capture(tester, 'home-populated-dark-bn');
    }, skip: !_enabled);

    testWidgets('home, two columns on a tablet, light en', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: const AppShell(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        size: const Size(900, 1100),
        donor: _donor(),
        requests: _requests(bengali: false),
        feed: _feed(bengali: false),
      );
      await _capture(tester, 'home-tablet-light-en');
    }, skip: !_enabled);

    testWidgets('home, narrowest phone, light bn', (WidgetTester tester) async {
      await _pump(
        tester,
        home: const AppShell(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('bn'),
        size: const Size(320, 640),
        donor: _donor(),
        requests: _requests(bengali: true),
        feed: _feed(bengali: true),
      );
      await _capture(tester, 'home-320-light-bn');
    }, skip: !_enabled);
  });

  group('profile', () {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      for (final Locale locale in <Locale>[
        const Locale('en'),
        const Locale('bn'),
      ]) {
        final String tag = '${mode.name}-${locale.languageCode}';

        testWidgets('profile, populated, $tag', (WidgetTester tester) async {
          await _pump(
            tester,
            home: ProfileScreen(user: verifiedUser),
            themeMode: mode,
            locale: locale,
            profile: filledProfile,
            history: sampleHistory(),
          );
          await _capture(tester, 'profile-$tag');
        }, skip: !_enabled);

        testWidgets('profile, empty, $tag', (WidgetTester tester) async {
          await _pump(
            tester,
            home: ProfileScreen(user: verifiedUser),
            themeMode: mode,
            locale: locale,
          );
          await _capture(tester, 'profile-empty-$tag');
        }, skip: !_enabled);
      }
    }

    // Tall enough to hold the whole page rather than the first screenful, so the
    // donation history and its statistics are in the capture too.
    testWidgets('profile, whole page with history, light en', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        size: const Size(430, 1900),
        profile: filledProfile,
        history: sampleHistory(),
      );
      await _capture(tester, 'profile-full-light-en');
    }, skip: !_enabled);

    testWidgets('profile, whole page with history, dark bn', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
        size: const Size(430, 1900),
        profile: filledProfile,
        history: sampleHistory(),
      );
      await _capture(tester, 'profile-full-dark-bn');
    }, skip: !_enabled);

    testWidgets('profile, two columns on a tablet, light en', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        size: const Size(900, 1100),
        profile: filledProfile,
        history: sampleHistory(),
      );
      await _capture(tester, 'profile-tablet-light-en');
    }, skip: !_enabled);

    // The width at which the completion header overflowed before the count was
    // allowed to shrink; captured so a regression is visible, not just failing.
    testWidgets('profile, narrowest phone, light bn', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('bn'),
        size: const Size(320, 640),
        profile: filledProfile,
        history: sampleHistory(),
      );
      await _capture(tester, 'profile-320-light-bn');
      expect(tester.takeException(), isNull);
    }, skip: !_enabled);

    testWidgets('profile edit form, light en', (WidgetTester tester) async {
      await _pump(
        tester,
        home: ProfileEditScreen(user: verifiedUser, initial: filledProfile),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        size: const Size(430, 1900),
        profile: filledProfile,
      );
      await _capture(tester, 'profile-edit-light-en');
    }, skip: !_enabled);

    testWidgets('profile edit form, dark bn', (WidgetTester tester) async {
      await _pump(
        tester,
        home: ProfileEditScreen(user: verifiedUser, initial: filledProfile),
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
        size: const Size(430, 1900),
        profile: filledProfile,
      );
      await _capture(tester, 'profile-edit-dark-bn');
    }, skip: !_enabled);

    // Stage 6: the photo flow. The avatar falls back to initials in these
    // renders because the test renderer answers every network image with 400 —
    // which is also the error path the avatar has to survive, so it is worth
    // seeing. What these captures are for is the control, the sheet and the
    // destructive confirmation, in both languages and both palettes.
    testWidgets('profile with a photo, light en', (WidgetTester tester) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        size: const Size(430, 1900),
        profile: _withPhoto(),
        history: sampleHistory(),
      );
      await _capture(tester, 'profile-with-photo-light-en');
    }, skip: !_enabled);

    testWidgets('photo sheet with removal, light en', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        profile: _withPhoto(),
        photoConfigured: true,
      );
      await _openPhotoSheet(tester);
      await _capture(tester, 'profile-photo-sheet-light-en');
    }, skip: !_enabled);

    testWidgets('photo sheet without removal, dark bn', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
        profile: filledProfile,
        photoConfigured: true,
      );
      await _openPhotoSheet(tester);
      await _capture(tester, 'profile-photo-sheet-dark-bn');
    }, skip: !_enabled);

    testWidgets('photo sheet when storage is not configured, light bn', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('bn'),
        profile: filledProfile,
        photoConfigured: false,
      );
      await _openPhotoSheet(tester);
      await _capture(tester, 'profile-photo-unconfigured-light-bn');
    }, skip: !_enabled);

    testWidgets('removing a photo asks first, dark en', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: ProfileScreen(user: verifiedUser),
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        profile: _withPhoto(),
        photoConfigured: true,
      );
      await _openPhotoSheet(tester);
      // The third row is "Remove photo" when a photo exists.
      await tester.tap(
        find
            .descendant(
              of: find.byType(ProfilePhotoSheet),
              matching: find.byType(InkWell),
            )
            .last,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _capture(tester, 'profile-photo-remove-confirm-dark-en');
    }, skip: !_enabled);
  });

  // Stage 7. The bar is the whole point of the stage, so it is captured over a
  // populated dashboard in both palettes, plus the tab it switches to and the
  // screen that sign-out moved into. The tablet shot in the group above now
  // shows the rail, because 900px is past the shell's breakpoint.
  group('navigation and settings', () {
    for (final ThemeMode mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
      testWidgets('shell over the dashboard, ${mode.name}', (
        WidgetTester tester,
      ) async {
        await _pump(
          tester,
          home: const AppShell(user: verifiedUser),
          themeMode: mode,
          locale: const Locale('en'),
          donor: _donor(),
          requests: _requests(bengali: false),
          feed: _feed(bengali: false),
          profile: filledProfile,
        );
        await _capture(tester, 'shell-home-${mode.name}');
      }, skip: !_enabled);
    }

    testWidgets('shell on the second tab, light bn', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        home: const AppShell(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('bn'),
        profile: filledProfile,
        history: sampleHistory(),
      );
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('প্রোফাইল'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await _capture(tester, 'shell-profile-light-bn');
    }, skip: !_enabled);

    testWidgets('settings, light en', (WidgetTester tester) async {
      await _pump(
        tester,
        home: const SettingsScreen(user: verifiedUser),
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        size: const Size(430, 1200),
      );
      await _capture(tester, 'settings-light-en');
    }, skip: !_enabled);

    testWidgets('settings, dark bn', (WidgetTester tester) async {
      await _pump(
        tester,
        home: const SettingsScreen(user: verifiedUser),
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
        size: const Size(430, 1200),
      );
      await _capture(tester, 'settings-dark-bn');
    }, skip: !_enabled);
  });

  // Stage 8.2. The feed is the stage's whole surface, so it is captured
  // populated in both palettes, at the wide measure, empty, and when the read
  // fails. Every shot is seeded through the repository seam, which is the same
  // seam the widget tests use — no production code carries a sample post.
  //
  // Pictures are seeded on the wide shot only, and they draw the tile's
  // broken-image glyph rather than a photo: the test renderer answers every
  // network image with 400. The Stage 6 profile render has the same limitation
  // and shows the initials avatar where the photograph would be.
  group('feed', () {
    testWidgets('feed, populated, light en', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        posts: _feedPosts(bengali: false),
      );
      await _capture(tester, 'feed-light-en');
    }, skip: !_enabled);

    testWidgets('feed, populated, dark bn', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        themeMode: ThemeMode.dark,
        locale: const Locale('bn'),
        posts: _feedPosts(bengali: true),
      );
      await _capture(tester, 'feed-dark-bn');
    }, skip: !_enabled);

    testWidgets('feed, wide measure with images, light en', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(
        tester,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        posts: _feedPosts(bengali: false, withImages: true),
        size: const Size(1000, 1300),
      );
      await _capture(tester, 'feed-wide-light-en');
    }, skip: !_enabled);

    testWidgets('feed, empty, light en', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        themeMode: ThemeMode.light,
        locale: const Locale('en'),
        posts: <Post>[],
      );
      await _capture(tester, 'feed-empty-light-en');
    }, skip: !_enabled);

    testWidgets('feed, read failed, dark en', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        themeMode: ThemeMode.dark,
        locale: const Locale('en'),
        failure: const NetworkFailure(debugMessage: 'offline'),
      );
      await _capture(tester, 'feed-error-dark-en');
    }, skip: !_enabled);
  });
}

/// Mounts the feed over a seeded repository, pushed above an empty dashboard.
///
/// The push is what makes the render truthful: mounted as `home:` the screen
/// would draw its app bar without a back arrow, and the feed is never the bottom
/// of the stack in the app. The extra pumps let the route transition finish and
/// the screen's post-frame first read resolve; `_pump` alone stops one frame
/// short of the populated state.
Future<void> _pumpFeed(
  WidgetTester tester, {
  required ThemeMode themeMode,
  required Locale locale,
  List<Post> posts = const <Post>[],
  Failure? failure,
  Size size = const Size(430, 1400),
}) async {
  final FakeFeedRepository repository = FakeFeedRepository(posts: posts);
  repository.failure = failure;

  await _pump(
    tester,
    home: const _PushedFeed(),
    themeMode: themeMode,
    locale: locale,
    feedRepository: repository,
    size: size,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
  await tester.pump();
}

/// Pushes [FeedScreen] onto an otherwise empty first route once mounted.
class _PushedFeed extends StatefulWidget {
  const _PushedFeed();

  @override
  State<_PushedFeed> createState() => _PushedFeedState();
}

class _PushedFeedState extends State<_PushedFeed> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) return;
      Navigator.of(context).push(FeedScreen.route());
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Four posts, in the language the capture is made in.
///
/// Timestamps are relative to the moment of capture so the labels show the
/// minute/minute/hour/day branches rather than one calendar date repeated.
List<Post> _feedPosts({required bool bengali, bool withImages = false}) {
  final DateTime now = DateTime.now();
  const List<String> pictures = <String>[
    'https://example.test/post-1.jpg',
    'https://example.test/post-2.jpg',
    'https://example.test/post-3.jpg',
    'https://example.test/post-4.jpg',
  ];

  return <Post>[
    fakePost(
      id: 'post-1',
      authorName: bengali ? 'আয়েশা রহমান' : 'Ayesha Rahman',
      text: bengali
          ? 'আজ ঢাকা মেডিকেলে রক্ত দিলাম। চার ঘণ্টা চেয়ারে, একটা ব্যাগ, আর ' *
                6
          : 'Donated a unit at Dhaka Medical today. Four hours in the chair, '
                    'one bag, and a stranger gets their evening back. ' *
                6,
      likeCount: 12,
      commentCount: 3,
      createdAt: now.subtract(const Duration(minutes: 40)),
    ),
    fakePost(
      id: 'post-2',
      authorName: bengali ? 'রফিক হাসান' : 'Rafiq Hasan',
      text: bengali
          ? 'আমার বোনের জন্য O- রক্ত খুঁজছি। মিরপুরে ভর্তি, হাসপাতালে ব্যাগ নেই।'
          : 'Looking for O- for my sister. She is admitted in Mirpur and the '
                'hospital has none today.',
      imageUrls: withImages ? pictures : const <String>[],
      likeCount: 4,
      createdAt: now.subtract(const Duration(hours: 3)),
    ),
    fakePost(
      id: 'post-3',
      authorName: bengali ? 'নুসরাত জাহান' : 'Nusrat Jahan',
      text: bengali
          ? 'প্রথমবার রক্ত দিলাম। ভয় পেয়েছিলাম, কিন্তু কিছুই হয়নি।'
          : 'First time donating. I was nervous and it was fine. The tea '
                'afterwards is the real reward.',
      likeCount: 27,
      commentCount: 9,
      createdAt: now.subtract(const Duration(hours: 20)),
    ),
    fakePost(
      id: 'post-4',
      authorName: bengali ? 'তানভীর আহমেদ' : 'Tanvir Ahmed',
      text: bengali
          ? 'আজ রক্তদান শিবিরে ৪২ ইউনিট সংগ্রহ হয়েছে।'
          : 'Forty-two units at the camp today. Thank you to everyone who '
                'queued in the rain.',
      imageUrls: withImages ? pictures.sublist(0, 1) : const <String>[],
      likeCount: 51,
      commentCount: 14,
      createdAt: now.subtract(const Duration(days: 4)),
    ),
  ];
}

/// A profile whose photo points at an object in the `avatars` bucket.
UserProfile _withPhoto() {
  return filledProfile.withPhoto(
    'https://demo.supabase.co/storage/v1/object/public/avatars/'
    'uid-verified/avatar-1730000000000.jpg',
  );
}

/// Taps the donor card's photo button and lets the sheet come up.
Future<void> _openPhotoSheet(WidgetTester tester) async {
  final Finder button = find.descendant(
    of: find.byType(ProfileIdentityCard),
    matching: find.byType(TextButton),
  );
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// A donor who has filled their profile in, for the populated renders.
DonorSnapshot _donor() {
  return DonorSnapshot(
    bloodGroup: 'O+',
    lastDonationAt: DateTime(2026, 3, 3),
    isAvailable: true,
    donationCount: 3,
  );
}

/// Two open requests, in the language the capture is made in: a donor reads
/// their own community's posts in their own language, so the seed data follows
/// the locale.
List<NearbyRequestSummary> _requests({required bool bengali}) {
  return <NearbyRequestSummary>[
    NearbyRequestSummary(
      id: 'req-1',
      bloodGroup: 'B+',
      area: bengali ? 'ধানমন্ডি' : 'Dhanmondi',
      neededBy: DateTime(2026, 11, 9),
      units: 2,
    ),
    NearbyRequestSummary(
      id: 'req-2',
      bloodGroup: 'O-',
      area: bengali ? 'মিরপুর' : 'Mirpur',
      neededBy: DateTime(2026, 11, 4),
      units: 1,
    ),
  ];
}

List<FeedPostPreview> _feed({required bool bengali}) {
  return <FeedPostPreview>[
    FeedPostPreview(
      id: 'post-1',
      authorName: bengali ? 'আয়েশা রহমান' : 'Ayesha Rahman',
      excerpt: bengali
          ? 'আজ ঢাকা মেডিকেলে রক্ত দিলাম।'
          : 'Donated at Dhaka Medical today.',
      createdAt: DateTime(2026, 10, 20),
    ),
    FeedPostPreview(
      id: 'post-2',
      authorName: bengali ? 'রফিক হাসান' : 'Rafiq Hasan',
      excerpt: bengali
          ? 'আমার বোনের জন্য O- রক্ত খুঁজছি।'
          : 'Looking for O- for my sister.',
      createdAt: DateTime(2026, 10, 18),
    ),
  ];
}
