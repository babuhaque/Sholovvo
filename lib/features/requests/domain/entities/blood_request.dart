import 'package:flutter/foundation.dart';

/// One open blood request, as this app reads it.
///
/// **What is deliberately not here.** `patientName` and `phoneNumber` are fields
/// of the same document, and `firestore.rules` lets any signed-in user read them
/// (`allow read: if request.auth != null` on `/blood_requests/{id}`, with no
/// field condition to hide behind). They are absent from this entity because the
/// screen has no use for them: a donor deciding whether to help needs the group,
/// the units, the place and the date, and a list of patients' names and phone
/// numbers is a directory of people in a medical emergency. A read model is the
/// place where that choice gets made — the rule cannot make it, because the rule
/// is frozen — so a row that could show the phone number does not carry it.
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
    required this.hospitalAddress,
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

  final String hospitalName;

  /// The address as typed, which may be a district or a full line. Empty when the
  /// document does not carry one — see [area], which is what a row shows.
  final String hospitalAddress;

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

  /// The place a row names. The address when there is one, otherwise the
  /// hospital — which is never empty, because the create rule requires a
  /// non-empty `hospitalName`.
  ///
  /// Not a distance: nothing in this stage knows where the donor is standing, and
  /// "near you" over a list that cannot compute near is a claim about the world
  /// the app has not checked.
  String get area => hospitalAddress.isNotEmpty ? hospitalAddress : hospitalName;

  /// Whether the row has any date to show at all, in either form.
  bool get hasNeededBy => neededBy != null || neededByText.isNotEmpty;

  /// Names the numbers, never the place: a `toString` that carries a hospital
  /// line puts somebody's address into a log or a test failure output.
  @override
  String toString() => 'BloodRequest($id, $bloodGroup, $units units)';
}
