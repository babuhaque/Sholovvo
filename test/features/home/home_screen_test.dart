import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_screen.dart';
import 'package:sholovvo_app/features/home/application/home_providers.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/donor_status_card.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_cards.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_header.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_section.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/widgets/request_tile.dart';

import '../../support/fake_auth_repository.dart';
import '../../support/fake_feed.dart';
import '../../support/fake_profile_repository.dart';
import '../../support/fake_requests.dart';
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
///
/// [feedRepository] is the feed both the dashboard's preview and the pushed
/// [FeedScreen] read. It is always stubbed — a fresh fake carries no posts —
/// because the dashboard asks the feed for its preview the moment it mounts, and
/// leaving the provider unoverridden would build `FirebaseFirestore.instance` in
/// every test in this file. Passing one in is how a test inspects the reads.
///
/// [requestRepository] is the same arrangement for the open-requests window the
/// dashboard reads since Stage 9, and the pushed [RequestsScreen] shares it.
Future<FakeAuthRepository> _pumpHome(
  WidgetTester tester, {
  AuthUser user = verifiedUser,
  DonorSnapshot? donor,
  UserProfile? profile,
  List<BloodRequest>? requests,
  List<FeedPostPreview>? feed,
  FeedRepository? feedRepository,
  FakeRequestRepository? requestRepository,
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
        if (requests != null)
          nearbyRequestsProvider.overrideWithValue(requests),
        if (feed != null) feedPreviewProvider.overrideWithValue(feed),
        feedRepositoryProvider.overrideWithValue(
          feedRepository ?? FakeFeedRepository(),
        ),
        // Always stubbed, for the reason the feed stub is: the dashboard now asks
        // for the open-requests window as soon as it mounts.
        requestRepositoryProvider.overrideWithValue(
          requestRepository ?? FakeRequestRepository(),
        ),
      ],
      child: testApp(
        // Mounted the way the shell mounts it: the dashboard is a tab, and its
        // "coming soon" snackbars are hosted by the `Scaffold` above it. The
        // shell supplies that one in the app; here it is spelled out.
        home: Scaffold(
          // The host supplies this in the app; a no-op is enough here, because
          // switching tabs is the shell's contract and is tested with the shell.
          body: HomeScreen(user: user, onOpenProfile: () {}),
        ),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );
  // `pumpAndSettle` would never return: the soft glow behind the dashboard
  // animates forever. The second pump is the one that lets the community read
  // resolve and reach the tree: the first builds the section while the read is
  // still in flight, so a test that stopped there would be looking at a spinner
  // rather than at the state it meant to assert.
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
///
/// Built through the shared fake rather than the entity directly, so this file and
/// the requests' own tests cannot drift apart on what a seeded request says. The
/// hospital address is left empty on purpose: the row would otherwise show two
/// lines and the assertions below would be about the address rather than the name.
///
/// [neededBy] and [neededByText] are passed through as given, with no default: a
/// test that leaves both out is asking for a request with no date at all, which is
/// one of the three forms the row has to render.
BloodRequest _request({
  String bloodGroup = 'B+',
  String hospital = 'Dhanmondi',
  int units = 2,
  DateTime? neededBy,
  String neededByText = '',
}) {
  return fakeRequest(
    id: 'req-1',
    bloodGroup: bloodGroup,
    hospitalName: hospital,
    hospitalAddress: '',
    units: units,
    neededBy: neededBy,
    neededByText: neededByText,
  );
}

/// The date the seeded requests are needed by, for the tests that assert the row
/// formats one.
final DateTime _seedNeededBy = DateTime(2026, 11, 9);

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

      expect(find.text('Open requests'), findsOneWidget);
      expect(find.text('From the community'), findsOneWidget);
      expect(find.byType(HomeEmptyCard), findsNWidgets(2));
      expect(find.text('No open requests'), findsOneWidget);
      expect(find.text('No posts yet'), findsOneWidget);
      expect(find.byType(RequestTile), findsNothing);
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

    testWidgets('lists an open request with only the facts it carries', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        requests: <BloodRequest>[_request(neededBy: _seedNeededBy)],
      );

      final String neededBy = MaterialLocalizations.of(
        tester.element(find.byType(HomeScreen)),
      ).formatShortMonthDay(_seedNeededBy);

      expect(find.byType(RequestTile), findsOneWidget);
      expect(find.text('B+'), findsOneWidget);
      expect(find.text('Dhanmondi'), findsOneWidget);
      expect(find.textContaining('2 units needed'), findsOneWidget);
      expect(find.textContaining('Needed by $neededBy'), findsOneWidget);
      // The feed is still empty, so exactly one empty card remains.
      expect(find.byType(HomeEmptyCard), findsOneWidget);
      expect(find.text('No posts yet'), findsOneWidget);
    });

    testWidgets('a request with no readable date says so rather than saying '
        'nothing', (WidgetTester tester) async {
      await _pumpHome(
        tester,
        requests: <BloodRequest>[
          _request(neededBy: null, neededByText: 'আগামীকাল'),
        ],
      );

      // Unparseable text is shown verbatim: the person who typed it chose those
      // words, and a row that quietly dropped them would read as a request that
      // does not need one soon.
      expect(find.textContaining('Needed by আগামীকাল'), findsOneWidget);
      expect(find.text('No date given'), findsNothing);

      await _pumpHome(
        tester,
        requests: <BloodRequest>[_request(neededBy: null)],
      );
      expect(find.textContaining('No date given'), findsOneWidget);
    });

    testWidgets('the row carries no patient name and no phone number', (
      WidgetTester tester,
    ) async {
      // The document the read returns holds both, and the frozen rules let any
      // signed-in user read them. The row showing them is the defect this pins
      // shut: a list of people in a medical emergency is not a directory.
      final FakeRequestRepository repository = FakeRequestRepository(
        requests: <BloodRequest>[_request()],
      );
      await _pumpHome(tester, requestRepository: repository);

      expect(tester.takeException(), isNull);
      expect(find.text('Patient'), findsNothing);
      expect(find.text('+8801700000000'), findsNothing);
    });

    testWidgets('offers "See all" once there is something to see, and it opens '
        'the requests', (WidgetTester tester) async {
      await _pumpHome(tester, requests: <BloodRequest>[_request()]);

      final Finder seeAll = find.text('See all');
      expect(seeAll, findsOneWidget);

      expect(find.byType(RequestsScreen), findsNothing);
      await _tapVisible(tester, seeAll);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();
      expect(find.byType(RequestsScreen), findsOneWidget);
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
      expect(find.text('No open requests'), findsOneWidget);
    });

    testWidgets('the community "See all" opens the feed', (
      WidgetTester tester,
    ) async {
      // Only the feed has content, so the single "See all" on screen is the
      // community one — the requests section still hides its own over an empty
      // list.
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[fakePost(text: 'Donated at Dhaka Medical today.')],
      );
      await _pumpHome(
        tester,
        feed: <FeedPostPreview>[_post()],
        feedRepository: feedRepository,
      );

      expect(find.byType(FeedScreen), findsNothing);

      await _tapVisible(tester, find.text('See all'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();

      expect(find.byType(FeedScreen), findsOneWidget);
      // The route carries the full post, read from the repository rather than
      // from the dashboard preview.
      expect(find.text('From the community'), findsNothing);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      // Two reads, and each has its own reason: the dashboard asked for its
      // preview on mount, and the feed screen always starts from the first page
      // when it opens. Not three — returning to the dashboard later does not pay
      // for the preview again, because the page it would re-read is the one
      // already held.
      expect(feedRepository.calls, 2);
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
        requests: <BloodRequest>[_request(units: 1)],
      );

      // "1 units needed" and "1 donations" would be the giveaway that the
      // catalogue is English-shaped rather than English.
      expect(find.text('1 donation'), findsOneWidget);
      expect(find.text('1 donations'), findsNothing);
      expect(find.textContaining('1 unit needed'), findsOneWidget);
      expect(find.textContaining('1 units'), findsNothing);
    });
  });

  group('HomeScreen community preview', () {
    // Everything below drives the preview through the *repository* rather than
    // through a `feedPreviewProvider` override, because these tests are about the
    // wiring: that the dashboard asks the feed's own controller for its page, and
    // then says honestly which of the four outcomes it got.
    testWidgets('spins while the preview read is in flight', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[fakePost()],
      )..gate = Completer<void>();

      await _pumpHome(tester, feedRepository: feedRepository);

      // Not the empty card, and not nothing: the section owns its own spinner,
      // so the donor's status card above it is never covered.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byType(HomeEmptyCard),
        findsOneWidget,
        reason: 'the requests section only',
      );
      expect(find.text('No posts yet'), findsNothing);
      expect(find.text('See all'), findsNothing);

      feedRepository.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FeedPostCard), findsOneWidget);
    });

    testWidgets('previews the newest posts, and only as many as a preview is', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[
          for (int index = 1; index <= 5; index++)
            fakePost(id: 'post-$index', text: 'Update $index'),
        ],
      );

      await _pumpHome(tester, feedRepository: feedRepository);

      expect(find.byType(FeedPostCard), findsNWidgets(feedPreviewLimit));
      expect(find.text('Update 1'), findsOneWidget);
      expect(find.text('Update 3'), findsOneWidget);
      // The rest of the page is not wasted: "See all" reaches it.
      expect(find.text('Update 4'), findsNothing);
      expect(find.text('See all'), findsOneWidget);
      expect(
        find.byType(HomeEmptyCard),
        findsOneWidget,
        reason: 'the requests section only',
      );
    });

    testWidgets('the empty card offers the way into the community, and it '
        'opens the feed', (WidgetTester tester) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository();
      await _pumpHome(tester, feedRepository: feedRepository);

      expect(find.text('No posts yet'), findsOneWidget);
      // Nothing to preview, so still no "See all" — but the section is not a
      // dead end either: the card itself carries one way in.
      expect(find.text('See all'), findsNothing);

      await _tapVisible(
        tester,
        find.widgetWithText(SolovvoButton, 'Open the community'),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.text('From the community'), findsNothing);
      // The feed starts from its own first page every time it opens, so this is
      // the second read — the preview's and the page's, and no more.
      expect(feedRepository.calls, 2);
    });

    testWidgets('says so when the preview read failed, and recovers on retry', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[fakePost(text: 'Donated at Dhaka Medical today.')],
      )..failure = const NetworkFailure(debugMessage: 'offline');

      await _pumpHome(tester, feedRepository: feedRepository);

      expect(find.text('The feed could not be loaded'), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      // A failure is never dressed up as an empty community.
      expect(find.text('No posts yet'), findsNothing);

      feedRepository.failure = null;
      await _tapVisible(
        tester,
        find.widgetWithText(SolovvoButton, 'Try again'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('The feed could not be loaded'), findsNothing);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
    });

    testWidgets('an unreadable preview is never called an empty community', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository()
        ..unreadable = 2;

      await _pumpHome(tester, feedRepository: feedRepository);
      // The read walks past every empty page it is allowed to before it stops, so
      // this state takes longer to reach the tree than a single read does. These
      // frames are the walk finishing, not the section animating in.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final int skipped = 2 * FeedController.maxEmptyPages;

      // The defect this closes. The section used to fall through to its empty
      // card here, telling a donor that nobody had posted at all while the
      // collection held [skipped] documents the mapper could not read. That is a
      // false report about other people's posts, and it is the one sentence in
      // this app that a shorter list cannot distinguish from the truth on its own.
      expect(find.text('No posts yet'), findsNothing);
      expect(find.text('The feed could not be fully read'), findsOneWidget);
      expect(find.text('$skipped posts could not be shown'), findsOneWidget);

      // And the control it offers works. "Try again" would re-ask the same window
      // and draw the same card, so the section points at the page that still has
      // a working "Load more" instead.
      await _tapVisible(
        tester,
        find.widgetWithText(SolovvoButton, 'Open the community'),
      );
      expect(find.byType(FeedScreen), findsOneWidget);
    });

    testWidgets('a failed refresh reports itself above the preview rather than '
        'hiding behind it', (WidgetTester tester) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[fakePost(text: 'Donated at Dhaka Medical today.')],
      );
      await _pumpHome(tester, feedRepository: feedRepository);

      // The refresh is the feed screen's gesture, and the dashboard shares that
      // one controller, so the test reaches the same object the feed would.
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      feedRepository.failure = const NetworkFailure(debugMessage: 'offline');
      await container.read(feedControllerProvider.notifier).refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The readable post stays, and the refusal is said out loud next to it.
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.text('No posts yet'), findsNothing);
    });
  });

  group('HomeScreen open-requests preview', () {
    // The same arrangement as the community group above, and for the same reason:
    // these tests are about the wiring — that the dashboard asks the requests'
    // own controller for its window, and then says honestly which of the five
    // outcomes it got.
    testWidgets('spins while the requests read is in flight', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository requestRepository = FakeRequestRepository(
        requests: <BloodRequest>[_request()],
      )..gate = Completer<void>();

      await _pumpHome(tester, requestRepository: requestRepository);

      // The section owns its spinner, so the donor's status card stays readable.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('No open requests'), findsNothing);
      expect(find.text('See all'), findsNothing);

      requestRepository.gate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(RequestTile), findsOneWidget);
    });

    testWidgets('previews the window, and only as many rows as a preview is', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository requestRepository = FakeRequestRepository(
        requests: <BloodRequest>[
          for (int index = 1; index <= 5; index++)
            _request(hospital: 'Hospital $index'),
        ],
      );
      await _pumpHome(tester, requestRepository: requestRepository);

      // The fake hands back what the repository would: soonest needed first. The
      // dashboard shows its own three and "See all" reaches the rest.
      expect(find.byType(RequestTile), findsNWidgets(nearbyRequestLimit));
      expect(find.text('Hospital 1'), findsOneWidget);
      expect(find.text('Hospital 3'), findsOneWidget);
      expect(find.text('Hospital 4'), findsNothing);
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('says so when the read failed, and recovers on retry', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository requestRepository = FakeRequestRepository(
        requests: <BloodRequest>[_request()],
      )..failure = const NetworkFailure(debugMessage: 'offline');

      await _pumpHome(tester, requestRepository: requestRepository);

      expect(find.text('The requests could not be loaded'), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      // A failure is never dressed up as a quiet collection.
      expect(find.text('No open requests'), findsNothing);

      requestRepository.failure = null;
      await _tapVisible(
        tester,
        find.widgetWithText(SolovvoButton, 'Try again'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('The requests could not be loaded'), findsNothing);
      expect(find.byType(RequestTile), findsOneWidget);
    });

    testWidgets('an unreadable window is never called an empty one', (
      WidgetTester tester,
    ) async {
      // The state the false report hides behind: the read succeeded, the mapper
      // refused everything it looked at, and the list is empty. "No open requests"
      // would be a sentence about the community that this read has no right to.
      await _pumpHome(
        tester,
        requestRepository: FakeRequestRepository()..skipped = 2,
      );

      expect(find.text('No open requests'), findsNothing);
      expect(
        find.text('The requests could not be fully read'),
        findsOneWidget,
      );
      expect(find.text('2 requests could not be shown'), findsOneWidget);
      // And no button: the window has no cursor to move, so a retry would re-ask
      // it and draw the same card.
      expect(find.widgetWithText(SolovvoButton, 'Try again'), findsNothing);
    });

    testWidgets('a full window says more are behind it', (
      WidgetTester tester,
    ) async {
      await _pumpHome(
        tester,
        requestRepository: FakeRequestRepository(
          requests: <BloodRequest>[_request()],
          truncated: true,
        ),
      );

      expect(
        find.text(
          'Only the first ${RequestRepository.window} open requests are shown '
          'here. More are still behind them.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a failed refresh reports itself above the rows rather than '
        'hiding behind it', (WidgetTester tester) async {
      final FakeRequestRepository requestRepository = FakeRequestRepository(
        requests: <BloodRequest>[_request()],
      );
      await _pumpHome(tester, requestRepository: requestRepository);

      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
      );
      requestRepository.failure = const NetworkFailure(debugMessage: 'offline');
      await container.read(requestsControllerProvider.notifier).refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(RequestTile), findsOneWidget);
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('No open requests'), findsNothing);
    });

    testWidgets('opening the requests screen and coming back does not re-read '
        'the window', (WidgetTester tester) async {
      final FakeRequestRepository requestRepository = FakeRequestRepository(
        requests: <BloodRequest>[_request()],
      );
      await _pumpHome(tester, requestRepository: requestRepository);
      expect(requestRepository.calls, 1);

      await _tapVisible(tester, find.text('See all'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump();
      expect(find.byType(RequestsScreen), findsOneWidget);
      // The screen starts from a fresh read every time it opens, which is the
      // right behaviour for a list whose contents change when somebody claims a
      // request — so this is the second read, and it is the screen's.
      expect(requestRepository.calls, 2);

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(RequestsScreen), findsNothing);
      expect(find.byType(RequestTile), findsOneWidget);
      // No third: the dashboard does not re-ask for a window the shared
      // controller already holds.
      expect(requestRepository.calls, 2);
    });
  });

  group('HomeScreen into the feed and back', () {
    testWidgets('a preview card opens the feed, and back returns to the '
        'dashboard', (WidgetTester tester) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[fakePost(text: 'Donated at Dhaka Medical today.')],
      );
      await _pumpHome(tester, feedRepository: feedRepository);

      await _tapVisible(tester, find.byType(FeedPostCard));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      expect(find.byType(FeedScreen), findsOneWidget);
      // One page on the stack, not two, and it is pushed rather than joined to
      // the tab bar: the feed is a destination above the shell, not a third one.
      expect(tester.widgetList(find.byType(FeedScreen)), hasLength(1));
      expect(find.text('From the community'), findsNothing);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(FeedScreen), findsNothing);
      expect(find.text('From the community'), findsOneWidget);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      // Two reads and no third: the dashboard's preview, then the feed's own
      // first page on open. Coming back does not re-ask for a page the shared
      // controller already holds.
      expect(feedRepository.calls, 2);
    });

    testWidgets('"See all" and a preview card reach the same page, not two', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository feedRepository = FakeFeedRepository(
        posts: <Post>[fakePost(text: 'Donated at Dhaka Medical today.')],
      );
      await _pumpHome(tester, feedRepository: feedRepository);

      await _tapVisible(tester, find.byType(FeedPostCard));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.byType(FeedScreen), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      await _tapVisible(tester, find.text('See all'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();

      // The second entry point opens the one screen rather than a parallel copy
      // of it, and never leaves a feed stacked under the new one.
      expect(find.byType(FeedScreen), findsOneWidget);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      // Preview, first open, second open — and no read for returning to the
      // dashboard in between.
      expect(feedRepository.calls, 3);
    });
  });

  group('HomeScreen layout', () {
    testWidgets('stacks the sections on a phone', (WidgetTester tester) async {
      await _pumpHome(tester, size: _phone);

      final double requests = tester.getTopLeft(find.text('Open requests')).dy;
      final double feed = tester.getTopLeft(find.text('From the community')).dy;
      expect(feed, greaterThan(requests));
    });

    testWidgets('puts the sections side by side from the 720 dp breakpoint', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, size: _tablet);

      final double requests = tester.getTopLeft(find.text('Open requests')).dy;
      final double feed = tester.getTopLeft(find.text('From the community')).dy;
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
      expect(find.text('Open requests'), findsOneWidget);
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
        requests: <BloodRequest>[_request()],
        feed: <FeedPostPreview>[_post()],
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(RequestTile), findsOneWidget);
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
      expect(
        find.widgetWithText(SolovvoButton, 'রক্তের অনুরোধ'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(SolovvoButton, 'ডোনার খুঁজুন'),
        findsOneWidget,
      );
      expect(find.text('ডোনার স্ট্যাটাস'), findsOneWidget);
      expect(find.text('এখনো দেওয়া হয়নি'), findsNWidgets(3));
      expect(find.text('খোলা অনুরোধ'), findsOneWidget);
      expect(find.text('কোনো খোলা অনুরোধ নেই'), findsOneWidget);
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
        requests: <BloodRequest>[_request(units: 2)],
      );

      // The date and the counts have to agree about which digits this is.
      expect(find.text('৩ বার রক্তদান'), findsOneWidget);
      expect(find.textContaining('২ ইউনিট দরকার'), findsOneWidget);
      expect(find.textContaining('2 ইউনিট'), findsNothing);
    });
  });
}
