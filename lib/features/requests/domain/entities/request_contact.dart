import 'package:flutter/foundation.dart';

/// The owner's private contact record for one blood request.
///
/// **The one read model that is allowed to carry PII.** [BloodRequest] is the
/// *public* projection and deliberately holds none of these three fields (M3-C1).
/// This type exists only for the owner reading their OWN
/// `blood_requests/{id}/private/contact` back — the increment `firestore.rules`
/// L234-236 permits and the app had avoided until now. It is never populated from
/// a public document, and a stranger or a donor cannot obtain it: the rules refuse
/// their read with a `permission-denied`, so this type only ever materialises for
/// the account whose uid equals the parent `userId`.
///
/// **The donor still cannot see this.** The M3-C2 blocker keeps the "matched donor
/// may read" branch closed, so a value of this type is an owner round-trip (edit
/// what I saved), not a disclosure to anyone else.
///
/// The three fields mirror the stored shape exactly — `patientName` and
/// `phoneNumber` the rule requires non-empty, `hospitalAddress` a string that may
/// be empty. A reader should not assume the required two are non-empty here: an
/// older document the rules did not gate could hold anything, and the mapper
/// coerces a missing/non-string value to empty rather than throwing, so the form
/// can still show and correct it.
@immutable
final class RequestContact {
  const RequestContact({
    required this.patientName,
    required this.phoneNumber,
    required this.hospitalAddress,
  });

  final String patientName;
  final String phoneNumber;
  final String hospitalAddress;

  /// Names nothing. A `toString` that carried the patient's name, phone or
  /// address would put PII into a log line or a test failure dump — the exact
  /// leak this private subcollection exists to prevent — so it says only that a
  /// private record exists, never what is in it.
  @override
  String toString() => 'RequestContact(private)';

  @override
  bool operator ==(Object other) =>
      other is RequestContact &&
      other.patientName == patientName &&
      other.phoneNumber == phoneNumber &&
      other.hospitalAddress == hospitalAddress;

  @override
  int get hashCode => Object.hash(
    patientName,
    phoneNumber,
    hospitalAddress,
  );
}
