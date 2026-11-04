import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/data/models/donor_profile_document.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';

import '../../support/fake_donors.dart';

Donor _donor(Map<String, Object?> fields, {String id = 'uid-1'}) {
  final Result<Donor> result = DonorProfileDocument.fromUserDoc(
    id: id,
    data: fields,
  );
  final Donor? donor = result.valueOrNull;
  expect(donor, isNotNull, reason: 'expected a donor, got ${result.failureOrNull}');
  return donor!;
}

ValidationFailure _refusal(Map<String, Object?> fields, {String id = 'uid-1'}) {
  final Result<Donor> result = DonorProfileDocument.fromUserDoc(
    id: id,
    data: fields,
  );
  expect(result.valueOrNull, isNull, reason: 'expected a refusal');
  final Failure? failure = result.failureOrNull;
  expect(failure, isA<ValidationFailure>());
  return failure! as ValidationFailure;
}

void main() {
  group('DonorProfileDocument accepts a consented donor', () {
    test('reads every discovery-safe field', () {
      final Donor donor = _donor(
        donorFields(
          displayName: 'Nadia Islam',
          bloodGroup: 'O+',
          isAvailable: true,
          area: 'Uttra, Dhaka',
          photoUrl: 'https://cdn/avatars/nadia.png',
        ),
      );

      expect(donor.uid, 'uid-1');
      expect(donor.displayName, 'Nadia Islam');
      expect(donor.bloodGroup, 'O+');
      expect(donor.isAvailable, isTrue);
      expect(donor.area, 'Uttra, Dhaka');
      expect(donor.photoUrl, 'https://cdn/avatars/nadia.png');
      expect(donor.hasArea, isTrue);
      expect(donor.hasPhoto, isTrue);
      expect(donor.hasBloodGroup, isTrue);
    });

    test('trims and drops a blank display name to empty, still a donor', () {
      final Donor donor = _donor(donorFields(displayName: '   '));

      expect(donor.displayName, '');
      expect(donor.displayName, isEmpty);
    });

    test('degrades an absent blood group to null rather than refusing', () {
      // A donor mid-onboarding has a real profile with no group yet; dropping them
      // from the directory would punish consent for incompleteness.
      final Donor donor = _donor(donorFields(bloodGroup: null));

      expect(donor.bloodGroup, isNull);
      expect(donor.hasBloodGroup, isFalse);
    });

    test('treats a blank area as unpublished, not as an empty line', () {
      final Donor donor = _donor(donorFields(area: '  '));

      expect(donor.area, isNull);
      expect(donor.hasArea, isFalse);
    });

    test('reads availability false as a real donor who is not offering', () {
      final Donor donor = _donor(donorFields(isAvailable: false));

      expect(donor.isAvailable, isFalse);
    });

    test('accepts each of the eight groups the rules allow', () {
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
        expect(_donor(donorFields(bloodGroup: group)).bloodGroup, group);
      }
    });
  });

  group('DonorProfileDocument refuses what is not a readable donor', () {
    test('refuses a document whose id is blank', () {
      final ValidationFailure failure = _refusal(donorFields(), id: '  ');

      expect(failure.messageKey, DonorIssue.idMissing.name);
    });

    test('refuses a non-donor role, so a recipient never appears', () {
      final ValidationFailure failure = _refusal(
        donorFields(role: 'recipient'),
      );

      expect(failure.messageKey, DonorIssue.notADonor.name);
    });

    test('refuses an absent role', () {
      final Map<String, Object?> fields = donorFields()..remove('role');

      expect(_refusal(fields).messageKey, DonorIssue.notADonor.name);
    });

    test('refuses a ninth blood-group spelling the backend would reject', () {
      // A badge next to a donor that cannot be matched is a medical-severity
      // mistake, not a cosmetic one — refuse the row rather than show a false group.
      final ValidationFailure failure = _refusal(donorFields(bloodGroup: 'O -'));

      expect(failure.messageKey, DonorIssue.bloodGroupUnknown.name);
    });

    test('refuses a blood group that is not a string at all', () {
      expect(
        _refusal(donorFields(bloodGroup: 7)).messageKey,
        DonorIssue.bloodGroupUnknown.name,
      );
    });
  });

  group('DonorProfileDocument Stage 9.5 consent gate', () {
    // The query already filters `allowDonorDiscovery == true`, so anything the
    // mapper sees on a live read should have opted in. These tests exercise the
    // defence-in-depth line: a test seam, a future cache, or a manually seeded
    // row that bypasses the query still has to be refused. Absent and false are
    // the same thing (a legacy document has never carried the key at all).
    test('refuses an explicit opt-out', () {
      final ValidationFailure failure = _refusal(
        donorFields(allowDonorDiscovery: false),
      );

      expect(failure.messageKey, DonorIssue.notDiscoverable.name);
    });

    test('refuses a legacy document with no allowDonorDiscovery key', () {
      final Map<String, Object?> fields = donorFields()
        ..remove('allowDonorDiscovery');

      expect(
        _refusal(fields).messageKey,
        DonorIssue.notDiscoverable.name,
      );
    });

    test('refuses a null allowDonorDiscovery, not just a missing one', () {
      expect(
        _refusal(donorFields(allowDonorDiscovery: null)).messageKey,
        DonorIssue.notDiscoverable.name,
      );
    });

    test('refuses a non-bool truthy value', () {
      // Only a real `true` counts as consent. A document that says `1`, or
      // `'true'`, or any other type was not written by `publicFields`, so the
      // mapper will not accept it as an opt-in.
      for (final Object? value in <Object?>[1, 'true', 0, '']) {
        expect(
          _refusal(donorFields(allowDonorDiscovery: value)).messageKey,
          DonorIssue.notDiscoverable.name,
          reason: 'value $value must not read as consent',
        );
      }
    });

    test('consent is checked after role, so a non-donor is reported as such', () {
      // The refusals have a defined order: an unroled or wrongly-roled document
      // is not a donor at all, and the consent question never arises. Reporting
      // `notADonor` here is more useful to an operator than `notDiscoverable`.
      final ValidationFailure failure = _refusal(
        donorFields(role: 'recipient', allowDonorDiscovery: false),
      );

      expect(failure.messageKey, DonorIssue.notADonor.name);
    });

    test('consent is checked before blood group, so an opted-out corrupt row reports consent', () {
      // Both would be refused; the consent refusal is the more important
      // operator-facing fact because it names the privacy invariant, not the
      // data-quality one.
      final ValidationFailure failure = _refusal(
        donorFields(allowDonorDiscovery: false, bloodGroup: 'C+'),
      );

      expect(failure.messageKey, DonorIssue.notDiscoverable.name);
    });

    test('accepts a consented donor — the default in the helper', () {
      // Sanity: the shared fixture is opted-in so unrelated tests do not have
      // to spell it out. A refusal test that forgets to reset the flag will not
      // accidentally start passing.
      expect(_donor(donorFields()).uid, 'uid-1');
    });
  });

  group('DonorProfileDocument privacy', () {
    test('a phone key on the document never reaches the donor', () {
      // The public document holds no phone today, but the mapper reads only the
      // fields it names — so even a document that somehow grew a phone key would not
      // put it on a read model that has nowhere to store it.
      final Map<String, Object?> fields = donorFields();
      fields['phone'] = '+8801700000000';
      fields['addressLine'] = 'House 12, Road 5';

      final Donor donor = _donor(fields);

      expect(donor.toString().contains('+8801700000000'), isFalse);
      expect(donor.toString().contains('House 12'), isFalse);
      expect(donor.toString().contains('Dhanmondi'), isFalse, reason: 'no area in logs');
    });

    test('its own summary names the person and the group, never the location', () {
      final Donor donor = _donor(donorFields(area: 'Gulshan, Dhaka'));

      expect(donor.toString(), contains('A+'));
      expect(donor.toString().contains('Gulshan'), isFalse);
    });
  });
}
