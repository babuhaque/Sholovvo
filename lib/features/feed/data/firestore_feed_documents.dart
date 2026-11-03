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
/// **What the query is, and why it is this small.** One collection, no `where`,
/// one `orderBy` on `createdAt`, one `limit`, and — for every page after the
/// first — `startAfterDocument`. That shape matters for three reasons:
///
/// * `firestore.rules` grants `allow read: if request.auth != null` on
///   `/posts/{postId}`, which covers a list query for a signed-in caller. The
///   rule has no field condition, so no filter is required to satisfy it.
/// * A single-field `orderBy` is served by Firestore's automatic index. There is
///   no `firestore.indexes.json` in this repository and none is needed: a
///   composite index only becomes necessary once a filter and a sort disagree,
///   and this query filters nothing.
/// * Nothing here reads a subcollection. Likes and comments are the counters the
///   post document already carries; the subcollections cost one read each and
///   this stage does not draw them.
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
