import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/feed_documents.dart';
import 'package:sholovvo_app/features/feed/data/firestore_feed_repository.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';

import '../../support/fake_feed.dart';

/// `count` valid documents, ids `p1` … `pn`, newest first.
List<FeedDocument> _documents(int count) {
  return <FeedDocument>[
    for (int index = 1; index <= count; index++)
      feedDocument('p$index', fields: postFields(text: 'Post $index')),
  ];
}

/// The repository under the fake database, plus the fake itself.
({FirestoreFeedRepository repository, FakeFeedDocuments documents}) _build(
  List<FeedDocument> documents,
) {
  final FakeFeedDocuments fake = FakeFeedDocuments(documents);
  return (repository: FirestoreFeedRepository(fake), documents: fake);
}

FeedPage _page(Result<FeedPage> result) {
  final FeedPage? page = result.valueOrNull;
  expect(
    page,
    isNotNull,
    reason: 'expected a page, got ${result.failureOrNull}',
  );
  return page!;
}

void main() {
  group('FirestoreFeedRepository', () {
    test('maps a document onto the Post entity', () async {
      final harness = _build(<FeedDocument>[
        feedDocument(
          'post-1',
          fields: postFields(
            authorName: 'Rafiq Hasan',
            text: 'Looking for O- for my sister.',
            imageUrls: <String>['https://example.test/a.jpg'],
            likeCount: 3,
            commentCount: 1,
            createdAt: DateTime.utc(2026, 10, 18, 6, 30),
          ),
        ),
      ]);

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts, hasLength(1));
      final Post post = page.posts.single;
      expect(post.id, 'post-1');
      expect(post.authorUid, 'uid-verified');
      expect(post.authorName, 'Rafiq Hasan');
      expect(post.text, 'Looking for O- for my sister.');
      expect(post.imageUrls, <String>['https://example.test/a.jpg']);
      expect(post.likeCount, 3);
      expect(post.commentCount, 1);
      // Normalised to UTC by the mapper, so equality across time zones holds.
      expect(post.createdAt, DateTime.utc(2026, 10, 18, 6, 30));
      expect(post.createdAt.isUtc, isTrue);
      expect(page.skipped, 0);
    });

    test('asks for one document more than a page', () async {
      final harness = _build(_documents(4));

      await harness.repository.loadPage();

      expect(harness.documents.lastLimit, FeedRepository.pageSize + 1);
    });

    test('reads the first page without a cursor', () async {
      final harness = _build(_documents(4));

      await harness.repository.loadPage();

      expect(harness.documents.lastAfter, isNull);
    });

    test('passes the previous cursor back to the database', () async {
      final harness = _build(_documents(30));
      const FeedTestCursor cursor = FeedTestCursor('p10');

      await harness.repository.loadPage(after: cursor);

      expect(harness.documents.lastAfter, same(cursor));
    });

    test('returns a full page and reports another one', () async {
      final harness = _build(_documents(11));

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts, hasLength(FeedRepository.pageSize));
      expect(page.hasMore, isTrue);
    });

    test('does not invent a second page when the first one ends exactly on the '
        'page size', () async {
      final harness = _build(_documents(10));

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts, hasLength(FeedRepository.pageSize));
      // The lookahead read one document past the page and found nothing, so
      // there is no phantom "load more" that resolves to an empty request.
      expect(page.hasMore, isFalse);
    });

    test(
      'points the cursor at the last post it kept, not at the lookahead',
      () async {
        final harness = _build(_documents(11));

        final FeedPage page = _page(await harness.repository.loadPage());

        // The eleventh document was read only to answer "is there more?".
        // Starting page two after it would skip that post forever.
        expect(page.cursor, isA<FeedTestCursor>());
        expect((page.cursor! as FeedTestCursor).id, 'p10');
      },
    );

    test('returns an empty page for an empty collection', () async {
      final harness = _build(<FeedDocument>[]);

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts, isEmpty);
      expect(page.isEmpty, isTrue);
      expect(page.hasMore, isFalse);
      expect(page.cursor, isNull);
      expect(page.skipped, 0);
    });

    test(
      'keeps the cursor of the page it was given when nothing follows',
      () async {
        final harness = _build(_documents(3));
        const FeedTestCursor last = FeedTestCursor('p3');

        final FeedPage page = _page(
          await harness.repository.loadPage(after: last),
        );

        expect(page.posts, isEmpty);
        // Keeping the cursor rather than nulling it means a retry and a "load
        // more" ask the same question.
        expect(page.cursor, same(last));
      },
    );

    test('drops a malformed document and counts it', () async {
      final harness = _build(<FeedDocument>[
        feedDocument('p1'),
        // No author: the mapper refuses it rather than inventing one.
        feedDocument('p2', fields: <String, Object?>{'text': 'Orphan'}),
        feedDocument('p3'),
      ]);

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts.map((Post post) => post.id), <String>['p1', 'p3']);
      expect(page.skipped, 1);
    });

    test('drops a document carrying more images than the limit allows', () async {
      final harness = _build(<FeedDocument>[
        feedDocument(
          'p1',
          fields: postFields(
            imageUrls: <String>[
              'https://example.test/1.jpg',
              'https://example.test/2.jpg',
              'https://example.test/3.jpg',
              'https://example.test/4.jpg',
              'https://example.test/5.jpg',
              'https://example.test/6.jpg',
            ],
          ),
        ),
        feedDocument('p2'),
      ]);

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts.single.id, 'p2');
      expect(page.skipped, 1);
    });

    test('counts every refused document, not just the first', () async {
      final harness = _build(<FeedDocument>[
        feedDocument('p1', fields: <String, Object?>{'authorName': 'No id'}),
        feedDocument('p2', fields: <String, Object?>{'text': 'No author'}),
        feedDocument('p3'),
      ]);

      final FeedPage page = _page(await harness.repository.loadPage());

      expect(page.posts.single.id, 'p3');
      expect(page.skipped, 2);
    });

    test('returns the failure the database reported', () async {
      final harness = _build(_documents(4));
      const NetworkFailure failure = NetworkFailure(debugMessage: 'offline');
      harness.documents.failure = failure;

      final Result<FeedPage> result = await harness.repository.loadPage();

      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, same(failure));
    });
  });
}
