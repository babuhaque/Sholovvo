import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// How old a post may be before the feed stops counting and names a date.
///
/// Seven days: "6 days ago" is still a rough position in the week, "23 days
/// ago" is arithmetic the reader has to do. Exposed so the test that pins the
/// boundary reads the same number the code uses.
const int feedCalendarAfterDays = 7;

/// The sentence for a feed read that failed.
///
/// Separate from `profileFailureMessage` and `authFailureMessage` so the feed
/// carries its own vocabulary. The switch is exhaustive on the sealed base, so a
/// new failure type fails to compile here rather than rendering a blank banner.
String feedFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    AuthFailure() => l10n.failureUnknownAuth,
    NetworkFailure() => l10n.failureNetwork,
    RateLimitedFailure() => l10n.failureRateLimited,
    // A refused list read is the rules' decision, not the donor's mistake.
    PermissionFailure() => l10n.failurePermission,
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure() => l10n.failureConflict,
    ValidationFailure() => l10n.failureValidation,
    ConfigurationFailure() => l10n.failureUnexpected,
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}

/// A post's age, in the coarsest unit that is still honest.
///
/// [olderDate] is the calendar date the caller has already formatted for the
/// active language. Passing it in rather than formatting here keeps this
/// function free of `MaterialLocalizations` — and therefore callable from a test
/// without a widget tree, which is the only way the boundaries below get
/// asserted rather than eyeballed.
///
/// A timestamp in the future reads as "just now". That is what a device clock
/// that disagrees with the server produces, and a feed that says "in 4 minutes"
/// looks broken even though the arithmetic is right.
String feedRelativeTime(
  AppLocalizations l10n,
  DateTime timestamp, {
  required String olderDate,
  DateTime? now,
}) {
  final Duration age = (now ?? DateTime.now()).difference(timestamp);

  if (age.inMinutes < 1) {
    return l10n.feedJustNow;
  }
  if (age.inHours < 1) {
    return l10n.feedMinutesAgo(age.inMinutes);
  }
  if (age.inDays < 1) {
    return l10n.feedHoursAgo(age.inHours);
  }
  if (age.inDays < feedCalendarAfterDays) {
    return l10n.feedDaysAgo(age.inDays);
  }
  return l10n.feedOnDate(olderDate);
}
