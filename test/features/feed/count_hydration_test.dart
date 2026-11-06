import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/data/feed_count_hydration_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_feed_count_hydration_service.dart';
import '../../support/fake_like_hydration_service.dart';
import '../../support/fake_post_like_service.dart';

void main() {
  late FakeFeedRepository repository;
  late FakePostLikeService likeService;
  late FakeLikeHydrationService likeHydration;
  late FakeFeedCountHydrationService countHydration;
  late ProviderContainer container;

  FeedController controller() =>
      container.read(feedControllerProvider.notifier);
  FeedState state() => container.read(feedControllerProvider);

  void setUp({
    int postCount = 5,
    String? uid = 'test-uid',
    List<int>? seedLikeCounts,
    List<int>? seedCommentCounts,
  }) {
    repository = FakeFeedRepository(
      posts: <Post>[
        for (int i = 0; i < postCount; i++)
          fakePost(
            id: 'p-$i',
            likeCount: seedLikeCounts?[i] ?? 0,
            commentCount: seedCommentCounts?[i] ?? 0,
          ),
      ],
      pageSize: postCount,
    );
    likeService = FakePostLikeService();
    likeHydration = FakeLikeHydrationService();
    countHydration = FakeFeedCountHydrationService();
    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repository),
        postLikeServiceProvider.overrideWithValue(likeService),
        likeHydrationServiceProvider.overrideWithValue(likeHydration),
        feedCountHydrationServiceProvider.overrideWithValue(countHydration),
        authUidProvider.overrideWithValue(uid),
      ],
    );
    addTearDown(container.dispose);
  }

  group('derived counts applied on first page', () {
    test('likeCount and commentCount replaced by hydration values', () async {
      setUp(postCount: 3, seedLikeCounts: [0, 0, 0], seedCommentCounts: [0, 0, 0]);
      countHydration.counts = <String, PostCountSnapshot>{
        'p-0': const PostCountSnapshot(likeCount: 7, commentCount: 3),
        'p-1': const PostCountSnapshot(likeCount: 12, commentCount: 1),
        'p-2': const PostCountSnapshot(likeCount: 0, commentCount: 5),
      };

      await controller().loadFirstPage();
      // Let the fire-and-forget hydration settle.
      await Future<void>.delayed(Duration.zero);

      final List<Post> posts = state().posts;
      expect(posts[0].likeCount, 7);
      expect(posts[0].commentCount, 3);
      expect(posts[1].likeCount, 12);
      expect(posts[1].commentCount, 1);
      expect(posts[2].likeCount, 0);
      expect(posts[2].commentCount, 5);
    });

    test('passes visible post ids to the count service', () async {
      setUp(postCount: 4);
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(countHydration.calls, hasLength(1));
      expect(
        countHydration.calls.first,
        <String>['p-0', 'p-1', 'p-2', 'p-3'],
      );
    });

    test('post absent from snapshot keeps its document-carried count', () async {
      setUp(postCount: 2, seedLikeCounts: [4, 9], seedCommentCounts: [2, 6]);
      // Only p-0 is reported; p-1 had a transient read failure.
      countHydration.counts = <String, PostCountSnapshot>{
        'p-0': const PostCountSnapshot(likeCount: 10, commentCount: 5),
      };

      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      // p-0 gets the derived value.
      expect(state().posts[0].likeCount, 10);
      expect(state().posts[0].commentCount, 5);
      // p-1 keeps the seed because it was omitted from the snapshot.
      expect(state().posts[1].likeCount, 9);
      expect(state().posts[1].commentCount, 6);
    });

    test('empty counts map leaves all posts unchanged', () async {
      setUp(postCount: 3, seedLikeCounts: [5, 3, 1], seedCommentCounts: [2, 4, 0]);
      countHydration.counts = <String, PostCountSnapshot>{};

      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(state().posts[0].likeCount, 5);
      expect(state().posts[1].likeCount, 3);
      expect(state().posts[2].likeCount, 1);
    });
  });

  group('defensive: count seam failure does not crash the feed', () {
    test('count service throwing leaves posts with original counts', () async {
      setUp(postCount: 2, seedLikeCounts: [3, 7], seedCommentCounts: [1, 2]);
      countHydration.throws = true;

      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      // Feed still works, counts unchanged (document seeds).
      expect(state().posts, hasLength(2));
      expect(state().posts[0].likeCount, 3);
      expect(state().posts[1].likeCount, 7);
    });
  });

  group('skips count hydration when', () {
    test('no uid (authUidProvider is null)', () async {
      setUp(postCount: 3, uid: null);
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(countHydration.calls, isEmpty);
    });

    test('empty feed (no posts)', () async {
      setUp(postCount: 0);
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(countHydration.calls, isEmpty);
    });
  });

  group('likes and counts coexist', () {
    test('like applied first, then counts, both visible', () async {
      setUp(postCount: 2, seedLikeCounts: [0, 0], seedCommentCounts: [0, 0]);
      likeHydration.likedIds = <String>{'p-1'};
      countHydration.counts = <String, PostCountSnapshot>{
        'p-0': const PostCountSnapshot(likeCount: 5, commentCount: 2),
        'p-1': const PostCountSnapshot(likeCount: 10, commentCount: 4),
      };

      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      // Likes merged from the like hydration.
      expect(state().likedPostIds, contains('p-1'));
      // Counts derived from the count hydration.
      expect(state().posts[0].likeCount, 5);
      expect(state().posts[1].likeCount, 10);
      expect(state().posts[0].commentCount, 2);
      expect(state().posts[1].commentCount, 4);
    });
  });

  group('refresh re-derives counts', () {
    test('second load fetches fresh counts', () async {
      setUp(postCount: 2, seedLikeCounts: [0, 0], seedCommentCounts: [0, 0]);
      countHydration.counts = <String, PostCountSnapshot>{
        'p-0': const PostCountSnapshot(likeCount: 3, commentCount: 1),
        'p-1': const PostCountSnapshot(likeCount: 6, commentCount: 2),
      };
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);
      expect(state().posts[0].likeCount, 3);

      // Simulate new likes arriving on the server.
      countHydration.counts = <String, PostCountSnapshot>{
        'p-0': const PostCountSnapshot(likeCount: 4, commentCount: 1),
        'p-1': const PostCountSnapshot(likeCount: 8, commentCount: 3),
      };
      await controller().refresh();
      await Future<void>.delayed(Duration.zero);
      expect(state().posts[0].likeCount, 4);
      expect(state().posts[1].likeCount, 8);
      expect(state().posts[1].commentCount, 3);
    });
  });
}
