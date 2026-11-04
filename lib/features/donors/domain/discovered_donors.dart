import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

/// The donors one search returned, and how much of the directory it saw.
///
/// **A window, not a page** — the same shape [OpenRequests] uses, for the same
/// reason. There is no trusted field to order the `users` collection by at the
/// database level: ordering by display name would need a composite index
/// (equality on role plus a sort), and creating an index means deploying
/// configuration the owner has to approve. So the read is bounded by a limit and
/// re-run when a filter changes, and the sort happens on the decoded list — see
/// `orderDonors`. A cursor would be asking Firestore for "the next documents in
/// document-id order", which is a position nobody chose.
///
/// [truncated] and [skipped] therefore carry the honest half of the sentence.
/// Because the repository asks for one document more than it keeps, `truncated ==
/// false` means this is every consented donor matching the filters, and `true`
/// means it is not. [skipped] counts documents inside the window that the mapper
/// refused — a public profile whose blood group is a ninth spelling, or whose role
/// is not `donor`. A short list without that number is a list that claims the
/// directory is small when the app could not read what is there.
@immutable
final class DiscoveredDonors {
  /// Not `const`, for the reason `OpenRequests` is not: the list is wrapped in
  /// [List.unmodifiable] here, so the constructor body has work to do.
  DiscoveredDonors({
    required List<Donor> donors,
    this.truncated = false,
    this.skipped = 0,
  }) : donors = List<Donor>.unmodifiable(donors);

  /// Available first, then by name, in the order [orderDonors] decided.
  final List<Donor> donors;

  /// Whether the window filled and at least one more matching donor stayed behind
  /// it unread.
  final bool truncated;

  /// How many documents the read returned that could not be turned into a donor.
  final int skipped;

  bool get isEmpty => donors.isEmpty;

  @override
  String toString() =>
      'DiscoveredDonors(${donors.length} donors, truncated: $truncated, '
      'skipped: $skipped)';
}
