import 'package:flutter/material.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The sentence for a requests read that failed.
///
/// Separate from `feedFailureMessage` and `profileFailureMessage` so the feature
/// carries its own vocabulary. The switch is exhaustive on the sealed base, so a
/// new failure type fails to compile here rather than rendering a blank banner.
String requestsFailureMessage(AppLocalizations l10n, Failure failure) {
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

/// The "needed by" line, in whichever of its three forms the data allows.
///
/// A formatted month-and-day when the document carried a readable date; the text
/// the requester typed, verbatim, when the date was there but not in a form this
/// app will parse; and an explicit "no date given" when the document has neither.
/// The third form exists because a row that silently drops the date looks like a
/// request that does not need one, and the whole point of the list is urgency.
///
/// The two labels come from the `home*` keys rather than new `requests*` ones:
/// they were written for the dashboard row that shows the same field, and a
/// second pair of identical strings is how the two screens start to disagree
/// about what the same data says.
String requestsNeededByLabel(BuildContext context, BloodRequest request) {
  final AppLocalizations l10n = context.l10n;
  final DateTime? neededBy = request.neededBy;

  if (neededBy != null) {
    return l10n.homeNeededBy(
      MaterialLocalizations.of(context)
          .formatShortMonthDay(neededBy.toLocal()),
    );
  }
  if (request.neededByText.isNotEmpty) {
    return l10n.homeNeededBy(request.neededByText);
  }
  return l10n.homeNeededByUnknown;
}
