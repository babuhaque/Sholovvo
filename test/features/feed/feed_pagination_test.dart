import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/data/feed_documents.dart';
import 'package:sholovvo_app/features/feed/data/firestore_feed_repository.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';

import '../../support/fake_feed.dart';
import '../../support/test_app.dart';

/// What this file is about.
///
/// [FirestoreFeedRepository] refuses a document it cannot map instead of
/// guessing at it, and it decides `hasMore` from the *raw* document count. Put
/// those two truths together and a page can carry no post at all while the
/// collection still has plenty to give. Left alone that is a dead end: the state
/// reads as "no posts yet", the screen draws that card and returns before its
/// footer, and the one control that could page past the bad writes never appears.
///
/// So the rules asserted here are, in order: the cursor is a position among raw
/// documents and moves even when nothing survives the mapper; an empty page is
/// walked past rather than believed; the walk is bounded, so a collection that
/// stays unreadable cannot spin; and the screen keeps offering "Load more" for
/// whatever the bound stopped on.
const Size _phone = Size(430, 932);

/// `count` documents the mapper refuses, ids running from [from].
///
/// No author is what `PostDocument.fromMap` rejects, which is the shape a client
/// writing the wrong field names leaves behind in the collection.
List<FeedDocument> _unreadable(int count, {int from = 1}) {
  return <FeedDocument>[
    for (int index = from; index < from + count; index++)
      feedDocument(
        'p$index',
        fields: <String, Object?>{'text': 'Unreadable $index'},
      ),
  ];
}

/// `count` documents that map cleanly, ids running from [from].
List<FeedDocument> _readable(int count, {int from = 1}) {
  return <FeedDocument>[
    for (int index = from; index < from + count; index++)
      feedDocument('p$index', fields: postFields(text: 'Post $index')),
  ];
}

/// The production repository over the fake database.
///
/// Every page here is assembled by the real rules; only the query is faked. That
/// is deliberate — the interaction being tested is between the mapper's refusals
/// and the page arithmetic, and a stub repository could get it wrong in the same
/// way as the code it stands in for.
({FakeFeedDocuments documents, FirestoreFeedRepository repository}) _real(
  List<FeedDocument> documents,
) {
  final FakeFeedDocuments fake = FakeFeedDocuments(documents);
  return (repository: FirestoreFeedRepository(fake), documents: fake);
}

