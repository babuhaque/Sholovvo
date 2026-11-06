import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/firestore_error_mapper.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/data/profile_documents.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/profile_repository.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// Firestore implementation of [ProfileRepository].
///
/// The document path is derived from `FirebaseAuth.currentUser` and never from a
/// parameter, so this class cannot be pointed at another account. [saveProfile]
/// additionally rejects a payload whose `uid` disagrees with the session: the
/// rules would reject that write anyway, but failing locally means the caller
/// gets [PermissionFailure] instead of an opaque `permission-denied`.
class FirestoreProfileRepository implements ProfileRepository {
  FirestoreProfileRepository(this._auth, this._firestore);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String usersCollection = 'users';
  static const String donationsCollection = 'donation_history';

  /// `donation_history` is addressed by a field filter, not by a subcollection:
  /// that is the shape `firestore.rules` validates (`resource.data.donorUid`),
  /// and the shape Stage 10 will add to.
  static const String donorUidField = 'donorUid';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(usersCollection);

  @override
  Stream<UserProfile?> watchProfile() async* {
    final String uid = _requireUid();
    final DocumentReference<Map<String, dynamic>> user = _users.doc(uid);

    // Public snapshot drives the stream, private document is read alongside it.
    // The private read is a second round trip on every change; that is the price
    // of the two-document split that keeps PII out of a world-readable document.
    await for (final DocumentSnapshot<Map<String, dynamic>> snapshot
        in user.snapshots()) {
      Map<String, dynamic>? privateData;
      if (snapshot.exists) {
        final DocumentSnapshot<Map<String, dynamic>> privateSnapshot =
            await _privateRef(user).get();
        privateData = privateSnapshot.data();
      }
      yield ProfileDocuments.fromDocuments(
        uid: uid,
        public: snapshot.data(),
        private: privateData,
      );
    }
  }

  @override
  Future<Result<void>> saveProfile(UserProfile profile) {
    return _run(() async {
      final String uid = _requireUid();
      if (profile.uid != uid) {
        throw const PermissionFailure(
          debugMessage:
              'Refusing to write a profile that names another account',
        );
      }

      final DocumentReference<Map<String, dynamic>> user = _users.doc(uid);
      // One batch, two documents: a profile half-saved into the private
      // subcollection would show a phone number next to a blank name, which is
      // exactly the partial state a merge write can otherwise leave behind.
      final WriteBatch batch = _firestore.batch();
      batch.set(
        user,
        ProfileDocuments.publicFields(profile),
        SetOptions(merge: true),
      );
      batch.set(
        _privateRef(user),
        ProfileDocuments.privateFields(profile),
        SetOptions(merge: true),
      );
      await batch.commit();
    });
  }

  @override
  Future<Result<void>> setAvailability(bool isAvailable) {
    return _run(() async {
      final String uid = _requireUid();
      await _users
          .doc(uid)
          .set(
            ProfileDocuments.availabilityFields(isAvailable),
            SetOptions(merge: true),
          );
    });
  }

  @override
  Future<Result<void>> setPhotoUrl(String? photoUrl) {
    return _run(() async {
      final String uid = _requireUid();
      await _users
          .doc(uid)
          .set(ProfileDocuments.photoFields(photoUrl), SetOptions(merge: true));
    });
  }

  @override
  Future<Result<void>> setCoverUrl(String? coverUrl) {
    return _run(() async {
      final String uid = _requireUid();
      await _users
          .doc(uid)
          .set(ProfileDocuments.coverFields(coverUrl), SetOptions(merge: true));
    });
  }

  @override
  Future<Result<DonationHistory>> loadDonationHistory() async {
    try {
      final String uid = _requireUid();
      // Equality on `donorUid` alone. Adding `orderBy(createdAt)` would need a
      // composite index, and creating one means deploying configuration — out of
      // scope for this stage — so the sort happens in ProfileDocuments.
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(donationsCollection)
          .where(donorUidField, isEqualTo: uid)
          .get();

      final List<DonationRecord> records = snapshot.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
                ProfileDocuments.donationRecord(doc.id, doc.data()),
          )
          .toList();

      return Success<DonationHistory>(
        DonationHistory(ProfileDocuments.sortNewestFirst(records)),
      );
    } on FirebaseException catch (error, stackTrace) {
      return FailureResult<DonationHistory>(
        mapFirestoreCodeToFailure(
          error.code,
          debugMessage: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<DonationHistory>(
        mapExceptionToFailure(error, stackTrace),
      );
    }
  }

  /// Runs a write and turns any thrown object into a [Failure].
  ///
  /// [Result.guard] is not used because it funnels everything through
  /// [mapExceptionToFailure], which cannot see a Firestore error code and would
  /// report `permission-denied` as an unknown error.
  Future<Result<void>> _run(Future<void> Function() operation) async {
    try {
      await operation();
      return const Success<void>(null);
    } on FirebaseException catch (error, stackTrace) {
      return FailureResult<void>(
        mapFirestoreCodeToFailure(
          error.code,
          debugMessage: error.message,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<void>(mapExceptionToFailure(error, stackTrace));
    }
  }

  DocumentReference<Map<String, dynamic>> _privateRef(
    DocumentReference<Map<String, dynamic>> user,
  ) {
    return user
        .collection(ProfileDocuments.privateCollection)
        .doc(ProfileDocuments.privateDocument);
  }

  /// The signed-in uid, or an [AuthFailure].
  ///
  /// Thrown rather than defaulted: a profile screen reached without a session is
  /// a bug in the gate, and writing to a guessed document id would be far worse
  /// than an error.
  String _requireUid() {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const AuthFailure(
        debugMessage: 'A profile read or write requires a signed-in user',
      );
    }
    return uid;
  }
}
