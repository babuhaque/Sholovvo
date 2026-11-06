import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';

/// The exact shape a `posts` document is written in, and the exact shape read
/// back.
///
/// Pure functions over plain maps, in the same style as `ProfileDocuments`:
/// both directions are testable against literal maps, with no emulator, no
/// network and no Firebase app. That matters here because a field written under
/// the wrong name does not fail loudly — it produces a post that other donors
/// see with a missing author, or a counter the rules do not recognise.
///
/// **What is required and what is optional.**
///
/// | Field | Present | Why |
/// | --- | --- | --- |
/// | `authorUid`, `authorName`, `text` | always | the post has no meaning without them |
/// | `imageUrls`, `imagePaths` | always written; absent reads as empty | a stable shape, so a rule never has to test for a key, and "no images" is an honest reading rather than a guess |
/// | `likeCount`, `commentCount` | always, from zero | a counter that is absent is a counter nobody updates |
/// | `createdAt`, `updatedAt` | always | the feed is ordered by the first of them |
/// | `authorPhotoUrl`, `editedAt` | only when there is a value | absent means "not set", the profile convention |
///
/// An absent optional field reads back as `null`; an absent *required* field is
/// refused, never defaulted. A reader that substitutes a value turns a broken
/// write into a post that looks fine and is wrong, which is the one outcome this
/// app cannot afford in a document it shows to strangers.
///
/// **Timestamps are instants.** They are written as Firestore `Timestamp`s in
/// UTC and read back as UTC `DateTime`s, so a `Post` decoded from a document
/// compares equal to one built with `DateTime.utc(...)` and not to a local
/// `DateTime` of the same instant.
///
/// **Nothing here talks to Firestore.** No repository, no query, no write: this
/// is the mapping layer only. `FirestorePostWriter` performs the one write and
/// `FirestoreFeedRepository` the one query.
abstract final class PostDocument {
  /// Collection name. Kept here rather than in a repository so the tests, the
  /// rules and the query all quote one string.
  static const String collection = 'posts';

  /// The flat, production-canonical likes collection:
  /// `post_likes/{postId}_{uid}` carrying `{postId, userId, createdAt}`.
  ///
  /// This is the shape the live database actually uses (the Stage 9.3 audit
  /// found 42 such rows), so the like read/write path targets it directly
  /// rather than the never-migrated `posts/{id}/likes` subcollection. The
  /// deterministic id makes a second like on the same post an id collision
  /// (an update, which the rules refuse) instead of a duplicate row that would
  /// inflate the derived count.
  static const String likesCollection = 'post_likes';

  /// `posts/{postId}/comments/{commentId}`.
  static const String commentsSubcollection = 'comments';

  /// The keys every document must carry. `firestore.rules` will have to require
  /// exactly these on create, which is why the list lives in code a test can
  /// read rather than only in prose.
  static const List<String> requiredFields = <String>[
    'authorUid',
    'authorName',
    'text',
    'imageUrls',
    'imagePaths',
    'likeCount',
    'commentCount',
    'createdAt',
    'updatedAt',
  ];

  /// The document this client would write for [post], with the entity's own
  /// timestamps.
  ///
  /// The id is **not** included: it is the document's address, and a field that
  /// repeats the address is a field that can disagree with it after a move.
  ///
  /// Because the timestamps come from the entity, a map produced here and read
  /// back through [fromMap] returns the post unchanged. [toCreateMap] is the
  /// variant a real write uses.
  static Map<String, Object?> toMap(Post post) {
    final Map<String, Object?> fields = <String, Object?>{
      'authorUid': post.authorUid,
      'authorName': post.authorName,
      'text': post.text,
      // Always written, even when empty: a stable shape means the rules can
      // require the key instead of testing for its absence.
      'imageUrls': post.imageUrls.toList(growable: false),
      'imagePaths': post.imagePaths.toList(growable: false),
      'likeCount': post.likeCount,
      'commentCount': post.commentCount,
      'createdAt': Timestamp.fromDate(post.createdAt.toUtc()),
      'updatedAt': Timestamp.fromDate(post.updatedAt.toUtc()),
    };

    final String? photoUrl = post.authorPhotoUrl?.trim();
    if (photoUrl != null && photoUrl.isNotEmpty) {
      fields['authorPhotoUrl'] = photoUrl;
    }

    final DateTime? editedAt = post.editedAt;
    if (editedAt != null) {
      fields['editedAt'] = Timestamp.fromDate(editedAt.toUtc());
    }

    return fields;
  }

