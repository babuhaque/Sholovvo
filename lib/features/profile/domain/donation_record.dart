import 'package:flutter/foundation.dart';

/// Where a donation record sits in its life cycle.
///
/// `pending` is a donor's own claim that has not been confirmed by the recipient
/// yet; `confirmed` has been, and only the recipient can create it (see
/// `firestore.rules`). The distinction is shown in the UI so a count of
/// "donations" never includes something nobody verified.
enum DonationStatus { pending, confirmed }

/// One row of `donation_history/{recordId}`.
///
/// A read model: the profile never writes here. Donations are recorded by the
/// request flow (Stages 10/11) when a recipient confirms one, so a date in this
/// list always came from a completed request rather than from someone typing a
/// number that would later look like a verified donation.
@immutable
class DonationRecord {
  const DonationRecord({
    required this.id,
    required this.bloodGroup,
    required this.hospitalName,
    required this.status,
    this.donatedAt,
    this.recordedAt,
  });

  final String id;
  final String bloodGroup;
  final String hospitalName;
  final DonationStatus status;

  /// `donationDate` on the document. Nullable in the rules, so nullable here.
  final DateTime? donatedAt;

  /// `createdAt`: when the record was written. Used as the sort key and as the
  /// display date when a donation date was never filled in, because "recorded
  /// on" is a true statement where "donated on" would be a guess.
  final DateTime? recordedAt;

  bool get isConfirmed => status == DonationStatus.confirmed;

  /// The date this record is shown and sorted by.
  DateTime? get effectiveDate => donatedAt ?? recordedAt;
}

/// The signed-in donor's history, newest first.
@immutable
class DonationHistory {
  const DonationHistory(this.records);

  static const DonationHistory empty = DonationHistory(<DonationRecord>[]);

  /// Sorted newest first by [DonationRecord.effectiveDate].
  final List<DonationRecord> records;

  bool get isEmpty => records.isEmpty;

  List<DonationRecord> get confirmed =>
      records.where((DonationRecord r) => r.isConfirmed).toList();

  /// Counted from confirmed records only. A pending claim is not a donation yet,
  /// and a statistic that counts it would overstate how much this person has
  /// given.
  int get confirmedCount => confirmed.length;

  /// The most recent confirmed donation, or null when there is none — which the
  /// screens render as "No donations yet" rather than as a blank date.
  DateTime? get lastConfirmedAt {
    DateTime? latest;
    for (final DonationRecord record in confirmed) {
      final DateTime? date = record.effectiveDate;
      if (date == null) {
        continue;
      }
      if (latest == null || date.isAfter(latest)) {
        latest = date;
      }
    }
    return latest;
  }
}
