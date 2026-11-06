import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/models/comment_document.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';

/// Reads and writes comments on a post.
///
/// The interface exists so the controller and widget tests never need a live
/// Firestore instance; the provider seam is overridden the same way
/// `feedRepositoryProvider` is.
abstract interface class CommentService {
  /// Loads up to [maxComments] comments for the given post, oldest first.
  Future<Result<List<Comment>>> loadComments(String postId);

  /// Creates a comment document. Returns the constructed [Comment] entity (the
  /// [createdAt] is the local clock; the server resolves `FieldValue
  /// .serverTimestamp()` independently).
  ///
  /// The parent post's `commentCount` is NOT written here — it is derived from
  /// the `comments` subcollection by the feed's count hydration, exactly as
  /// likes are (see [PostLikeService]). `firestore.rules` keeps the counters
  /// immutable to every client.
  Future<Result<Comment>> addComment({
    required String postId,
    required String authorUid,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
    String? parentId,
    String? replyToName,
  });

  /// Deletes a comment. The parent's `commentCount` is derived, not written
  /// here.
  Future<Result<void>> deleteComment({
    required String postId,
    required String commentId,
  });
}

/// Firestore-backed implementation.
///
/// Writes a single comment document per add and a single delete per removal;
/// the parent's `commentCount` is never touched here because the rules forbid a
/// client counter write and the count is derived from the subcollection. Reads
/// are simple queries ordered by `createdAt`.
final class FirestoreCommentService implements CommentService {
  const FirestoreCommentService(this._firestore);

  final FirebaseFirestore _firestore;

  /// A practical page ceiling for a single post's thread. Past this the sheet
  /// shows what it has; a post with 100+ comments is a moderation signal, not
  /// a normal thread.
  static const int maxComments = 50;

  @override
  Future<Result<List<Comment>>> loadComments(String postId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection(PostDocument.collection)
              .doc(postId)
              .collection(PostDocument.commentsSubcollection)
              .orderBy('createdAt', descending: false)
              .limit(maxComments)
              .get();

      final List<Comment> comments = <Comment>[];
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in
          snapshot.docs) {
        final Result<Comment> result =
            CommentDocument.fromMap(doc.id, doc.data());
        if (result case Success<Comment>(:final value)) {
          comments.add(value);
        }
        // Malformed comments are silently skipped; a thread with 49 readable
        // entries is more useful than an error page over a broken document.
      }
      return Success<List<Comment>>(comments);
    } on FirebaseException catch (e) {
      return FailureResult<List<Comment>>(_mapException(e));
    }
  }

  @override
  Future<Result<Comment>> addComment({
    required String postId,
    required String authorUid,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
    String? parentId,
    String? replyToName,
  }) async {
    // Client-side validation before the write.
    final CommentIssue? issue = CommentValidator.validate(
      text: text,
      parentId: parentId,
      replyToName: replyToName,
    );
    if (issue != null) {
      return FailureResult<Comment>(
        ValidationFailure(messageKey: issue.name),
      );
    }

    final CollectionReference<Map<String, dynamic>> commentsRef = _firestore
        .collection(PostDocument.collection)
        .doc(postId)
        .collection(PostDocument.commentsSubcollection);
    final DocumentReference<Map<String, dynamic>> commentDoc = commentsRef.doc();

    final Map<String, Object?> fields = CommentDocument.toMap(
      postId: postId,
      authorUid: authorUid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl,
      text: text,
      parentId: parentId,
      replyToName: replyToName,
    );

    try {
      await commentDoc.set(fields);
    } on FirebaseException catch (e) {
      return FailureResult<Comment>(_mapException(e));
    }

    // Build the local entity. The server timestamp is approximate — it will
    // differ from this by network latency. The next load returns the exact one.
    final DateTime now = DateTime.now().toUtc();
    final Comment comment = Comment(
      id: commentDoc.id,
      authorUid: authorUid,
      authorName: authorName,
      authorPhotoUrl: authorPhotoUrl?.trim(),
      text: text.trim(),
      parentId: parentId?.trim(),
      replyToName: replyToName?.trim(),
      createdAt: now,
    );
    return Success<Comment>(comment);
  }

  @override
  Future<Result<void>> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    final DocumentReference<Map<String, dynamic>> postRef =
        _firestore.collection(PostDocument.collection).doc(postId);
    final DocumentReference<Map<String, dynamic>> commentRef =
        postRef.collection(PostDocument.commentsSubcollection).doc(commentId);

    try {
      await commentRef.delete();
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
