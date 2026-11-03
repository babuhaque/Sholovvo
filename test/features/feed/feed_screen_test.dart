import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';

import '../../support/fake_feed.dart';
import '../../support/test_app.dart';

const Size _phone = Size(430, 932);

/// A post long enough to be collapsed at any sane text width: 40 sentences of
/// four words each is far past six lines.
final String _longText = List<String>.filled(
  40,
  'Donated blood at Dhaka Medical today',
).join('. ');

/// Mounts the feed over a paging fake.
///
/// The screen reads its first page from a post-frame callback, so the pumps
/// after mounting are what let that read start and resolve. `pumpAndSettle` is
/// not usable anywhere in this file: the soft glow behind the page animates
/// forever.
Future<FakeFeedRepository> _pumpFeed(
  WidgetTester tester, {
  List<Post>? posts,
  int pageSize = 2,
  Failure? failure,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
  Size size = _phone,
  Completer<void>? gate,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final FakeFeedRepository repository = FakeFeedRepository(
    posts: posts,
    pageSize: pageSize,
  );
  repository.failure = failure;
  repository.gate = gate;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [feedRepositoryProvider.overrideWithValue(repository)],
      child: testApp(
        home: const FeedScreen(),
        themeMode: themeMode,
        locale: locale,
      ),
    ),
  );
  await _settle(tester);
  return repository;
}

/// A few frames, enough for a resolved read to reach the tree.
Future<void> _settle(WidgetTester tester, [int frames = 4]) async {
  for (int index = 0; index < frames; index++) {
    await tester.pump();
  }
}

