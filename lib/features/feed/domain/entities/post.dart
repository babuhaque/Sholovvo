import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/error/failure.dart';

/// What is wrong with a post's data.
///
/// One vocabulary for both sides of the boundary: the field rules
/// ([PostValidator]) raise the first group, the document mapper
/// (`PostDocument.fromMap`) raises the second. They live together because a
/// screen that reports "this post cannot be shown" and a form that reports "this
/// text is too long" must not invent two spellings of the same problem.
///
/// Values only. Presentation turns one of these into a sentence in the active
/// language, exactly as `ProfileFieldIssue` and `PhotoIssue` are handled.
enum PostIssue {
  /// Nothing to read once the text is trimmed. A post is a message; this stage
  /// has no image-only post.
  textRequired,

  /// Longer than [PostValidator.maxTextLength].
  textTooLong,

  /// More than [PostValidator.maxImages] photographs.
  tooManyImages,

  /// More storage paths than published URLs, or more than the same limit. A
  /// path with no URL points at an object no reader can see, and a path the
  /// delete path cannot name is a file nobody can ever remove.
  tooManyImagePaths,

  /// A counter below zero. Likes and comments are counts, not balances.
  counterNegative,

  /// A document read without an id. The id is the document's address, and a
  /// post that cannot be addressed cannot be liked, commented on or deleted.
  idMissing,

  /// `authorUid` absent, blank, or not a string.
  authorUidMissing,

  /// `createdAt` absent or not a timestamp.
  createdAtMissing,

  /// `updatedAt` absent or not a timestamp.
  updatedAtMissing,

  /// A field is present but not the type the document shape promises. Reported
  /// rather than coerced: a reader that guesses turns a broken write into a
  /// post that looks fine and is wrong.
  fieldMalformed,
}

/// The rules a post has to satisfy, wherever it was built.
///
/// Pure functions returning `null` when the data is sound, in the same shape as
/// `ProfileValidators` and `PhotoValidator`, so both the compose screen and the
/// document mapper ask the same question and get the same answer.
abstract final class PostValidator {
  /// Two thousand characters: long enough for an account of a blood drive,
  /// short enough that a feed page is still a page. `firestore.rules` enforces
  /// this ceiling on the **stored** `text`, and the publish path trims before it
  /// writes (see `compose_providers`), so the trimmed length measured here is
  /// exactly the length the server will check — the client never accepts a
  /// draft the rules would reject. Why it is a constant here rather than a
  /// literal in the form.
  static const int maxTextLength = 2000;

  /// Four. Fixed by the compose screen's grid, by the storage budget (four
  /// images per post on a free tier), and by the fact that a feed card stops
  /// being scannable past a small gallery.
  static const int maxImages = 4;

  /// Field-level rules only. Counts are passed in as lengths rather than as
  /// lists so this stays free of collection types and callable from the mapper
  /// after it has read the document.
  static PostIssue? validate({
    required String text,
    required int imageCount,
    required int imagePathCount,
    required int likeCount,
    required int commentCount,
  }) {
    if (text.trim().isEmpty) {
      return PostIssue.textRequired;
    }
    // Trimmed length: the publish path stores `state.text.trim()`, so the
    // value the rules measure equals this trimmed measure. A draft padded past
    // the limit trims back under it and is stored trimmed — client and server
    // agree. See the note on [maxTextLength] and the compose publish trim.
    if (text.trim().length > maxTextLength) {
      return PostIssue.textTooLong;
    }
    if (imageCount > maxImages) {
      return PostIssue.tooManyImages;
    }
    if (imagePathCount > maxImages || imagePathCount > imageCount) {
      return PostIssue.tooManyImagePaths;
    }
    if (likeCount < 0 || commentCount < 0) {
      return PostIssue.counterNegative;
    }
    return null;
  }

  /// The issue a [Failure] carries, or `null` when it names none.
  ///
  /// Symmetric with `PhotoValidator.issueOf`: a refused draft travels as a
  /// [ValidationFailure] whose `messageKey` is the [PostIssue] name, so
  /// presentation can turn it back into the sentence for that rule instead of
  /// showing a generic "check your input" for a post that is simply too long.
  static PostIssue? issueOf(Failure failure) {
    if (failure is! ValidationFailure) {
      return null;
    }
    for (final PostIssue issue in PostIssue.values) {
      if (issue.name == failure.messageKey) {
        return issue;
      }
    }
    return null;
  }
}

