import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Accepts (claims) an open blood request as a donor.
abstract interface class RequestAcceptService {
  /// Moves a `blood_requests/{requestId}` document from `open` to `accepted`,
  /// stamping the caller as the assigned donor.
  ///
  /// The rules at `firestore.rules` L147-160 enforce eligibility: the caller's
  /// `users/{uid}` document must carry `role == 'donor'`, `isAvailable == true`,
  /// and a `bloodGroup` that matches the request. Ownership is also checked:
  /// the caller must NOT be the request owner. The client gates the affordance
  /// on the same fields (via `profileProvider`), but rules are authoritative —
  /// a race where another donor claims first still fails here, and the caller
  /// sees the error rather than silently overwriting the other donor's claim.
  Future<Result<void>> acceptRequest({
    required String requestId,
    required String donorUid,
  });
}

/// Firestore-backed implementation.
///
/// Writes exactly the three keys the accept rule allows: `status`,
/// `assignedDonorId`, and `acceptedAt`. Anything else on the document stays
/// untouched.
final class FirestoreRequestAcceptService implements RequestAcceptService {
  const FirestoreRequestAcceptService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('requests.accept');
  static const String _collection = 'blood_requests';

  @override
  Future<Result<void>> acceptRequest({
    required String requestId,
    required String donorUid,
  }) async {
    if (requestId.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'requestIdRequired'),
      );
    }
    if (donorUid.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'donorUidRequired'),
      );
    }

    try {
      await _firestore.collection(_collection).doc(requestId).update(
        <String, Object?>{
          'status': 'accepted',
          'assignedDonorId': donorUid,
          'acceptedAt': FieldValue.serverTimestamp(),
        },
      );
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      _logger.warning('Request accept failed', error: e);
      return FailureResult<void>(_mapException(e));
    }
  }

  Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: 'Request accept permission denied',
        cause: e,
      ),
      'not-found' => ValidationFailure(
        messageKey: 'requestNotFound',
        debugMessage: 'Accept target doc missing: ${e.message}',
      ),
      'aborted' => ValidationFailure(
        messageKey: 'alreadyAccepted',
        debugMessage:
            'Request already transitioned: ${e.message}',
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: 'Request accept network error',
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: 'Request accept: unexpected [${e.code}] ${e.message}',
        cause: e,
      ),
    };
  }
}
