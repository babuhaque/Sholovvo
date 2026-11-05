import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Cancels (withdraws) an open blood request.
abstract interface class RequestCancelService {
  /// Moves a `blood_requests/{requestId}` document from `open` or `accepted` to
  /// `cancelled`. Fails with a [ValidationFailure] when inputs are empty; maps
  /// Firestore exceptions to typed [Failure]s on write.
  ///
  /// Ownership is enforced at the rules layer (`resource.data.userId ==
  /// request.auth.uid`); this service does not re-check it client-side because
  /// only Firestore can attest to the authenticated caller.
  Future<Result<void>> cancelRequest({
    required String requestId,
  });
}

/// Firestore-backed implementation.
///
/// Writes exactly the two keys the cancel rule allows: `status` and
/// `cancelledAt`. A `diff().affectedKeys().hasOnly(['status', 'cancelledAt'])`
/// in `firestore.rules` L132-136 refuses any broader document mutation, so this
/// service uses `Update` semantics (a map with two keys) rather than `Set` on the
/// whole document.
final class FirestoreRequestCancelService implements RequestCancelService {
  const FirestoreRequestCancelService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('requests.cancel');
  static const String _collection = 'blood_requests';

  @override
  Future<Result<void>> cancelRequest({
    required String requestId,
  }) async {
    if (requestId.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'requestIdRequired'),
      );
    }

    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .update(<String, Object?>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      _logger.warning('Request cancel failed', error: e);
      return FailureResult<void>(_mapException(e));
    }
  }

  Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: 'Request cancel permission denied',
        cause: e,
      ),
      'not-found' => ValidationFailure(
        messageKey: 'requestNotFound',
        debugMessage: 'Cancel target doc missing: ${e.message}',
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: 'Request cancel network error',
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: 'Request cancel: unexpected [${e.code}] ${e.message}',
        cause: e,
      ),
    };
  }
}
