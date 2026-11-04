import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/firestore_error_mapper.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/data/donor_documents.dart';
import 'package:sholovvo_app/features/donors/data/models/donor_profile_document.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';

/// Reads the public `users` profiles, one window at a time.
///
/// **What the query is, and why it is this shape.** It always filters
/// `role == 'donor'` and `allowDonorDiscovery == true`, then adds an equality
/// filter for each refinement the [DonorQuery] carries — `isAvailable`,
/// `bloodGroup`, `area` — and a `limit`. No `orderBy`, no cursor. Each absence is
/// a decision:
///
/// * **Only equality filters.** Firestore serves a query of any number of equality
///   filters by merge-joining the automatic single-field indexes, so this read needs
///   nothing deployed before it works. Adding an `orderBy` on a second field (a name
///   or a date) *would* need a composite index — a delivery step the owner has to
///   approve and a `firestore.indexes.json` this repository still does not have — so
///   the ordering happens after the read, in `orderDonors`. This is the same line
///   `FirestoreRequestDocuments` and `FirestoreProfileRepository.loadDonationHistory`
///   hold.
/// * **The window is bounded, not paged.** With no trusted order there is nothing to
///   resume, so `search` re-runs on a filter change instead of scrolling.
/// * **Consent is enforced at the database, not in memory.** The
///   `allowDonorDiscovery == true` filter is applied by the same Firestore query
///   that returns the window: no opted-out document is ever downloaded, so a
///   directory that grew to a million donors costs the same bandwidth and refuses
///   the same way a small one does. Documents that have no `allowDonorDiscovery`
///   key at all — every legacy `users/{uid}` written before Stage 9.5 — also do
///   not match, which is what "existing donors must not silently become
///   discoverable" means in a query the app can actually send.
/// * **It reads only the public document.** Discovery is `users/{uid}`, which the
///   profile layer keeps free of phone, address, date of birth and gender — those are
///   in `users/{uid}/private/profile`, which `firestore.rules` opens to the owner
///   alone. A directory search therefore cannot reach a phone number, and this class
///   never asks for one.
/// * **The rules answer it unchanged.** `firestore.rules` grants
///   `allow read: if request.auth != null` on `/users/{userId}` with no field
///   condition, so a signed-in list read over the public profiles is permitted and
///   nothing here needs a Rules change to work. The Stage 9.4 change is on the
///   *other* collection: `donors`, which holds a phone, is closed back to owner-only.
///
/// **What it cannot prove.** That the deployed project's `users` documents match the
/// shapes above. Nothing in this stage has read a live collection under the approved
/// rules — the working-tree ruleset is held undeployed pending the owner's Stage 9.4
/// sign-off — so the field spellings come from `ProfileDocuments.publicFields`, the
/// only writer of this document, and the mapper refuses rather than assumes whatever
/// arrives that disagrees.
class FirestoreDonorDocuments implements DonorDocuments {
  FirestoreDonorDocuments(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  // Field names, named here so the query and `ProfileDocuments.publicFields` and
  // `firestore.rules` cannot drift apart on an inlined string.
  static const String roleField = 'role';
  static const String availabilityField = 'isAvailable';
  static const String bloodGroupField = 'bloodGroup';
  static const String areaField = 'area';

  /// The Stage 9.5 consent key. Present-and-true means the donor has opted into
  /// the directory; absent or false means they have not. Querying equality on
  /// `true` (rather than writing an explicit `false` for opted-out donors) keeps
  /// legacy documents — which have no such key at all — out of the results
  /// without a data migration.
  static const String discoveryField = 'allowDonorDiscovery';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(DonorProfileDocument.collection);

  @override
  Future<Result<List<DonorDocument>>> fetch({
    required DonorQuery query,
    required int limit,
  }) async {
    // A zero or negative limit is not a database question: `limit(0)` would still
    // cost a round trip and could not be honoured.
    if (limit <= 0) {
      return const Success<List<DonorDocument>>(<DonorDocument>[]);
    }

    try {
      // Checked explicitly so a missing session is reported as an auth problem
      // rather than as the `permission-denied` the rules would eventually send.
      if (_auth.currentUser == null) {
        throw const AuthFailure(
          debugMessage: 'A donor search requires a signed-in user',
        );
      }

      final DonorQuery normalised = query.normalised();
      Query<Map<String, dynamic>> built = _users.where(
        roleField,
        isEqualTo: DonorProfileDocument.donorRole,
      );
      // Consent is always on, for every query — it is not a refinement the
      // caller can turn off. Filtering here (not in the mapper and not after
      // the read) is what keeps opted-out documents off the wire.
      built = built.where(discoveryField, isEqualTo: true);
      if (normalised.availableOnly) {
        built = built.where(availabilityField, isEqualTo: true);
      }
      if (normalised.bloodGroup != null) {
        built = built.where(bloodGroupField, isEqualTo: normalised.bloodGroup);
      }
      if (normalised.area != null) {
        built = built.where(areaField, isEqualTo: normalised.area);
      }

      final QuerySnapshot<Map<String, dynamic>> snapshot = await built
          .limit(limit)
          .get();

      return Success<List<DonorDocument>>(<DonorDocument>[
        for (final QueryDocumentSnapshot<Map<String, dynamic>> document
            in snapshot.docs)
          DonorDocument(id: document.id, fields: document.data()),
      ]);
    } on FirebaseException catch (error, stackTrace) {
      return FailureResult<List<DonorDocument>>(
        mapFirestoreCodeToFailure(
          error.code,
          debugMessage: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<List<DonorDocument>>(
        mapExceptionToFailure(error, stackTrace),
      );
    }
  }
}