  /// The document a **publish** actually writes.
  ///
  /// Two differences from [toMap], both of them decisions rather than
  /// conveniences:
  ///
  /// * `createdAt` and `updatedAt` are [FieldValue.serverTimestamp]. A device
  ///   clock can be minutes out, and the feed is ordered by the first of these,
  ///   so a client that stamps its own writes can put a new post below older
  ///   ones for everybody else. The server's clock is the only shared one.
  /// * `editedAt` is never sent. A publish is not an edit, and the field means
  ///   "the author rewrote this", which would be a lie on a brand-new document.
  ///
  /// The repository still returns the entity with its local estimate, so the
  /// donor sees their post immediately; the next read replaces it with the
  /// stamped copy. Nothing reads `createdAt` back out of this map — the sentinel
  /// is not a value until the write lands.
  static Map<String, Object?> toCreateMap(Post post) {
    final Map<String, Object?> fields = toMap(post)
      ..remove('editedAt');
    fields['createdAt'] = FieldValue.serverTimestamp();
    fields['updatedAt'] = FieldValue.serverTimestamp();
    return fields;
  }

  /// Rebuilds a post from a document id and its data.
  ///
  /// Returns a [ValidationFailure] carrying a [PostIssue] name in `messageKey`
  /// for anything the shape does not allow — a missing required field, a field
  /// of the wrong type, a negative counter, a text longer than
  /// [PostValidator.maxTextLength]. Nothing is coerced and nothing is dropped.
  static Result<Post> fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final String postId = id.trim();
    if (postId.isEmpty) {
      return FailureResult<Post>(
        _reject(PostIssue.idMissing, 'document id is empty'),
      );
    }

    final Object? authorUid = data['authorUid'];
    if (authorUid is! String || authorUid.trim().isEmpty) {
      return FailureResult<Post>(
        _reject(
          PostIssue.authorUidMissing,
          'authorUid: ${_describe(authorUid)}',
        ),
      );
    }

    // A display name may legitimately be empty — a donor who never set one is
    // rendered with the person icon, not with an invented letter — but it has to
    // be a string, because a number there means a write went wrong.
    final Object? authorName = data['authorName'];
    if (authorName is! String) {
      return FailureResult<Post>(
        _reject(
          PostIssue.fieldMalformed,
          'authorName: ${_describe(authorName)}',
        ),
      );
    }

    final Object? text = data['text'];
    if (text is! String) {
      return FailureResult<Post>(
        _reject(PostIssue.fieldMalformed, 'text: ${_describe(text)}'),
      );
    }

    final Result<List<String>> imageUrls = _urls(
      data['imageUrls'],
      'imageUrls',
      PostIssue.tooManyImages,
    );
    if (imageUrls.isFailure) {
      return FailureResult<Post>(imageUrls.failureOrNull!);
    }
    final Result<List<String>> imagePaths = _urls(
      data['imagePaths'],
      'imagePaths',
      PostIssue.tooManyImagePaths,
    );
    if (imagePaths.isFailure) {
      return FailureResult<Post>(imagePaths.failureOrNull!);
    }

    final Result<int> likeCount = _counter(data['likeCount'], 'likeCount');
    if (likeCount.isFailure) {
      return FailureResult<Post>(likeCount.failureOrNull!);
    }
    final Result<int> commentCount = _counter(
      data['commentCount'],
      'commentCount',
    );
    if (commentCount.isFailure) {
      return FailureResult<Post>(commentCount.failureOrNull!);
    }

    final Result<DateTime> createdAt = _timestamp(
      data['createdAt'],
      'createdAt',
      PostIssue.createdAtMissing,
    );
    if (createdAt.isFailure) {
      return FailureResult<Post>(createdAt.failureOrNull!);
    }
    final Result<DateTime> updatedAt = _timestamp(
      data['updatedAt'],
      'updatedAt',
      PostIssue.updatedAtMissing,
    );
    if (updatedAt.isFailure) {
      return FailureResult<Post>(updatedAt.failureOrNull!);
    }

    final Result<String?> authorPhotoUrl = _optionalText(
      data['authorPhotoUrl'],
      'authorPhotoUrl',
    );
    if (authorPhotoUrl.isFailure) {
      return FailureResult<Post>(authorPhotoUrl.failureOrNull!);
    }
    final Result<DateTime?> editedAt = _optionalTimestamp(
      data['editedAt'],
      'editedAt',
    );
    if (editedAt.isFailure) {
      return FailureResult<Post>(editedAt.failureOrNull!);
    }

    List<String> urls = imageUrls.valueOrNull!;
    // Legacy read compatibility. A pre-Stage-8 post stored a single `imageUrl`
    // and has no `imageUrls` array, so reading the modern array alone would drop
    // a photograph its author really attached. When the modern array is absent or
    // empty and a non-blank legacy url is present, it folds into the one-element
    // list. This is read-only — [toMap] never writes `imageUrl` — and it fires
    // only when the modern array is empty, so a modern post is never second-guessed
    // by a stray legacy key.
    if (urls.isEmpty) {
      final Object? legacyUrl = data['imageUrl'];
      if (legacyUrl is String && legacyUrl.trim().isNotEmpty) {
        urls = <String>[legacyUrl.trim()];
      }
    }
    final List<String> paths = imagePaths.valueOrNull!;

