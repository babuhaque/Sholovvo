import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:sholovvo_app/features/home/application/home_providers.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/donor_status_card.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_cards.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_header.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_section.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/test_app.dart';

/// A phone, for the tests that only read what is above the fold.
const Size _phone = Size(430, 932);

/// The same width but tall enough that every control is reachable without
/// scrolling, for the tests that tap something near the bottom.
const Size _tallPhone = Size(430, 1600);

/// The narrowest width the brief still has to look right at.
const Size _narrowPhone = Size(320, 640);

/// Above [HomeScreen.twoColumnBreakpoint], where the sections sit side by side.
const Size _tablet = Size(900, 1200);

/// Mounts [HomeScreen] the way the gate does: a signed-in user plus a fake
/// identity backend, so sign-out can be exercised without Firebase.
///
/// The dashboard values are stubbed at their provider seams, which is exactly
/// how the stages that own that data supply it for real. Leaving one null keeps
/// the shipped default, so "no data" is the default here too.
///
/// [profile] is the donor document the header and the donor strip read; it stays
/// `null` unless a test asks for it, which is the state of a new account.
Future<FakeAuthRepository> _pumpHome(
  WidgetTester tester, {
  AuthUser user = verifiedUser,
  DonorSnapshot? donor,
  UserProfile? profile,
  List<NearbyRequestSummary>? requests,
  List<FeedPostPreview>? feed,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('en'),
  Size size = _tallPhone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeAuthRepository repo = FakeAuthRepository(initialUser: user);
  addTearDown(repo.dispose);
  final FakeProfileRepository profiles = FakeProfileRepository(
    profile: profile,
  );
  addTearDown(profiles.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(repo),
        // Watched by the real donor-strip provider when a test does not stub it.
        profileRepositoryProvider.overrideWithValue(profiles),
        if (donor != null) donorSnapshotProvider.overrideWithValue(donor),
        if (requests != null) nearbyRequestsProvider.overrideWithValue(requests),
        if (feed != null) feedPreviewProvider.overrideWithValue(feed),
      ],
      child: testApp(
        home: HomeScreen(user: user),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );
  // `pumpAndSettle` would never return: the soft glow behind the dashboard
  // animates forever.
  await tester.pump();
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

/// The colour a card actually paints, read off its decoration rather than
/// assumed from the theme.
Color? _cardColor(WidgetTester tester, Finder card) {
  final Finder decoration = find
      .descendant(of: card, matching: find.byType(DecoratedBox))
      .first;
  return (tester.widget<DecoratedBox>(decoration).decoration as BoxDecoration)
      .color;
}

/// One open request, as the dashboard would list it.
NearbyRequestSummary _request({
  String bloodGroup = 'B+',
  String area = 'Dhanmondi',
  int units = 2,
}) {
  return NearbyRequestSummary(
    id: 'req-1',
    bloodGroup: bloodGroup,
    area: area,
    neededBy: DateTime(2026, 11, 9),
    units: units,
  );
}

/// One community post, as the dashboard would preview it.
FeedPostPreview _post() {
  return FeedPostPreview(
    id: 'post-1',
    authorName: 'Ayesha Rahman',
    excerpt: 'Donated at Dhaka Medical today.',
    createdAt: DateTime(2026, 10, 20),
  );
}

void main() {
  group('HomeScreen with no data yet', () {
    testWidgets('greets the donor by first name and offers the appearance '
        'control', (WidgetTester tester) async {
      await _pumpHome(tester, size: _phone);

      expect(find.text('Welcome, Ayesha'), findsOneWidget);
      expect(
        find.text('Everything you need to give blood — and to ask for it.'),
        findsOneWidget,
      );
      // The dashboard is signed-in surface: the theme switch has to stay
      // reachable here, not only at the welcome screen.
      expect(find.byType(AppearanceButton), findsOneWidget);
    });

    testWidgets('shows the verified chip only for a confirmed address', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, size: _phone);
      expect(find.byType(VerifiedChip), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      await _pumpHome(tester, user: unverifiedUser, size: _phone);
      expect(find.byType(VerifiedChip), findsNothing);
      expect(find.text('Verified'), findsNothing);
      expect(find.text('Welcome, Rafiq'), findsOneWidget);
    });

    testWidgets('greets a donor who never set a name by their address', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        user: const AuthUser(
          uid: 'uid-nameless',
          email: 'donor@solovvo.app',
          displayName: null,
          isEmailVerified: true,
        ),
        size: _phone,
      );

      expect(find.text('Welcome, donor'), findsOneWidget);
    });

    testWidgets('says "Not set yet" for each fact it does not have', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, size: _phone);

      expect(find.text('Donor status'), findsOneWidget);
      expect(find.text('Blood group'), findsOneWidget);
      expect(find.text('Last donation'), findsOneWidget);
      expect(find.text('Availability'), findsOneWidget);
      // Blood group, last donation, availability — each named, none invented.
      expect(find.text('Not set yet'), findsNWidgets(3));
      // No donation count over a donor whose count is unknown.
      expect(find.textContaining('donations'), findsNothing);
    });

    testWidgets('offers both headline actions, and says they are still to '
        'come', (WidgetTester tester) async {
      await _pumpHome(tester);

      final Finder requestBlood = find.widgetWithText(
        SolovvoButton,
        'Request blood',
      );
      final Finder findDonors = find.widgetWithText(
        SolovvoButton,
        'Find donors',
      );
      expect(requestBlood, findsOneWidget);
      expect(findDonors, findsOneWidget);

      await _tapVisible(tester, requestBlood);
      expect(find.text('Coming soon.'), findsOneWidget);

      await _tapVisible(tester, findDonors);
      expect(find.text('Coming soon.'), findsOneWidget);
    });

    testWidgets('shows one honest empty card per section and no "See all" '
        'over nothing', (WidgetTester tester) async {
      await _pumpHome(tester);

      expect(find.text('Requests near you'), findsOneWidget);
      expect(find.text('From the community'), findsOneWidget);
      expect(find.byType(HomeEmptyCard), findsNWidgets(2));
      expect(find.text('No open requests nearby'), findsOneWidget);
      expect(find.text('No posts yet'), findsOneWidget);
      expect(find.byType(NearbyRequestCard), findsNothing);
      expect(find.byType(FeedPostCard), findsNothing);
      // A link to an empty list would be a link to nothing.
      expect(find.text('See all'), findsNothing);
    });
  });

  group('HomeScreen with data', () {
    testWidgets('renders the donor strip once a snapshot exists', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        size: _phone,
        donor: DonorSnapshot(
          bloodGroup: 'O+',
          lastDonationAt: DateTime(2026, 3, 3),
          isAvailable: true,
          donationCount: 3,
        ),
      );

      // Asserted through the same delegate the card formats with, so the test
      // does not pin an English date pattern.
      final String donationDay = MaterialLocalizations.of(
        tester.element(find.byType(HomeScreen)),
      ).formatShortMonthDay(DateTime(2026, 3, 3));

      expect(find.text('O+'), findsOneWidget);
      expect(find.text(donationDay), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('3 donations'), findsOneWidget);
      expect(find.text('Not set yet'), findsNothing);
    });

    testWidgets('a donor who has never donated reads as such, not as unknown', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        size: _phone,
        donor: const DonorSnapshot(
          bloodGroup: 'AB-',
          isAvailable: false,
          donationCount: 0,
        ),
      );

      expect(find.text('AB-'), findsOneWidget);
      expect(find.text('No donations yet'), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Not set yet'), findsNothing);
      // A zero count is a fact, not an achievement to badge.
      expect(find.text('0 donations'), findsNothing);
    });

    testWidgets('lists a nearby request with only the facts it carries', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, requests: <NearbyRequestSummary>[_request()]);

      final String neededBy = MaterialLocalizations.of(
        tester.element(find.byType(HomeScreen)),
      ).formatShortMonthDay(DateTime(2026, 11, 9));

      expect(find.byType(NearbyRequestCard), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Dhanmondi'), findsOneWidget);
      expect(find.textContaining('2 units needed'), findsOneWidget);
      expect(find.textContaining('Needed by $neededBy'), findsOneWidget);
      // The feed is still empty, so exactly one empty card remains.
      expect(find.byType(HomeEmptyCard), findsOneWidget);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('offers "See all" once there is something to see', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, requests: <NearbyRequestSummary>[_request()]);

      final Finder seeAll = find.text('See all');
      expect(seeAll, findsOneWidget);

      await _tapVisible(tester, seeAll);
      expect(find.text('Coming soon.'), findsOneWidget);
    });

    testWidgets('previews a community post with an initials avatar', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, feed: <FeedPostPreview>[_post()]);

      expect(find.byType(FeedPostCard), findsOneWidget);
      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      expect(find.text('No posts yet'), findsNothing);
      expect(find.text('No open requests nearby'), findsOneWidget);
    });

    testWidgets('counts one unit and one donation in the singular', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        donor: const DonorSnapshot(
          bloodGroup: 'A+',
          isAvailable: true,
          donationCount: 1,
        ),
        requests: <NearbyRequestSummary>[_request(units: 1)],
      );

      // "1 units needed" and "1 donations" would be the giveaway that the
      // catalogue is English-shaped rather than English.
      expect(find.text('1 donation'), findsOneWidget);
      expect(find.text('1 donations'), findsNothing);
      expect(find.textContaining('1 unit needed'), findsOneWidget);
      expect(find.textContaining('1 units'), findsNothing);
    });
  });

  group('HomeScreen layout', () {
    testWidgets('stacks the sections on a phone', (WidgetTester tester) async {
      await _pumpHome(tester, size: _phone);

      final double requests = tester
          .getTopLeft(find.text('Requests near you'))
          .dy;
      final double feed = tester
          .getTopLeft(find.text('From the community'))
          .dy;
      expect(feed, greaterThan(requests));
    });

    testWidgets('puts the sections side by side from the 720 dp breakpoint', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, size: _tablet);

      final double requests = tester
          .getTopLeft(find.text('Requests near you'))
          .dy;
      final double feed = tester
          .getTopLeft(find.text('From the community'))
          .dy;
      expect(feed, closeTo(requests, 1));
    });

    testWidgets('stacks the two actions on a phone and pairs them when wide', (
      WidgetTester tester,
    ) async {
      final Finder requestBlood = find.widgetWithText(
        SolovvoButton,
        'Request blood',
      );
      final Finder findDonors = find.widgetWithText(
        SolovvoButton,
        'Find donors',
      );

      await _pumpHome(tester, size: _phone);
      expect(
        tester.getTopLeft(findDonors).dy,
        greaterThan(tester.getTopLeft(requestBlood).dy),
      );

      await _pumpHome(tester, size: _tablet);
      expect(
        tester.getTopLeft(findDonors).dy,
        closeTo(tester.getTopLeft(requestBlood).dy, 1),
      );
    });

    testWidgets('keeps the three donor values aligned when a Bengali label '
        'wraps at 320 dp', (WidgetTester tester) async {
      await _pumpHome(
        tester,
        size: _narrowPhone,
        locale: const Locale('bn'),
        donor: const DonorSnapshot(
          bloodGroup: 'O+',
          isAvailable: true,
          donationCount: 1,
        ),
      );

      // "সর্বশেষ রক্তদান" needs two lines at 320 dp while the other two labels
      // need one, which is what used to drop the third value out of line.
      final double wrappedLabel = tester
          .getTopLeft(find.text('সর্বশেষ রক্তদান'))
          .dy;
      final double bloodGroup = tester.getTopLeft(find.text('O+')).dy;
      final double availability = tester.getTopLeft(find.text('উপলব্ধ')).dy;

      expect(tester.takeException(), isNull);
      expect(bloodGroup, greaterThan(wrappedLabel));
      expect(availability, closeTo(bloodGroup, 1));
    });

    testWidgets('fits the narrowest phone with a full dashboard, empty', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, size: _narrowPhone);

      expect(tester.takeException(), isNull);
      expect(find.text('Requests near you'), findsOneWidget);
      expect(find.byType(HomeEmptyCard), findsNWidgets(2));
    });

    testWidgets('fits the narrowest phone with a full dashboard, populated', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        size: _narrowPhone,
        donor: DonorSnapshot(
          bloodGroup: 'O+',
          lastDonationAt: DateTime(2026, 3, 3),
          isAvailable: true,
          donationCount: 12,
        ),
        requests: <NearbyRequestSummary>[_request()],
        feed: <FeedPostPreview>[_post()],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(NearbyRequestCard), findsOneWidget);
      expect(find.byType(FeedPostCard), findsOneWidget);
    });
  });

  group('HomeScreen theme', () {
    testWidgets('paints every surface from the dark palette', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, themeMode: ThemeMode.dark);

      expect(
        _cardColor(tester, find.byType(DonorStatusCard)),
        SolovvoPalette.dark.surface,
      );
      expect(
        _cardColor(tester, find.byType(HomeEmptyCard).first),
        SolovvoPalette.dark.surfaceMuted,
      );
      // Not the light values wearing dark text.
      expect(
        _cardColor(tester, find.byType(DonorStatusCard)),
        isNot(SolovvoPalette.light.surface),
      );
    });

    testWidgets('paints every surface from the light palette', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester);

      expect(
        _cardColor(tester, find.byType(DonorStatusCard)),
        SolovvoPalette.light.surface,
      );
      expect(
        _cardColor(tester, find.byType(HomeEmptyCard).first),
        SolovvoPalette.light.surfaceMuted,
      );
    });
  });

  group('HomeScreen in Bengali', () {
    testWidgets('renders the whole dashboard in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, locale: const Locale('bn'));

      expect(find.text('স্বাগতম, Ayesha'), findsOneWidget);
      expect(
        find.text('রক্ত দেওয়া আর রক্ত চাওয়ার সবকিছু এক জায়গায়।'),
        findsOneWidget,
      );
      expect(find.widgetWithText(SolovvoButton, 'রক্তের অনুরোধ'), findsOneWidget);
      expect(find.widgetWithText(SolovvoButton, 'ডোনার খুঁজুন'), findsOneWidget);
      expect(find.text('ডোনার স্ট্যাটাস'), findsOneWidget);
      expect(find.text('এখনো দেওয়া হয়নি'), findsNWidgets(3));
      expect(find.text('আপনার কাছের অনুরোধ'), findsOneWidget);
      expect(find.text('কাছাকাছি কোনো অনুরোধ নেই'), findsOneWidget);
      expect(find.text('কমিউনিটি থেকে'), findsOneWidget);
      expect(find.text('এখনো কোনো পোস্ট নেই'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('writes counts in Bengali numerals, not Western ones', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        locale: const Locale('bn'),
        donor: const DonorSnapshot(
          bloodGroup: 'O+',
          isAvailable: true,
          donationCount: 3,
        ),
        requests: <NearbyRequestSummary>[_request(units: 2)],
      );

      // The date and the counts have to agree about which digits this is.
      expect(find.text('৩ বার রক্তদান'), findsOneWidget);
      expect(find.textContaining('২ ইউনিট দরকার'), findsOneWidget);
      expect(find.textContaining('2 ইউনিট'), findsNothing);
    });
  });

  group('HomeScreen sign-out', () {
    testWidgets('a rejected sign-out is reported and the dashboard stays', (
      WidgetTester tester,
    ) async {
      final FakeAuthRepository repo = await _pumpHome(tester);
      repo.signOutFailure = const NetworkFailure(debugMessage: 'offline');

      await _tapVisible(
        tester,
        find.widgetWithText(SolovvoButton, 'Sign out'),
      );

      expect(repo.signOutCalls, 1);
      expect(find.byType(AuthErrorBanner), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
