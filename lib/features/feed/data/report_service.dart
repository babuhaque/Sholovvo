import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/entities/report.dart';

/// Writes a report to the `reports` top-level collection.
///
/// The client cannot read reports (the rules deny it); this service is
/// write-only. The document is auto-id — the rules only check the payload, not
/// the id. `createdAt` uses `FieldValue.serverTimestamp()` so the rules'
/// `createdAt == request.time` check passes without a clock-skew risk.
abstract interface class ReportService {
  Future<Result<void>> submitReport({
    required String reporterUid,
    required ReportTarget target,
    required String targetId,
    required String targetAuthorUid,
    required ReportReason reason,
    String? note,
  });
}

/// Firestore-backed implementation.
///
/// A single `set` call; no transaction needed because nothing else is written
/// atomically alongside it. The `hasOnly`/`hasAll` shape is enforced here to
/// match `firestore.rules` exactly — a stray key would fail the write.
final class FirestoreReportService implements ReportService {
  const FirestoreReportService(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _collection = 'reports';

  @override
  Future<Result<void>> submitReport({
    required String reporterUid,
    required ReportTarget target,
    required String targetId,
    required String targetAuthorUid,
    required ReportReason reason,
    String? note,
  }) async {
    // Client-side validation mirrors the rules.
    final ReportIssue? issue = ReportValidator.validate(
      reporterUid: reporterUid,
      targetId: targetId,
      targetAuthorUid: targetAuthorUid,
      note: note,
    );
    if (issue != null) {
      return FailureResult<void>(
        ValidationFailure(messageKey: issue.name),
      );
    }

    final Map<String, Object?> data = <String, Object?>{
      'reporterUid': reporterUid,
      'target': target.wireName,
      'targetId': targetId,
      'targetAuthorUid': targetAuthorUid,
      'reason': reason.wireName,
      'createdAt': FieldValue.serverTimestamp(),
    };
    final String? trimmed = note?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      data['note'] = trimmed;
    }

    try {
      await _firestore.collection(_collection).doc().set(data);
      return const Success<void>(null);
    } on FirebaseException catch (e) {
      return FailureResult<void>(_mapException(e));
    }
  }

  static Failure _mapException(FirebaseException e) {
    return switch (e.code) {
      'permission-denied' => PermissionFailure(
        debugMessage: e.message,
        cause: e,
      ),
      'unavailable' || 'deadline-exceeded' => NetworkFailure(
        debugMessage: e.message,
        cause: e,
      ),
      _ => UnexpectedFailure(
        debugMessage: '${e.code}: ${e.message}',
        cause: e,
      ),
    };
  }
}
