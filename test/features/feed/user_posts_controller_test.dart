import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/application/user_posts_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

import '../../support/fake_feed.dart';

void main() {
  late ProviderContainer container;

  UserPostsController controller() =>
      container.read(userPostsControllerProvider.notifier);
  FeedState state() => container.read(userPostsControllerProvider);

  /// Mounts one author's wall over a mixed-author fake feed.
  ///
  /// The uid is handed to [UserPostsController.open] exactly the way the pushed
  /// screen hands it from its first frame, and [uid] is the *viewer*
  /// (authUidProvider) — leaving it null skips hydration, which the
  /// like-hydration suite already covers.
  void setUp({required List<Post> posts, int pageSize = 10, String? uid}) {
    container = ProviderContainer(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          FakeFeedRepository(posts: posts, pageSize: pageSize),
        ),
        authUidProvider.overrideWithValue(uid),
      ],
    );
    addTearDown(container.dispose);
  }

  group('lists only the chosen author', () {
    test('open returns that author and nobody else', () async {
      setUp(
        posts: <Post>[
          fakePost(id: 'a1', authorUid: 'uid-a'),
          fakePost(id: 'b1', authorUid: 'uid-b'),
          fakePost(id: 'a2', authorUid: 'uid-a'),
          fakePost(id: 'b2', authorUid: 'uid-b'),
        ],
      );

      await controller().open('uid-a');

      expect(state().posts.map((Post p) => p.id), <String>['a1', 'a2']);
      expect(
        state().posts.every((Post p) => p.authorUid == 'uid-a'),
        isTrue,
      );
    });

    test('an author with no posts lands in the honest empty state', () async {
      setUp(posts: <Post>[fakePost(id: 'b1', authorUid: 'uid-b')]);

      await controller().open('uid-none');

      expect(state().posts, isEmpty);
      expect(state().loaded, isTrue);
      expect(state().isEmptyResult, isTrue);
    });

    test('pages within the author only, and stops at their end', () async {
      setUp(
        pageSize: 1,
        posts: <Post>[
          fakePost(id: 'a1', authorUid: 'uid-a'),
          fakePost(id: 'b1', authorUid: 'uid-b'),
          fakePost(id: 'a2', authorUid: 'uid-a'),
        ],
      );

      await controller().open('uid-a');
      expect(state().posts.map((Post p) => p.id), <String>['a1']);
      expect(state().hasMore, isTrue);

      await controller().loadMore();
      expect(state().posts.map((Post p) => p.id), <String>['a1', 'a2']);
      expect(state().hasMore, isFalse);
    });
  });

  group('a read needs an author', () {
    test('loadFirstPage before open lists nothing (never the whole feed)', () async {
      setUp(
        posts: <Post>[
          fakePost(id: 'a1', authorUid: 'uid-a'),
          fakePost(id: 'b1', authorUid: 'uid-b'),
        ],
      );

      // No open(): the guard in _read must refuse rather than fall back to an
      // unfiltered read that would show strangers' posts under one name.
      await controller().loadFirstPage();

      expect(state().posts, isEmpty);
      expect(state().loaded, isFalse);
    });
  });
}
