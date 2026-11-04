import 'package:flutter/foundation.dart';

/// One discoverable donor, as this app reads them.
///
/// **What is deliberately not here, and why it is the whole point.** A donor's
/// phone number, street address, date of birth and gender are *not* fields of
/// this model, and they are not fields of the document this model is built from
/// either. Donor discovery reads the public `users/{uid}` profile, which the
/// profile layer populates with only the discovery-safe fields — display name,
/// role, blood group, availability, photo URL, and the coarse area *only* when
/// the donor has switched publication on. The private PII lives in
/// `users/{uid}/private/profile`, which `firestore.rules` opens to the owner
/// alone, so a search row cannot carry a phone number even if a later screen
/// wanted one. That is the privacy model Stage 9.4 requires: a directory that
/// exposes who can give blood must not also expose how to telephone them.
///
/// This mirrors [BloodRequest] leaving the patient's name and phone number out of
/// the read model: the screen has no use for a donor's phone to decide whether
/// they are a match, and a list that could show it is a list that will one day
/// show it. The absence is decided here, at the read model, because the rule
/// cannot decide it — the rule only says a signed-in user may read the public
/// document, and the public document simply holds no phone to read.
///
/// **Two of these fields are optional because the document is.** [area] exists
/// only when the donor published it, and [photoUrl] only once they have uploaded
/// a photo. A null is shown as "not given", never invented: a wrong area on a
/// donor row sends someone to the wrong part of the city, and a wrong blood group
/// is a medical-severity mistake rather than a cosmetic one.
@immutable
final class Donor {
  const Donor({
    required this.uid,
    required this.displayName,
    required this.bloodGroup,
    required this.isAvailable,
    this.area,
    this.photoUrl,
  });

  /// The `users/{uid}` document id, which is the donor's Firebase uid. The key the
  /// list deduplicates on and the address a later "respond" flow would carry.
  final String uid;

  /// The name the donor publishes. May be empty when the document never carried
  /// one; the card then falls back to an initials avatar rather than a blank.
  final String displayName;

  /// One of the eight groups the rules accept, or `null` when the donor has not
  /// set one. A ninth spelling is refused by the mapper rather than reaching here
  /// — a group shown next to a donor's own that the backend would reject is worse
  /// than no group.
  final String? bloodGroup;

  /// The donor's own availability switch, read straight from the public document.
  /// Discovery never flips it; only the donor's profile screen does.
  final bool isAvailable;

  /// The coarse area ("Dhanmondi, Dhaka"), present only when the donor published
  /// it. `null` means "this donor has chosen not to share a location", which the
  /// card shows as nothing rather than as a district it does not know.
  final String? area;

  /// Absolute URL of the published profile photo, or `null`.
  final String? photoUrl;

  bool get hasArea => area != null && area!.isNotEmpty;

  bool get hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  /// Whether there is any blood group to badge. The "all groups" search surfaces
  /// donors mid-onboarding, so a missing group is a real state, not an error.
  bool get hasBloodGroup => bloodGroup != null && bloodGroup!.isNotEmpty;

  /// Names the person and the group, never the location. `area` is a person's
  /// neighbourhood and `toString` lands in logs and test output, so the row
  /// identifies itself without putting anybody's whereabouts into a log line.
  @override
  String toString() =>
      'Donor($uid, ${bloodGroup ?? 'no group'}, '
      'available: $isAvailable)';
}
