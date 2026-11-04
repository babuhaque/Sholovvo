import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

/// Why a `blood_requests` document was not turned into a [BloodRequest].
enum RequestIssue {
  idMissing,
  statusNotOpen,
  bloodGroupMissing,
  bloodGroupUnknown,
  unitsInvalid,
  hospitalMissing,
  fieldMalformed,
}

/// The exact shape a `blood_requests` document is written in, as this client
/// reads it back.
///
/// Pure functions over plain maps, in the same style as `PostDocument` and
/// `ProfileDocuments`: both the Firestore shape (`Timestamp`) and the plain-Dart
/// shape (`DateTime`, a string) can be exercised against literals, with no
/// emulator, no network and no Firebase app.
///
/// **Where the field list comes from.** Not from a schema file and not from a
/// live collection — nobody has read one in this project's verified state. It is
/// `firestore.rules`, which is in this repository and enumerates the keys:
///
/// ```
/// hasAll(['userId', 'patientName', 'phoneNumber', 'bloodGroup', 'bloodBags',
///         'hospitalName', 'hospitalAddress', 'requiredDateTime', 'status',
///         'createdAt'])
///   && hasOnly([… , 'requestType', 'notes', 'latitude', 'longitude', …])
///   && status == 'open' && bloodGroup in [the eight] && bloodBags is int >= 1
///   && patientName.size() > 0 && hospitalName.size() > 0
/// ```
///
/// Those constraints are the *create* rule. Documents written before it — the
/// collection came from the app this repository replaced — are not covered by it,
/// which is why every field is re-checked on the way in rather than trusted.
///
/// **What is refused and what is degraded, and the line between them.** A
/// document is refused when the field that is wrong is the one the row's medical
/// claim rests on: the group, the units, the hospital, the status, the id. A row
/// that says "O−, 3 bags, X Hospital" on the strength of a document that does not
/// support it is worse than no row.
///
/// Everything else is *degraded*, not refused. `requiredDateTime` and
/// `hospitalAddress` are display detail: a request whose date nobody can read is
/// still a request, and hiding it over a spelling would leave blood un-collected
/// in silence. This is a deliberate difference from the feed, where the text *is*
/// the post and a malformed document has nothing left to show.
abstract final class BloodRequestDocument {
  /// Collection name. Kept here so the query, the tests and `firestore.rules` all
  /// quote one string.
  static const String collection = 'blood_requests';

  /// The only status this stage lists. The rules start a request here and move it
  /// to `accepted`, `cancelled`, `donation_completed` or `fulfilled`; a request
  /// somebody has already claimed is not a request this screen should show as
  /// open, and a cancelled one is not a need.
  static const String openStatus = 'open';

  static Result<BloodRequest> fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final String requestId = id.trim();
    if (requestId.isEmpty) {
      return FailureResult<BloodRequest>(
        _reject(RequestIssue.idMissing, 'document id is empty'),
      );
    }

    // Re-checked here even though the query filters on it: the seam that feeds
    // this mapper in a test hands over literal maps, and a repository that showed
    // a cancelled request as open would be lying about a person's emergency.
    if (data['status'] != openStatus) {
      return FailureResult<BloodRequest>(
        _reject(
          RequestIssue.statusNotOpen,
          'status: ${_describe(data['status'])}',
        ),
      );
    }

    final Object? group = data['bloodGroup'];
    if (group == null) {
      return FailureResult<BloodRequest>(
        _reject(RequestIssue.bloodGroupMissing, 'bloodGroup is absent'),
      );
    }
    // The rules accept exactly eight strings on create. A ninth spelling — "O -",
    // "O−", "positive O" — is not a group this app can show as a badge next to a
    // donor's own, so the document is refused and counted rather than rendered.
    if (group is! String || !BloodGroups.isKnown(group)) {
      return FailureResult<BloodRequest>(
        _reject(RequestIssue.bloodGroupUnknown, 'bloodGroup: ${_describe(group)}'),
      );
    }

    final Object? bags = data['bloodBags'];
    if (bags is! int || bags < 1) {
      return FailureResult<BloodRequest>(
        _reject(RequestIssue.unitsInvalid, 'bloodBags: ${_describe(bags)}'),
      );
    }

    // The create rule requires a non-empty `hospitalName`, and it is the field the
    // row falls back to when there is no address — so a document without one has
    // no place a donor could go to.
    final Object? name = data['hospitalName'];
    final String hospitalName = name is String ? name.trim() : '';
    if (hospitalName.isEmpty) {
      return FailureResult<BloodRequest>(
        _reject(
          RequestIssue.hospitalMissing,
          'hospitalName: ${_describe(name)}',
        ),
      );
    }

    // Degraded rather than refused: a wrong-typed or blank address still leaves a
    // row that names the hospital.
    final Object? address = data['hospitalAddress'];
    final String hospitalAddress = address is String ? address.trim() : '';

    final (DateTime? instant, String text) = _neededBy(data['requiredDateTime']);