/// One community post.
///
/// A view of the `posts/{postId}` document, with no SDK type in sight: the
/// timestamps are `DateTime`, the images are URLs and storage paths, and the
/// counts are the cached integers the document carries. `PostDocument` is the
/// only thing that knows how those fields are spelled on the wire.
///
/// **The author is a snapshot, and that is deliberate.** Name and photo are
/// copied into the document when the post is written rather than read per card,
/// because the alternative is one profile read per post on a plan that counts
/// reads. The price is staleness: a donor who renames themselves keeps the old
/// name on everything they already wrote. That is accepted — a post is a record
/// of what was said at the time, the profile is the current truth, and the feed
/// shows the former.
///
/// **Nothing else about the author is copied.** Not the blood group, not the
/// area, not availability, not the phone number. Those live in `users/{uid}`
/// under the profile's own privacy split, and copying one into a document that
/// every signed-in account can read would quietly undo that split.
///
/// **There is no moderation status and no follow graph.** Neither exists in the
/// product, and an enum invented now would be a field the rules have to guess
/// about later. Reporting is a separate collection (`Report`), not a flag here.
@immutable
final class Post {
  Post({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.authorPhotoUrl,
    List<String> imageUrls = const <String>[],
    List<String> imagePaths = const <String>[],
    this.likeCount = 0,
    this.commentCount = 0,
    this.editedAt,
  }) : imageUrls = List<String>.unmodifiable(imageUrls),
       imagePaths = List<String>.unmodifiable(imagePaths);

  /// The `posts` document id. Never empty; a post without one cannot be
  /// addressed.
  final String id;

  final String authorUid;

  /// The author's display name at the moment of writing. See the class note on
  /// staleness.
  final String authorName;

  /// The author's avatar URL at the moment of writing, if they had one.
  final String? authorPhotoUrl;

  /// What the donor wrote, as they wrote it. The validator measures the trimmed
  /// length; nothing here silently trims, because a mapper that trims is a
  /// mapper that rewrites the donor's words.
  final String text;

  /// Public URLs of up to [PostValidator.maxImages] photographs, in the order
  /// the donor arranged them. Unmodifiable.
  final List<String> imageUrls;

  /// The storage object path behind each URL, in the same order. Held so a
  /// delete or an edit can remove exactly the objects the post stops
  /// referencing; a URL alone cannot be turned into a path without parsing.
  ///
  /// May be shorter than [imageUrls] — an image this app did not store (an
  /// older post, or one written by another client) still renders. It may never
  /// be longer, because a path with no URL names an object nobody can reach.
  final List<String> imagePaths;

  /// The cached like count written by the like path. Authoritative only in the
  /// sense that rules keep it within one of the truth; the count on a post's
  /// own screen comes from an aggregation query.
  final int likeCount;

  /// The cached comment count, maintained the same way.
  final int commentCount;

  final DateTime createdAt;

  final DateTime updatedAt;

  /// When the author last edited the text, or `null` if they never have.
  /// Separate from [updatedAt] so an edit can be labelled without pretending a
  /// counter change was a rewrite.
  final DateTime? editedAt;

  bool get hasImages => imageUrls.isNotEmpty;

  bool get isEdited => editedAt != null;

  @override
  bool operator ==(Object other) =>
      other is Post &&
      other.id == id &&
      other.authorUid == authorUid &&
      other.authorName == authorName &&
      other.authorPhotoUrl == authorPhotoUrl &&
      other.text == text &&
      listEquals(other.imageUrls, imageUrls) &&
      listEquals(other.imagePaths, imagePaths) &&
      other.likeCount == likeCount &&
      other.commentCount == commentCount &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.editedAt == editedAt;

  @override
  int get hashCode => Object.hash(
    id,
    authorUid,
    authorName,
    authorPhotoUrl,
    text,
    Object.hashAll(imageUrls),
    Object.hashAll(imagePaths),
    likeCount,
    commentCount,
    createdAt,
    updatedAt,
    editedAt,
  );

  @override
  String toString() =>
      'Post($id, author: $authorUid, images: ${imageUrls.length}, '
      'likes: $likeCount, comments: $commentCount)';
}
