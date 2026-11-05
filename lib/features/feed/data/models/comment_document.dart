import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';

/// The wire shape of one comment document at
/// `posts/{postId}/comments/{commentId}`.
///
/// Mirrors `PostDocument`: pure functions over plain maps, testable without an
/// emulator. The rules require `hasAll(['authorUid', 'authorName', 'text',
/// 'createdAt'])` and allow optional `authorPhotoUrl`, `parentId`, `replyToName`.
abstract final class CommentDocument {
  /// Required keys, as the rules spell them.
  static const List<String> requiredFields = [
    'authorUid',
    'authorName',
    'text',
    'createdAt',
  ];

  /// All keys the rules allow.
  static const Set<String> allowedKeys = {
    'authorUid',
    'authorName',
    'authorPhotoUrl',
    'text',
    'parentId',
    'replyToName',
    'createdAt',
  };

  /// Builds the map for a Firestore `set` or transaction write.
  ///
  /// [createdAt] is written as `FieldValue.serverTimestamp()` so the rules'
  /// `createdAt == request.time` check passes without a clock-skew risk.
  static Map<String, Object?> toMap({
    required String authorUid,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
    String? parentId,
    String? replyToName,
  }) {
    final Map<String, Object?> fields = <String, Object?>{
      'authorUid': authorUid,
      'authorName': authorName,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    final String? photo = authorPhotoUrl?.trim();
    if (photo != null && photo.isNotEmpty) {
      fields['authorPhotoUrl'] = photo;
    }
    final String? parent = parentId?.trim();
    if (parent != null && parent.isNotEmpty) {
      fields['parentId'] = parent;
      final String? name = replyToName?.trim();
      if (name != null && name.isNotEmpty) {
        fields['replyToName'] = name;
      }
    }
    return fields;
  }

  /// Reads a comment from a Firestore document snapshot.
  ///
  /// Returns [Success] with the parsed [Comment], or a [FailureResult] wrapping a
  /// [ValidationFailure] whose `messageKey` is the [CommentIssue] name when a
  /// required field is missing or malformed.
  static Result<Comment> fromMap(String id, Map<String, Object?> data) {
    final Object? authorUid = data['authorUid'];
    if (authorUid is! String || authorUid.trim().isEmpty) {
      return FailureResult<Comment>(
        ValidationFailure(
          messageKey: CommentIssue.authorUidMissing.name,
          debugMessage: 'authorUid: $authorUid',
        ),
      );
    }
    final Object? authorName = data['authorName'];
    if (authorName is! String) {
      return FailureResult<Comment>(
        ValidationFailure(
          messageKey: CommentIssue.fieldMalformed.name,
          debugMessage: 'authorName: $authorName',
        ),
      );
    }
    final Object? text = data['text'];
    if (text is! String || text.isEmpty) {
      return FailureResult<Comment>(
        ValidationFailure(
          messageKey: CommentIssue.textRequired.name,
          debugMessage: 'text: $text',
        ),
      );
    }
    final Object? rawCreated = data['createdAt'];
    if (rawCreated is! Timestamp) {
      return FailureResult<Comment>(
        ValidationFailure(
          messageKey: CommentIssue.createdAtMissing.name,
          debugMessage: 'createdAt: $rawCreated',
        ),
      );
    }
    final DateTime createdAt = rawCreated.toDate().toUtc();
    final Object? photoUrl = data['authorPhotoUrl'];
    final Object? parentId = data['parentId'];
    final Object? replyToName = data['replyToName'];

    return Success<Comment>(
      Comment(
        id: id,
        authorUid: authorUid.trim(),
        authorName: authorName,
        authorPhotoUrl: photoUrl is String && photoUrl.isNotEmpty
            ? photoUrl
            : null,
        text: text,
        parentId: parentId is String && parentId.isNotEmpty ? parentId : null,
        replyToName: replyToName is String && replyToName.isNotEmpty
            ? replyToName
            : null,
        createdAt: createdAt,
      ),
    );
  }
}