    return Success<BloodRequest>(
      BloodRequest(
        id: requestId,
        bloodGroup: group,
        hospitalName: hospitalName,
        hospitalAddress: hospitalAddress,
        units: bags,
        neededBy: instant,
        neededByText: text,
      ),
    );
  }

  /// Reads `requiredDateTime` in whichever of its three lives it arrives in.
  ///
  /// Returns the instant (when there is one, normalised to UTC) and the text the
  /// document actually holds. A real `Timestamp` produces an instant and no text:
  /// there is nothing verbatim to show, and the formatted date *is* what the
  /// field said.
  ///
  /// Kept as a visible function rather than inlined because it is the part of the
  /// mapper that a future schema change will break, and a test should be able to
  /// aim at it directly.
  static (DateTime?, String) neededBy(Object? value) => _neededBy(value);

  static (DateTime?, String) _neededBy(Object? value) {
    final DateTime? instant = switch (value) {
      Timestamp() => value.toDate().toUtc(),
      DateTime() => value.toUtc(),
      _ => null,
    };
    if (instant != null) {
      return (instant, '');
    }
    if (value is! String) {
      // Absent, or a number, or a map. No text to show and no instant to sort by:
      // the row says the date was not given, which is the truth.
      return (null, '');
    }
    final String text = value.trim();
    if (text.isEmpty) {
      return (null, '');
    }
    return (parseRequiredText(text), text);
  }

  /// The two date-time separators this collection uses, and the one it does not.
  ///
  /// Accepts, and returns a UTC instant for:
  ///
  /// * `2026-11-10` — date only, read in the device's zone the way the person who
  ///   typed it meant it, then normalised.
  /// * `2026-11-10 10:00`, `2026-11-10T10:00:00`, `…+06:00`, `…Z`, and a
  ///   fractional second — the ISO family.
  /// * `2026-11-10 10:00 AM` — the shape `firestore-rules-tests` seeds, and the
  ///   reason a `DateTime.parse` call is not enough on its own.
  ///
  /// Returns `null` for anything else, and the caller then shows the text
  /// verbatim. **Ambiguous is refused, not guessed:** `10/11/2026` is October 11
  /// or November 10 depending on who typed it, and a list ordered on that coin
  /// flip would put the most urgent request second. An out-of-range component is
  /// refused for the same reason — Dart's `DateTime` constructor would *normalise*
  /// month 13 into next January, which is inventing a date. `DateTime.parse` checks
  /// those ranges and throws instead, so it is doing the work here rather than a
  /// hand-written field-by-field regex.
  static DateTime? parseRequiredText(String raw) {
    final String text = raw.trim();
    if (text.isEmpty) {
      return null;
    }

    final RegExpMatch? meridiem = _meridiem.firstMatch(text);
    if (meridiem == null) {
      return _parse(text, toUtc: true);
    }

    // A meridiem attached to a date with no clock time (`2026-11-10 PM`) says
    // nothing about the hour, so there is nothing to shift.
    final String clock = text.substring(0, meridiem.start).trim();
    if (!_time.hasMatch(clock)) {
      return null;
    }
    // Read in the zone the text names — usually the device's — and shift *that*
    // hour. Converting to UTC first would move the hour out from under the marker:
    // `10:00 PM +06:00` is 16:00 UTC, and shifting a 16 would be arithmetic on a
    // number nobody wrote.
    final DateTime? parsed = _parse(clock, toUtc: false);
    if (parsed == null) {
      return null;
    }
    return _applyMeridiem(parsed, meridiem.group(1)!.toUpperCase());
  }

  /// `DateTime.parse` over one of the accepted shapes, or `null`.
  ///
  /// The space-between-date-and-time variant this collection writes is normalised
  /// to the `T` ISO wants, so the mapper does not depend on Dart's parser
  /// continuing to accept a separator it was never specified to allow.
  static DateTime? _parse(String value, {required bool toUtc}) {
    try {
      final DateTime parsed = DateTime.parse(
        value.replaceFirstMapped(
          _separator,
          (Match match) => '${match.group(1)}T',
        ),
      );
      return toUtc ? parsed.toUtc() : parsed;
    } on FormatException {
      return null;
    }
  }

  /// Turns a 12-hour clock into the hour Dart needs.
  ///
  /// A `12`-hour clock is only 12-hour *with a marker on it*: hours `0` and
  /// `13`–`23` beside an AM/PM tail are a contradiction, and a contradiction is not
  /// a date — it is refused rather than quietly read as the 24-hour value. `12 AM`
  /// is midnight and `12 PM` is noon, which is the one part of this that everybody
  /// gets wrong at least once, so it is stated here and pinned in a test.
  static DateTime? _applyMeridiem(DateTime parsed, String marker) {
    final int hour = parsed.hour;
    if (hour < 1 || hour > 12) {
      return null;
    }
    final int? shifted = switch (marker) {
      'AM' => hour == 12 ? 0 : hour,
      'PM' => hour == 12 ? 12 : hour + 12,
      _ => null,
    };
    if (shifted == null) {
      return null;
    }

    // Rebuilt in the zone it was parsed in, then normalised: a value that carried
    // `Z` or an offset is UTC, and `DateTime(...)` alone would reinterpret it as
    // local time and shift every request by the phone's offset.
    final DateTime wall = parsed.isUtc
        ? DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            shifted,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          )
        : DateTime(
            parsed.year,
            parsed.month,
            parsed.day,
            shifted,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
    return wall.toUtc();
  }

  /// Matches a trailing `AM`/`PM`/`am`/`p.m.`, with the space before it.
  static final RegExp _meridiem = RegExp(r'\s([AaPp])\.?[Mm]\.?\s*$');

  /// A space standing where ISO 8601 puts its `T`.
  static final RegExp _separator = RegExp(r'^(\d{4}-\d{1,2}-\d{1,2}) ');

  /// Whether a clock time is present at all.
  static final RegExp _time = RegExp(r'\d{1,2}:\d{2}');

  /// What a value *is*, for a debug message — never what it contains. A patient's
  /// name or phone number must not end up in a log line or a test report.
  static String _describe(Object? value) {
    if (value == null) {
      return 'absent';
    }
    return value.runtimeType.toString();
  }

  static ValidationFailure _reject(RequestIssue issue, String detail) {
    return ValidationFailure(
      messageKey: issue.name,
      debugMessage: 'Request document rejected: ${issue.name} ($detail)',
    );
  }
}
