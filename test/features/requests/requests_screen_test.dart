import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/widgets/request_tile.dart';

import '../../support/fake_requests.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

/// A window of [count] requests, soonest needed first — the order the repository
/// hands over, spelled here so the screen is tested on what it is given rather
/// than on the sort that produced it.
List<BloodRequest> _requests(int count) {
  return <BloodRequest>[
    for (int index = 0; index < count; index++)
      fakeRequest(
        id: 'req-$index',
        hospitalName: 'Hospital $index',
        neededBy: DateTime.utc(2026, 11, 10).add(Duration(days: index)),
      ),
  ];
}

/// Mounts the screen over a fake repository.
///
/// The screen reads from a post-frame callback, so the pumps after mounting are
/// what let that read start and resolve. `pumpAndSettle` is not usable anywhere in
/// this file: the soft glow behind the page animates forever.
Future<FakeRequestRepository> _pumpRequests(
  WidgetTester tester, {
  List<BloodRequest>? requests,
  bool truncated = false,
  int skipped = 0,
  Failure? failure,
  Completer<void>? gate,
  Locale locale = const Locale('en'),
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeRequestRepository repository = FakeRequestRepository(
    requests: requests,
    truncated: truncated,
    skipped: skipped,
  );
  repository.failure = failure;
  repository.gate = gate;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [requestRepositoryProvider.overrideWithValue(repository)],
      child: testApp(
        home: const RequestsScreen(),
        locale: locale,
      ),
    ),
  );
  await _settle(tester);
  return repository;
}

/// A few frames, enough for a resolved read to reach the tree.
Future<void> _settle(WidgetTester tester, [int frames = 4]) async {
  for (int index = 0; index < frames; index++) {
    await tester.pump();
  }
}

/// Pulls the page down, the way a donor re-asks for the window.
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(
    find.byType(CustomScrollView),
    const Offset(0, 300),
    1000,
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 800));
}

Finder get _retry => find.widgetWithText(SolovvoButton, 'Try again');

