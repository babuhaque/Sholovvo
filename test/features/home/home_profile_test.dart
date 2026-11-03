import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_header.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

/// Mounts the dashboard with the profile seam wired to a fake, the way the real
/// repository is wired in the app.
///
/// [donor] stays null unless a test stubs it, so the donor strip is exercised
/// through [donorSnapshotProvider]'s real projection over the profile and the
/// donation history — which is the seam this stage had to fill.
Future<FakeProfileRepository> _pumpHome(
  WidgetTester tester, {
  AuthUser user = verifiedUser,
  UserProfile? profile,
  DonationHistory? history,
  VoidCallback? onOpenProfile,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeAuthRepository repo = FakeAuthRepository(initialUser: user);
  addTearDown(repo.dispose);
  final FakeProfileRepository profiles = FakeProfileRepository(
    profile: profile,
    history: history ?? DonationHistory.empty,
  );
  addTearDown(profiles.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        profileRepositoryProvider.overrideWithValue(profiles),
        // The dashboard previews the community, so it reads the feed on mount.
        // An empty fake is the state this file is not about, and it is the one
        // that keeps the read away from Firestore.
        feedRepositoryProvider.overrideWithValue(FakeFeedRepository()),
      ],
      child: testApp(
        home: HomeScreen(
          user: user,
          onOpenProfile: onOpenProfile ?? () {},
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return profiles;
}

void main() {
  group('the dashboard reads the profile', () {
    testWidgets('the donor strip is built from the profile and its history', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        profile: filledProfile,
        history: sampleHistory(),
      );

      final String lastDonation = MaterialLocalizations.of(
        tester.element(find.byType(HomeScreen)),
      ).formatShortMonthDay(DateTime(2026, 9, 12));

      expect(find.text('O+'), findsOneWidget);
      expect(find.text(lastDonation), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('2 donations'), findsOneWidget);
      // Nothing is unknown any more, so no placeholder is left over.
      expect(find.text('Not set yet'), findsNothing);
    });

    testWidgets('a profile with no donations does not invent a count', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, profile: filledProfile);

      expect(find.text('O+'), findsOneWidget);
      expect(find.text('No donations yet'), findsOneWidget);
      expect(find.text('0 donations'), findsNothing);
    });

    testWidgets('the strip follows a change to the profile', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository profiles = await _pumpHome(
        tester,
        profile: filledProfile,
      );
      expect(find.text('Available'), findsOneWidget);

      profiles.emit(filledProfile.copyWith(isAvailable: false));
      // One frame for the stream event, one for the rebuild it causes.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Available'), findsNothing);
    });

    testWidgets('an account with no profile keeps the honest empty strip', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);

      expect(find.text('Not set yet'), findsNWidgets(3));
      expect(find.text('No donations yet'), findsNothing);
    });
  });

  group('the dashboard greeting', () {
    testWidgets('prefers the name on the profile over the sign-in name', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        // The account was registered as one thing and the profile says another;
        // the profile is what the donor maintains.
        user: const AuthUser(
          uid: 'uid-verified',
          email: 'ayesha@solovvo.app',
          displayName: 'Rafiq Hasan',
          isEmailVerified: true,
        ),
        profile: filledProfile,
      );

      expect(find.text('Welcome, Ayesha'), findsOneWidget);
      expect(find.text('Welcome, Rafiq'), findsNothing);
    });

    testWidgets('falls back to the account name while there is no profile', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);

      expect(find.text('Welcome, Ayesha'), findsOneWidget);
    });
  });

  group('the header profile entry point', () {
    testWidgets('shows the donor\'s initials', (WidgetTester tester) async {
      await _pumpHome(tester, profile: filledProfile);

      final Finder avatar = find.descendant(
        of: find.byType(HomeHeader),
        matching: find.byType(InitialsAvatar),
      );
      expect(avatar, findsOneWidget);
      expect(
        tester.widget<InitialsAvatar>(avatar).name,
        filledProfile.displayName,
      );
      expect(tester.takeException(), isNull);
    });

    // The tap used to push a route from here. Since the profile is a tab of the
    // shell, the dashboard asks its host to switch tabs instead, so this test
    // pins the hand-off and the shell's own suite pins what happens next.
    testWidgets('asks its host to show the profile', (
      WidgetTester tester,
    ) async {
      int opened = 0;
      await _pumpHome(
        tester,
        profile: filledProfile,
        onOpenProfile: () => opened++,
      );

      await tester.tap(
        find.descendant(
          of: find.byType(HomeHeader),
          matching: find.byType(InitialsAvatar),
        ),
      );
      await tester.pump();

      expect(opened, 1);
    });
  });
}
