import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';
import 'package:sholovvo_app/features/requests/presentation/my_requests_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/request_detail_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/widgets/request_tile.dart';

import '../../support/fake_requests.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);
const Size _narrow = Size(320, 640);
const Size _tablet = Size(900, 1200);

/// The uid the projection is matched against. Both [fakeRequest] and
/// [requestFields] default to this same string, so a caller who passes neither
/// gets the "mine" case by accident of the default; tests that want the
/// "someone else raised it" case pass an explicit different uid.
const String _myUid = 'uid-recipient';

/// Mounts [MyRequestsScreen] over a fake repository and a fake uid.
///
/// The screen reads from a post-frame callback (mirroring the all-requests
/// screen), so the four pumps after mounting are what let the read resolve.
/// `pumpAndSettle` is not used anywhere in this file for the same reason: the
/// soft glow background animates forever.
Future<FakeRequestRepository> _pumpMy(
  WidgetTester tester, {
  List<BloodRequest>? requests,
  bool truncated = false,
  int skipped = 0,
  Failure? failure,
  String? authUid = _myUid,
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

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        requestRepositoryProvider.overrideWithValue(repository),
        requestsAuthUidProvider.overrideWithValue(authUid),
      ],
      child: testApp(
        home: const MyRequestsScreen(),
        locale: locale,
      ),
    ),
  );
  for (int i = 0; i < 4; i++) {
    await tester.pump();
  }
  return repository;
}

Finder get _retry => find.widgetWithText(SolovvoButton, english.requestsRetry);

