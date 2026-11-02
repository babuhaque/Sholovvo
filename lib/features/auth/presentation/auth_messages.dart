import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/auth/domain/auth_validators.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Turns a broken field rule into a sentence in the active language.
///
/// Declared on `AuthFieldIssue?` so a form can pass the validator's result
/// straight through: a `null` issue yields a `null` message, which is exactly
/// the contract `TextFormField.validator` expects.
extension AuthFieldIssueMessage on AuthFieldIssue? {
  String? message(AppLocalizations l10n) => switch (this) {
    null => null,
    AuthFieldIssue.emailRequired => l10n.errorEmailRequired,
    AuthFieldIssue.emailTooLong => l10n.errorEmailTooLong,
    AuthFieldIssue.emailInvalid => l10n.errorEmailInvalid,
    AuthFieldIssue.passwordRequired => l10n.errorPasswordRequired,
    AuthFieldIssue.passwordChoose => l10n.errorPasswordChoose,
    // The limits live in the validators, so the sentence quotes the rule
    // instead of repeating the number in two catalogues.
    AuthFieldIssue.passwordTooShort => l10n.errorPasswordTooShort(
      AuthValidators.minPasswordLength,
    ),
    AuthFieldIssue.passwordComposition => l10n.errorPasswordComposition,
    AuthFieldIssue.confirmRequired => l10n.errorConfirmRequired,
    AuthFieldIssue.confirmMismatch => l10n.errorConfirmMismatch,
    AuthFieldIssue.nameRequired => l10n.errorNameRequired,
    AuthFieldIssue.nameTooShort => l10n.errorNameTooShort,
    AuthFieldIssue.nameTooLong => l10n.errorNameTooLong(
      AuthValidators.maxDisplayNameLength,
    ),
  };
}

/// User-facing sentence for a rejected authentication attempt.
///
/// Lives in presentation, not in [Failure]: the domain carries reasons and this
/// file owns the wording, so neither has to know about the other's vocabulary.
String authFailureMessage(AppLocalizations l10n, Failure failure) {
  if (failure is AuthFailure) {
    return switch (failure.reason) {
      // One sentence for a wrong password and for an unknown address. Telling
      // them apart turns the sign-in form into an account enumeration oracle.
      AuthFailureReason.invalidCredentials => l10n.failureInvalidCredentials,
      AuthFailureReason.userDisabled => l10n.failureUserDisabled,
      AuthFailureReason.emailAlreadyInUse => l10n.failureEmailAlreadyInUse,
      AuthFailureReason.weakPassword => l10n.failureWeakPassword,
      AuthFailureReason.emailNotVerified => l10n.failureEmailNotVerified,
      AuthFailureReason.requiresRecentLogin => l10n.failureRequiresRecentLogin,
      AuthFailureReason.operationNotAllowed => l10n.failureOperationNotAllowed,
      AuthFailureReason.unknown => l10n.failureUnknownAuth,
    };
  }

  // Exhaustive on the sealed base so a new failure type is a compile error
  // here rather than a blank banner at runtime.
  return switch (failure) {
    AuthFailure() => l10n.failureUnknownAuth,
    NetworkFailure() => l10n.failureNetwork,
    RateLimitedFailure() => l10n.failureRateLimited,
    PermissionFailure() => l10n.failurePermission,
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure() => l10n.failureConflict,
    ValidationFailure() => l10n.failureValidation,
    // Nothing in the auth flow needs build-time configuration, so this can only
    // arrive if a caller wired a profile failure into an auth banner. Reported
    // as an unexpected error rather than inventing a sentence for it.
    ConfigurationFailure() => l10n.failureUnexpected,
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}
