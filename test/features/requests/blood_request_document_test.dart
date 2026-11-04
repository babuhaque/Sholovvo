import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/requests/data/models/blood_request_document.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';

import '../../support/fake_requests.dart';

/// The mapper's own vocabulary: the reason a document was refused, taken off the
/// failure it produced.
///
/// Asserting through [ValidationFailure.messageKey] rather than matching on the
/// type keeps a test honest about *which* rule fired: a document refused for the
/// wrong reason is a bug that looks like a pass.
String? _issueOf(Result<Object?> result) {
  final Failure? failure = result.failureOrNull;
  return failure is ValidationFailure ? failure.messageKey : null;
}

Result<BloodRequest> _map({
  String id = 'req-1',
  Map<String, Object?>? fields,
}) {
  return BloodRequestDocument.fromMap(
    id: id,
    data: Map<String, dynamic>.from(fields ?? requestFields()),
  );
}

void main() {
  group('BloodRequestDocument refuses', () {
    test('a document with no id', () {
      expect(_issueOf(_map(id: '  ')), RequestIssue.idMissing.name);
    });

    test('a request that is not open, in each of the ways it might not be', () {
      for (final String status in <String>[
        'accepted',
        'cancelled',
        'donation_completed',
        'fulfilled',
      ]) {
        expect(
          _issueOf(_map(fields: requestFields(status: status))),
          RequestIssue.statusNotOpen.name,
          reason: 'a $status request is not an open one',
        );
      }
      expect(
        _issueOf(_map(fields: requestFields(status: null))),
        RequestIssue.statusNotOpen.name,
        reason: 'a document with no status field is not a promise of one',
      );
    });

    test('a blood group that is absent, misspelt, or not a string', () {
      expect(
        _issueOf(_map(fields: requestFields(bloodGroup: null))),
        RequestIssue.bloodGroupMissing.name,
      );
      // The rules accept exactly eight spellings. These are the ones a human
      // types: a space, a minus that is a Unicode dash, an adjective.
      for (final String group in <String>['O -', 'O−', 'positive O', 'o+']) {
        expect(
          _issueOf(_map(fields: requestFields(bloodGroup: group))),
          RequestIssue.bloodGroupUnknown.name,
          reason: '"$group" is not one of the eight',
        );
      }
      expect(
        _issueOf(_map(fields: requestFields(bloodGroup: 5))),
        RequestIssue.bloodGroupUnknown.name,
      );
    });

    test('units that are not a positive whole number', () {
      for (final Object? bags in <Object?>[0, -1, '2', 1.5, null]) {
        expect(
          _issueOf(_map(fields: requestFields(bloodBags: bags))),
          RequestIssue.unitsInvalid.name,
          reason: 'bloodBags: $bags',
        );
      }
    });

    test('a document that names no hospital', () {
      for (final Object? name in <Object?>['', '   ', null, 42]) {
        expect(
          _issueOf(_map(fields: requestFields(hospitalName: name))),
          RequestIssue.hospitalMissing.name,
          reason: 'hospitalName: $name',
        );
      }
    });

    test('everything it refuses, and nothing it does not', () {
      expect(_map().failureOrNull, isNull);
      // The eight groups, spelled as the rules spell them, all map.
      for (final String group in <String>[
        'A+',
        'A-',
        'B+',
        'B-',
        'AB+',
        'AB-',
        'O+',
        'O-',
      ]) {
        expect(
          _map(fields: requestFields(bloodGroup: group)).valueOrNull,
          isNotNull,
          reason: group,
        );
      }
    });
  });

  group('BloodRequestDocument maps', () {
    test('the fields a donor decides on, and only those', () {
      final BloodRequest request = _map(
        fields: requestFields(
          bloodGroup: 'B+',
          bloodBags: 3,
          hospitalName: 'Dhaka Medical College',
          hospitalAddress: 'Dhaka',
        ),
      ).valueOrNull!;

      expect(request.id, 'req-1');
      expect(request.bloodGroup, 'B+');
      expect(request.units, 3);
      expect(request.hospitalName, 'Dhaka Medical College');
      expect(request.hospitalAddress, 'Dhaka');
    });

    test('no patient name and no phone number, whatever the document holds', () {
      // The seed carries both and the frozen rules let any signed-in user read
      // them, so the only thing standing between a stranger and a patient's
      // number is this read model not carrying it. `toString` is asserted too:
      // a log line is as leaky as a widget.
      final BloodRequest request = _map().valueOrNull!;
      final String printed = request.toString();

      expect(printed.contains('Patient'), isFalse, reason: printed);
      expect(printed.contains('+8801700000000'), isFalse, reason: printed);
      expect(
        printed.contains('Dhaka Medical College'),
        isFalse,
        reason: 'an address does not belong in a log line either: $printed',
      );
    });

    test('a blank address as no address, not as a broken document', () {
      // Degraded rather than refused: the row still names the hospital.
      final BloodRequest request = _map(
        fields: requestFields(hospitalAddress: '   '),
      ).valueOrNull!;

      expect(request.hospitalAddress, isEmpty);
      expect(request.area, 'Dhaka Medical College');
    });

    test('a wrong-typed address as no address', () {
      final BloodRequest request = _map(
        fields: requestFields(hospitalAddress: 123),
      ).valueOrNull!;

      expect(request.hospitalAddress, isEmpty);
      expect(request.area, request.hospitalName);
    });

    test('the area as the address when there is one', () {
      final BloodRequest request = _map(
        fields: requestFields(hospitalAddress: 'Mirpur'),
      ).valueOrNull!;

      expect(request.area, 'Mirpur');
    });
  });

  group('requiredDateTime', () {
    test('a Firestore Timestamp becomes an instant and no text', () {
      final DateTime when = DateTime.utc(2026, 11, 10, 4);
      final (DateTime? neededBy, String text) = BloodRequestDocument.neededBy(
        Timestamp.fromDate(when),
      );

      expect(neededBy, when);
      // Nothing was typed, so there is nothing verbatim to show: the formatted
      // date is what the field said.
      expect(text, isEmpty);
    });

    test('a Dart DateTime, in either zone, arrives normalised to UTC', () {
      final (DateTime? local, String localText) = BloodRequestDocument.neededBy(
        DateTime(2026, 11, 10, 10),
      );
      final (DateTime? utc, String utcText) = BloodRequestDocument.neededBy(
        DateTime.utc(2026, 11, 10, 10),
      );

      expect(local, DateTime(2026, 11, 10, 10).toUtc());
      expect(local!.isUtc, isTrue);
      expect(utc, DateTime.utc(2026, 11, 10, 10));
      expect(localText, isEmpty);
      expect(utcText, isEmpty);
    });

    test('the shape the rules test seeds parses', () {
      // `firestore-rules-tests/firestore.test.js` writes
      // `'2026-11-10 10:00 AM'` — free text, not a Timestamp. The instant is
      // compared against the same wall clock read in the same zone, so the
      // assertion holds whatever machine runs it while still pinning the
      // AM/PM shift itself.
      final (DateTime? neededBy, String text) = BloodRequestDocument.neededBy(
        '2026-11-10 10:00 AM',
      );

      expect(neededBy, DateTime(2026, 11, 10, 10).toUtc());
      expect(text, '2026-11-10 10:00 AM');
    });

    test('midnight and noon are the two the marker is wrong about', () {
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 12:00 AM'),
        DateTime(2026, 11, 10, 0).toUtc(),
      );
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 12:00 PM'),
        DateTime(2026, 11, 10, 12).toUtc(),
      );
    });

    test('the marker shifts the hour that was written', () {
      // Half past ten at night is ten in the morning plus twelve, and the pair of
      // them is what separates a parsed meridiem from a `DateTime.parse` that
      // would have thrown on the tail. The expected value is built with the same
      // wall clock and the same zone, so the assertion pins the shift rather than
      // the machine's offset.
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 10:00 PM'),
        DateTime(2026, 11, 10, 22).toUtc(),
      );
    });

    test('a marker that does not trail the time is not a marker', () {
      // `10:00:00 PM+06:00` puts an offset after the meridiem, which is a shape
      // nothing in this collection writes. It is refused outright rather than
      // half-parsed, and the mapper keeps the text for the row to show.
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 10:00:00 PM+06:00'),
        isNull,
      );
      expect(
        BloodRequestDocument.neededBy('2026-11-10 10:00:00 PM+06:00').$2,
        '2026-11-10 10:00:00 PM+06:00',
      );
    });

    test('a meridiem with no clock time, and an hour that contradicts it', () {
      expect(BloodRequestDocument.parseRequiredText('2026-11-10 PM'), isNull);
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 13:00 PM'),
        isNull,
      );
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 0:00 AM'),
        isNull,
      );
    });

    test('the ISO family parses, with the space variant the app writes', () {
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10'),
        DateTime(2026, 11, 10).toUtc(),
      );
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10 10:00'),
        DateTime(2026, 11, 10, 10).toUtc(),
      );
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10T10:00:00.500Z'),
        DateTime.utc(2026, 11, 10, 10, 0, 0, 500),
      );
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10T10:00:00+06:00'),
        DateTime.utc(2026, 11, 10, 4),
      );
    });

    test('an ambiguous date is refused rather than guessed', () {
      // 10/11/2026 is October 11 or November 10 depending on who typed it, and a
      // list ordered on that coin flip can put the most urgent request second.
      expect(BloodRequestDocument.parseRequiredText('10/11/2026'), isNull);
      expect(BloodRequestDocument.parseRequiredText('tomorrow'), isNull);
      expect(BloodRequestDocument.parseRequiredText('asap'), isNull);
    });

    test('a date out of range is refused rather than rolled over', () {
      // Dart's parser does not reject these: it normalises them into a real day
      // some months away, and the list would then order a request on a date
      // nobody wrote.
      expect(BloodRequestDocument.parseRequiredText('2026-13-40'), isNull);
      expect(BloodRequestDocument.parseRequiredText('2026-02-30'), isNull);
      expect(BloodRequestDocument.parseRequiredText('2026-11-31'), isNull);
    });

    test('a day that only exists in a leap year is not invented', () {
      expect(BloodRequestDocument.parseRequiredText('2024-02-29'), isNotNull);
      expect(BloodRequestDocument.parseRequiredText('2026-02-29'), isNull);
    });

    test('an early hour with an offset is not refused for crossing midnight', () {
      // 02:00 in a +06:00 zone is the previous evening in UTC. The calendar check
      // reads the day as it was written, so a value that only moves when it is
      // normalised still parses — and parses to the instant it names.
      expect(
        BloodRequestDocument.parseRequiredText('2026-11-10T02:00:00+06:00'),
        DateTime.utc(2026, 11, 9, 20),
      );
    });

    test('unparseable text is kept, because it is what the person wrote', () {
      final (DateTime? neededBy, String text) = BloodRequestDocument.neededBy(
        'আগামীকাল রাতে',
      );

      expect(neededBy, isNull);
      expect(text, 'আগামীকাল রাতে');
    });

    test('absent, blank and wrong-typed all mean no date at all', () {
      for (final Object? value in <Object?>[
        null,
        '',
        '   ',
        1730000000,
        <String, Object>{},
      ]) {
        final (DateTime? neededBy, String text) = BloodRequestDocument.neededBy(
          value,
        );

        expect(neededBy, isNull, reason: '$value');
        expect(text, isEmpty, reason: '$value');
      }
    });

    test('a document whose date cannot be read still maps', () {
      // The whole point of degrading instead of refusing here: a request whose
      // spelling nobody can read is still a request somebody needs blood for.
      final BloodRequest request = _map(
        fields: requestFields(requiredDateTime: 'শুক্রবার'),
      ).valueOrNull!;

      expect(request.neededBy, isNull);
      expect(request.neededByText, 'শুক্রবার');
      expect(request.hasNeededBy, isTrue);
    });

    test('a document with no date at all still maps, and says so', () {
      final BloodRequest request = _map(
        fields: requestFields(requiredDateTime: null),
      ).valueOrNull!;

      expect(request.neededBy, isNull);
      expect(request.hasNeededBy, isFalse);
    });
  });
}
