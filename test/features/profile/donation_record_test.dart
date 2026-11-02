import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';

DonationRecord _record({
  required String id,
  DonationStatus status = DonationStatus.confirmed,
  DateTime? donatedAt,
  DateTime? recordedAt,
  String hospitalName = 'Dhaka Medical College Hospital',
}) {
  return DonationRecord(
    id: id,
    bloodGroup: 'O+',
    hospitalName: hospitalName,
    status: status,
    donatedAt: donatedAt,
    recordedAt: recordedAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('DonationRecord', () {
    test('shows the donation date when there is one', () {
      final DonationRecord record = _record(
        id: 'don-1',
        donatedAt: DateTime(2026, 3, 4),
        recordedAt: DateTime(2026, 3, 9),
      );

      expect(record.effectiveDate, DateTime(2026, 3, 4));
    });

    test('falls back to the date it was recorded', () {
      // "Recorded on" is true where "donated on" would be a guess.
      final DonationRecord record = _record(
        id: 'don-1',
        recordedAt: DateTime(2026, 3, 9),
      );

      expect(record.donatedAt, isNull);
      expect(record.effectiveDate, DateTime(2026, 3, 9));
    });

    test('knows which records have been confirmed', () {
      expect(_record(id: 'a').isConfirmed, isTrue);
      expect(
        _record(id: 'b', status: DonationStatus.pending).isConfirmed,
        isFalse,
      );
    });
  });

  group('DonationHistory', () {
    test('an empty history claims nothing', () {
      expect(DonationHistory.empty.isEmpty, isTrue);
      expect(DonationHistory.empty.confirmedCount, 0);
      expect(DonationHistory.empty.lastConfirmedAt, isNull);
      expect(DonationHistory.empty.confirmed, isEmpty);
    });

    test('counts confirmed records only', () {
      final DonationHistory history = DonationHistory(<DonationRecord>[
        _record(id: 'a', donatedAt: DateTime(2026, 3, 4)),
        _record(id: 'b', donatedAt: DateTime(2026, 9, 12)),
        _record(
          id: 'c',
          status: DonationStatus.pending,
          donatedAt: DateTime(2026, 10, 30),
        ),
      ]);

      expect(history.records, hasLength(3));
      expect(history.confirmed, hasLength(2));
      expect(
        history.confirmedCount,
        2,
        reason: 'a pending claim is not a donation yet',
      );
    });

    test('a history of pending claims has no donation statistic at all', () {
      final DonationHistory history = DonationHistory(<DonationRecord>[
        _record(id: 'a', status: DonationStatus.pending),
      ]);

      expect(history.isEmpty, isFalse);
      expect(history.confirmedCount, 0);
      expect(history.lastConfirmedAt, isNull);
    });

    test('reports the most recent confirmed donation, not the newest record', () {
      final DonationHistory history = DonationHistory(<DonationRecord>[
        _record(id: 'a', donatedAt: DateTime(2026, 3, 4)),
        _record(id: 'b', donatedAt: DateTime(2026, 9, 12)),
        _record(
          id: 'c',
          status: DonationStatus.pending,
          donatedAt: DateTime(2026, 11, 1),
        ),
      ]);

      expect(history.lastConfirmedAt, DateTime(2026, 9, 12));
    });

    test('ignores a confirmed record with no usable date', () {
      final DonationHistory history = DonationHistory(<DonationRecord>[
        const DonationRecord(
          id: 'a',
          bloodGroup: 'O+',
          hospitalName: 'Square Hospital',
          status: DonationStatus.confirmed,
        ),
      ]);

      expect(history.confirmedCount, 1);
      expect(history.lastConfirmedAt, isNull);
    });
  });
}
