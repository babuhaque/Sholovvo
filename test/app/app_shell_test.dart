import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/app_shell.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_header.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/settings/presentation/settings_screen.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_profile_repository.dart';
import '../support/test_app.dart';

const Size _phone = Size(430, 932);

/// Past [AppShell.railBreakpoint], where the bar becomes a rail.
const Size _tablet = Size(900, 1100);

/// Mounts the shell with both of its tabs satisfied by fakes.
///
/// Both tabs are built at once, so the profile's seams are overridden here even
/// in the tests that only look at the dashboard: a test that forgot them would
/// fail on a Firestore call rather than on the tab it was checking.
Future<void> _pumpShell(
  WidgetTester tester, {
  Size size = _phone,
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeAuthRepository auth = FakeAuthRepository(initialUser: verifiedUser);
  addTearDown(auth.dispose);
  final FakeProfileRepository profiles = FakeProfileRepository(
    profile: filledProfile,
    history: DonationHistory.empty,
  );
  addTearDown(profiles.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
        // Reached only by the test that walks into Settings from the gear. It
        // throws by default, on purpose, so leaving it out would make the
        // failure look like a navigation bug.
        appConfigProvider.overrideWithValue(
          const AppConfig(flavor: AppFlavor.development),
        ),
      ],
      child: testApp(
        home: const AppShell(user: verifiedUser),
        locale: locale,
      ),
    ),
  );
  // The soft glow behind both tabs never settles, so `pumpAndSettle` would hang.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

/// Which tab the shell is showing, read from the stack it keeps both in.
int? _visibleTab(WidgetTester tester) {
  return tester.widget<IndexedStack>(find.byType(IndexedStack)).index;
}

/// Switches to the Profile tab the way a donor does, from the bar.
Future<void> _openProfileTab(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('Profile'),
    ),
  );
  await tester.pump();
}

/// Whether the shell lets a system back press through to the navigator.
bool _canPop(WidgetTester tester) {
  final Finder scope = find.descendant(
    of: find.byType(AppShell),
    matching: find.byType(PopScope<Object?>),
  );
  return tester.widget<PopScope<Object?>>(scope).canPop;
}

/// Presses the Android system back button.
///
/// Routed through the binding rather than the navigator so the test travels the
/// path the platform takes: message → binding → navigator → the topmost route's
/// `PopScope`. A test that called `maybePop` directly would still pass if the
/// scope were registered on the wrong route.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  group('AppShell on a phone', () {
    testWidgets('opens on the dashboard with a bar under it', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);

      expect(find.byType(IndexedStack), findsOneWidget);
      expect(_visibleTab(tester), ShellTab.home.index);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      // The dashboard is the destination, not a screen pushed over one.
      expect(find.byType(HomeHeader), findsOneWidget);
    });

    testWidgets('the bar switches to the profile tab', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pump();

      expect(_visibleTab(tester), ShellTab.profile.index);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        ShellTab.profile.index,
      );
    });

    testWidgets('the profile tab offers no back arrow', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Profile'),
        ),
      );
      await tester.pump();

      // A tab has nothing behind it; the arrow would pop the shell itself.
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('the dashboard header hands the profile tab over', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);

      final Finder avatar = find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byType(InitialsAvatar),
      );
      expect(
        tester.widget<InitialsAvatar>(avatar).name,
        filledProfile.displayName,
      );

      await tester.tap(avatar);
      await tester.pump();

      expect(_visibleTab(tester), ShellTab.profile.index);
    });

    testWidgets('the destinations are named in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, locale: const Locale('bn'));

      final Finder bar = find.byType(NavigationBar);
      expect(
        find.descendant(of: bar, matching: find.text('হোম')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('প্রোফাইল')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('a narrow phone fits the bar without an overflow', (
      WidgetTester tester,
    ) async {
      // The tightest width the brief has to look right at, in the longer of the
      // two languages.
      await _pumpShell(
        tester,
        size: const Size(320, 640),
        locale: const Locale('bn'),
      );

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('AppShell on a wide window', () {
    testWidgets('swaps the bar for a rail', (WidgetTester tester) async {
      await _pumpShell(tester, size: _tablet);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets('the rail navigates the same two destinations', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester, size: _tablet);

      await tester.tap(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text('Profile'),
        ),
      );
      await tester.pump();

      expect(_visibleTab(tester), ShellTab.profile.index);
    });
  });

  // The back button is the only navigation this stage did not get from a
  // widget. Left alone it pops the route, and the shell's route is the app's
  // root, so a press while the Profile tab was showing would close the app.
  group('system back', () {
    testWidgets('on the profile tab it returns to the dashboard', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);
      await _openProfileTab(tester);
      expect(_visibleTab(tester), ShellTab.profile.index);

      // Blocked, so the press cannot close the app while a later tab shows.
      expect(_canPop(tester), isFalse);

      await _pressBack(tester);

      expect(_visibleTab(tester), ShellTab.home.index);
      expect(find.byType(AppShell), findsOneWidget);
      // And the press is left to the system again, now that Home is showing.
      expect(_canPop(tester), isTrue);
    });

    testWidgets('on the dashboard it is left to the system', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);

      expect(_canPop(tester), isTrue);
      await _pressBack(tester);

      // Nothing in the shell consumed it: no tab change, the app is still here.
      expect(_visibleTab(tester), ShellTab.home.index);
      expect(find.byType(AppShell), findsOneWidget);
    });

    testWidgets('from settings it pops the route and keeps the profile tab', (
      WidgetTester tester,
    ) async {
      await _pumpShell(tester);
      await _openProfileTab(tester);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(SettingsScreen), findsOneWidget);

      await _pressBack(tester);

      // Back closes Settings and stops there. A shell-level handler that fired
      // regardless of the pushed route would also drop the donor on the
      // dashboard, which is the regression this test exists to catch.
      expect(find.byType(SettingsScreen), findsNothing);
      expect(_visibleTab(tester), ShellTab.profile.index);
    });
  });
}