void main() {
  group('FeedScreen', () {
    testWidgets('spins while the first page is in flight', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository repository = await _pumpFeed(
        tester,
        posts: <Post>[fakePost()],
        gate: Completer<void>(),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FeedPostTile), findsNothing);
      expect(repository.calls, 1, reason: 'opening the feed reads once');

      repository.gate!.complete();
      await _settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(FeedPostTile), findsOneWidget);
    });

    testWidgets('draws a page of posts', (WidgetTester tester) async {
      final DateTime threeHoursAgo = DateTime.now().subtract(
        const Duration(hours: 3),
      );

      await _pumpFeed(
        tester,
        posts: <Post>[
          fakePost(
            id: 'post-1',
            authorName: 'Ayesha Rahman',
            text: 'Donated at Dhaka Medical today.',
            likeCount: 4,
            commentCount: 2,
            createdAt: threeHoursAgo,
          ),
          fakePost(
            id: 'post-2',
            authorName: 'Rafiq Hasan',
            text: 'Looking for O- for my sister.',
            createdAt: threeHoursAgo,
          ),
        ],
        pageSize: 2,
      );

      expect(find.byType(FeedPostTile), findsNWidgets(2));
      expect(find.text('Ayesha Rahman'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      expect(find.text('Donated at Dhaka Medical today.'), findsOneWidget);
      expect(find.text('4 likes'), findsOneWidget);
      expect(find.text('2 comments'), findsOneWidget);
      expect(find.text('0 likes'), findsOneWidget);
      // Relative, because the post is hours old rather than weeks: the label
      // switches to a calendar date only after a week.
      expect(find.text('3 hours ago'), findsNWidgets(2));
    });

    testWidgets('says the feed is empty rather than showing nothing', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(tester);

      expect(find.text('No posts yet'), findsOneWidget);
      expect(
        find.text('When a donor shares an update, it appears here.'),
        findsOneWidget,
      );
      expect(find.byType(FeedPostTile), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // A calm card, not a card-shaped hole: the empty state is centred inside
      // the remaining height, and it must not be stretched to fill it.
      expect(tester.getSize(find.byType(EmptyStateCard)).height, lessThan(200));
    });

    testWidgets('reports a failed first page and offers a retry', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository repository = await _pumpFeed(
        tester,
        posts: <Post>[fakePost()],
        failure: const NetworkFailure(debugMessage: 'offline'),
      );

      expect(find.text('The feed could not be loaded'), findsOneWidget);
      expect(
        find.text('No connection. Check your network and try again.'),
        findsOneWidget,
      );
      expect(find.byType(FeedPostTile), findsNothing);
      expect(tester.getSize(find.byType(EmptyStateCard)).height, lessThan(300));

      repository.failure = null;
      await tester.tap(find.text('Try again'));
      await _settle(tester);

      expect(repository.calls, 2);
      expect(find.text('The feed could not be loaded'), findsNothing);
      expect(find.byType(FeedPostTile), findsOneWidget);
    });

    testWidgets('pages forward and then says the list has ended', (
      WidgetTester tester,
    ) async {
      // Eleven posts at the real page size of ten: one full page plus proof that
      // a second one exists. The window is tall enough to hold both pages, so a
      // lazily built list builds every tile and the footer is really on screen.
      await _pumpFeed(
        tester,
        posts: <Post>[
          for (int index = 0; index < 11; index++)
            fakePost(id: 'post-$index', text: 'Post $index'),
        ],
        pageSize: FeedRepository.pageSize,
        size: const Size(430, 3200),
      );

      expect(find.byType(FeedPostTile), findsNWidgets(10));
      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await _settle(tester);

      expect(find.byType(FeedPostTile), findsNWidgets(11));
      expect(find.text('Load more'), findsNothing);
      expect(find.text('You have reached the end of the feed'), findsOneWidget);
    });

    testWidgets('offers no "load more" when the first page is the last', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(tester, posts: <Post>[fakePost()], pageSize: 2);

      expect(find.byType(FeedPostTile), findsOneWidget);
      expect(find.text('Load more'), findsNothing);
      // One short page that ends is obvious; a label under it would be noise.
      expect(find.text('You have reached the end of the feed'), findsNothing);
    });

    testWidgets('pulling down asks for the first page again', (
      WidgetTester tester,
    ) async {
      final FakeFeedRepository repository = await _pumpFeed(
        tester,
        posts: <Post>[fakePost()],
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);

      await tester.fling(
        find.byType(CustomScrollView),
        const Offset(0, 300),
        1000,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 800));

      expect(repository.calls, 2);
      // A refresh is a first page: it must not carry the previous cursor.
      expect(repository.requestedAfter.last, isNull);
    });

    testWidgets('expands a post that is longer than six lines', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(
        tester,
        posts: <Post>[fakePost(text: _longText)],
        pageSize: 1,
      );

      expect(find.text('Read more'), findsOneWidget);
      expect(find.text('Show less'), findsNothing);
      expect(tester.widget<Text>(find.text(_longText)).maxLines, 6);

      await tester.ensureVisible(find.text('Read more'));
      await tester.tap(find.text('Read more'));
      await _settle(tester);

      expect(find.text('Show less'), findsOneWidget);
      expect(tester.widget<Text>(find.text(_longText)).maxLines, isNull);
    });

    testWidgets('offers no expander on a short post', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(tester, posts: <Post>[fakePost(text: 'Short.')]);

      expect(find.text('Read more'), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('draws four images and no more', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        posts: <Post>[
          fakePost(
            imageUrls: <String>[
              'https://example.test/1.jpg',
              'https://example.test/2.jpg',
              'https://example.test/3.jpg',
              'https://example.test/4.jpg',
            ],
          ),
        ],
      );

      // The test renderer answers every network image with 400, and the tile's
      // errorBuilder is what keeps that from becoming a failed test: a post
      // whose pictures have gone is still a readable post.
      expect(find.byType(Image), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    });

    testWidgets('caps how tall a picture may draw on a wide window', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(
        tester,
        posts: <Post>[
          fakePost(
            id: 'one',
            imageUrls: <String>['https://example.test/1.jpg'],
          ),
          fakePost(
            id: 'four',
            imageUrls: <String>[
              'https://example.test/1.jpg',
              'https://example.test/2.jpg',
              'https://example.test/3.jpg',
              'https://example.test/4.jpg',
            ],
          ),
        ],
        size: const Size(1000, 2000),
      );

      // The wide measure makes a 16:10 picture over 500 dp tall and a square
      // cell over 400; either would let one photograph fill the screen.
      expect(find.byType(Image), findsNWidgets(5));
      for (final Element image in find.byType(Image).evaluate()) {
        expect(
          tester.getSize(find.byWidget(image.widget)).height,
          lessThan(310),
        );
      }
    });

    testWidgets('copies a post and says so', (WidgetTester tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pumpFeed(
        tester,
        posts: <Post>[fakePost(text: 'Donated at Dhaka Medical today.')],
      );

      await tester.tap(find.byTooltip('Copy text'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(copied, 'Donated at Dhaka Medical today.');
      expect(find.text('Post text copied.'), findsOneWidget);
    });

    testWidgets('speaks Bangla end to end', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        posts: <Post>[fakePost()],
        locale: const Locale('bn'),
      );

      expect(find.text('কমিউনিটি'), findsOneWidget);
      expect(find.text('০ লাইক'), findsOneWidget);
      expect(find.text('০ মন্তব্য'), findsOneWidget);
    });

    testWidgets('is readable in the dark theme and at the narrowest width', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(
        tester,
        posts: <Post>[fakePost()],
        locale: const Locale('bn'),
        themeMode: ThemeMode.dark,
        size: const Size(320, 640),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(FeedPostTile), findsOneWidget);
    });

    testWidgets('widens the column on a tablet', (WidgetTester tester) async {
      await _pumpFeed(
        tester,
        posts: <Post>[fakePost()],
        size: const Size(1200, 900),
      );

      final double width = tester.getSize(find.byType(FeedPostTile)).width;
      // Centred at the wide measure (900) inside the 1200 dp window.
      expect(width, closeTo(FeedScreen.wideMaxWidth, 1));
    });

    testWidgets('keeps the narrow measure on a phone', (
      WidgetTester tester,
    ) async {
      await _pumpFeed(tester, posts: <Post>[fakePost()]);

      final double width = tester.getSize(find.byType(FeedPostTile)).width;
      expect(width, closeTo(_phone.width - 2 * 24, 1));
      expect(width, lessThan(FeedScreen.narrowMaxWidth));
    });
  });
}
