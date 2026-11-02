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

/// A blood request as the dashboard row shows it.
///
/// A view model, not a Firestore document: only the fields this row renders are
/// here. Stage 9 (search) and Stage 10 (requests) map `blood_requests` into it.
@immutable
class NearbyRequestSummary {
  const NearbyRequestSummary({
    required this.id,
    required this.bloodGroup,
    required this.area,
    required this.neededBy,
    required this.units,
  });

  final String id;
  final String bloodGroup;

  /// Human-readable place ("Dhanmondi, Dhaka"). Deliberately not coordinates:
  /// the dashboard row does not show a map or a distance it cannot compute.
  final String area;

  final DateTime neededBy;
  final int units;
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
