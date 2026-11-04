import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/donors/application/donor_search_providers.dart';
import 'package:sholovvo_app/features/donors/application/donor_search_state.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

import '../../support/fake_donors.dart';

void main() {
  late FakeDonorRepository repository;
  late ProviderContainer container;

  DonorSearchController controller() =>
      container.read(donorSearchControllerProvider.notifier);
  DonorSearchState state() => container.read(donorSearchControllerProvider);

  void setUpController({
    int count = 3,
    bool truncated = false,
    int skipped = 0,
  }) {
    repository = FakeDonorRepository(
      donors: <Donor>[
        for (int index = 1; index <= count; index++)
          fakeDonor(uid: 'd-$index', displayName: 'Donor $index'),
      ],
      truncated: truncated,
      skipped: skipped,
    );
    container = ProviderContainer(
      overrides: [donorRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  }

  group('DonorSearchController before any read', () {
    test('starts untouched, with nothing read', () {
      setUpController();

      expect(state().status, DonorSearchStatus.initial);
      expect(state().donors, isEmpty);
      expect(state().loaded, isFalse);
      expect(state().failure, isNull);
      expect(controller().isFetching, isFalse);
      expect(state().isInitialLoading, isTrue);
      expect(repository.calls, 0, reason: 'mounting the provider asks no question');
    });

    test('will not call itself empty and loaded', () {
      setUpController();

      expect(state().isEmptyResult, isFalse);
      expect(state().isUnreadableResult, isFalse);
      expect(state().isFatalError, isFalse);
    });
  });

  group('DonorSearchController.load', () {
    test('reports loading while the window is in flight', () async {
      setUpController();
      repository.gate = Completer<void>();

      final Future<void> pending = controller().load();
      expect(state().status, DonorSearchStatus.loading);
      expect(state().donors, isEmpty);
      expect(state().loaded, isFalse);
      expect(controller().isFetching, isTrue);
      expect(repository.calls, 1);

      repository.gate!.complete();
      await pending;

      expect(state().status, DonorSearchStatus.ready);
      expect(state().donors, hasLength(3));
      expect(state().loaded, isTrue);
      expect(controller().isFetching, isFalse);
    });

    test('carries the window, not just the list', () async {
      setUpController(count: 2, truncated: true, skipped: 4);

      await controller().load();

      expect(state().donors, hasLength(2));
      expect(state().truncated, isTrue);
      expect(state().skipped, 4);
      expect(state().isEmptyResult, isFalse);
      expect(state().isUnreadableResult, isFalse);
    });

    test('leaves an empty directory empty, and honest about it', () async {
      setUpController(count: 0);

      await controller().load();

      expect(state().donors, isEmpty);
      expect(state().loaded, isTrue);
      expect(state().isEmptyResult, isTrue);
      expect(state().isUnreadableResult, isFalse);
    });

    test('reports a window of refusals as unreadable, never as empty', () async {
      setUpController(count: 0, skipped: 3);

      await controller().load();

      expect(state().isUnreadableResult, isTrue);
      expect(state().isEmptyResult, isFalse);
    });

    test('reports a full window of refusals as unreadable too', () async {
      setUpController(count: 0, truncated: true);

      await controller().load();

      expect(state().isUnreadableResult, isTrue);
      expect(state().isEmptyResult, isFalse);
    });
  });

  group('DonorSearchController.search', () {
    test('applies and stores a normalised query', () async {
      setUpController();

      // 'Z+' is not one of the eight; normalising drops it to "any group".
      await controller().search(const DonorQuery(bloodGroup: 'Z+', area: ' Mirpur '));

      expect(state().query.bloodGroup, isNull);
      expect(state().query.area, 'Mirpur');
      expect(repository.lastQuery, state().query);
    });

    test('a changed filter re-reads even while a list is on screen', () async {
      // A refresh keeps the rows; a *new* question replaces them, because the old
      // rows answered a different filter.
      setUpController(count: 2);
      await controller().load();

      repository.donors = <Donor>[fakeDonor(uid: 'new-1')];
      await controller().search(const DonorQuery(bloodGroup: 'A+'));

      expect(state().donors, hasLength(1));
      expect(state().donors.first.uid, 'new-1');
    });
  });

  group('DonorSearchController one read at a time', () {
    test('ignores a second load while one is in flight', () async {
      setUpController();
      repository.gate = Completer<void>();

      final Future<void> first = controller().load();
      await controller().load();
      await controller().refresh();

      expect(repository.calls, 1);

      repository.gate!.complete();
      await first;
      expect(state().donors, hasLength(3));
      expect(controller().isFetching, isFalse);
    });

    test('treats refresh as the same request load is', () async {
      setUpController();

      await controller().refresh();

      expect(repository.calls, 1);
      expect(state().status, DonorSearchStatus.ready);
    });
  });

  group('DonorSearchController when the read fails', () {
    test('keeps an untouched window as a fatal error, not as an empty one', () async {
      setUpController();
      repository.failure = const NetworkFailure();

      await controller().load();

      expect(state().status, DonorSearchStatus.failure);
      expect(state().failure, isA<NetworkFailure>());
      expect(state().loaded, isFalse);
      expect(state().isFatalError, isTrue);
      expect(state().isEmptyResult, isFalse);
    });

    test('keeps the donors on screen when a refresh fails', () async {
      setUpController(count: 2);
      await controller().load();
      repository.failure = const NetworkFailure();

      await controller().refresh();

      expect(state().donors, hasLength(2));
      expect(state().status, DonorSearchStatus.ready);
      expect(state().failure, isA<NetworkFailure>());
      expect(state().isFatalError, isFalse, reason: 'there is a list behind it');
    });

    test('clears the failure as soon as a read succeeds', () async {
      setUpController();
      repository.failure = const NetworkFailure();
      await controller().load();
      expect(state().failure, isNotNull);

      repository.failure = null;
      await controller().load();

      expect(state().failure, isNull);
      expect(state().status, DonorSearchStatus.ready);
    });
  });

  group('DonorSearchState', () {
    test('names its own numbers and no location', () {
      final DonorSearchState state = DonorSearchState(
        status: DonorSearchStatus.ready,
        donors: <Donor>[
          fakeDonor(displayName: 'Ayesha', area: 'Dhanmondi, Dhaka'),
        ],
        truncated: true,
        skipped: 2,
      );

      expect(state.toString(), contains('1 donors'));
      expect(state.toString(), contains('truncated: true'));
      expect(state.toString(), contains('skipped: 2'));
      expect(state.toString().contains('Dhanmondi'), isFalse);
      expect(state.toString().contains('Ayesha'), isFalse);
    });

    test('hasActiveFilters reads the normalised query, not a half-typed one', () {
      // An empty area that has not been submitted is still the default question.
      const DonorSearchState start = DonorSearchState(query: DonorQuery());
      expect(start.hasActiveFilters, isFalse);

      const DonorSearchState grouped = DonorSearchState(
        query: DonorQuery(bloodGroup: 'B+'),
      );
      expect(grouped.hasActiveFilters, isTrue);
    });
  });
}
