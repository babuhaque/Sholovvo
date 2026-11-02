import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_edit_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_availability_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_completion_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_details_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_privacy_card.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/test_app.dart';

/// Tall enough that the whole profile is laid out without scrolling, so a tap
/// near the bottom lands on the control it names.
const Size _tallPhone = Size(430, 2400);

/// The narrowest width the brief still has to look right at.
const Size _narrowPhone = Size(320, 900);

/// Above [ProfileScreen.twoColumnBreakpoint], where the cards pair up.
const Size _tablet = Size(900, 1400);

/// Mounts the profile screen for the signed-in account, with the repository
/// stubbed at its provider seam.
///
/// The default fake has **no** profile document, which is what a newly
/// registered account actually has — so the empty state is the default here too.
Future<FakeProfileRepository> _pumpProfile(
  WidgetTester tester, {
  UserProfile? profile,
  DonationHistory? history,
  Failure? streamFailure,
  FakeProfileRepository? repository,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
  Size size = _tallPhone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeProfileRepository repo =
      repository ??
      FakeProfileRepository(
        profile: profile,
        history: history ?? DonationHistory.empty,
      );
  repo.streamFailure = streamFailure;
  addTearDown(repo.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [profileRepositoryProvider.overrideWithValue(repo)],
      child: testApp(
        home: ProfileScreen(user: verifiedUser),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );
  // `pumpAndSettle` would never return: the soft glow behind the screen
  // animates forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return repo;
}

/// Taps a control that may start below the fold, the way a user would reach it.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// The availability switch specifically — there are two switches on this
/// screen and they write different documents.
Finder get _availabilitySwitch => find.descendant(
  of: find.byType(ProfileAvailabilityCard),
  matching: find.byType(Switch),
);

/// The publication switch.
Finder get _privacySwitch => find.descendant(
  of: find.byType(ProfilePrivacyCard),
  matching: find.byType(Switch),
);

/// The colour a card actually paints, read off its decoration rather than
/// assumed from the theme.
Color? _cardColor(WidgetTester tester, Finder card) {
  final Finder decoration = find
      .descendant(of: card, matching: find.byType(DecoratedBox))
      .first;
  return (tester.widget<DecoratedBox>(decoration).decoration as BoxDecoration)
      .color;
}

void main() {
  group('ProfileScreen with no document yet', () {
    testWidgets('offers to create the profile instead of inventing a donor', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester);

      expect(find.text(english.profileNotSetCtaTitle), findsOneWidget);
      expect(find.text(english.profileNotSetCtaBody), findsOneWidget);
      // No donor card over data that does not exist.
      expect(find.byType(ProfileIdentityCard), findsNothing);
      expect(find.byType(ProfileDetailsCard), findsNothing);
      expect(find.text(english.notSetYet), findsNothing);
      expect(find.text('O+'), findsNothing);
    });

    testWidgets('editing is enabled as soon as the screen knows there is no '
        'document', (WidgetTester tester) async {
      await _pumpProfile(tester);

      final TextButton edit = tester.widget<TextButton>(
        find.widgetWithText(TextButton, english.profileEditAction).first,
      );
      expect(edit.onPressed, isNotNull);
    });

    testWidgets('the create action opens the form, seeded with the sign-in '
        'name only', (WidgetTester tester) async {
      await _pumpProfile(tester);

      await _tapVisible(
        tester,
        find.widgetWithText(SolovvoButton, english.profileAddDetails),
      );

      expect(find.byType(ProfileEditScreen), findsOneWidget);
      // The name came from the account, not from an invented profile.
      expect(find.text('Ayesha Rahman'), findsOneWidget);
    });
  });

  group('ProfileScreen with a profile', () {
    testWidgets('shows the donor card, the details and the privacy split', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, profile: filledProfile);

      // Donor card: what other donors see.
      expect(find.byType(ProfileIdentityCard), findsOneWidget);
      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('O+'), findsOneWidget);
      expect(find.text(english.verified), findsOneWidget);
      expect(find.text(english.profileEmailManaged), findsWidgets);

      // Personal details, including the ones that are private.
      expect(find.byType(ProfileDetailsCard), findsOneWidget);
      expect(find.text('01712345678'), findsOneWidget);
      expect(find.text('House 12, Road 5'), findsOneWidget);
      expect(find.text(english.profileGenderFemale), findsOneWidget);
      // Phone, address, date of birth and gender each carry the marker.
      expect(find.text(english.profileContactPrivateBadge), findsNWidgets(4));
      expect(find.text(english.profilePrivacyPrivateTitle), findsWidgets);
    });

    testWidgets('counts completion from the fields that are really filled in', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, profile: filledProfile);

      expect(
        find.text(english.profileCompletionCount(5, 7)),
        findsOneWidget,
        reason: 'photo and date of birth are still missing',
      );
      expect(find.text(english.profileFieldPhoto), findsOneWidget);
      expect(find.text(english.profileDobLabel), findsWidgets);
      expect(find.text(english.profileCompletionAllDone), findsNothing);
    });

    testWidgets('lists only the fields a partial profile is missing', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, profile: partialProfile);

      expect(find.text(english.profileCompletionCount(3, 7)), findsOneWidget);
      expect(find.text(english.profileFieldPhoto), findsOneWidget);
      expect(find.text(english.profileAreaLabel), findsWidgets);
      expect(find.text(english.profilePhoneLabel), findsWidgets);
      // Gender is filled in, so it must not be listed as missing.
      expect(
        find.descendant(
          of: find.byType(ProfileCompletionCard),
          matching: find.text(english.profileGenderLabel),
        ),
        findsNothing,
      );
    });
  });

  group('ProfileScreen availability', () {
    testWidgets('the switch writes the donor\'s own flag', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpProfile(
        tester,
        profile: filledProfile,
      );
      expect(find.text(english.availableNow), findsOneWidget);

      await _tapVisible(tester, _availabilitySwitch);

      expect(repo.availabilityCalls, 1);
      expect(repo.lastAvailability, isFalse);
      expect(find.text(english.notAvailableNow), findsOneWidget);
      expect(find.text(english.profileAvailabilityOffBody), findsOneWidget);
    });

    testWidgets('a rejected write is reported and the flag is not moved', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpProfile(
        tester,
        profile: filledProfile,
      );
      repo.availabilityFailure = const NetworkFailure(debugMessage: 'offline');

      await _tapVisible(tester, _availabilitySwitch);

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text(english.failureNetwork), findsOneWidget);
      // Not optimistic: the switch still reads the stored value.
      expect(tester.widget<Switch>(_availabilitySwitch).value, isTrue);
    });

    testWidgets('warns when "on" cannot be matched without a blood group', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        profile: const UserProfile(
          uid: 'uid-verified',
          displayName: 'Ayesha Rahman',
        ),
      );

      expect(find.text(english.profileAvailabilityNeedsGroup), findsOneWidget);
    });
  });

  group('ProfileScreen privacy', () {
    testWidgets('withdrawing publication saves the whole profile', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpProfile(
        tester,
        profile: filledProfile,
      );
      expect(tester.widget<Switch>(_privacySwitch).value, isTrue);

      await _tapVisible(tester, _privacySwitch);

      // Withdrawing has to delete the public copy of the area, which only the
      // full write knows how to do.
      expect(repo.saveCalls, 1);
      expect(repo.lastSaved?.publishAreaInSearch, isFalse);
      expect(repo.lastSaved?.area, filledProfile.area);
      expect(tester.widget<Switch>(_privacySwitch).value, isFalse);
    });

    testWidgets('cannot publish an area that is not set', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpProfile(
        tester,
        profile: partialProfile,
      );

      expect(tester.widget<Switch>(_privacySwitch).onChanged, isNull);

      await _tapVisible(tester, _privacySwitch);
      expect(repo.saveCalls, 0);
    });

    testWidgets('says that phone and address are always private', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, profile: filledProfile);

      expect(find.text(english.profilePrivacyPrivateBody), findsOneWidget);
    });
  });

  group('ProfileScreen donation history', () {
    testWidgets('an empty history says so and shows no statistics', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, profile: filledProfile);

      expect(find.text(english.profileHistoryEmptyTitle), findsOneWidget);
      expect(find.text(english.profileHistoryEmptyBody), findsOneWidget);
      // No statistic over a history that does not exist: not even a zero.
      expect(find.textContaining('Last donation'), findsNothing);
      expect(find.text(english.profileHistoryCount(2)), findsNothing);
      expect(find.text(english.profileHistoryConfirmed), findsNothing);
    });

    testWidgets('counts confirmed donations only and lists pending ones', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        profile: filledProfile,
        history: sampleHistory(),
      );

      expect(
        find.text(english.profileHistoryCount(2)),
        findsOneWidget,
        reason: 'three records, two of them confirmed',
      );
      expect(find.text(english.profileHistoryConfirmed), findsNWidgets(2));
      expect(find.text(english.profileHistoryPending), findsOneWidget);
      expect(find.text('Square Hospital'), findsOneWidget);
      expect(find.text('United Hospital'), findsOneWidget);
      expect(find.text(english.profileHistoryEmptyTitle), findsNothing);
    });

    testWidgets('a failed history read is reported with a retry', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = FakeProfileRepository(
        profile: filledProfile,
      );
      // Configured before the first frame: a read that failed is not the same
      // state as a read that has not happened.
      repo.historyFailure = const NetworkFailure(debugMessage: 'offline');
      await _pumpProfile(tester, repository: repo);

      expect(find.text(english.profileHistoryErrorTitle), findsOneWidget);
      expect(find.text(english.profileHistoryEmptyTitle), findsNothing);

      // The retry re-reads the collection rather than the cached failure.
      repo.historyFailure = null;
      await _tapVisible(tester, find.text(english.tryAgain));

      expect(repo.historyCalls, 2);
      expect(find.text(english.profileHistoryErrorTitle), findsNothing);
      expect(find.text(english.profileHistoryEmptyTitle), findsOneWidget);
    });
  });

  group('ProfileScreen failure states', () {
    testWidgets('a failed profile read is reported, not shown as "no profile"', (
      WidgetTester tester,
    ) async {
      final FakeProfileRepository repo = await _pumpProfile(
        tester,
        streamFailure: const NetworkFailure(debugMessage: 'offline'),
      );

      expect(find.text(english.profileLoadErrorTitle), findsOneWidget);
      expect(find.text(english.failureNetwork), findsOneWidget);
      // The one thing it must not do is claim the account has no profile.
      expect(find.text(english.profileNotSetCtaTitle), findsNothing);
      expect(find.byType(ProfileIdentityCard), findsNothing);

      repo
        ..streamFailure = null
        ..profile = filledProfile;
      await _tapVisible(tester, find.text(english.tryAgain));

      expect(find.byType(ProfileIdentityCard), findsOneWidget);
      expect(find.text(english.profileLoadErrorTitle), findsNothing);
    });
  });

  group('ProfileScreen in Bengali', () {
    testWidgets('renders every card in Bangla with Bengali numerals', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        profile: filledProfile,
        locale: const Locale('bn'),
      );

      expect(find.text(bangla.profileTitle), findsOneWidget);
      expect(find.text(bangla.profileSectionDetails), findsOneWidget);
      expect(find.text(bangla.profileSectionPrivacy), findsOneWidget);
      expect(find.text(bangla.profileSectionHistory), findsOneWidget);
      expect(
        find.text(bangla.profileCompletionCount(5, 7)),
        findsOneWidget,
      );
      // The count has to use the digits of the language it is written in.
      expect(find.textContaining(RegExp(r'[০-৯]')), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ProfileScreen layout', () {
    testWidgets('stacks the cards on the narrowest phone without overflowing', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        profile: filledProfile,
        history: sampleHistory(),
        size: _narrowPhone,
        locale: const Locale('bn'),
      );

      expect(tester.takeException(), isNull);
      final Offset identity = tester.getTopLeft(
        find.byType(ProfileIdentityCard),
      );
      final Offset details = tester.getTopLeft(find.byType(ProfileDetailsCard));

      // One column: same left edge, one card under the other.
      expect(details.dx, closeTo(identity.dx, 1));
      expect(details.dy, greaterThan(identity.dy));
    });

    testWidgets('pairs the cards from the 720 dp breakpoint', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        profile: filledProfile,
        history: sampleHistory(),
        size: _tablet,
      );

      final Offset identity = tester.getTopLeft(
        find.byType(ProfileIdentityCard),
      );
      final Offset details = tester.getTopLeft(find.byType(ProfileDetailsCard));
      final Size identitySize = tester.getSize(
        find.byType(ProfileIdentityCard),
      );

      // Two columns: the details start to the right, within the vertical span
      // of the first card rather than below it.
      expect(details.dx, greaterThan(identity.dx));
      expect(details.dy, lessThan(identity.dy + identitySize.height));
    });
  });

  group('ProfileScreen theme', () {
    testWidgets('paints its cards from the dark palette', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(
        tester,
        profile: filledProfile,
        themeMode: ThemeMode.dark,
      );

      expect(
        _cardColor(tester, find.byType(ProfileIdentityCard)),
        SolovvoPalette.dark.surface,
      );
      expect(
        _cardColor(tester, find.byType(ProfileIdentityCard)),
        isNot(SolovvoPalette.light.surface),
      );
    });

    testWidgets('paints its cards from the light palette', (
      WidgetTester tester,
    ) async {
      await _pumpProfile(tester, profile: filledProfile);

      expect(
        _cardColor(tester, find.byType(ProfileIdentityCard)),
        SolovvoPalette.light.surface,
      );
    });
  });
}
