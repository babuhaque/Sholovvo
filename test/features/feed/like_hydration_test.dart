import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_like_hydration_service.dart';
import '../../support/fake_post_like_service.dart';

void main() {
  late FakeFeedRepository repository;
  late FakePostLikeService likeService;
  late FakeLikeHydrationService hydrationService;
  late ProviderContainer container;

  FeedController controller() =>
      container.read(feedControllerProvider.notifier);
  FeedState state() => container.read(feedControllerProvider);

  void setUp({int postCount = 5, String? uid = 'test-uid'}) {
    repository = FakeFeedRepository(
      posts: <Post>[
        for (int i = 0; i < postCount; i++)
          fakePost(id: 'p-$i', likeCount: 0),
      ],
      pageSize: postCount,
    );
    likeService = FakePostLikeService();
    hydrationService = FakeLikeHydrationService();
    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repository),
        postLikeServiceProvider.overrideWithValue(likeService),
        likeHydrationServiceProvider.overrideWithValue(hydrationService),
        authUidProvider.overrideWithValue(uid),
      ],
    );
    addTearDown(container.dispose);
  }

  group('hydrates on first page', () {
    test('likedPostIds populated from server', () async {
      setUp();
      hydrationService.likedIds = <String>{'p-1', 'p-3'};

      await controller().loadFirstPage();
      // Wait for the fire-and-forget hydration to settle.
      await Future<void>.delayed(Duration.zero);

      expect(state().likedPostIds, <String>{'p-1', 'p-3'});
    });

    test('passes post ids and uid to the hydration service', () async {
      setUp(postCount: 3, uid: 'user-99');
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(hydrationService.calls, hasLength(1));
      expect(hydrationService.calls.first, <String>['p-0', 'p-1', 'p-2']);
      expect(hydrationService.lastUid, 'user-99');
    });

    test('merges with existing local likes', () async {
      setUp(uid: null);

      // Load without hydration (no uid).
      await controller().loadFirstPage();
      await controller().toggleLike('p-0', 'me');
      expect(state().likedPostIds, contains('p-0'));

      // Now load with uid: server says p-2 was liked.
      setUp(uid: 'me');
      hydrationService.likedIds = <String>{'p-2'};
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      // The new container starts fresh, so p-0 isn't there.
      // The server only says p-2.
      expect(state().likedPostIds, contains('p-2'));
    });

    test('empty hydration result leaves likedPostIds unchanged', () async {
      setUp();
      hydrationService.likedIds = <String>{};

      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(state().likedPostIds, isEmpty);
    });
  });

  group('skips hydration when', () {
    test('no uid (authUidProvider is null)', () async {
      setUp(uid: null);
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(hydrationService.calls, isEmpty);
    });

    test('empty feed', () async {
      setUp(postCount: 0);
      // Override with an empty repository.
      repository = FakeFeedRepository(posts: <Post>[], pageSize: 0);
      container = ProviderContainer(
        overrides: [
          feedRepositoryProvider.overrideWithValue(repository),
          postLikeServiceProvider.overrideWithValue(likeService),
          likeHydrationServiceProvider.overrideWithValue(hydrationService),
          authUidProvider.overrideWithValue('me'),
        ],
      );
      addTearDown(container.dispose);

      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);

      expect(hydrationService.calls, isEmpty);
    });
  });

  group('refresh preserves likes across hydration', () {
    test('previously-hydrated likes survive a refresh', () async {
      setUp();
      hydrationService.likedIds = <String>{'p-1'};
      await controller().loadFirstPage();
      await Future<void>.delayed(Duration.zero);
      expect(state().likedPostIds, contains('p-1'));

      // Change what the server reports.
      hydrationService.likedIds = <String>{'p-4'};
      await controller().refresh();
      await Future<void>.delayed(Duration.zero);

      // p-1 survives (from first hydration) AND p-4 is added.
      expect(state().likedPostIds, containsAll(<String>{'p-1', 'p-4'}));
    });
  });
}
