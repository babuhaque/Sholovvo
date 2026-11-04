import 'package:flutter/foundation.dart';

/// One open blood request, as this app reads it.
///
/// **What is deliberately not here.** `patientName`, `phoneNumber` and
/// `hospitalAddress` are no longer fields of this document at all. As of Stage
/// 9.5 (M3, corrected in M3-C1) the Firestore security rules moved all three to
/// `blood_requests/{id}/private/contact`, where the owner and the single donor
/// whose immutable `response_claims` record actually landed are the only callers
/// who may read them; the public create/update rules refuse those keys. Before
/// M3 the same fields lived on the public document with `allow read: if
/// request.auth != null`, which made every patient's name, phone number and
/// street address a directory available to any signed-in account — a leak a read
/// model could mitigate by omission but not prevent. M3 closes the door at the
/// rules layer.
///
/// This entity remains the read model for the open-requests list, and a donor
/// deciding whether to help needs the group, the units, the hospital and the
/// date — never the patient's name, phone or the specific street line. A future
/// Stage-10 contact flow that legitimately needs them reads the private/contact
/// subcollection directly, gated by the rules, not through this entity.
///
/// `notes` is left out for the same reason in the other direction: it is free
/// text typed by whoever raised the request, and this stage has not decided what
/// it is allowed to contain or who is allowed to see it.
///
/// **Two fields for one date, and why.** [neededBy] is a real instant, and
/// [neededByText] is what the document actually says. `requiredDateTime` is not a
/// timestamp in this collection: `firestore.rules` requires the *key* on create
/// but constrains no type for it, and the seed documents in
/// `firestore-rules-tests/firestore.test.js` write it as
/// `'2026-11-10 10:00 AM'`. Some requests therefore arrive with a date this app
/// can read and some do not, and both have to be shown. [neededBy] answers "when
/// is it needed, for sorting and for a formatted date", [neededByText] answers
/// "what did the person write", and neither invents a value for the other.
@immutable
final class BloodRequest {
  const BloodRequest({
    required this.id,
    required this.bloodGroup,
    required this.hospitalName,
    required this.units,
    required this.neededBy,
    required this.neededByText,
  });

  /// The document id. Also the key the list deduplicates on, and the address a
  /// later stage hands to a response write.
  final String id;

  /// One of the eight groups [firestore.rules] accepts. Anything else is refused
  /// by the mapper rather than rendered: a ninth spelling on a badge next to a
  /// blood type is a medical-severity mistake, not a cosmetic one.
  final String bloodGroup;

  /// The facility a row names as its place. The specific street `hospitalAddress`
  /// was moved to `private/contact` in Stage 9.5 (M3-C1), so the hospital name is
  /// now the only location the public list shows — [area] returns it.
  final String hospitalName;

  /// Bags of blood asked for. At least one: the create rule requires an `int`
  /// `>= 1`, and the mapper refuses anything else.
  final int units;

  /// When the blood is needed, when the document said so in a form that could be
  /// read as a date. `null` means "this request has no readable date", never "no
  /// date matters" — [neededByText] is what the donor sees instead.
  final DateTime? neededBy;

  /// The stored text verbatim, trimmed. Empty when the field was absent or blank,
  /// and also empty when [neededBy] came from a real timestamp.
  final String neededByText;

  /// The place a row names. Since Stage 9.5 (M3-C1) that is always the hospital
  /// name — the private `hospitalAddress` never reaches this read model — and the
  /// hospital name is never empty, because the create rule requires a non-empty
  /// `hospitalName`.
  ///
  /// Not a distance: nothing in this stage knows where the donor is standing, and
  /// "near you" over a list that cannot compute near is a claim about the world
  /// the app has not checked.
  String get area => hospitalName;

  /// Whether the row has any date to show at all, in either form.
  bool get hasNeededBy => neededBy != null || neededByText.isNotEmpty;

  /// Names the numbers, never the place: a `toString` that carries a hospital
  /// line puts somebody's address into a log or a test failure output.
  @override
  String toString() => 'BloodRequest($id, $bloodGroup, $units units)';
}
