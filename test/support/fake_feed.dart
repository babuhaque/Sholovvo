import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/feed_documents.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';

/// A cursor with no Firestore in it.
///
/// Shaped like the real one — an opaque position — so a test can hand it back
/// and assert that it was forwarded, without a `DocumentSnapshot`.
final class FeedTestCursor implements FeedCursor {
  const FeedTestCursor(this.id);

  final String id;

  // Value equality, so a test can write `expect(requestedAfter, [const
  // FeedTestCursor('2')])` and mean "the same position" rather than "this
  // instance". The real cursor is a snapshot and compares by identity, which is
  // exactly why the repository tests assert with `same()` there.
  @override
  bool operator ==(Object other) => other is FeedTestCursor && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'FeedTestCursor($id)';
}

/// One valid `posts` document, spelled the way [PostDocument] writes it.
///
/// The map is built rather than the entity so the repository tests exercise
/// `fromMap` — the half of the mapper that reads what another client wrote.
Map<String, Object?> postFields({
  String authorUid = 'uid-verified',
  String authorName = 'Ayesha Rahman',
  String text = 'Donated at Dhaka Medical today.',
  List<String> imageUrls = const <String>[],
  List<String> imagePaths = const <String>[],
  int likeCount = 0,
  int commentCount = 0,
  DateTime? createdAt,
}) {
  final DateTime stamp = createdAt ?? DateTime.utc(2026, 10, 20, 9);
  return <String, Object?>{
    'authorUid': authorUid,
    'authorName': authorName,
    'text': text,
    'imageUrls': imageUrls,
    'imagePaths': imagePaths,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'createdAt': Timestamp.fromDate(stamp.toUtc()),
    'updatedAt': Timestamp.fromDate(stamp.toUtc()),
  };
}

/// A [FeedDocument] wrapping [fields].
FeedDocument feedDocument(String id, {Map<String, Object?>? fields}) {
  return FeedDocument(
    id: id,
    fields: fields ?? postFields(),
    cursor: FeedTestCursor(id),
  );
}

/// A valid [Post], for the controller and screen tests.
Post fakePost({
  String id = 'post-1',
  String authorUid = 'uid-verified',
  String authorName = 'Ayesha Rahman',
  String text = 'Donated at Dhaka Medical today.',
  List<String> imageUrls = const <String>[],
  int likeCount = 0,
  int commentCount = 0,
  DateTime? createdAt,
}) {
  final DateTime stamp = createdAt ?? DateTime.utc(2026, 10, 20, 9);
  return Post(
    id: id,
    authorUid: authorUid,
    authorName: authorName,
    text: text,
    imageUrls: imageUrls,
    likeCount: likeCount,
    commentCount: commentCount,
    createdAt: stamp,
    updatedAt: stamp,
  );
}

/// An in-memory [FeedDocuments].
///
/// Behaves like the query it stands in for: it honours `limit`, starts after the
/// cursor it was given, and counts the calls, so the repository's page assembly
/// can be tested without a Firebase project.
class FakeFeedDocuments implements FeedDocuments {
  FakeFeedDocuments(this.documents);

  final List<FeedDocument> documents;

  /// Returned instead of a page when set.
  Failure? failure;

  /// Holds every call open until completed, which is how the "one read at a
  /// time" tests keep two requests genuinely in flight at once.
  Completer<void>? gate;

  int calls = 0;
  int? lastLimit;
  FeedCursor? lastAfter;

  /// The cursor each call was given, in order.
  ///
  /// [lastAfter] answers "what did the final call ask for"; this answers "what
  /// did the whole walk ask for, in what order", which is the question a test
  /// about page advancement has to ask.
  final List<FeedCursor?> requestedAfter = <FeedCursor?>[];

  @override
  Future<Result<List<FeedDocument>>> fetch({
    required int limit,
    FeedCursor? after,
    String? authorUid,
  }) async {
    calls++;
    lastLimit = limit;
    lastAfter = after;
    requestedAfter.add(after);

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<List<FeedDocument>>(failure!);
    }

    // Narrow to one author when asked, mirroring the `where('authorUid')` the
    // real query adds; a null authorUid is the whole collection, as before.
    final List<FeedDocument> pool = authorUid == null
        ? documents
        : documents
              .where(
                (FeedDocument document) =>
                    document.fields['authorUid'] == authorUid,
              )
              .toList(growable: false);

    final int start = after is FeedTestCursor
        ? pool.indexWhere(
                (FeedDocument document) => document.id == after.id,
              ) +
              1
        : 0;

    return Success<List<FeedDocument>>(
      pool.skip(start).take(limit).toList(growable: false),
    );
  }
}

/// A paging [FeedRepository] over a fixed list of posts.
///
/// The real repository is covered against [FakeFeedDocuments]; this one exists
/// for the controller and the screen, which care about *state* rather than
/// about mapping.
class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository({
    List<Post>? posts,
    this.pageSize = FeedRepository.pageSize,
  }) : posts = posts ?? <Post>[];

  /// Newest first, as the collection would return them.
  List<Post> posts;

  final int pageSize;

  /// Returned instead of a page when set.
  Failure? failure;

  /// Holds every call open until completed.
  Completer<void>? gate;

  int calls = 0;

  /// Every page answers with no post, with this many refused documents, and with
  /// more still behind it.
  ///
  /// This is the shape [FirestoreFeedRepository] produces when a run of stored
  /// documents is malformed, and it is a shape no other setting of this fake can
  /// reach by accident: an empty *page* inside a non-empty *collection*. A screen
  /// test sets it to ask what the donor is told when the community has posted and
  /// the app cannot read what they posted — the one case where "No posts yet" is
  /// a false statement about somebody else's work.
  int? unreadable;

  /// The cursor each call was given, in order, so a test can see that page two
  /// asked for page two and that a retry re-asked the same question.
  final List<FeedCursor?> requestedAfter = <FeedCursor?>[];

  @override
  Future<Result<FeedPage>> loadPage({
    FeedCursor? after,
    String? authorUid,
  }) async {
    calls++;
    requestedAfter.add(after);

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<FeedPage>(failure!);
    }

    final int? refused = unreadable;
    if (refused != null) {
      // The cursor is passed back unchanged rather than advanced, which is what
      // makes a caller's bounded walk the thing under test: every page looks
      // exactly like the last, so the read can only stop by reaching its own
      // limit, and the count it accumulates is that limit times [refused].
      return Success<FeedPage>(
        FeedPage(
          posts: const <Post>[],
          cursor: after,
          hasMore: true,
          skipped: refused,
        ),
      );
    }

    // Narrow to one author when asked, exactly as the real repository's query
    // does. Paging is over the filtered pool, so the index cursor addresses
    // positions within what this screen is actually showing.
    final List<Post> pool = authorUid == null
        ? posts
        : posts
              .where((Post post) => post.authorUid == authorUid)
              .toList(growable: false);

    final int start = after is FeedTestCursor ? int.parse(after.id) : 0;
    final int end = math.min(start + pageSize, pool.length);
    final List<Post> slice = pool.sublist(start, end);

    return Success<FeedPage>(
      FeedPage(
        posts: slice,
        cursor: slice.isEmpty ? after : FeedTestCursor('$end'),
        hasMore: end < pool.length,
      ),
    );
  }
}
