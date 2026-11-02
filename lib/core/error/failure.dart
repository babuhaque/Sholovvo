import 'dart:async';

/// Machine-readable failure categories.
///
/// Presentation code translates a [FailureCode] into Bangla or English text
/// (Stage 3 localisation). No English prose is baked into failures, so a
/// Bangla UI can never leak an English error message.
enum FailureCode {
  network,
  timeout,
  unauthorised,
  permissionDenied,
  notFound,
  conflict,
  validation,
  rateLimited,
  unavailable,
  cancelled,
  unknown,
}

/// A recoverable error crossing a layer boundary.
///
/// Data layers translate SDK exceptions into a [Failure]; repository
/// interfaces return `Result<T>` rather than leaking Firebase, Supabase or
/// platform types into the domain and presentation layers.
sealed class Failure implements Exception {
  const Failure({
    required this.code,
    this.debugMessage,
    this.cause,
    this.stackTrace,
  });

  final FailureCode code;

  /// Developer-facing detail. Logged, never rendered to users.
  final String? debugMessage;

  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() =>
      '$runtimeType(code: $code, debugMessage: $debugMessage)';
}

/// Transport-level problem: offline, DNS, TLS, or the request never landed.
final class NetworkFailure extends Failure {
  const NetworkFailure({
    super.code = FailureCode.network,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// Why an authentication attempt was rejected.
///
/// Values only, never prose: the same reason needs different wording for a
/// sign-in form, a registration form and a password reset, and Stage 3 renders
/// each of them in the active language.
enum AuthFailureReason {
  /// Email/password pair rejected, or the account was never created.
  invalidCredentials,
  userDisabled,
  emailAlreadyInUse,
  weakPassword,
  emailNotVerified,
  requiresRecentLogin,
  /// The sign-in method is switched off in the Firebase console.
  operationNotAllowed,
  unknown,
}

/// The caller is not signed in, or their session expired.
final class AuthFailure extends Failure {
  const AuthFailure({
    this.reason = AuthFailureReason.unknown,
    super.code = FailureCode.unauthorised,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  final AuthFailureReason reason;

  @override
  String toString() =>
      'AuthFailure(code: $code, reason: $reason, '
      'debugMessage: $debugMessage)';
}

/// Signed in but not allowed to perform this action (ownership or role).
final class PermissionFailure extends Failure {
  const PermissionFailure({
    super.code = FailureCode.permissionDenied,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// User input rejected. [field] identifies the offending input, if any.
final class ValidationFailure extends Failure {
  const ValidationFailure({
    required this.messageKey,
    this.field,
    super.code = FailureCode.validation,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// Localisation key describing the rule that failed.
  final String messageKey;

  /// Form field identifier, for inline form errors.
  final String? field;
}

/// The requested document or resource does not exist.
final class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.code = FailureCode.notFound,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// State changed underneath the caller, e.g. another donor claimed a request.
final class ConflictFailure extends Failure {
  const ConflictFailure({
    super.code = FailureCode.conflict,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// Too many attempts. Enforced client-side for UX and server-side by rules.
final class RateLimitedFailure extends Failure {
  const RateLimitedFailure({
    super.code = FailureCode.rateLimited,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// The feature needs a build-time setting the app was not given.
///
/// Distinct from [UnexpectedFailure] because nothing is broken: the build simply
/// carries no configuration for this capability (Stage 6: Supabase Storage), and
/// the honest answer is "not set up", not "something went wrong".
final class ConfigurationFailure extends Failure {
  const ConfigurationFailure({
    required this.setting,
    super.code = FailureCode.unavailable,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });

  /// The missing or unusable setting, for logs. Never rendered to users.
  final String setting;
}

/// Anything not classified above.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure({
    super.code = FailureCode.unknown,
    super.debugMessage,
    super.cause,
    super.stackTrace,
  });
}

/// Normalises an arbitrary thrown object into a [Failure].
///
/// SDK-specific mapping (Firebase Auth error codes, Supabase storage errors)
/// is added in the stage that introduces each SDK, so this function stays
/// honest about what it can actually classify.
Failure mapExceptionToFailure(Object error, [StackTrace? stackTrace]) {
  if (error is Failure) {
    return error;
  }
  if (error is TimeoutException) {
    return NetworkFailure(
      code: FailureCode.timeout,
      debugMessage: error.message ?? 'Operation timed out',
      cause: error,
      stackTrace: stackTrace,
    );
  }
  return UnexpectedFailure(
    debugMessage: error.toString(),
    cause: error,
    stackTrace: stackTrace,
  );
}
