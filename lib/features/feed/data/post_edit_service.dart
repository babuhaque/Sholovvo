import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

/// Manages the text, photographs and lifecycle of an existing post (author-only).
abstract interface class PostEditService {
  /// Rewrites the [newText] and the post's images, stamping `editedAt` and
  /// `updatedAt` with the server clock. Fails with [AuthFailure] if the caller
  /// is not the author (verified client-side before touching the network).
  ///
  /// [imageUrls] and [imagePaths] are the full lists the post should carry after
  /// the edit — the ones left in the edit sheet, in order — not only the changes.
  /// They are always written so the stored document satisfies the rules'
  /// `isPostBody()` even when it predates the `imageUrls`/`imagePaths` schema:
  /// a legacy post edited for the first time gains the two empty (or supplied)
  /// lists, which is exactly what the earlier text-only write left out and what
  /// made those edits fail with a permission-denied the donor could not read.
  Future<Result<void>> editPost({
    required String postId,
    required String uid,
    required String newText,
    required List<String> imageUrls,
    required List<String> imagePaths,
  });

  /// Permanently deletes the post identified by [postId].
  ///
  /// Verifies authorship client-side (same read-then-act pattern as [editPost])
  /// so a non-author gets a clean [PermissionFailure] rather than the generic
  /// `permission-denied` the rules return. The rules enforce this too.
  Future<Result<void>> deletePost({
    required String postId,
    required String uid,
  });
}

/// Firestore-backed implementation.
///
/// The rules (L451-462) enforce author-only updates with an immutable-key
/// whitelist (`text`, `imageUrls`, `imagePaths`, `editedAt`, `updatedAt`). This
/// service writes the text, the two image lists and the two timestamp fields; the
/// rules re-validate the resulting document via `isPostBody()`.
final class FirestorePostEditService implements PostEditService {
  const FirestorePostEditService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('feed.edit');

  static const String _collection = 'posts';

  @override
  Future<Result<void>> editPost({
    required String postId,
    required String uid,
    required String newText,
    required List<String> imageUrls,
    required List<String> imagePaths,
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
    // The same field rules a new post is held to, so an edit can never store a
    // body the publish path would have refused. Counts are immutable on an edit
    // and are not measured here, so the (non-negative) seeds keep the validator
    // focused on the text and the two image lists.
    final PostIssue? issue = PostValidator.validate(
      text: trimmed,
      imageCount: imageUrls.length,
      imagePathCount: imagePaths.length,
      likeCount: 0,
      commentCount: 0,
    );
    if (issue != null) {
      return FailureResult<void>(
        ValidationFailure(
          messageKey: issue.name,
          debugMessage: 'Edit rejected the body: ${issue.name}',
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

    // Write the five fields the rules allow on an edit. The two image lists are
    // written even when unchanged, so a document that predates them gains the
    // keys `isPostBody()` requires rather than being rejected on first edit.
    try {
      await _firestore.collection(_collection).doc(postId).update(
        <String, Object?>{
          'text': trimmed,
          'imageUrls': imageUrls,
          'imagePaths': imagePaths,
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
