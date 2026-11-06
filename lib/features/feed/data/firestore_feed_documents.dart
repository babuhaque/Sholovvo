import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/firestore_error_mapper.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/feed_documents.dart';
import 'package:sholovvo_app/features/feed/data/models/post_document.dart';
import 'package:sholovvo_app/features/feed/domain/feed_page.dart';

/// The cursor this app actually uses: a `DocumentSnapshot`.
///
/// Opaque outside this file — [FeedCursor] is an empty interface, so the domain
/// and the repository pass it around without ever seeing a Firestore type. It
/// also makes the snapshot a *stable* cursor: it addresses a document, not an
/// offset, so a post published between two pages cannot shift the window.
final class SnapshotCursor implements FeedCursor {
  const SnapshotCursor(this.snapshot);

  final DocumentSnapshot<Map<String, dynamic>> snapshot;
}

/// Reads the `posts` collection, one page at a time, newest first.
///
/// **What the query is, and why it is this small.** The whole-feed read (`authorUid`
/// `null`) is one collection, no `where`, one `orderBy` on `createdAt`, one
/// `limit`, and — for every page after the first — `startAfterDocument`. The
/// author-scoped read adds one `where('authorUid', isEqualTo: …)`. Both shapes
/// matter for three reasons:
///
/// * `firestore.rules` grants `allow read: if request.auth != null` on
///   `/posts/{postId}`, which covers a list query for a signed-in caller. The
///   rule has no field condition, so neither read needs a filter to satisfy it.
/// * The whole-feed `orderBy` alone is served by Firestore's automatic index.
///   The author-scoped read puts an equality filter on one field and a sort on
///   another, which is exactly the disagreement that needs a composite index
///   (`authorUid` ASC, `createdAt` DESC) — declared in `firestore.indexes.json`.
/// * Nothing here reads a subcollection. These queries only turn over the
///   `posts` documents; the like and comment counts a card shows are DERIVED
///   separately by the feed's count hydration, which runs an aggregate `count()`
///   over each post's `likes`/`comments` subcollections after the page resolves.
///   Keeping them out of this query is what lets a page be one indexed scan.
class FirestoreFeedDocuments implements FeedDocuments {
  FirestoreFeedDocuments(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// The ordering field. Named here rather than inlined so the query and the
  /// explanation above cannot drift apart.
  static const String orderByField = 'createdAt';

  CollectionReference<Map<String, dynamic>> get _posts =>
      _firestore.collection(PostDocument.collection);

  @override
  Future<Result<List<FeedDocument>>> fetch({
    required int limit,
    FeedCursor? after,
    String? authorUid,
  }) async {
    // A zero or negative limit is not a database question. Asking Firestore for
    // `limit(0)` would still cost a round trip and could not be honoured.
    if (limit <= 0) {
      return const Success<List<FeedDocument>>(<FeedDocument>[]);
    }

    try {
      // Checked explicitly so a missing session is reported as an auth problem
      // rather than as the `permission-denied` the rules would eventually send.
      if (_auth.currentUser == null) {
        throw const AuthFailure(
          debugMessage: 'A feed read requires a signed-in user',
        );
      }

      Query<Map<String, dynamic>> query = _posts
          .orderBy(orderByField, descending: true)
          .limit(limit);

      // Narrowing to one author is the whole point of the tap-through "author
      // posts" screen. An equality filter plus the `createdAt` sort is the one
      // shape that needs a composite index (`authorUid` ASC, `createdAt` DESC)
      // rather than the automatic single-field one — declared in
      // `firestore.indexes.json`. A cursor from the filtered query stays valid
      // because `startAfterDocument` re-applies every ordering column.
      if (authorUid != null) {
        query = _posts
            .where('authorUid', isEqualTo: authorUid)
            .orderBy(orderByField, descending: true)
            .limit(limit);
      }

      if (after != null) {
        // A cursor from anywhere else is refused rather than coerced: paging
        // from a snapshot of a different collection would silently return
        // whatever happens to sort after it.
        if (after is! SnapshotCursor) {
          return FailureResult<List<FeedDocument>>(
            ValidationFailure(
              messageKey: 'feedCursorInvalid',
              debugMessage:
                  'The feed was given a cursor it did not produce '
                  '(${after.runtimeType})',
            ),
          );
        }
        query = query.startAfterDocument(after.snapshot);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await query.get();

      return Success<List<FeedDocument>>(<FeedDocument>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in snapshot.docs)
          FeedDocument(
            id: document.id,
            fields: document.data(),
            cursor: SnapshotCursor(document),
          ),
      ]);
    } on FirebaseException catch (error, stackTrace) {
      return FailureResult<List<FeedDocument>>(
        mapFirestoreCodeToFailure(
          error.code,
          debugMessage: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<List<FeedDocument>>(
        mapExceptionToFailure(error, stackTrace),
      );
    }
  }
}
