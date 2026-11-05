import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Creates a new `blood_requests` document.
abstract interface class RequestCreateService {
  /// Publishes an open blood request. Fails with a [ValidationFailure] when a
  /// client-side guard rejects the input before a network call; maps Firestore
  /// exceptions to typed [Failure]s on write.
  Future<Result<String>> createRequest({
    required String uid,
    required String bloodGroup,
    required int bloodBags,
    required String hospitalName,
    required Timestamp requiredDateTime,
    String? requestType,
    String? notes,
    double? latitude,
    double? longitude,
  });
}

/// Firestore-backed implementation.
///
/// Writes only the public `blood_requests` document. The private PII subcollection
/// (`private/contact`) is a separate write the owner may add later; the rules allow
/// creating it independently, and this service does not attempt it.
final class FirestoreRequestCreateService implements RequestCreateService {
  const FirestoreRequestCreateService(this._firestore);

  final FirebaseFirestore _firestore;

  static const AppLogger _logger = AppLogger('requests.create');
  static const String _collection = 'blood_requests';

  static const Set<String> _validGroups = <String>{
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  };

  @override
  Future<Result<String>> createRequest({
    required String uid,
    required String bloodGroup,
    required int bloodBags,
    required String hospitalName,
    required Timestamp requiredDateTime,
    String? requestType,
    String? notes,
    double? latitude,
    double? longitude,
  }) async {
    // --- Validation (client-side, mirrors rules) ---
    if (uid.isEmpty) {
      return const FailureResult<String>(
        ValidationFailure(messageKey: 'uidRequired'),
      );
    }
    if (!_validGroups.contains(bloodGroup)) {
      return const FailureResult<String>(
        ValidationFailure(messageKey: 'invalidBloodGroup'),
      );
    }
    if (bloodBags < 1) {
      return const FailureResult<String>(
        ValidationFailure(messageKey: 'bloodBagsMin'),
      );
    }
    final String trimmedHospital = hospitalName.trim();
    if (trimmedHospital.isEmpty) {
      return const FailureResult<String>(
        ValidationFailure(messageKey: 'hospitalRequired'),
      );
    }

    // --- Build the document ---
    final Map<String, Object?> data = <String, Object?>{
      'userId': uid,
      'bloodGroup': bloodGroup,
      'bloodBags': bloodBags,
      'hospitalName': trimmedHospital,
      'requiredDateTime': requiredDateTime,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    };
    final String? trimmedType = requestType?.trim();
    if (trimmedType != null && trimmedType.isNotEmpty) {
      data['requestType'] = trimmedType;
    }
    final String? trimmedNotes = notes?.trim();
    if (trimmedNotes != null && trimmedNotes.isNotEmpty) {
      data['notes'] = trimmedNotes;
    }
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;

    // --- Write ---
    try {
      final DocumentReference<Map<String, dynamic>> doc =
          await _firestore.collection(_collection).add(data);
      return Success<String>(doc.id);
    } on FirebaseException catch (e) {
      _logger.warning('Request create failed', error: e);
      return FailureResult<String>(_mapException(e));
    }
  }

  Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: 'Request create permission denied',
        cause: e,
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: 'Request create network error',
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: 'Request create: unexpected [${e.code}] ${e.message}',
        cause: e,
      ),
    };
  }
}
