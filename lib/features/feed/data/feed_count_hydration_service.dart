import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';

/// The server-authoritative counts for one post, as derived from its
/// subcollections.
///
/// A value object so the feed's count hydration can hand both numbers back for
/// a post in one map entry rather than making the caller juggle two parallel
/// results.
class PostCountSnapshot {
  const PostCountSnapshot({
    required this.likeCount,
    required this.commentCount,
  });

  final int likeCount;
  final int commentCount;
}

/// Reads how many likes and comments each post actually has.
///
/// This exists because the post document's `likeCount`/`commentCount` fields
/// are no longer written by any client: `firestore.rules` keeps them immutable
/// to close a counter-forging hole, and no rules mechanism in this environment
/// can pair a counter move with the like/comment write. The rows in
/// `post_likes` and `posts/{id}/comments` are the truth, so the count is
/// derived from them with an aggregate `count()` query — which does not read or
/// return the documents, only their number.
///
/// Like [LikeHydrationService] this is a read-only seam the feed controller
/// calls after a first page resolves, and the same reason applies: it must never
/// throw. A post that renders with a stale zero is a cosmetic gap that
/// self-heals on the next read; a thrown exception takes the feed down.
abstract interface class FeedCountHydrationService {
  /// The derived counts for each of [postIds].
  ///
  /// Posts whose count could not be read are omitted from the map rather than
  /// reported as zero, so the caller keeps whatever it already had instead of
  /// blanking a real number on a transient read failure.
  Future<Map<String, PostCountSnapshot>> fetchCounts(List<String> postIds);
}

/// Firestore-backed implementation using aggregate `count()` queries.
///
/// Takes the [FirebaseFirestore] instance rather than the static singleton, so
/// a test can inject a fake and never reach the real backend. All posts are
/// counted concurrently with [Future.wait]; one post's failure is logged and
/// skipped, not propagated.
final class FirestoreFeedCountHydrationService
    implements FeedCountHydrationService {
  const FirestoreFeedCountHydrationService(this._firestore);

  final FirebaseFirestore _firestore;

  static final AppLogger _logger = AppLogger('feed.count');

  @override
  Future<Map<String, PostCountSnapshot>> fetchCounts(
    List<String> postIds,
  ) async {
    if (postIds.isEmpty) {
      return const <String, PostCountSnapshot>{};
    }

    final Map<String, PostCountSnapshot> counts =
        <String, PostCountSnapshot>{};

    await Future.wait<void>(postIds.map((String postId) async {
      try {
        final AggregateQuerySnapshot likes = await _firestore
            .collection(PostDocument.likesCollection)
            .where('postId', isEqualTo: postId)
            .count()
            .get();
        final AggregateQuerySnapshot comments = await _firestore
            .collection(PostDocument.collection)
            .doc(postId)
            .collection(PostDocument.commentsSubcollection)
            .count()
            .get();
        counts[postId] = PostCountSnapshot(
          likeCount: likes.count ?? 0,
          commentCount: comments.count ?? 0,
        );
      } on FirebaseException catch (e) {
        _logger.warning('Count hydration failed for post $postId: ${e.code}');
      }
    }));

    return counts;
  }
}
