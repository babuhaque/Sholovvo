import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/auth_gate.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';

import 'fake_auth_repository.dart';
import 'fake_profile_repository.dart';
import 'test_app.dart';

/// The app shell with a fake identity backend behind it.
///
/// Defaults to starting at the [AuthGate] — the real entry point — so a test
/// exercises the same route stack the user sees. [locale] and [themeMode] exist
/// so the same harness can assert Bangla copy and the dark palette.
Widget authHarness({
  required FakeAuthRepository repository,
  FakeProfileRepository? profileRepository,
  Widget? home,
  Widget Function(Widget app)? wrap,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  PreferencesStore? preferences,
}) {
  final Widget app = testApp(
    themeMode: themeMode,
    locale: locale,
    onGenerateRoute: AppRouter.onGenerateRoute,
    home: home ?? const AuthGate(),
  );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      // The gate renders the home dashboard, which now reads the profile, so
      // every gate test would otherwise construct `FirebaseFirestore.instance`.
      // A fresh fake has no profile document, which is what an account that has
      // just signed in actually has.
      profileRepositoryProvider.overrideWithValue(
        profileRepository ?? FakeProfileRepository(),
      ),
      if (preferences != null)
        preferencesStoreProvider.overrideWithValue(preferences),
    ],
    child: wrap == null ? app : wrap(app),
  );
}

/// Advances past the two second brand reveal and lets the destination build.
///
/// `pumpAndSettle` is unusable in this app: the floating drop field animates
/// forever, so a settle call would time out rather than wait. The final pump
/// carries a duration on purpose — the reveal's `setState` lands during the
/// frame that completes the animation, so the gate rebuilds on the frame after
/// it, and a zero-duration pump does not get there.
Future<void> passSplash(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AppMotion.splash);
  await tester.pump(const Duration(milliseconds: 100));
}

/// Advances past the route transition used by every pushed auth form.
Future<void> settleRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Pins a phone-sized surface so the form's actions are on screen and tappable.
///
/// The 800x600 default test window is shorter than most phones and would push
/// the primary button of the longer forms below the fold, which would make a tap
/// land on nothing.
void usePhoneSurface(WidgetTester tester, {Size size = const Size(400, 900)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
