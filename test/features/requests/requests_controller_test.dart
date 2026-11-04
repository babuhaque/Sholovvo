import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/application/requests_state.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

import '../../support/fake_requests.dart';

void main() {
  late FakeRequestRepository repository;
  late ProviderContainer container;

  RequestsController controller() =>
      container.read(requestsControllerProvider.notifier);
  RequestsState state() => container.read(requestsControllerProvider);

  /// Mounts the controller over a fake that answers with [count] requests.
  void setUpController({
    int count = 3,
    bool truncated = false,
    int skipped = 0,
  }) {
    repository = FakeRequestRepository(
      requests: <BloodRequest>[
        for (int index = 1; index <= count; index++)
          fakeRequest(id: 'req-$index', hospitalName: 'Hospital $index'),
      ],
      truncated: truncated,
      skipped: skipped,
    );
    container = ProviderContainer(
      overrides: [requestRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  }

  group('RequestsController before any read', () {
    test('starts untouched, with nothing read', () {
      setUpController();

      expect(state().status, RequestsStatus.initial);
      expect(state().requests, isEmpty);
      expect(state().loaded, isFalse);
      expect(state().failure, isNull);
      expect(controller().isFetching, isFalse);
      // The one case that earns a full-height spinner, and the reason `initial`
      // counts as loading: the screen has to draw *something* while it waits.
      expect(state().isInitialLoading, isTrue);
      expect(
        repository.calls,
        0,
        reason: 'mounting the provider asks no question',
      );
    });

    test('will not call itself empty and loaded', () {
      // The predicates are the contract the screens draw from, so a state that has
      // never been read must not satisfy any of the four resolved ones.
      setUpController();

      expect(state().isEmptyResult, isFalse);
      expect(state().isUnreadableResult, isFalse);
      expect(state().isFatalError, isFalse);
    });
  });

  group('RequestsController.load', () {
    test('reports loading while the window is in flight', () async {
      setUpController();
      repository.gate = Completer<void>();

      final Future<void> pending = controller().load();
      expect(state().status, RequestsStatus.loading);
      expect(state().requests, isEmpty);
      expect(state().loaded, isFalse);
      expect(controller().isFetching, isTrue);
      expect(repository.calls, 1);

      repository.gate!.complete();
      await pending;

      expect(state().status, RequestsStatus.ready);
      expect(state().requests, hasLength(3));
      expect(state().loaded, isTrue);
      expect(controller().isFetching, isFalse);
    });

    test('carries the window, not just the list', () async {
      // `truncated` and `skipped` travel with the requests because together they are
      // the only sentence the screen is allowed to say about the collection.
      setUpController(count: 2, truncated: true, skipped: 4);

      await controller().load();

      expect(state().requests, hasLength(2));
      expect(state().truncated, isTrue);
      expect(state().skipped, 4);
      expect(state().status, RequestsStatus.ready);
      expect(state().isEmptyResult, isFalse);
      expect(state().isUnreadableResult, isFalse);
    });

    test('leaves an empty collection empty, and honest about it', () async {
      setUpController(count: 0);

      await controller().load();

      expect(state().requests, isEmpty);
      expect(state().loaded, isTrue);
      expect(state().isEmptyResult, isTrue);
      expect(state().isUnreadableResult, isFalse);
    });

    test('reports a window of refusals as unreadable, never as empty', () async {
      // The distinction the skip count exists for: a donor who is told "no open
      // requests" stops looking, and that sentence is a lie when the read found
      // documents it could not parse.
      setUpController(count: 0, skipped: 3);

      await controller().load();

      expect(state().isUnreadableResult, isTrue);
      expect(state().isEmptyResult, isFalse);
    });

    test('reports a full window of refusals as unreadable too', () async {
      // Nothing readable came back, but the extra document proves requests are
      // behind it — so this is the other half of the same sentence.
      setUpController(count: 0, truncated: true);

      await controller().load();

      expect(state().isUnreadableResult, isTrue);
      expect(state().isEmptyResult, isFalse);
    });

    test('says there are requests when the window has them', () async {
      setUpController(count: 1);

      await controller().load();

      expect(state().isEmptyResult, isFalse);
      expect(state().isUnreadableResult, isFalse);
      expect(state().isInitialLoading, isFalse);
    });
  });

  group('RequestsController one read at a time', () {
    test('ignores a second load while one is in flight', () async {
      // The point of the flag rather than of disabled buttons: pull-to-refresh is a
      // gesture, and a donor hammering "Try again" four times should cost one read
      // of twenty-five documents, not four.
      setUpController();
      repository.gate = Completer<void>();

      final Future<void> first = controller().load();
      // A second ask while one is running answers immediately with a completed
      // future rather than queueing a second read of twenty-five documents.
      await controller().load();
      await controller().refresh();

      expect(repository.calls, 1);

      repository.gate!.complete();
      await first;
      expect(state().requests, hasLength(3));
      expect(controller().isFetching, isFalse);
    });

    test('treats refresh as the same request load is', () async {
      setUpController();

      await controller().refresh();

      expect(repository.calls, 1);
      expect(state().status, RequestsStatus.ready);
      expect(state().loaded, isTrue);
    });

    test('answers a load after a completed one with a fresh read', () async {
      setUpController();

      await controller().load();
      await controller().load();

      expect(repository.calls, 2);
    });
  });

  group('RequestsController when the read fails', () {
    test('keeps an untouched window as a fatal error, not as an empty one', () async {
      // `loaded` staying false is what stops the screen reading an empty list as
      // "nobody needs blood" — the failure is the only true statement here.
      setUpController();
      repository.failure = const NetworkFailure();

      await controller().load();

      expect(state().status, RequestsStatus.failure);
      expect(state().failure, isA<NetworkFailure>());
      expect(state().loaded, isFalse);
      expect(state().isFatalError, isTrue);
      expect(state().isEmptyResult, isFalse);
      expect(state().isInitialLoading, isFalse);
    });

    test('keeps the requests on screen when a refresh fails', () async {
      // The requests were true a moment ago; an error page in their place throws
      // away the only useful thing the donor has. The banner says the picture may
      // be stale, which is the whole message.
      setUpController(count: 2);
      await controller().load();
      repository.failure = const NetworkFailure();

      await controller().refresh();

      expect(state().requests, hasLength(2));
      expect(state().status, RequestsStatus.ready);
      expect(state().failure, isA<NetworkFailure>());
      expect(state().isFatalError, isFalse, reason: 'there is a list behind it');
      expect(state().isEmptyResult, isFalse);
    });

    test('keeps the window it already had, and its own caveats', () async {
      // A failed refresh must not quietly downgrade "only the first twenty-five are
      // shown" to a clean window: what is on screen is still what was measured.
      setUpController(count: 1, truncated: true, skipped: 2);
      await controller().load();
      repository.failure = const PermissionFailure(debugMessage: 'rules');

      await controller().refresh();

      expect(state().truncated, isTrue);
      expect(state().skipped, 2);
      expect(state().failure, isA<PermissionFailure>());
    });

    test('clears the failure as soon as a read succeeds', () async {
      setUpController();
      repository.failure = const NetworkFailure();
      await controller().load();
      expect(state().failure, isNotNull);

      repository.failure = null;
      await controller().load();

      expect(state().failure, isNull);
      expect(state().status, RequestsStatus.ready);
      expect(state().requests, hasLength(3));
    });

    test('replaces a stale list with the new one on recovery', () async {
      setUpController(count: 1);
      await controller().load();

      repository.requests = <BloodRequest>[
        fakeRequest(id: 'req-9', hospitalName: 'United Hospital'),
      ];
      await controller().refresh();

      expect(
        state().requests.map((BloodRequest request) => request.id),
        <String>['req-9'],
      );
    });

    test('does not blank a list it already has for a spinner', () async {
      // Status stays `ready` while a refresh with requests on screen is in flight:
      // replacing a readable list with a spinner for a second is worse than showing
      // stale-but-real requests.
      setUpController(count: 2);
      await controller().load();
      repository.gate = Completer<void>();

      final Future<void> pending = controller().refresh();
      expect(state().status, RequestsStatus.ready);
      expect(state().requests, hasLength(2));
      expect(state().isInitialLoading, isFalse);

      repository.gate!.complete();
      await pending;
      expect(controller().isFetching, isFalse);
    });

    test('lets a retry start once a failed read is over', () async {
      setUpController();
      repository.failure = const NetworkFailure();
      await controller().load();

      expect(
        controller().isFetching,
        isFalse,
        reason: 'the flag is always cleared',
      );
      repository.failure = null;
      await controller().load();

      expect(repository.calls, 2);
      expect(state().status, RequestsStatus.ready);
    });
  });

  group('RequestsState', () {
    test('names its own numbers and no place', () {
      // `toString` lands in log lines and in test failures, and these windows are
      // built from documents that carry a patient name, a phone number and an
      // address.
      final RequestsState state = RequestsState(
        status: RequestsStatus.ready,
        requests: <BloodRequest>[
          fakeRequest(
            hospitalName: 'Dhaka Medical College',
            hospitalAddress: 'Dhaka',
          ),
        ],
        truncated: true,
        skipped: 2,
      );

      expect(state.toString(), contains('1 requests'));
      expect(state.toString(), contains('truncated: true'));
      expect(state.toString(), contains('skipped: 2'));
      expect(state.toString().contains('Dhaka'), isFalse);
    });

    test('copyWith refuses to forget a failure by accident', () {
      const RequestsState start = RequestsState(
        status: RequestsStatus.ready,
        truncated: true,
        skipped: 1,
      );

      final RequestsState cleared = start.copyWith(clearFailure: true);
      final RequestsState untouched = start.copyWith();

      expect(cleared.truncated, isTrue);
      expect(cleared.skipped, 1);
      expect(cleared.loaded, isFalse);
      // Every field survives a copy that named none of them: a state update that
      // forgot `truncated` would silently retract the notice on screen.
      expect(untouched.status, start.status);
      expect(untouched.requests, start.requests);
      expect(untouched.truncated, isTrue);
      expect(untouched.skipped, 1);
      expect(untouched.failure, isNull);
    });
  });
}
