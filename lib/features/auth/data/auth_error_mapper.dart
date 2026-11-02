import 'package:sholovvo_app/core/error/failure.dart';

/// Translates a Firebase Auth error code into a [Failure].
///
/// Takes the **code string**, not the exception, on purpose: `FirebaseAuthException`
/// has a protected constructor, so a mapper that accepted the exception itself
/// could not be unit-tested. The repository calls `mapAuthErrorCode(error.code)`.
///
/// The full list of codes is at https://firebase.google.com/docs/auth/admin/errors.
/// Anything unrecognised stays an unexpected failure rather than being guessed
/// at, so a new SDK code surfaces as a bug report instead of a wrong message.
Failure mapAuthErrorCode(
  String code, {
  String? debugMessage,
  Object? cause,
  StackTrace? stackTrace,
}) {
  switch (code) {
    // The project shows one message for both: revealing that an address is
    // registered turns sign-in into an account-enumeration oracle.
    case 'wrong-password':
    case 'user-not-found':
    case 'invalid-credential':
    case 'invalid-login-credentials':
    case 'invalid-email':
      return AuthFailure(
        reason: AuthFailureReason.invalidCredentials,
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'user-disabled':
      return AuthFailure(
        reason: AuthFailureReason.userDisabled,
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'email-already-in-use':
      return AuthFailure(
        reason: AuthFailureReason.emailAlreadyInUse,
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'weak-password':
      return AuthFailure(
        reason: AuthFailureReason.weakPassword,
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'requires-recent-login':
      return AuthFailure(
        reason: AuthFailureReason.requiresRecentLogin,
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'operation-not-allowed':
      return AuthFailure(
        reason: AuthFailureReason.operationNotAllowed,
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'too-many-requests':
      return RateLimitedFailure(
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'network-request-failed':
      return NetworkFailure(
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    case 'user-token-expired':
    case 'user-token-revoked':
      return AuthFailure(
        debugMessage: debugMessage ?? code,
        cause: cause,
        stackTrace: stackTrace,
      );

    default:
      return UnexpectedFailure(
        debugMessage: 'Unmapped auth error "$code": $debugMessage',
        cause: cause,
        stackTrace: stackTrace,
      );
  }
}
