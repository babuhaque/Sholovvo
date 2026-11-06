import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';

/// Writes and removes one donor's like on a post.
///
/// The like lives in the **flat `post_likes` collection**, the shape the live
/// database actually uses: `post_likes/{postId}_{uid}` carrying
/// `{postId, userId, createdAt}`. The document id embeds the post and the
/// liker, so a duplicate like is an id collision (an update, which the rules
/// refuse) rather than a second row that would inflate the count.
///
/// **This path writes the like document and nothing else.** The cached
/// `likeCount` on the parent post is NOT incremented here. `firestore.rules`
/// keeps the post's counters immutable to every client (an any-signed-in-user
/// +/-1 branch was a counter-forging hole). The authoritative count is
/// therefore derived: the feed's count hydration counts `post_likes` rows with
/// an aggregate `count()` query, so what the donor sees always comes from the
/// rows that actually exist, never from a number a client could drive.
///
/// Both methods return a [Result]: a [Success] means the server accepted the
/// write; a [Failure] carries the error for the controller to decide whether to
/// roll back the optimistic local state. A network failure, a permission
/// refusal, or a document that no longer exists all surface here; none crashes.
///
/// **No stream, no read.** The like path only writes. Whether the caller is
/// currently liked or unliked is hydrated by [LikeHydrationService] on feed
/// load and tracked in the controller's in-memory set for the session.
abstract interface class PostLikeService {
  /// Creates the like document. The parent's `likeCount` is derived, not
  /// written here.
  Future<Result<void>> like(String postId, String uid);

  /// Deletes the like document. The parent's `likeCount` is derived, not
  /// written here.
  Future<Result<void>> unlike(String postId, String uid);
}

/// The Firestore-backed implementation.
///
/// Takes the [FirebaseFirestore] instance rather than reaching for the static
/// singleton, so a widget or unit test can inject an in-memory or fake instance
/// without the real backend. The collection constant comes from
/// [PostDocument.likesCollection], keeping the path definition in one place.
final class FirestorePostLikeService implements PostLikeService {
  const FirestorePostLikeService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Result<void>> like(String postId, String uid) async {
    try {
      // Deterministic id: one like per (post, donor), enforced by collision.
      await _firestore
          .collection(PostDocument.likesCollection)
          .doc('${postId}_$uid')
          .set(<String, Object?>{
        'postId': postId,
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      return FailureResult<void>(_mapException(e));
    }
  }

  @override
  Future<Result<void>> unlike(String postId, String uid) async {
    try {
      // Query rather than delete-by-id so a legacy auto-id row (the
      // pre-migration build did not embed the id) is removed too. Deleting
      // every match is idempotent: zero rows is a success, not an error.
      final QuerySnapshot<Map<String, dynamic>> rows = await _firestore
          .collection(PostDocument.likesCollection)
          .where('postId', isEqualTo: postId)
          .where('userId', isEqualTo: uid)
          .get();
      if (rows.docs.isEmpty) {
        return const Success<void>(null);
      }
      final WriteBatch batch = _firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> row in rows.docs) {
        batch.delete(row.reference);
      }
      await batch.commit();
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      return FailureResult<void>(_mapException(e));
    }
  }

  static Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: e.message,
        cause: e,
      ),
      'not-found' => NotFoundFailure(debugMessage: e.message, cause: e),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: e.message,
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: '${e.code}: ${e.message}',
        cause: e,
      ),
    };
  }
}
