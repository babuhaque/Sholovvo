import 'package:flutter/foundation.dart';

/// What the dashboard is allowed to claim about the signed-in donor.
///
/// Every field is nullable on purpose. A new account has no blood group, no
/// recorded donation and no stated availability, and the status strip says so
/// ("Not set yet") rather than printing a `0` or an invented group — a wrong
/// blood group on a donor dashboard is a medical-severity mistake, not a
/// cosmetic one.
///
/// Filled by Stage 5 (profile) and Stage 8 (donor management) from
/// `users/{uid}` and `donation_history`.
@immutable
class DonorSnapshot {
  const DonorSnapshot({
    this.bloodGroup,
    this.lastDonationAt,
    this.isAvailable,
    this.donationCount,
  });

  /// ABO/Rh group as recorded by the profile, e.g. `O+`.
  final String? bloodGroup;

  /// When the donor last gave blood, from the donation history.
  final DateTime? lastDonationAt;

  /// Whether the donor has opted in to being matched right now.
  final bool? isAvailable;

  /// Lifetime donation count, when the profile has one.
  final int? donationCount;
}

/// A community post as the dashboard preview shows it.
///
/// A view model, not a Firestore document. Stage 6 (feed) maps `posts` into it.
@immutable
class FeedPostPreview {
  const FeedPostPreview({
    required this.id,
    required this.authorName,
    required this.excerpt,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String excerpt;
  final DateTime createdAt;
}