void main() {
  group('RequestsScreen while it reads', () {
    testWidgets('asks for the window once, on opening', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: _requests(2),
        gate: Completer<void>(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(RequestTile), findsNothing);
      expect(repository.calls, 1, reason: 'opening the screen reads once');

      repository.gate!.complete();
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(RequestTile), findsNWidgets(2));
    });

    testWidgets('draws the window in the order it was handed', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: _requests(3));

      expect(
        find.text('Hospital 0'),
        findsOneWidget,
        reason: 'the soonest request is the first row',
      );
      final Finder rows = find.descendant(
        of: find.byType(RequestsScreen),
        matching: find.byType(RequestTile),
      );
      expect(rows, findsNWidgets(3));

      // The screen reorders nothing: a list that sorted again here is a list that
      // could disagree with the dashboard's three-row preview of the same window.
      expect(
        tester.getTopLeft(rows.first).dy,
        lessThan(tester.getTopLeft(rows.last).dy),
      );
    });

    testWidgets('tells the donor what this list cannot do', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: _requests(1));

      // The footer points the donor at the place where accepting happens — the
      // detail screen — and promises no control here. §9 asks for no controls that
      // look functional and are not.
      expect(
        find.textContaining('Open a request to accept it if you are eligible'),
        findsOneWidget,
      );
      expect(find.text('Load more'), findsNothing);
    });
  });

  group('RequestsScreen with nothing to show', () {
    testWidgets('says the collection is empty, and only then', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: <BloodRequest>[]);

      expect(find.text('No open requests right now'), findsOneWidget);
      expect(
        find.text('Nothing is marked open at the moment. Pull down to check again.'),
        findsOneWidget,
      );
      expect(find.byType(RequestTile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed first read is an error, not an empty collection', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, failure: const NetworkFailure());

      expect(find.text('The requests could not be loaded'), findsOneWidget);
      expect(find.text(english.failureNetwork), findsOneWidget);
      expect(find.text('No open requests right now'), findsNothing);
      expect(_retry, findsOneWidget);
    });

    testWidgets('a read that failed after an empty window still says error', (
      WidgetTester tester,
    ) async {
      // `RequestsState` lets both `isFatalError` and `isEmptyResult` hold here, and
      // the screen tests the error first — a donor must never be told "nobody needs
      // blood" by a screen that failed to look.
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: <BloodRequest>[],
      );
      expect(find.text('No open requests right now'), findsOneWidget);

      repository.failure = const NetworkFailure();
      await _pullToRefresh(tester);

      expect(find.text('The requests could not be loaded'), findsOneWidget);
      expect(find.text('No open requests right now'), findsNothing);
    });

    testWidgets('retries from the error card and shows the requests', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        failure: const NetworkFailure(),
      );
      expect(repository.calls, 1);

      repository.failure = null;
      repository.requests = _requests(2);
      await tester.tap(_retry);
      await _settle(tester);

      expect(repository.calls, 2);
      expect(find.text('The requests could not be loaded'), findsNothing);
      expect(find.byType(RequestTile), findsNWidgets(2));
    });

    testWidgets('reports documents it could not read, without a button', (
      WidgetTester tester,
    ) async {
      // The unreadable card deliberately has no action: this read has no cursor, so
      // a retry re-asks the same window and earns the same documents. The gesture
      // above the card is the honest way to ask again.
      await _pumpRequests(tester, requests: <BloodRequest>[], skipped: 2);

      expect(find.text('The requests could not be fully read'), findsOneWidget);
      expect(find.text('2 requests could not be shown'), findsOneWidget);
      expect(find.text('No open requests right now'), findsNothing);
      expect(_retry, findsNothing);
    });

    testWidgets('says requests are behind the window without pretending to '
        'read them', (WidgetTester tester) async {
      await _pumpRequests(tester, requests: <BloodRequest>[], truncated: true);

      expect(find.text('The requests could not be fully read'), findsOneWidget);
      expect(
        find.text(
          'There are open requests behind this, but they could not be read.',
        ),
        findsOneWidget,
      );
      expect(find.text('No open requests right now'), findsNothing);
      expect(_retry, findsNothing);
    });

    testWidgets('one refusal is counted in the language of one refusal', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: <BloodRequest>[], skipped: 1);

      expect(find.text('1 request could not be shown'), findsOneWidget);
      expect(find.text('1 requests could not be shown'), findsNothing);
    });
  });

  group('RequestsScreen caveats over a list', () {
    testWidgets('keeps the rows and adds the skip notice under them', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: _requests(2), skipped: 3);

      expect(find.byType(RequestTile), findsNWidgets(2));
      expect(find.text('3 requests could not be shown'), findsOneWidget);
      // The card that answers an empty window is not drawn over a real list.
      expect(find.text('The requests could not be fully read'), findsNothing);
    });

    testWidgets('names the window size when the list filled up', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: _requests(2), truncated: true);

      expect(
        find.text(
          'Only the first ${RequestRepository.window} open requests are shown '
          'here. More are still behind them.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says both, when both are true', (WidgetTester tester) async {
      await _pumpRequests(
        tester,
        requests: _requests(1),
        truncated: true,
        skipped: 2,
      );

      expect(find.text('2 requests could not be shown'), findsOneWidget);
      expect(
        find.textContaining('Only the first ${RequestRepository.window}'),
        findsOneWidget,
      );
    });

    testWidgets('keeps the list and banners a refresh that failed', (
      WidgetTester tester,
    ) async {
      // The requests on screen were true a moment ago. Replacing them with an error
      // page throws away the only useful thing the donor has; the banner says the
      // picture may be old, which is the whole message.
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: _requests(2),
      );
      repository.failure = const NetworkFailure();

      await _pullToRefresh(tester);

      expect(find.byType(RequestTile), findsNWidgets(2));
      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text(english.failureNetwork), findsOneWidget);
      // Not the full-height error card, and not its button.
      expect(find.text('The requests could not be loaded'), findsNothing);
      expect(_retry, findsNothing);
    });

    testWidgets('clears the banner on the next good read', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: _requests(2),
      );
      repository.failure = const NetworkFailure();
      await _pullToRefresh(tester);
      expect(find.byType(ErrorBanner), findsOneWidget);

      repository.failure = null;
      await _pullToRefresh(tester);

      expect(find.byType(ErrorBanner), findsNothing);
      expect(find.byType(RequestTile), findsNWidgets(2));
    });
  });

  group('RequestsScreen refresh', () {
    testWidgets('pulling down reads the window again', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: _requests(1),
      );
      expect(repository.calls, 1);

      await _pullToRefresh(tester);

      expect(repository.calls, 2);
      expect(find.byType(RequestTile), findsOneWidget);
    });

    testWidgets('replaces the list with what the new read returned', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: _requests(2),
      );

      repository.requests = _requests(1);
      await _pullToRefresh(tester);

      expect(find.byType(RequestTile), findsOneWidget);
      expect(find.text('Hospital 1'), findsNothing);
    });

    testWidgets('does not start a second read while one is running', (
      WidgetTester tester,
    ) async {
      // A donor who pulls twice while the page is thinking should pay for one read
      // of twenty-five documents, not two.
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: _requests(1),
        gate: Completer<void>(),
      );
      expect(repository.calls, 1);

      repository.gate!.complete();
      await _settle(tester);
      repository.gate = Completer<void>();
      await _pullToRefresh(tester);
      final int during = repository.calls;
      await _pullToRefresh(tester);

      expect(repository.calls, during, reason: 'the second pull was refused');
      repository.gate!.complete();
      await _settle(tester);
      expect(find.byType(RequestTile), findsOneWidget);
    });
  });

  group('RequestsScreen in Bangla', () {
    testWidgets('titles, empty card and all', (WidgetTester tester) async {
      await _pumpRequests(
        tester,
        requests: <BloodRequest>[],
        locale: const Locale('bn'),
      );

      expect(find.text(bangla.requestsTitle), findsOneWidget);
      expect(find.text(bangla.requestsEmptyTitle), findsOneWidget);
      expect(find.text(bangla.requestsEmptyBody), findsOneWidget);
      expect(find.text(english.requestsEmptyTitle), findsNothing);
    });

    testWidgets('says an unreadable window in Bangla, with the count', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(
        tester,
        requests: <BloodRequest>[],
        skipped: 2,
        locale: const Locale('bn'),
      );

      expect(find.text(bangla.requestsUnreadableTitle), findsOneWidget);
      expect(find.text(bangla.requestsSkippedNotice(2)), findsOneWidget);
      expect(find.text(english.requestsSkippedNotice(2)), findsNothing);
    });

    testWidgets('offers the retry in Bangla, and it works', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        failure: const NetworkFailure(),
        locale: const Locale('bn'),
      );
      expect(
        find.widgetWithText(SolovvoButton, bangla.requestsRetry),
        findsOneWidget,
      );

      repository.failure = null;
      repository.requests = _requests(3);
      await tester.tap(
        find.widgetWithText(SolovvoButton, bangla.requestsRetry),
      );
      await _settle(tester);

      expect(repository.calls, 2);
      expect(find.byType(RequestTile), findsNWidgets(3));
    });
  });

  group('RequestsScreen layout', () {
    testWidgets('stays inside its measure on a wide window', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(
        tester,
        requests: _requests(4),
        size: const Size(1200, 900),
      );

      expect(find.byType(RequestTile), findsNWidgets(4));
      expect(tester.takeException(), isNull);
      // Centred by padding, so the scroll view spans the window while the rows stay
      // readable: a list stretched to 1200 pixels is a list nobody can scan.
      expect(
        tester.getSize(find.byType(RequestTile).first).width,
        lessThanOrEqualTo(RequestsScreen.wideMaxWidth),
      );
      expect(
        tester.getSize(find.byType(CustomScrollView)).width,
        1200,
        reason: 'the pull gesture has to work anywhere on the page',
      );
    });

    testWidgets('is pullable at a phone width with a list shorter than the '
        'screen', (WidgetTester tester) async {
      // `AlwaysScrollableScrollPhysics` is the whole reason a one-row window can
      // still be dragged: without it the refresh gesture does not exist on a page
      // that fits.
      await _pumpRequests(tester, requests: _requests(1));

      final CustomScrollView scroll = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scroll.physics, isA<AlwaysScrollableScrollPhysics>());
    });

    testWidgets('shows the notice rather than a spinner when a read is '
        're-asked', (WidgetTester tester) async {
      // The empty card is not a dead end: pulling the page re-reads it, so there is
      // no button to duplicate here.
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: <BloodRequest>[],
      );
      expect(find.byType(SolovvoButton), findsNothing);

      repository.requests = _requests(2);
      await _pullToRefresh(tester);

      expect(find.byType(RequestTile), findsNWidgets(2));
      expect(find.text('No open requests right now'), findsNothing);
    });
  });

  group('RequestsScreen blood-group filter', () {
    // Three requests with three distinct groups, created in a helper so
    // tests reference the exact string that drives the filter branch.
    final List<BloodRequest> mixed = <BloodRequest>[
      fakeRequest(id: 'r1', bloodGroup: 'A+', hospitalName: 'A Hospital'),
      fakeRequest(id: 'r2', bloodGroup: 'O+', hospitalName: 'O Hospital'),
      fakeRequest(id: 'r3', bloodGroup: 'AB-', hospitalName: 'AB Hospital'),
    ];

    testWidgets('shows eight filter chips when the list is ready', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: mixed);

      // Exactly the eight groups the rules accept, and nothing else.
      for (final String group in BloodGroups.all) {
        expect(
          find.widgetWithText(ChoiceChip, group),
          findsOneWidget,
          reason: 'chip for $group should render once',
        );
      }
      expect(find.byType(ChoiceChip), findsNWidgets(8));
    });

    testWidgets('all requests show when no filter is active', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: mixed);

      expect(find.byType(RequestTile), findsNWidgets(3));
    });

    testWidgets('tapping a chip filters the list to that group', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: mixed);

      await tester.tap(find.widgetWithText(ChoiceChip, 'O+'));
      await tester.pump();

      // Only the O+ request survives. The other two are absent, not hidden
      // behind overflow.
      expect(find.byType(RequestTile), findsOneWidget);
      expect(find.text('O Hospital'), findsOneWidget);
      expect(find.text('A Hospital'), findsNothing);
      expect(find.text('AB Hospital'), findsNothing);
    });

    testWidgets('tapping the selected chip clears the filter', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: mixed);

      await tester.tap(find.widgetWithText(ChoiceChip, 'A+'));
      await tester.pump();
      expect(find.byType(RequestTile), findsOneWidget);

      // Re-tap the same chip — `onSelected(false)` fires and the filter
      // clears, showing all three again.
      await tester.tap(find.widgetWithText(ChoiceChip, 'A+'));
      await tester.pump();
      expect(find.byType(RequestTile), findsNWidgets(3));
    });

    testWidgets('switching from one filter to another is a single tap', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: mixed);

      await tester.tap(find.widgetWithText(ChoiceChip, 'A+'));
      await tester.pump();
      expect(find.byType(RequestTile), findsOneWidget);

      // Selecting a different chip replaces the filter (does not compound
      // to two selected at once).
      await tester.tap(find.widgetWithText(ChoiceChip, 'AB-'));
      await tester.pump();
      expect(find.byType(RequestTile), findsOneWidget);
      expect(find.text('AB Hospital'), findsOneWidget);
      expect(find.text('A Hospital'), findsNothing);
    });

    testWidgets('a filter that matches nothing shows the filter-empty message',
        (WidgetTester tester) async {
      final List<BloodRequest> onlyA = <BloodRequest>[
        fakeRequest(id: 'only-a', bloodGroup: 'A+', hospitalName: 'Alpha'),
      ];
      await _pumpRequests(tester, requests: onlyA);

      await tester.tap(find.widgetWithText(ChoiceChip, 'B-'));
      await tester.pump();

      // The filter-empty text appears, the list is gone, and the chips
      // remain so the donor can clear.
      expect(find.text('No open requests need this group right now.'),
          findsOneWidget);
      expect(find.byType(RequestTile), findsNothing);
      expect(find.byType(ChoiceChip), findsNWidgets(8));
    });

    testWidgets('the filter chip row does not show while loading', (
      WidgetTester tester,
    ) async {
      // A gate that never resolves keeps the screen in `isInitialLoading`.
      // There is nothing to filter yet, so the chips must not render.
      final FakeRequestRepository repository = await _pumpRequests(
        tester,
        requests: <BloodRequest>[],
        gate: Completer<void>(),
      );

      expect(find.byType(ChoiceChip), findsNothing);

      repository.gate!.complete();
      await _settle(tester);
      // Once the gate resolves and shows an empty collection, the empty
      // card renders instead of the chips — there is no list to narrow.
      expect(find.byType(ChoiceChip), findsNothing);
    });

    testWidgets('filter label is localised in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(tester, requests: mixed, locale: const Locale('bn'));

      expect(
        find.text(bangla.requestsFilterLabel.toUpperCase()),
        findsOneWidget,
      );
      // The chips still render (group strings are locale-invariant).
      expect(find.byType(ChoiceChip), findsNWidgets(8));
    });

    testWidgets('filter chips fit a narrow screen (320x600) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpRequests(
        tester,
        requests: mixed,
        size: const Size(320, 600),
      );

      expect(tester.takeException(), isNull);
      // All eight are present and at least partially visible.
      expect(find.byType(ChoiceChip), findsNWidgets(8));
    });
  });
}
