import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/firestore_error_mapper.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/data/models/blood_request_document.dart';
import 'package:sholovvo_app/features/requests/data/request_documents.dart';

/// Reads the `blood_requests` collection, one window at a time.
///
/// **What the query is, and why it is this small.** One collection, one equality
/// filter on `status`, one `limit`. No `where` on a date, no `orderBy`, no
/// `startAfterDocument`. Each of those absences is a decision:
///
/// * **No date bound and no date sort.** `requiredDateTime` is free text in this
///   collection — the create rule in `firestore.rules` requires the key but
///   constrains no type, and the project's own rules-test seed writes
///   `'2026-11-10 10:00 AM'`. Firestore orders by *type* before value, so a
///   `Timestamp` bound or an `orderBy` on that field matches none of those
///   documents rather than matching them badly: the query succeeds, returns zero,
///   and the screen prints "no open requests" over a collection full of them.
///   That is the one failure mode a blood-request search must not have, so the
///   ordering is done on the decoded list instead — see
///   `orderRequests`.
/// * **No composite index.** A single equality filter with the default
///   document-id ordering is served by the automatic single-field index, so this
///   query needs nothing deployed before it works. There is still no
///   `firestore.indexes.json` in this repository, and none is added: the moment a
///   filter and a sort on different fields are both wanted, one will be, and that
///   is a delivery step the owner has to approve — not something a screen can
///   assume.
/// * **No cursor.** Without a trusted order there is nothing to resume after, so
///   this read is a window and the screen re-reads it on refresh instead of
///   paging through it.
/// * **The rules answer it unchanged.** `firestore.rules` grants
///   `allow read: if request.auth != null` on `/blood_requests/{requestId}`, with
///   no field condition, so a signed-in list read is permitted and nothing in
///   this stage asks for a Rules change. That is the difference between this
///   feature and the feed's write path, which is still waiting on one.
///
/// **What it cannot prove.** That the deployed project's documents match the
/// shapes above. Nothing in this stage has read a live collection; the field
/// spellings come from the rules file and the rules-test seed, and the mapper
/// refuses rather than assumes whatever arrives that disagrees.
class FirestoreRequestDocuments implements RequestDocuments {
  FirestoreRequestDocuments(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// The field the window is filtered on. Named here rather than inlined so the
  /// query and the explanation above cannot drift apart.
  static const String statusField = 'status';

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection(BloodRequestDocument.collection);

  @override
  Future<Result<List<RequestDocument>>> fetch({
    required int limit,
  }) async {
    // A zero or negative limit is not a database question. Asking Firestore for
    // `limit(0)` would still cost a round trip and could not be honoured.
    if (limit <= 0) {
      return const Success<List<RequestDocument>>(<RequestDocument>[]);
    }

    try {
      // Checked explicitly so a missing session is reported as an auth problem
      // rather than as the `permission-denied` the rules would eventually send.
      if (_auth.currentUser == null) {
        throw const AuthFailure(
          debugMessage: 'A request read requires a signed-in user',
        );
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _requests
              .where(statusField, isEqualTo: BloodRequestDocument.openStatus)
              .limit(limit)
              .get();

      return Success<List<RequestDocument>>(<RequestDocument>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in snapshot.docs)
          RequestDocument(id: document.id, fields: document.data()),
      ]);
    } on FirebaseException catch (error, stackTrace) {
      return FailureResult<List<RequestDocument>>(
        mapFirestoreCodeToFailure(
          error.code,
          debugMessage: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<List<RequestDocument>>(
        mapExceptionToFailure(error, stackTrace),
      );
    }
  }
}
