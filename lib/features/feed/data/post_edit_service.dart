import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

/// Manages the text and lifecycle of an existing post (author-only).
abstract interface class PostEditService {
  /// Updates only the [newText] field, stamping `editedAt` and `updatedAt` with
  /// the server clock. Fails with [AuthFailure] if the caller is not the author
  /// (verified client-side before touching the network).
  Future<Result<void>> editText({
    required String postId,
    required String uid,
    required String newText,
  });

  /// Permanently deletes the post identified by [postId].
  ///
  /// Verifies authorship client-side (same read-then-act pattern as [editText])
  /// so a non-author gets a clean [PermissionFailure] rather than the generic
  /// `permission-denied` the rules return. The rules enforce this too.
  Future<Result<void>> deletePost({
    required String postId,
    required String uid,
  });
}

/// Firestore-backed implementation.
///
/// The rules (L449-460) enforce author-only updates with an immutable-key
/// whitelist (`text`, `imageUrls`, `imagePaths`, `editedAt`, `updatedAt`). This
/// service writes the text and the two timestamp fields; the rules re-validate
/// the resulting document via `isPostBody()`.
final class FirestorePostEditService implements PostEditService {
  const FirestorePostEditService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('feed.edit');

  static const String _collection = 'posts';

  @override
  Future<Result<void>> editText({
    required String postId,
    required String uid,
    required String newText,
  }) async {
    // Client-side validation mirrors the rules' `isPostBody()` bounds.
    if (uid.isEmpty || postId.isEmpty) {
      return const FailureResult<void>(
        AuthFailure(debugMessage: 'Missing uid or postId'),
      );
    }

    final String trimmed = newText.trim();
    if (trimmed.isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(
          messageKey: 'textRequired',
          debugMessage: 'Edit rejected: empty text',
        ),
      );
    }
    if (trimmed.length > PostValidator.maxTextLength) {
      return const FailureResult<void>(
        ValidationFailure(
          messageKey: 'textTooLong',
          debugMessage: 'Edit rejected: exceeds ${PostValidator.maxTextLength}',
        ),
      );
    }

    // Verify authorship before writing (cheap read; the rules enforce this
    // server-side too, but a client check gives a better error message).
    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection(_collection)
          .doc(postId)
          .get();
    } on FirebaseException catch (e) {
      _logger.warning('Post edit read failed', error: e);
      return FailureResult<void>(_mapException(e));
    }

    if (!snap.exists) {
      return const FailureResult<void>(
        NotFoundFailure(debugMessage: 'Post not found for edit'),
      );
    }
    if (snap['authorUid'] != uid) {
      return const FailureResult<void>(
        PermissionFailure(
          debugMessage: 'Post edit rejected: caller is not author',
        ),
      );
    }

    // Write the three fields the rules allow on a text-only edit.
    try {
      await _firestore.collection(_collection).doc(postId).update(
        <String, Object?>{
          'text': trimmed,
          'editedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      );
    } on FirebaseException catch (e) {
      _logger.warning('Post edit write failed', error: e);
      return FailureResult<void>(_mapException(e));
    }

    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deletePost({
    required String postId,
    required String uid,
  }) async {
    if (uid.isEmpty || postId.isEmpty) {
      return const FailureResult<void>(
        AuthFailure(debugMessage: 'Missing uid or postId for delete'),
      );
    }

    // Verify authorship before deleting.
    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore.collection(_collection).doc(postId).get();
    } on FirebaseException catch (e) {
      _logger.warning('Post delete read failed', error: e);
      return FailureResult<void>(_mapException(e));
    }

    if (!snap.exists) {
      return const FailureResult<void>(
        NotFoundFailure(debugMessage: 'Post already deleted'),
      );
    }
    if (snap['authorUid'] != uid) {
      return const FailureResult<void>(
        PermissionFailure(
          debugMessage: 'Post delete rejected: caller is not author',
        ),
      );
    }

    try {
      await _firestore.collection(_collection).doc(postId).delete();
    } on FirebaseException catch (e) {
      _logger.warning('Post delete write failed', error: e);
      return FailureResult<void>(_mapException(e));
    }

    return const Success<void>(null);
  }

  Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: 'Post edit denied by rules',
        cause: e,
      ),
      'not-found' => NotFoundFailure(
        debugMessage: 'Post document gone',
        cause: e,
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: 'Post edit network error',
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: 'Post edit: unexpected [${e.code}] ${e.message}',
        cause: e,
      ),
    };
  }
}
