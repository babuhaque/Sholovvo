import 'package:sholovvo_app/core/error/failure.dart';

/// Translates a Firestore error code into a [Failure].
///
/// Takes the **code string**, not `FirebaseException`, for the same reason
/// `auth_error_mapper` does: the exception's constructor is not public in a way
/// a test can use, so accepting the exception would make this mapping only
/// testable against a live project. A code string is data, and data can be
/// enumerated in a unit test.
///
/// It lives in `core/error` rather than in one feature because two features
/// now read Firestore (profile since Stage 5, feed since Stage 8.2) and a second
/// copy of this switch is how `permission-denied` ends up meaning one thing on
/// the profile screen and something else in the feed. Nothing here imports
/// `cloud_firestore`: the mapping is over strings.
///
/// Anything unrecognised stays [UnexpectedFailure] with the original code kept
/// in `debugMessage`, so a new backend code is diagnosable from a log instead of
/// disappearing into "something went wrong".
Failure mapFirestoreCodeToFailure(
  String code, {
  String? debugMessage,
  Object? cause,
  StackTrace? stackTrace,
}) {
  return switch (code) {
    // Signed in, but the rules refused the read or the write. In this app that
    // almost always means the payload names a document the caller does not own.
    'permission-denied' => PermissionFailure(
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    // No session, or the token expired mid-flight.
    'unauthenticated' => const AuthFailure(
      debugMessage: 'Firestore call without a session',
    ),
    'unavailable' || 'deadline-exceeded' => NetworkFailure(
      code: code == 'deadline-exceeded'
          ? FailureCode.timeout
          : FailureCode.network,
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    'resource-exhausted' => RateLimitedFailure(
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    'not-found' => NotFoundFailure(
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    // Two writers touched the same document; the caller should re-read.
    'aborted' || 'already-exists' => ConflictFailure(
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    // The document the client built violates a rule or a type constraint.
    'invalid-argument' || 'failed-precondition' => ValidationFailure(
      messageKey: 'failureValidation',
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    'cancelled' => UnexpectedFailure(
      code: FailureCode.cancelled,
      debugMessage: debugMessage ?? code,
      cause: cause,
      stackTrace: stackTrace,
    ),
    _ => UnexpectedFailure(
      debugMessage: '$code${debugMessage == null ? '' : ': $debugMessage'}',
      cause: cause,
      stackTrace: stackTrace,
    ),
  };
}