/// Mounts the controller over [repository].
ProviderContainer _container(FeedRepository repository) {
  final ProviderContainer container = ProviderContainer(
    overrides: [feedRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

/// Answers from a script rather than from a collection.
///
/// The last entry repeats forever, which is the useful part: a run of unreadable
/// documents that never ends looks, to the caller, exactly like a repository that
/// keeps answering with the same empty page. A [Failure] in any earlier slot is
/// how a test interrupts a walk mid-flight.
final class _ScriptedPages implements FeedRepository {
  _ScriptedPages(this.script);

  final List<Object> script;

  /// Holds every call open until completed.
  Completer<void>? gate;

  /// The cursor each call was given, in order.
  ///
  /// Deliberately separate from the script position, so a test can shorten the
  /// list it is about to assert without rewinding the answers.
  final List<FeedCursor?> requestedAfter = <FeedCursor?>[];

  int _next = 0;

  int get calls => _next;

  @override
  Future<Result<FeedPage>> loadPage({FeedCursor? after}) async {
    requestedAfter.add(after);

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    final int index = _next < script.length ? _next : script.length - 1;
    _next++;
    final Object answer = script[index];
    return answer is Failure
        ? FailureResult<FeedPage>(answer)
        : Success<FeedPage>(answer as FeedPage);
  }
}

/// A page with no post in it while the collection still has more.
FeedPage _emptyPage(FeedCursor cursor) {
  return FeedPage(posts: const <Post>[], cursor: cursor, hasMore: true);
}

/// Mounts the real feed screen over the real repository.
Future<FakeFeedDocuments> _pumpFeedOver(
  WidgetTester tester,
  List<FeedDocument> documents,
) async {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final ({FakeFeedDocuments documents, FirestoreFeedRepository repository})
  harness = _real(documents);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [feedRepositoryProvider.overrideWithValue(harness.repository)],
      child: testApp(home: const FeedScreen()),
    ),
  );
  // A walk is a chain of awaits, and the glow behind the page never settles, so
  // this gives the queue more frames than `pumpAndSettle` would be willing to.
  for (int frame = 0; frame < 8; frame++) {
    await tester.pump();
  }
  return harness.documents;
}

void main() {
  group('A page of unreadable documents', () {
    test('is an empty page without being an empty collection', () async {
      final harness = _real(_unreadable(11));

      final FeedPage page = (await harness.repository.loadPage()).valueOrNull!;

      // Eleven documents were read, ten of them belong to this page, none of
      // them survived the mapper — and the eleventh says there is more.
      expect(page.posts, isEmpty);
      expect(page.skipped, FeedRepository.pageSize);
      expect(page.hasMore, isTrue);
    });

    test('still moves the cursor a whole page of raw documents', () async {
      final harness = _real(_unreadable(11));

      final FeedPage page = (await harness.repository.loadPage()).valueOrNull!;

      // The cursor is a position among documents, not among posts: nothing was
      // readable, and the position still advanced by a page.
      expect((page.cursor! as FeedTestCursor).id, 'p10');
    });

    test('resumes after the run without skipping or repeating a document', () async {
      final harness = _real(<FeedDocument>[
        ..._unreadable(10),
        ..._readable(3, from: 11),
      ]);

      final FeedPage first = (await harness.repository.loadPage()).valueOrNull!;
      expect(first.posts, isEmpty);

      final FeedPage second = (await harness.repository.loadPage(
        after: first.cursor,
      )).valueOrNull!;

      expect(second.posts.map((Post post) => post.id), <String>[
        'p11',
        'p12',
        'p13',
      ]);
      // Page one covered documents 1–10, page two starts at 11: the refused run
      // cost the reader no post.
      expect(harness.documents.lastAfter, const FeedTestCursor('p10'));
    });

    test('keeps the readable posts in document order when bad writes sit '
        'between them', () async {
      final harness = _real(<FeedDocument>[
        ..._readable(1),
        ..._unreadable(1, from: 2),
        ..._readable(1, from: 3),
        ..._unreadable(1, from: 4),
        ..._readable(1, from: 5),
      ]);

      final FeedPage page = (await harness.repository.loadPage()).valueOrNull!;

      expect(page.posts.map((Post post) => post.id), <String>[
        'p1',
        'p3',
        'p5',
      ]);
      expect(page.skipped, 2);
      expect(page.hasMore, isFalse);
    });

    test('ends the collection when the raw window runs out, not before', () async {
      final harness = _real(_unreadable(12));

      final FeedPage first = (await harness.repository.loadPage()).valueOrNull!;
      expect(first.hasMore, isTrue);

      final FeedPage second = (await harness.repository.loadPage(
        after: first.cursor,
      )).valueOrNull!;
      // Two documents left, both refused. This is the real bottom: fewer than a
      // page were read, so `hasMore` is false on its own evidence.
      expect(second.posts, isEmpty);
      expect(second.hasMore, isFalse);
      expect(second.skipped, 2);

      final FeedPage third = (await harness.repository.loadPage(
        after: second.cursor,
      )).valueOrNull!;
      expect(third.posts, isEmpty);
      expect(third.hasMore, isFalse);
      // Asking past the end keeps the position it was given rather than erasing
      // it, so a retry can be re-asked.
      expect(third.cursor, same(second.cursor));
    });
  });

  group('The controller walks past unreadable pages', () {
    test('reaches the readable posts in one first-page read', () async {
      final harness = _real(<FeedDocument>[
        ..._unreadable(25),
        ..._readable(3, from: 26),
      ]);
      final ProviderContainer container = _container(harness.repository);

      await container.read(feedControllerProvider.notifier).loadFirstPage();

      final FeedState state = container.read(feedControllerProvider);
      expect(state.posts.map((Post post) => post.id), <String>[
        'p26',
        'p27',
        'p28',
      ]);
      // Three reads: two empty windows walked over, one readable window kept.
      expect(harness.documents.calls, 3);
      expect(state.hasMore, isFalse);
      expect(state.isEmptyResult, isFalse);
    });

    test('walks every empty page without ever re-asking a position', () async {
      final harness = _real(<FeedDocument>[
        ..._unreadable(25),
        ..._readable(3, from: 26),
      ]);
      final ProviderContainer container = _container(harness.repository);

      await container.read(feedControllerProvider.notifier).loadFirstPage();

      // Each window's last raw document, in the order the walk asked for them.
      // Strictly advancing and never repeated, which is what makes walking safe
      // rather than a shuffle that loses posts.
      expect(harness.documents.requestedAfter, <FeedCursor?>[
        null,
        const FeedTestCursor('p10'),
        const FeedTestCursor('p20'),
      ]);
      expect(
        harness.documents.requestedAfter.toSet(),
        hasLength(harness.documents.requestedAfter.length),
      );
      expect(
        container.read(feedControllerProvider).cursor,
        const FeedTestCursor('p28'),
        reason: 'the walk finished where the readable window ended',
      );
    });

    test(
      'stops at the empty-page bound and hands the decision to the donor',
      () async {
        // A run of bad writes long enough to exhaust the bound: 51 unreadable
        // documents, so the walk stops after [FeedController.maxEmptyPages]
        // windows rather than scanning the collection to its end.
        final harness = _real(<FeedDocument>[
          ..._unreadable(51),
          ..._readable(1, from: 52),
        ]);
        final ProviderContainer container = _container(harness.repository);
        final FeedController controller = container.read(
          feedControllerProvider.notifier,
        );

        await controller.loadFirstPage();

        final FeedState capped = container.read(feedControllerProvider);
        expect(harness.documents.calls, FeedController.maxEmptyPages);
        expect(capped.posts, isEmpty);
        expect(
          capped.hasMore,
          isTrue,
          reason: 'the bound stops the walk, not the feed',
        );
        expect(
          capped.isEmptyResult,
          isFalse,
          reason: 'no false "no posts yet"',
        );
        expect(
          controller.isFetching,
          isFalse,
          reason: 'the walk did terminate',
        );

        // The donor's own tap continues it, and finds the post behind the run.
        await controller.loadMore();

        final FeedState resumed = container.read(feedControllerProvider);
        expect(resumed.posts.map((Post post) => post.id), <String>['p52']);
        expect(resumed.hasMore, isFalse);
        expect(harness.documents.calls, FeedController.maxEmptyPages + 1);
      },
    );

    test('does not spin when a repository answers every page with the same '
        'unreadable window', () async {
      // The pathological case the bound exists for: a page with no post, no
      // position to move on by, and a promise that there is more — forever.
      final _ScriptedPages script = _ScriptedPages(<Object>[
        FeedPage(posts: const <Post>[], hasMore: true),
      ]);
      final ProviderContainer container = _container(script);

      await container.read(feedControllerProvider.notifier).loadFirstPage();

      final FeedState state = container.read(feedControllerProvider);
      expect(script.calls, FeedController.maxEmptyPages);
      expect(state.status, FeedStatus.ready);
      expect(state.posts, isEmpty);
      expect(state.hasMore, isTrue);
      expect(state.loaded, isTrue);
      // With no position to advance by it re-asked the same question, bounded
      // rather than endless.
      expect(
        script.requestedAfter,
        List<FeedCursor?>.filled(FeedController.maxEmptyPages, null),
      );
    });

    test('keeps the posts already on screen when a load-more walk hits the '
        'bound', () async {
      final _ScriptedPages script = _ScriptedPages(<Object>[
        FeedPage(
          posts: <Post>[fakePost(id: 'a', text: 'First')],
          cursor: const FeedTestCursor('c1'),
          hasMore: true,
        ),
        _emptyPage(const FeedTestCursor('c2')),
      ]);
      final ProviderContainer container = _container(script);
      final FeedController controller = container.read(
        feedControllerProvider.notifier,
      );

      await controller.loadFirstPage();
      await controller.loadMore();

      // Refusing to show new posts is what the bad writes earned; blanking the
      // good ones already on screen would be a second, unearned penalty.
      expect(container.read(feedControllerProvider).posts, hasLength(1));
      expect(container.read(feedControllerProvider).hasMore, isTrue);
      expect(script.calls, 1 + FeedController.maxEmptyPages);
    });

    test('does not append a post the walk already showed', () async {
      final Post a = fakePost(id: 'a', text: 'First');
      final Post b = fakePost(id: 'b', text: 'Second');
      final Post c = fakePost(id: 'c', text: 'Third');
      final _ScriptedPages script = _ScriptedPages(<Object>[
        FeedPage(
          posts: <Post>[a, b],
          cursor: const FeedTestCursor('c2'),
          hasMore: true,
        ),
        // A window of bad writes, then a window that re-surfaces `b` — what a
        // document rewritten with a new timestamp legitimately does.
        _emptyPage(const FeedTestCursor('c3')),
        FeedPage(
          posts: <Post>[b, c],
          cursor: const FeedTestCursor('c4'),
          hasMore: false,
        ),
      ]);
      final ProviderContainer container = _container(script);
      final FeedController controller = container.read(
        feedControllerProvider.notifier,
      );

      await controller.loadFirstPage();
      await controller.loadMore();

      expect(
        container
            .read(feedControllerProvider)
            .posts
            .map((Post post) => post.id),
        <String>['a', 'b', 'c'],
      );
    });

    test(
      'a failure in the middle of a walk is re-asked from the same place',
      () async {
        final _ScriptedPages script = _ScriptedPages(<Object>[
          _emptyPage(const FeedTestCursor('c1')),
          const NetworkFailure(debugMessage: 'offline'),
          _emptyPage(const FeedTestCursor('c1')),
          FeedPage(
            posts: <Post>[fakePost(id: 'a', text: 'First')],
            cursor: const FeedTestCursor('c2'),
            hasMore: false,
          ),
        ]);
        final ProviderContainer container = _container(script);
        final FeedController controller = container.read(
          feedControllerProvider.notifier,
        );

        await controller.loadFirstPage();

        expect(
          container.read(feedControllerProvider).isFatalError,
          isTrue,
          reason: 'a refused read with nothing on screen has to say so',
        );
        expect(script.requestedAfter, <FeedCursor?>[
          null,
          const FeedTestCursor('c1'),
        ]);

        // The walk's own progress is deliberately not remembered, so the retry
        // re-asks the same two positions in the same order rather than jumping
        // past the page the failure interrupted.
        await controller.loadFirstPage();

        expect(script.requestedAfter, <FeedCursor?>[
          null,
          const FeedTestCursor('c1'),
          null,
          const FeedTestCursor('c1'),
        ]);
        expect(
          container
              .read(feedControllerProvider)
              .posts
              .map((Post post) => post.id),
          <String>['a'],
        );
        expect(container.read(feedControllerProvider).failure, isNull);
      },
    );

    test('a failed load-more keeps the cursor, so the retry re-walks from the '
        'page still on screen', () async {
      final _ScriptedPages script = _ScriptedPages(<Object>[
        FeedPage(
          posts: <Post>[fakePost(id: 'a', text: 'First')],
          cursor: const FeedTestCursor('c1'),
          hasMore: true,
        ),
        _emptyPage(const FeedTestCursor('c2')),
        const NetworkFailure(debugMessage: 'offline'),
        _emptyPage(const FeedTestCursor('c3')),
        FeedPage(
          posts: <Post>[fakePost(id: 'b', text: 'Second')],
          cursor: const FeedTestCursor('c4'),
          hasMore: false,
        ),
      ]);
      final ProviderContainer container = _container(script);
      final FeedController controller = container.read(
        feedControllerProvider.notifier,
      );

      await controller.loadFirstPage();
      await controller.loadMore();

      final FeedState failed = container.read(feedControllerProvider);
      expect(failed.posts, hasLength(1), reason: 'the page survives');
      expect(failed.failure, isA<NetworkFailure>());
      // The cursor is still the first page's: the empty window the walk crossed
      // is not consumed by a read that never finished.
      expect(failed.cursor, const FeedTestCursor('c1'));

      script.requestedAfter.clear();
      await controller.loadMore();

      // Re-asked from the position the screen actually shows, then walked on.
      expect(script.requestedAfter, <FeedCursor?>[
        const FeedTestCursor('c1'),
        const FeedTestCursor('c3'),
      ]);
      final FeedState resumed = container.read(feedControllerProvider);
      expect(resumed.failure, isNull);
      expect(resumed.posts.map((Post post) => post.id), <String>[
        'a',
        'b',
      ], reason: 'the retry added the post without losing the first one');
    });

    test('walks one page at a time when load-more is tapped twice', () async {
      final _ScriptedPages script = _ScriptedPages(<Object>[
        FeedPage(
          posts: <Post>[fakePost(id: 'a', text: 'First')],
          cursor: const FeedTestCursor('c1'),
          hasMore: true,
        ),
        _emptyPage(const FeedTestCursor('c2')),
      ]);
      final ProviderContainer container = _container(script);
      final FeedController controller = container.read(
        feedControllerProvider.notifier,
      );
      await controller.loadFirstPage();

      script.gate = Completer<void>();
      final Future<void> first = controller.loadMore();
      final Future<void> second = controller.loadMore();

      // One walk, not two: the second tap arrived while the walk's first window
      // was still in flight and was turned away by the same flag as before.
      expect(script.requestedAfter, hasLength(2));
      expect(controller.isFetching, isTrue);

      script.gate!.complete();
      await Future.wait(<Future<void>>[first, second]);

      expect(script.calls, 1 + FeedController.maxEmptyPages);
      expect(container.read(feedControllerProvider).posts, hasLength(1));
      expect(controller.isFetching, isFalse);
    });
  });

  group('The feed screen with unreadable documents', () {
    testWidgets('offers "Load more" instead of an empty feed', (
      WidgetTester tester,
    ) async {
      final FakeFeedDocuments documents = await _pumpFeedOver(
        tester,
        <FeedDocument>[..._unreadable(51), ..._readable(1, from: 52)],
      );

      // The symptom this whole group exists to remove: an empty mapped page used
      // to draw "No posts yet" and return before the footer, so nothing on screen
      // could reach the posts sitting behind the bad writes.
      expect(find.text('No posts yet'), findsNothing);
      expect(find.byType(EmptyStateCard), findsNothing);
      expect(find.widgetWithText(SolovvoButton, 'Load more'), findsOneWidget);
      expect(documents.calls, FeedController.maxEmptyPages);
    });

    testWidgets('shows the post behind the run when the donor asks for more', (
      WidgetTester tester,
    ) async {
      await _pumpFeedOver(tester, <FeedDocument>[
        ..._unreadable(51),
        ..._readable(1, from: 52),
      ]);

      final Finder loadMore = find.widgetWithText(SolovvoButton, 'Load more');
      await tester.ensureVisible(loadMore);
      await tester.pump();
      await tester.tap(loadMore);
      await tester.pump();
      for (int frame = 0; frame < 4; frame++) {
        await tester.pump();
      }

      expect(find.byType(FeedPostTile), findsOneWidget);
      expect(find.text('Post 52'), findsOneWidget);
      expect(find.widgetWithText(SolovvoButton, 'Load more'), findsNothing);
    });

    testWidgets('an honest empty feed still says so', (
      WidgetTester tester,
    ) async {
      await _pumpFeedOver(tester, <FeedDocument>[]);

      expect(find.text('No posts yet'), findsOneWidget);
      expect(find.byType(EmptyStateCard), findsOneWidget);
      expect(find.widgetWithText(SolovvoButton, 'Load more'), findsNothing);
    });
  });
}
