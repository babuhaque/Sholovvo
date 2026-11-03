import 'package:flutter/foundation.dart';

/// What is wrong with a comment's data.
///
/// The same split as `PostIssue`: field rules ([CommentValidator]) and document
/// shape (`CommentDocument.fromMap`, Stage 8.5) share one vocabulary, so the
/// composer and the reader describe a problem the same way.
enum CommentIssue {
  /// Nothing to read once the text is trimmed.
  textRequired,

  /// Longer than [CommentValidator.maxTextLength].
  textTooLong,

  /// A reply that names somebody without naming the comment it answers. The
  /// name is what the reader sees; the id is what makes the reply reach the
  /// right thread.
  replyWithoutParent,

  /// A document read without an id.
  idMissing,

  /// `authorUid` absent, blank, or not a string.
  authorUidMissing,

  /// `createdAt` absent or not a timestamp.
  createdAtMissing,

  /// A field is present but not the type the document shape promises.
  fieldMalformed,
}

/// The rules a comment has to satisfy.
abstract final class CommentValidator {
  /// Five hundred: a comment answers a post, it does not compete with it.
  static const int maxTextLength = 500;

  static CommentIssue? validate({
    required String text,
    String? parentId,
    String? replyToName,
  }) {
    if (text.trim().isEmpty) {
      return CommentIssue.textRequired;
    }
    if (text.trim().length > maxTextLength) {
      return CommentIssue.textTooLong;
    }
    final String name = replyToName?.trim() ?? '';
    final String parent = parentId?.trim() ?? '';
    if (name.isNotEmpty && parent.isEmpty) {
      return CommentIssue.replyWithoutParent;
    }
    return null;
  }
}

/// One comment, or one reply to a comment.
///
/// **The post is the path, not a field.** A comment lives at
/// `posts/{postId}/comments/{commentId}`, so the post it belongs to is already
/// in its address; a `postId` field would be a second copy of that fact, and two
/// copies of a fact are two things that can disagree.
///
/// **One level of replies.** [parentId] points at a top-level comment and never
/// at another reply, and [replyToName] is the snapshot of whose comment is being
/// answered, so a thread renders without a second lookup per reply. Deeper
/// nesting is not modelled, because a comment thread on a phone screen is two
/// levels deep whether or not the schema allows more.
///
/// Like `Post`, the author is a snapshot: name and photo at the time of writing,
/// nothing else. See the note on staleness there.
@immutable
final class Comment {
  const Comment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorPhotoUrl,
    this.parentId,
    this.replyToName,
  });

  /// The `comments` document id.
  final String id;

  final String authorUid;

  final String authorName;

  final String? authorPhotoUrl;

  final String text;

  /// The top-level comment this answers, or `null` for a top-level comment.
  final String? parentId;

  /// The display name of the person being answered, copied at write time so the
  /// thread reads correctly even if they rename themselves or delete the parent.
  final String? replyToName;

  final DateTime createdAt;

  bool get isReply => parentId != null;

  @override
  bool operator ==(Object other) =>
      other is Comment &&
      other.id == id &&
      other.authorUid == authorUid &&
      other.authorName == authorName &&
      other.authorPhotoUrl == authorPhotoUrl &&
      other.text == text &&
      other.parentId == parentId &&
      other.replyToName == replyToName &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    authorUid,
    authorName,
    authorPhotoUrl,
    text,
    parentId,
    replyToName,
    createdAt,
  );

  @override
  String toString() =>
      'Comment($id, author: $authorUid, parent: ${parentId ?? '(none)'})';
}
