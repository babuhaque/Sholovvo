import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/domain/entities/request_contact.dart';

/// Reads and writes the owner's private contact record for a blood request.
abstract interface class RequestContactService {
  /// Reads `blood_requests/{requestId}/private/contact` back for the owner.
  /// Returns [Success] with a `null` contact when the document does not exist
  /// yet — the first-capture case, which is not a failure. Fails with a typed
  /// [Failure] when the read is refused or the network is down.
  ///
  /// **Owner-only, and the app's first contact read.** `firestore.rules`
  /// L234-236 grants `read` to the parent document's `userId` and nobody else,
  /// so a stranger or a donor reaches a `permission-denied` here — mapped to a
  /// [PermissionFailure], never a value. This is deliberately the one place the
  /// app reads a contact document, and it is gated to the caller who wrote it.
  Future<Result<RequestContact?>> loadContact({
    required String requestId,
  });
  /// Writes the three PII keys onto
  /// `blood_requests/{requestId}/private/contact`. Fails with a
  /// [ValidationFailure] when a client-side guard rejects the input before a
  /// network call; maps Firestore exceptions to typed [Failure]s on write.
  ///
  /// Ownership is enforced at the rules layer: `firestore.rules` L219-228
  /// requires the parent `blood_requests/{requestId}` document's `userId` to
  /// equal `request.auth.uid`, and gates the write on exactly this three-key
  /// shape. Only the owner ever reaches this call — the affordance lives on the
  /// detail screen's owner branch — but the rules are authoritative, so a
  /// stranger that somehow calls this gets a `permission-denied` mapped to a
  /// [PermissionFailure] here rather than a silent write.
  ///
  /// **Why [hospitalAddress] may be empty but is always written.** The rule
  /// requires all three keys (`hasAll`) and no others (`hasOnly`), yet constrains
  /// only `patientName` and `phoneNumber` to be non-empty. An empty
  /// [hospitalAddress] is therefore a valid stored value, and the key must still
  /// be present for the write to pass `hasAll`.
  Future<Result<void>> saveContact({
    required String requestId,
    required String patientName,
    required String phoneNumber,
    required String hospitalAddress,
  });
}

/// Firestore-backed implementation.
///
/// [saveContact] uses `Set` (replace) semantics on the fixed document id
/// `contact`, so the stored shape is always exactly the three keys the rule's
/// `hasOnly` clause demands — the same write whether this is a first capture or a
/// re-capture, and with no leftover field a partial merge could strand on the
/// document. The rules accept `create` and `update` under one identical clause
/// (L219-228), so a single `set` covers both.
///
/// [loadContact] reads that same document back, but only ever for the owner — the
/// rules refuse anyone else, so the app reading a contact here is not a privacy
/// widening; it is the owner round-tripping what they saved. The M3-C2 blocker
/// still keeps a *donor* read closed, so no matched donor obtains this value.
final class FirestoreRequestContactService implements RequestContactService {
  const FirestoreRequestContactService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('requests.contact');
  static const String _collection = 'blood_requests';

  /// The fixed subcollection document id the rules require (`contactDoc ==
  /// 'contact'`, `firestore.rules` L220). Any other id is refused by the rules;
  /// this is not caller-supplied so the client can never drift from it.
  static const String _privateCollection = 'private';
  static const String _contactDocId = 'contact';

  @override
  Future<Result<RequestContact?>> loadContact({
    required String requestId,
  }) async {
    if (requestId.trim().isEmpty) {
      return const FailureResult<RequestContact?>(
        ValidationFailure(messageKey: 'requestIdRequired'),
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection(_privateCollection)
          .doc(_contactDocId)
          .get();

      // Absent is the first-capture case, not an error: the owner simply has not
      // saved a contact yet, and the form opens blank so they can add one.
      if (!snapshot.exists) {
        return const Success<RequestContact?>(null);
      }
      final Map<String, dynamic>? data = snapshot.data();
      if (data == null) {
        return const Success<RequestContact?>(null);
      }

      // Coerce, never throw: a legacy or hand-written document could hold a
      // non-string or omit a key, and the owner must still be able to open the
      // form and correct it rather than be locked out by their own bad data.
      return Success<RequestContact?>(
        RequestContact(
          patientName: data['patientName'] is String
              ? data['patientName']! as String
              : '',
          phoneNumber: data['phoneNumber'] is String
              ? data['phoneNumber']! as String
              : '',
          hospitalAddress: data['hospitalAddress'] is String
              ? data['hospitalAddress']! as String
              : '',
        ),
      );
    } on FirebaseException catch (e) {
      _logger.warning('Request contact load failed', error: e);
      return FailureResult<RequestContact?>(_mapException(e));
    }
  }

  @override
  Future<Result<void>> saveContact({
    required String requestId,
    required String patientName,
    required String phoneNumber,
    required String hospitalAddress,
  }) async {
    // --- Validation (client-side, mirrors the create/update rule) ---
    if (requestId.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'requestIdRequired'),
      );
    }
    // Named by key only, never by value: a debug message that echoed a whole
    // map would put a patient's name and phone number into a log — the exact
    // leak the private subcollection exists to prevent.
    if (patientName.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'patientNameRequired'),
      );
    }
    if (phoneNumber.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'phoneNumberRequired'),
      );
    }

    // --- Write (replace, exactly the three keys the rule allows) ---
    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .collection(_privateCollection)
          .doc(_contactDocId)
          .set(<String, Object?>{
            'patientName': patientName.trim(),
            'phoneNumber': phoneNumber.trim(),
            'hospitalAddress': hospitalAddress.trim(),
          });
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      _logger.warning('Request contact save failed', error: e);
      return FailureResult<void>(_mapException(e));
    }
  }

  Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: 'Request contact permission denied',
        cause: e,
      ),
      'not-found' => ValidationFailure(
        messageKey: 'requestNotFound',
        debugMessage: 'Contact parent doc missing: ${e.message}',
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: 'Request contact network error',
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: 'Request contact: unexpected [${e.code}] ${e.message}',
        cause: e,
      ),
    };
  }
}
