import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

import '../../support/fake_feed.dart';
import '../../support/fake_saved_posts_service.dart';

void main() {
  late FakeFeedRepository repository;
  late FakeSavedPostsService savedService;
  late ProviderContainer container;

  FeedController controller() =>
      container.read(feedControllerProvider.notifier);
  FeedState state() => container.read(feedControllerProvider);

  void setUp({Set<String>? initialIds}) {
    repository = FakeFeedRepository(
      posts: <Post>[
        for (int i = 0; i < 5; i++) fakePost(id: 'p-$i'),
      ],
      pageSize: 5,
    );
    savedService = FakeSavedPostsService(initialIds: initialIds);
    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(repository),
        savedPostsServiceProvider.overrideWithValue(savedService),
      ],
    );
    addTearDown(container.dispose);
  }

  Future<void> loadFeed() async {
    await controller().loadFirstPage();
  }

  group('toggleSave', () {
    test('adds to savedPostIds', () async {
      setUp();
      await loadFeed();

      controller().toggleSave('p-2');

      expect(state().savedPostIds, contains('p-2'));
    });

    test('removes from savedPostIds on second toggle', () async {
      setUp();
      await loadFeed();

      controller().toggleSave('p-2');
      controller().toggleSave('p-2');

      expect(state().savedPostIds, isNot(contains('p-2')));
    });

    test('persists via service.save()', () async {
      setUp();
      await loadFeed();

      controller().toggleSave('p-0');
      // Let fire-and-forget settle.
      await Future<void>.delayed(Duration.zero);

      expect(savedService.saveCallCount, 1);
      expect(savedService.savedIds, contains('p-0'));
    });

    test('hydrates from service.load() on build', () async {
      setUp(initialIds: {'p-1', 'p-3'});
      await loadFeed();

      expect(state().savedPostIds, containsAll(<String>{'p-1', 'p-3'}));
    });

    test('preserves savedPostIds across refresh', () async {
      setUp();
      await loadFeed();
      controller().toggleSave('p-4');

      await controller().refresh();

      expect(state().savedPostIds, contains('p-4'));
    });
  });
}
