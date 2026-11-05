import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_post_like_service.dart';

void main() {
  late FakeFeedRepository repository;
  late FakePostLikeService likeService;
  late ProviderContainer container;

  FeedController controller() =>
      container.read(feedControllerProvider.notifier);
  FeedState state() => container.read(feedControllerProvider);

  /// Mounts the controller over a fake feed + fake like service.
  void setUp({int count = 5}) {
    repository = FakeFeedRepository(
      posts: <Post>[
        for (int i = 0; i < count; i++)
          fakePost(id: 'p-$i', likeCount: i),
      ],
      pageSize: count,
    );
    likeService = FakePostLikeService();
    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repository),
        postLikeServiceProvider.overrideWithValue(likeService),
      ],
    );
    addTearDown(container.dispose);
  }

  /// Loads the first page so posts are available.
  Future<void> loadFeed() async {
    await controller().loadFirstPage();
  }

  group('toggleLike', () {
    test('likes a post: adds to likedPostIds, increments count, calls service', () async {
      setUp();
      await loadFeed();

      expect(state().likedPostIds, isEmpty);
      expect(state().posts[0].likeCount, 0);

      await controller().toggleLike('p-0', 'uid-1');

      expect(state().likedPostIds, contains('p-0'));
      expect(state().posts[0].likeCount, 1);
      expect(likeService.likeCalls, ['p-0']);
      expect(likeService.unlikeCalls, isEmpty);
    });

    test('unlikes a liked post: removes from set, decrements, calls unlike', () async {
      setUp();
      await loadFeed();

      // Like first.
      await controller().toggleLike('p-0', 'uid-1');
      expect(state().likedPostIds, contains('p-0'));

      // Unlike.
      await controller().toggleLike('p-0', 'uid-1');

      expect(state().likedPostIds, isNot(contains('p-0')));
      expect(state().posts[0].likeCount, 0);
      expect(likeService.unlikeCalls, ['p-0']);
    });

    test('rolls back on service failure', () async {
      setUp();
      await loadFeed();
      likeService.failure = NetworkFailure(debugMessage: 'offline');

      await controller().toggleLike('p-0', 'uid-1');

      // State reverted: not liked, count restored to original (0).
      expect(state().likedPostIds, isNot(contains('p-0')));
      expect(state().posts[0].likeCount, 0);
      // The service was still called.
      expect(likeService.likeCalls, ['p-0']);
    });

    test('no-op for a post not in the list', () async {
      setUp();
      await loadFeed();

      await controller().toggleLike('nonexistent', 'uid-1');

      expect(state().likedPostIds, isEmpty);
      expect(likeService.likeCalls, isEmpty);
    });

    test('optimistic: local state updates before the service completes', () async {
      setUp();
      await loadFeed();

      // Use a gate to hold the service response.
      final completer = Future<void>.delayed(const Duration(milliseconds: 50));
      likeService.failure = null; // Will succeed normally, but we test timing.

      final future = controller().toggleLike('p-0', 'uid-1');

      // Immediately after the call (before await), the optimistic state should
      // already be set (the controller updates before awaiting).
      // Actually, Dart async: the toggleLike synchronously updates state
      // before its first await (the service call). So checking right after
      // calling toggleLike but before awaiting:
      expect(state().likedPostIds, contains('p-0'));
      expect(state().posts[0].likeCount, 1);

      await future;
      await completer;
    });

    test('multiple posts can be liked independently', () async {
      setUp(count: 5);
      await loadFeed();

      await controller().toggleLike('p-1', 'uid-1');
      await controller().toggleLike('p-3', 'uid-1');

      expect(state().likedPostIds, {'p-1', 'p-3'});
      expect(state().posts[1].likeCount, 2); // was 1, +1
      expect(state().posts[3].likeCount, 4); // was 3, +1
    });
  });
}
