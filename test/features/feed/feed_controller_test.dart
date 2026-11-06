import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';

import '../../support/fake_feed.dart';

/// A repository that answers with a fixed script of pages, so a test can make
/// two pages overlap and watch what the controller does with them.
final class _ScriptedRepository implements FeedRepository {
  _ScriptedRepository(this.pages);

  final List<FeedPage> pages;
  int calls = 0;

  @override
  Future<Result<FeedPage>> loadPage({
    FeedCursor? after,
    String? authorUid,
  }) async {
    final FeedPage page =
        pages[calls < pages.length ? calls : pages.length - 1];
    calls++;
    return Success<FeedPage>(page);
  }
}

void main() {
  late FakeFeedRepository repository;
  late ProviderContainer container;

  FeedController controller() =>
      container.read(feedControllerProvider.notifier);
  FeedState state() => container.read(feedControllerProvider);

  /// Mounts the controller over a paging fake with [count] posts.
  void setUpController({int count = 30, int pageSize = 2}) {
    repository = FakeFeedRepository(
      posts: <Post>[
        for (int index = 0; index < count; index++)
          fakePost(id: 'post-$index', text: 'Post $index'),
      ],
      pageSize: pageSize,
    );
    container = ProviderContainer(
      overrides: [feedRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  }

  group('FeedController', () {
    test('starts untouched, with nothing read', () {
      setUpController();

      expect(state().status, FeedStatus.initial);
      expect(state().posts, isEmpty);
      expect(state().loaded, isFalse);
      // The one case that earns a full-height spinner.
      expect(state().isInitialLoading, isTrue);
      expect(repository.calls, 0);
    });

    test('reports loading while the first page is in flight', () async {
      setUpController();
      repository.gate = Completer<void>();

      final Future<void> pending = controller().loadFirstPage();
      expect(state().status, FeedStatus.loading);
      expect(state().posts, isEmpty);

      repository.gate!.complete();
      await pending;

      expect(state().status, FeedStatus.ready);
      expect(state().posts, hasLength(2));
      expect(state().loaded, isTrue);
      expect(state().hasMore, isTrue);
    });

    test('reads the first page without a cursor', () async {
      setUpController();

      await controller().loadFirstPage();

      expect(repository.requestedAfter, <FeedCursor?>[null]);
    });

    test('appends the next page and moves the cursor', () async {
      setUpController();

      await controller().loadFirstPage();
      await controller().loadMore();

      expect(state().posts.map((Post post) => post.id), <String>[
        'post-0',
        'post-1',
        'post-2',
        'post-3',
      ]);
      expect(repository.requestedAfter, <FeedCursor?>[
        null,
        const FeedTestCursor('2'),
      ]);
    });

    test('stops offering more once the list is exhausted', () async {
      setUpController(count: 3);

      await controller().loadFirstPage();
      await controller().loadMore();

      expect(state().posts, hasLength(3));
      expect(state().hasMore, isFalse);

      final int calls = repository.calls;
      await controller().loadMore();
      // Nothing left to ask for, so nothing was asked for.
      expect(repository.calls, calls);
    });

    test('ignores a second load-more while one is in flight', () async {
      setUpController();
      await controller().loadFirstPage();

      repository.gate = Completer<void>();
      final Future<void> first = controller().loadMore();
      final Future<void> second = controller().loadMore();

      expect(repository.calls, 2, reason: 'first page plus one load-more');
      expect(controller().isFetching, isTrue);

      repository.gate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      // Four posts, not six: the second tap paid for nothing.
      expect(state().posts, hasLength(4));
      expect(controller().isFetching, isFalse);
    });

    test('shows the loading-more state without blanking the list', () async {
      setUpController();
      await controller().loadFirstPage();

      repository.gate = Completer<void>();
      final Future<void> pending = controller().loadMore();
      await Future<void>.value();

      expect(state().status, FeedStatus.loadingMore);
      expect(state().posts, hasLength(2), reason: 'the page stays readable');

      repository.gate!.complete();
      await pending;
    });

    test('a refresh keeps the posts on screen while it runs', () async {
      setUpController();
      await controller().loadFirstPage();

      repository.gate = Completer<void>();
      final Future<void> pending = controller().refresh();
      await Future<void>.value();

      // Not `loading`: blanking a readable list for a spinner is a worse answer
      // than showing stale-but-real posts for another second.
      expect(state().status, FeedStatus.ready);
      expect(state().posts, hasLength(2));

      repository.gate!.complete();
      await pending;

      expect(state().posts, hasLength(2));
      expect(repository.requestedAfter, <FeedCursor?>[null, null]);
    });

    test('a failed refresh keeps the posts and reports the failure', () async {
      setUpController();
      await controller().loadFirstPage();

      repository.failure = const NetworkFailure(debugMessage: 'offline');
      await controller().refresh();

      expect(state().posts, hasLength(2), reason: 'the list survives');
      expect(state().status, FeedStatus.ready);
      expect(state().failure, isA<NetworkFailure>());
      expect(state().isFatalError, isFalse);
    });

    test('a failed first page is fatal and says why', () async {
      setUpController();
      repository.failure = const NetworkFailure(debugMessage: 'offline');

      await controller().loadFirstPage();

      expect(state().posts, isEmpty);
      expect(state().status, FeedStatus.failure);
      expect(state().isFatalError, isTrue);
      expect(
        state().isInitialLoading,
        isFalse,
        reason: 'the spinner must stop',
      );
    });

    test('retrying after a fatal failure loads the page', () async {
      setUpController();
      repository.failure = const NetworkFailure(debugMessage: 'offline');
      await controller().loadFirstPage();

      repository.failure = null;
      await controller().loadFirstPage();

      expect(state().status, FeedStatus.ready);
      expect(state().posts, hasLength(2));
      expect(state().failure, isNull, reason: 'the old banner is cleared');
    });

    test('a failed load-more keeps the page and the cursor', () async {
      setUpController();
      await controller().loadFirstPage();

      repository.failure = const NetworkFailure(debugMessage: 'offline');
      await controller().loadMore();

      expect(state().posts, hasLength(2), reason: 'the page survives');
      expect(state().status, FeedStatus.ready);
      expect(state().failure, isNotNull);
      expect(state().cursor, const FeedTestCursor('2'));

      repository.failure = null;
      await controller().loadMore();

      // The retry asked the same question rather than skipping a page.
      expect(repository.requestedAfter, <FeedCursor?>[
        null,
        const FeedTestCursor('2'),
        const FeedTestCursor('2'),
      ]);
      expect(state().failure, isNull);
      expect(state().posts, hasLength(4));
    });

    test('does not append a post it already has', () async {
      final Post first = fakePost(id: 'a', text: 'First');
      final Post second = fakePost(id: 'b', text: 'Second');
      final Post third = fakePost(id: 'c', text: 'Third');
      final _ScriptedRepository scripted = _ScriptedRepository(<FeedPage>[
        FeedPage(
          posts: <Post>[first, second],
          cursor: const FeedTestCursor('1'),
          hasMore: true,
        ),
        // A rewrite that moved a post's timestamp can legitimately surface it
        // twice; a feed that shows it twice still looks broken.
        FeedPage(
          posts: <Post>[second, third],
          cursor: const FeedTestCursor('2'),
        ),
      ]);
      final ProviderContainer scriptedContainer = ProviderContainer(
        overrides: [feedRepositoryProvider.overrideWithValue(scripted)],
      );
      addTearDown(scriptedContainer.dispose);

      await scriptedContainer
          .read(feedControllerProvider.notifier)
          .loadFirstPage();
      await scriptedContainer.read(feedControllerProvider.notifier).loadMore();

      expect(
        scriptedContainer
            .read(feedControllerProvider)
            .posts
            .map((Post post) => post.id),
        <String>['a', 'b', 'c'],
      );
    });
  });
}