    final PostIssue? issue = PostValidator.validate(
      text: text,
      imageCount: urls.length,
      imagePathCount: paths.length,
      likeCount: likeCount.valueOrNull!,
      commentCount: commentCount.valueOrNull!,
    );
    if (issue != null) {
      return FailureResult<Post>(_reject(issue, 'posts/$postId'));
    }

    return Success<Post>(
      Post(
        id: postId,
        authorUid: authorUid.trim(),
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl.valueOrNull,
        text: text,
        imageUrls: urls,
        imagePaths: paths,
        likeCount: likeCount.valueOrNull!,
        commentCount: commentCount.valueOrNull!,
        createdAt: createdAt.valueOrNull!,
        updatedAt: updatedAt.valueOrNull!,
        editedAt: editedAt.valueOrNull,
      ),
    );
  }

  /// A list of non-blank strings. Absent reads as empty; present but not a list
  /// of strings is refused, because a silently dropped entry is an image the
  /// donor attached and nobody can see.
  static Result<List<String>> _urls(
    Object? value,
    String field,
    PostIssue overflow,
  ) {
    if (value == null) {
      return const Success<List<String>>(<String>[]);
    }
    if (value is! List) {
      return FailureResult<List<String>>(
        _reject(PostIssue.fieldMalformed, '$field: ${_describe(value)}'),
      );
    }
    final List<String> values = <String>[];
    for (final Object? entry in value) {
      if (entry is! String || entry.trim().isEmpty) {
        return FailureResult<List<String>>(
          _reject(
            PostIssue.fieldMalformed,
            '$field entry: ${_describe(entry)}',
          ),
        );
      }
      values.add(entry.trim());
    }
    if (values.length > PostValidator.maxImages) {
      return FailureResult<List<String>>(
        _reject(overflow, '$field has ${values.length}'),
      );
    }
    return Success<List<String>>(values);
  }

  static Result<int> _counter(Object? value, String field) {
    if (value is! int) {
      return FailureResult<int>(
        _reject(PostIssue.fieldMalformed, '$field: ${_describe(value)}'),
      );
    }
    if (value < 0) {
      return FailureResult<int>(
        _reject(PostIssue.counterNegative, '$field is $value'),
      );
    }
    return Success<int>(value);
  }

  static Result<DateTime> _timestamp(
    Object? value,
    String field,
    PostIssue missing,
  ) {
    if (value == null) {
      return FailureResult<DateTime>(_reject(missing, '$field is absent'));
    }
    final DateTime? date = _date(value);
    if (date == null) {
      return FailureResult<DateTime>(
        _reject(PostIssue.fieldMalformed, '$field: ${_describe(value)}'),
      );
    }
    return Success<DateTime>(date);
  }

  static Result<DateTime?> _optionalTimestamp(Object? value, String field) {
    if (value == null) {
      return const Success<DateTime?>(null);
    }
    final DateTime? date = _date(value);
    if (date == null) {
      return FailureResult<DateTime?>(
        _reject(PostIssue.fieldMalformed, '$field: ${_describe(value)}'),
      );
    }
    return Success<DateTime?>(date);
  }

  /// A text field that is allowed to be absent. Blank reads as absent, because an
  /// empty string and a missing key mean the same thing everywhere downstream.
  static Result<String?> _optionalText(Object? value, String field) {
    if (value == null) {
      return const Success<String?>(null);
    }
    if (value is! String) {
      return FailureResult<String?>(
        _reject(PostIssue.fieldMalformed, '$field: ${_describe(value)}'),
      );
    }
    final String trimmed = value.trim();
    return Success<String?>(trimmed.isEmpty ? null : trimmed);
  }

  /// Both forms a timestamp arrives in: a `Timestamp` from Firestore, or a
  /// `DateTime` when a test (or a batch of local data) supplies one directly.
  ///
  /// Both are normalised to UTC. `Timestamp.toDate()` answers in the device's
  /// local zone, and `DateTime` equality is false for the same instant in two
  /// zones, so a post read on a phone abroad would not equal the post that was
  /// written — and a UI comparing the two would redraw when nothing changed.
  /// A stored instant is an instant; the zone is the phone's business.
  static DateTime? _date(Object? value) {
    return switch (value) {
      Timestamp() => value.toDate().toUtc(),
      DateTime() => value.toUtc(),
      _ => null,
    };
  }

  /// What a value *is*, for a debug message — never what it contains. A post's
  /// text or an author's name must not end up in a log line.
  static String _describe(Object? value) {
    if (value == null) {
      return 'absent';
    }
    return value.runtimeType.toString();
  }

  static ValidationFailure _reject(PostIssue issue, String detail) {
    return ValidationFailure(
      messageKey: issue.name,
      debugMessage: 'Post document rejected: ${issue.name} ($detail)',
    );
  }
}
