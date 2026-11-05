import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Edits an existing `blood_requests` document while it is still open.
abstract interface class RequestEditService {
  /// Writes the caller-supplied fields onto `blood_requests/{requestId}`. Fails
  /// with a [ValidationFailure] when the id is empty or the field map is empty
  /// or violates a shape the create rule requires; maps Firestore exceptions to
  /// typed [Failure]s on write.
  ///
  /// Ownership and the still-open precondition are enforced at the rules layer
  /// (`resource.data.userId == request.auth.uid` and
  /// `resource.data.status == 'open' && request.resource.data.status == 'open'`).
  /// The affected-keys set is checked the same way: this service may only touch
  /// the eight keys `firestore.rules` L127-131 lists, and the caller in
  /// [EditRequestScreen] only ever passes four of those.
  Future<Result<void>> editRequest({
    required String requestId,
    required Map<String, Object?> fields,
  });
}

/// Firestore-backed implementation.
///
/// Uses `Update` semantics on the supplied map, so a partial edit merges into
/// the existing document rather than replacing it. The rules' `affectedKeys()
/// .hasOnly([...])` clause refuses any key outside the eight-field edit set —
/// including `userId` and `status` — so this service never attempts to write
/// them either.
final class FirestoreRequestEditService implements RequestEditService {
  const FirestoreRequestEditService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('requests.edit');
  static const String _collection = 'blood_requests';

  /// The eight fields `firestore.rules` L127-131 permits an owner edit to
  /// affect. Anything else the caller passes here is refused client-side
  /// before a round trip, so a bug in the form surfaces as a typed failure
  /// rather than as a `permission-denied` at the rules layer.
  static const Set<String> _allowedKeys = <String>{
    'bloodGroup',
    'bloodBags',
    'hospitalName',
    'requiredDateTime',
    'requestType',
    'notes',
    'latitude',
    'longitude',
  };

  static const Set<String> _validGroups = <String>{
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  };

  @override
  Future<Result<void>> editRequest({
    required String requestId,
    required Map<String, Object?> fields,
  }) async {
    if (requestId.trim().isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'requestIdRequired'),
      );
    }
    if (fields.isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'noFieldsSupplied'),
      );
    }
    for (final String key in fields.keys) {
      if (!_allowedKeys.contains(key)) {
        // Named only by key, never by value — the document also holds a
        // patient's phone number on the private subcollection, and a log or
        // debug message that echoes a whole map is a leak path this stage
        // does not need.
        return FailureResult<void>(
          ValidationFailure(
            messageKey: 'fieldNotAllowed',
            debugMessage: 'edit refused on key: $key',
          ),
        );
      }
    }
    final Object? group = fields['bloodGroup'];
    if (group != null && (group is! String || !_validGroups.contains(group))) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'invalidBloodGroup'),
      );
    }
    final Object? bags = fields['bloodBags'];
    if (bags != null && (bags is! int || bags < 1)) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'bloodBagsMin'),
      );
    }
    final Object? hospital = fields['hospitalName'];
    if (hospital != null && (hospital is! String || hospital.trim().isEmpty)) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'hospitalRequired'),
      );
    }

    try {
      await _firestore
          .collection(_collection)
          .doc(requestId)
          .update(fields);
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      _logger.warning('Request edit failed', error: e);
      return FailureResult<void>(_mapException(e));
    }
  }

  Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: 'Request edit permission denied',
        cause: e,
      ),
      'not-found' => ValidationFailure(
        messageKey: 'requestNotFound',
        debugMessage: 'Edit target doc missing: ${e.message}',
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: 'Request edit network error',
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: 'Request edit: unexpected [${e.code}] ${e.message}',
        cause: e,
      ),
    };
  }
}
