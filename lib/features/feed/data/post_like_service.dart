import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';

/// Writes and removes one donor's like on a post.
///
/// The like model uses the **donor's uid as the document id** within the post's
/// `likes` subcollection, so a duplicate like is an id collision (an update,
/// which the rules refuse) rather than a second row nobody can detect. The
/// cached `likeCount` on the parent post document is maintained atomically via
/// `FieldValue.increment` — a server-side operation that cannot go negative
/// below what Firestore tracks and that needs no read-before-write.
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
  /// Creates the like document and increments the parent's `likeCount`.
  Future<Result<void>> like(String postId, String uid);

  /// Deletes the like document and decrements the parent's `likeCount`.
  Future<Result<void>> unlike(String postId, String uid);
}

/// The Firestore-backed implementation.
///
/// Takes the [FirebaseFirestore] instance rather than reaching for the static
/// singleton, so a widget or unit test can inject an in-memory or fake instance
/// without the real backend. The collection constant comes from [PostDocument]
/// and the likes subcollection from [PostDocument.likesSubcollection], keeping
/// the path definition in one place.
final class FirestorePostLikeService implements PostLikeService {
  const FirestorePostLikeService(this._firestore);

  final FirebaseFirestore _firestore;

  @override
  Future<Result<void>> like(String postId, String uid) async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef =
          _firestore.collection(PostDocument.collection).doc(postId);
      final DocumentReference<Map<String, dynamic>> likeRef =
          postRef.collection(PostDocument.likesSubcollection).doc(uid);

      await _firestore.runTransaction<void>((tx) async {
        tx.set(likeRef, <String, Object?>{'likedAt': FieldValue.serverTimestamp()});
        tx.update(postRef, <String, Object?>{
          'likeCount': FieldValue.increment(1),
        });
      });
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      return FailureResult<void>(_mapException(e));
    }
  }

  @override
  Future<Result<void>> unlike(String postId, String uid) async {
    try {
      final DocumentReference<Map<String, dynamic>> postRef =
          _firestore.collection(PostDocument.collection).doc(postId);
      final DocumentReference<Map<String, dynamic>> likeRef =
          postRef.collection(PostDocument.likesSubcollection).doc(uid);

      await _firestore.runTransaction<void>((tx) async {
        tx.delete(likeRef);
        tx.update(postRef, <String, Object?>{
          'likeCount': FieldValue.increment(-1),
        });
      });
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
