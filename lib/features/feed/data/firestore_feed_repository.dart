import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/feed_documents.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';

/// Turns raw `posts` documents into a [FeedPage].
///
/// It holds no Firestore type: the query lives in [FeedDocuments], the field
/// spellings live in [PostDocument], and this class only decides what a page is.
/// That is deliberate — pagination rules are the part most likely to be wrong
/// and the part hardest to test against a live project.
class FirestoreFeedRepository implements FeedRepository {
  FirestoreFeedRepository(this._documents);

  final FeedDocuments _documents;

  static const AppLogger _logger = AppLogger('feed');

  @override
  Future<Result<FeedPage>> loadPage({
    FeedCursor? after,
    String? authorUid,
  }) async {
    // One extra document, so "is there another page?" is answered by the same
    // read that fills this one instead of by an empty request the user pays for
    // at the bottom of the list.
    final Result<List<FeedDocument>> fetched = await _documents.fetch(
      limit: FeedRepository.pageSize + 1,
      after: after,
      authorUid: authorUid,
    );

    final Failure? failure = fetched.failureOrNull;
    if (failure != null) {
      return FailureResult<FeedPage>(failure);
    }

    final List<FeedDocument> documents = fetched.valueOrNull!;
    final bool hasMore = documents.length > FeedRepository.pageSize;
    final List<FeedDocument> window = hasMore
        ? documents.sublist(0, FeedRepository.pageSize)
        : documents;

    final List<Post> posts = <Post>[];
    int skipped = 0;

    for (final FeedDocument document in window) {
      final Result<Post> mapped = PostDocument.fromMap(
        id: document.id,
        data: Map<String, dynamic>.from(document.fields),
      );
      final Post? post = mapped.valueOrNull;
      if (post == null) {
        // Refused, not repaired. One unreadable document must not cost the
        // donor the nine good posts around it, so it is dropped and counted;
        // the issue name is logged so a broken write is still diagnosable.
        skipped++;
        _logger.warning(
          'Skipped an unreadable post',
          error: mapped.failureOrNull,
        );
        continue;
      }
      posts.add(post);
    }

    return Success<FeedPage>(
      FeedPage(
        posts: posts,
        // The cursor addresses the last document kept, not the one lookahead:
        // starting after the lookahead would skip that post on the next page.
        cursor: window.isEmpty ? after : window.last.cursor,
        hasMore: hasMore,
        skipped: skipped,
      ),
    );
  }
}
