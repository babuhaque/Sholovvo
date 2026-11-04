import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The sentence for a donor search that failed.
///
/// Its own vocabulary, separate from `requestsFailureMessage` and
/// `feedFailureMessage`, and exhaustive on the sealed base so a new failure type
/// fails to compile here rather than rendering a blank banner. A refused read is the
/// rules' decision, not the searcher's mistake — the permission branch says so.
String donorFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    AuthFailure() => l10n.failureUnknownAuth,
    NetworkFailure() => l10n.failureNetwork,
    RateLimitedFailure() => l10n.failureRateLimited,
    PermissionFailure() => l10n.failurePermission,
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure() => l10n.failureConflict,
    ValidationFailure() => l10n.failureValidation,
    ConfigurationFailure() => l10n.failureUnexpected,
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}

/// The availability line on a donor card.
///
/// "Available" and "Not available" rather than a bare tick: a directory row that
/// shows only green for the present ones leaves a reader who *does* want the
/// unavailable set (the widened search) with no way to tell what they are looking at.
String donorAvailabilityLabel(AppLocalizations l10n, bool isAvailable) {
  return isAvailable ? l10n.donorAvailable : l10n.donorUnavailable;
}

/// The blood-group line, or an explicit "not set" when the donor has none.
///
/// Never a silent blank. A donor mid-onboarding has a real profile with no group
/// yet, and a row that simply omits the badge reads as a broken one.
String donorGroupLabel(AppLocalizations l10n, String? bloodGroup) {
  if (bloodGroup == null || bloodGroup.isEmpty) {
    return l10n.donorGroupNotSet;
  }
  return bloodGroup;
}