void main() {
  group('MyRequestsScreen', () {
    testWidgets('titles the app bar with the my-requests copy', (
      WidgetTester tester,
    ) async {
      await _pumpMy(tester);

      expect(find.text(english.requestsMyTitle), findsOneWidget);
    });

    testWidgets('asks for the window once on opening', (
      WidgetTester tester,
    ) async {
      // Same underlying read as the all-requests screen — one paid query,
      // not a per-screen duplicate. A second call here would be a bug that
      // looks like a live screen but costs twice as much on the free tier.
      final FakeRequestRepository repository = await _pumpMy(tester);

      expect(repository.calls, 1);
    });

    testWidgets('shows only the requests the signed-in account raised', (
      WidgetTester tester,
    ) async {
      final BloodRequest mine = fakeRequest(
        id: 'mine-1',
        userId: _myUid,
        hospitalName: 'Dhaka Medical',
        neededBy: DateTime.utc(2026, 11, 10),
      );
      final BloodRequest theirs = fakeRequest(
        id: 'theirs-1',
        userId: 'uid-someone-else',
        hospitalName: 'Chattogram General',
        neededBy: DateTime.utc(2026, 11, 11),
      );

      await _pumpMy(tester, requests: <BloodRequest>[mine, theirs]);

      expect(find.text('Dhaka Medical'), findsOneWidget);
      // The stranger's request is on the shared window (the fake returned
      // both) but not on the projection, and the projection is what the
      // screen draws.
      expect(find.text('Chattogram General'), findsNothing);
      expect(find.byType(RequestTile), findsOneWidget);
    });

    testWidgets('empty when none of the open requests are mine', (
      WidgetTester tester,
    ) async {
      // The window has content, so `state.isEmptyResult` is false, but the
      // projected list is empty and the screen still has to say so — with
      // the my-specific copy, not with the shared "no open requests" card
      // (which would be a lie; the collection *does* have open requests,
      // they just are not the caller's).
      await _pumpMy(
        tester,
        requests: <BloodRequest>[
          fakeRequest(id: 'other', userId: 'uid-someone-else'),
        ],
      );

      expect(find.text(english.requestsMyEmptyTitle), findsOneWidget);
      expect(find.text(english.requestsMyEmptyBody), findsOneWidget);
      // The shared all-requests empty card is not shown.
      expect(find.text(english.requestsEmptyTitle), findsNothing);
    });

    testWidgets('spinner while the first read is unresolved', (
      WidgetTester tester,
    ) async {
      // A gate Completer that never resolves keeps the FakeRequestRepository
      // hanging on the first call, so the controller's state stays on
      // `RequestsStatus.loading`. One pump is enough to run `initState`'s
      // post-frame callback and start the read without letting it land.
      final FakeRequestRepository repository = FakeRequestRepository(
        requests: <BloodRequest>[],
      );
      repository.gate = Completer<void>();

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(repository),
            requestsAuthUidProvider.overrideWithValue(_myUid),
          ],
          child: testApp(home: const MyRequestsScreen()),
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('fatal error card with a retry that re-asks', (
      WidgetTester tester,
    ) async {
      final FakeRequestRepository repository = await _pumpMy(
        tester,
        failure: const NetworkFailure(debugMessage: 'test: offline'),
      );

      expect(find.text(english.requestsErrorTitle), findsOneWidget);
      expect(_retry, findsOneWidget);

      final int callsBefore = repository.calls;
      await tester.tap(_retry);
      await tester.pump();
      // `load()` on the controller re-checks the in-flight flag and would
      // return early if a read were already running. Here there is none, so
      // the retry pays for one more read.
      expect(repository.calls, callsBefore + 1);
    });

    testWidgets('shows the shared failure banner above a partial list', (
      WidgetTester tester,
    ) async {
      // A refresh failure with the initial window already loaded: the list
      // stays and the banner says the picture may be old. Same rule as the
      // all-requests screen, and this screen inherits it because the state
      // it reads is the same one.
      final FakeRequestRepository repository = FakeRequestRepository(
        requests: <BloodRequest>[
          fakeRequest(id: 'mine', userId: _myUid, hospitalName: 'Narayanganj'),
        ],
      );

      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(repository),
            requestsAuthUidProvider.overrideWithValue(_myUid),
          ],
          child: testApp(home: const MyRequestsScreen()),
        ),
      );
      // Let the initial read land — the projection now has one tile.
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }

      // Flip the repository to failure and drive a refresh through the
      // controller so the state machine actually moves to the "content +
      // banner" branch. Calling `repository.loadOpenRequests()` directly
      // would return a result nobody consumed; the state only updates when
      // the controller is the one asking.
      repository.failure = const NetworkFailure(debugMessage: 'test: stale');
      final ProviderContainer container = ProviderScope.containerOf(
        tester.element(find.byType(MyRequestsScreen)),
      );
      await container.read(requestsControllerProvider.notifier).refresh();
      await tester.pump();

      expect(find.byType(ErrorBanner), findsOneWidget);
      expect(find.text('Narayanganj'), findsOneWidget);
    });

    testWidgets('renders the truncated notice when the shared window filled', (
      WidgetTester tester,
    ) async {
      // The truncation is measured on the shared window and is therefore
      // about that window; a "mine" that fell outside the top-N is invisible
      // here for the same reason it is invisible on the list. The screen
      // says so rather than showing a shorter list as if it were complete.
      await _pumpMy(
        tester,
        requests: <BloodRequest>[
          fakeRequest(id: 'a', userId: _myUid),
        ],
        truncated: true,
      );

      expect(
        find.textContaining(english.requestsTruncatedNotice(
          RequestRepository.window,
        )),
        findsOneWidget,
      );
    });

    testWidgets('a row tap opens the detail screen', (
      WidgetTester tester,
    ) async {
      // The owner's Cancel button is what makes the detail useful from here,
      // and the detail screen already tests its own behaviour. This case is
      // about the plumbing: a projection row is a full-fledged `RequestTile`
      // with a working `onTap` that pushes the same route the list uses.
      await _pumpMy(
        tester,
        requests: <BloodRequest>[
          fakeRequest(id: 'mine', userId: _myUid, hospitalName: 'Khulna'),
        ],
      );

      await tester.tap(find.byType(RequestTile));
      await tester.pumpAndSettle();

      expect(find.byType(RequestDetailScreen), findsOneWidget);
    });

    testWidgets('pull-to-refresh re-reads the shared window', (
      WidgetTester tester,
    ) async {
      // `RefreshIndicator.onRefresh` points at `controller.refresh`, which
      // is the same method the all-requests screen's gesture calls. The
      // projection follows because it derives from the same state.
      final FakeRequestRepository repository = await _pumpMy(
        tester,
        requests: <BloodRequest>[fakeRequest(id: 'x', userId: _myUid)],
      );
      final int callsBefore = repository.calls;

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));

      expect(repository.calls, greaterThan(callsBefore));
    });

    testWidgets('renders my-requests copy in Bangla', (
      WidgetTester tester,
    ) async {
      await _pumpMy(
        tester,
        locale: const Locale('bn'),
        requests: <BloodRequest>[
          fakeRequest(id: 'mine', userId: _myUid, hospitalName: 'Rajshahi'),
        ],
      );

      expect(find.text(bangla.requestsMyTitle), findsOneWidget);
      expect(find.text('Rajshahi'), findsOneWidget);
      // English is genuinely absent, not merely hidden.
      expect(find.text(english.requestsMyTitle), findsNothing);
    });

    testWidgets('Bangla empty state uses the my-specific copy', (
      WidgetTester tester,
    ) async {
      await _pumpMy(tester, locale: const Locale('bn'));

      expect(find.text(bangla.requestsMyEmptyTitle), findsOneWidget);
      expect(find.text(bangla.requestsMyEmptyBody), findsOneWidget);
      expect(find.text(english.requestsMyEmptyTitle), findsNothing);
    });

    testWidgets('fits a small phone (320x640) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpMy(
        tester,
        size: _narrow,
        requests: <BloodRequest>[fakeRequest(id: 'm', userId: _myUid)],
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('fits a large phone (430x932) without overflow', (
      WidgetTester tester,
    ) async {
      await _pumpMy(
        tester,
        size: _phone,
        requests: <BloodRequest>[fakeRequest(id: 'm', userId: _myUid)],
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('reflows to a wider measure on a tablet (900x1200)', (
      WidgetTester tester,
    ) async {
      await _pumpMy(
        tester,
        size: _tablet,
        requests: <BloodRequest>[fakeRequest(id: 'm', userId: _myUid)],
      );

      expect(tester.takeException(), isNull);
      expect(find.text(english.requestsMyTitle), findsOneWidget);
    });

    testWidgets('empty when the uid provider returns null', (
      WidgetTester tester,
    ) async {
      // The auth gate prevents this shape in the real app, but the provider
      // contract allows a null (a widget test that forgot to override, or a
      // session that expired between gate-check and build), and the screen
      // has to answer that shape honestly: with the my-empty card, not with
      // a spinner or an error. The projection itself returns an empty list
      // for a null uid, and the state below has `loaded=true` after the
      // fake read resolves.
      await _pumpMy(
        tester,
        authUid: null,
        requests: <BloodRequest>[fakeRequest(id: 'other', userId: 'x')],
      );

      expect(find.text(english.requestsMyEmptyTitle), findsOneWidget);
      expect(find.byType(RequestTile), findsNothing);
    });
  });

  group('RequestsScreen app-bar entry point', () {
    testWidgets('offers a My Requests action that pushes the screen', (
      WidgetTester tester,
    ) async {
      // The single entry point a donor has to reach "mine" from the shared
      // list today. Kept as a test on the entry — not on the projection —
      // because a future rewire (e.g., to a bottom sheet or a dashboard
      // card) would otherwise silently orphan the screen.
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(
              FakeRequestRepository(requests: <BloodRequest>[]),
            ),
            requestsAuthUidProvider.overrideWithValue(_myUid),
          ],
          child: testApp(home: const RequestsScreen()),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }

      await tester.tap(find.byTooltip(english.requestsMyAction));
      await tester.pumpAndSettle();

      expect(find.byType(MyRequestsScreen), findsOneWidget);
    });

    testWidgets('My Requests action tooltip is localised in Bangla', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            requestRepositoryProvider.overrideWithValue(
              FakeRequestRepository(requests: <BloodRequest>[]),
            ),
            requestsAuthUidProvider.overrideWithValue(_myUid),
          ],
          child: testApp(home: const RequestsScreen(), locale: const Locale('bn')),
        ),
      );
      for (int i = 0; i < 4; i++) {
        await tester.pump();
      }

      expect(find.byTooltip(bangla.requestsMyAction), findsOneWidget);
      expect(find.byTooltip(english.requestsMyAction), findsNothing);
    });
  });
}
