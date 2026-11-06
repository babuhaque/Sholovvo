import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/user_posts_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';

import '../../support/fake_feed.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

/// Mounts the whole feed over a paging fake.
///
/// Mirrors `feed_screen_test.dart`: the first page resolves from a post-frame
/// callback, and the soft-glow background animates forever, so settling is a
/// fixed number of pumps rather than `pumpAndSettle`.
Future<void> _pumpFeed(
  WidgetTester tester, {
  required List<Post> posts,
  int pageSize = 10,
}) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        feedRepositoryProvider.overrideWithValue(
          FakeFeedRepository(posts: posts, pageSize: pageSize),
        ),
      ],
      child: testApp(home: const FeedScreen()),
    ),
  );
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester, [int frames = 6]) async {
  for (int index = 0; index < frames; index++) {
    await tester.pump();
  }
}

void main() {
  group('tapping an author in the feed', () {
    testWidgets('opens that author\'s wall', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        posts: <Post>[
          fakePost(id: 'a1', authorUid: 'uid-a', authorName: 'Ayesha Rahman'),
          fakePost(id: 'b1', authorUid: 'uid-b', authorName: 'Rafiq Hasan'),
        ],
      );

      expect(find.byType(UserPostsScreen), findsNothing);

      await tester.tap(find.text('Ayesha Rahman').first);
      await _settle(tester, 12);

      expect(find.byType(UserPostsScreen), findsOneWidget);
    });

    testWidgets('the wall lists only the tapped author\'s posts', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(
        tester,
        posts: <Post>[
          fakePost(id: 'a1', authorUid: 'uid-a', authorName: 'Ayesha Rahman'),
          fakePost(id: 'b1', authorUid: 'uid-b', authorName: 'Rafiq Hasan'),
          fakePost(id: 'a2', authorUid: 'uid-a', authorName: 'Ayesha Rahman'),
        ],
      );

      await tester.tap(find.text('Ayesha Rahman').first);
      // Extra pumps: the pushed screen kicks its own first read from a
      // post-frame callback once it mounts.
      await _settle(tester, 14);

      expect(find.byType(UserPostsScreen), findsOneWidget);
      // Only Ayesha's tiles reach the author screen's list; Rafiq's post is
      // filtered out by the scoped uid.
      final Iterable<FeedPostTile> tiles = tester.widgetList<FeedPostTile>(
        find.descendant(
          of: find.byType(UserPostsScreen),
          matching: find.byType(FeedPostTile),
        ),
      );
      expect(tiles.map((FeedPostTile t) => t.post.id), <String>['a1', 'a2']);
      expect(
        tiles.every((FeedPostTile t) => t.post.authorUid == 'uid-a'),
        isTrue,
      );
    });

    testWidgets('the wall header names the author', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(
        tester,
        posts: <Post>[
          fakePost(id: 'a1', authorUid: 'uid-a', authorName: 'Ayesha Rahman'),
        ],
      );

      await tester.tap(find.text('Ayesha Rahman').first);
      await _settle(tester, 14);

      // The app bar carries the author's name as the wall's title.
      expect(
        find.descendant(
          of: find.byType(UserPostsScreen),
          matching: find.text('Ayesha Rahman'),
        ),
        findsWidgets,
      );
    });
  });
}
