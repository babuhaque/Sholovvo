import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/profile/domain/profile_validators.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

void main() {
  group('ProfileValidators.name', () {
    test('requires a name and bounds its length', () {
      expect(ProfileValidators.name(null), ProfileFieldIssue.nameRequired);
      expect(ProfileValidators.name('   '), ProfileFieldIssue.nameRequired);
      expect(ProfileValidators.name('A'), ProfileFieldIssue.nameTooShort);
      expect(ProfileValidators.name('Ayesha Rahman'), isNull);
      expect(
        ProfileValidators.name('A' * (ProfileValidators.maxNameLength + 1)),
        ProfileFieldIssue.nameTooLong,
      );
    });

    test('accepts a name at each boundary and trims before measuring', () {
      expect(
        ProfileValidators.name('Ab'),
        isNull,
        reason: 'two characters is the shortest valid name',
      );
      expect(
        ProfileValidators.name('A' * ProfileValidators.maxNameLength),
        isNull,
        reason: 'the limit itself is allowed',
      );
      expect(ProfileValidators.name('  Ayesha  '), isNull);
    });

    test('accepts Bengali script', () {
      expect(ProfileValidators.name('আয়েশা রহমান'), isNull);
    });
  });

  group('ProfileValidators.phone', () {
    test('accepts the forms a Bangladeshi mobile number is written in', () {
      for (final String number in <String>[
        '01712345678',
        '+8801712345678',
        '8801712345678',
        '017-1234-5678',
        ' 017 1234 5678 ',
        '01912345678',
        '01312345678',
      ]) {
        expect(ProfileValidators.phone(number), isNull, reason: number);
      }
    });

    test('treats an empty field as "not shared", not as invalid', () {
      expect(ProfileValidators.phone(null), isNull);
      expect(ProfileValidators.phone(''), isNull);
      expect(ProfileValidators.phone('   '), isNull);
      expect(ProfileValidators.phone('-'), isNull);
    });

    test('rejects a number it could not dial', () {
      for (final String number in <String>[
        '0171234567', // one digit short
        '017123456789', // one digit long
        '01212345678', // no operator issues this prefix
        '0171234567a',
        '+88017123',
        '1712345678', // no trunk prefix and no country code
        '+447700900123', // not a Bangladeshi mobile
      ]) {
        expect(
          ProfileValidators.phone(number),
          ProfileFieldIssue.phoneInvalid,
          reason: number,
        );
      }
    });
  });

  group('ProfileValidators.area and address', () {
    test('an empty area is allowed: it is optional', () {
      expect(ProfileValidators.area(null), isNull);
      expect(ProfileValidators.area(''), isNull);
      expect(ProfileValidators.area('Dhanmondi, Dhaka'), isNull);
    });

    test('bounds the area length', () {
      expect(
        ProfileValidators.area('ঢ' * ProfileValidators.maxAreaLength),
        isNull,
      );
      expect(
        ProfileValidators.area('ঢ' * (ProfileValidators.maxAreaLength + 1)),
        ProfileFieldIssue.areaTooLong,
      );
    });

    test('bounds the address length', () {
      expect(
        ProfileValidators.address('R' * ProfileValidators.maxAddressLength),
        isNull,
      );
      expect(
        ProfileValidators.address('R' * (ProfileValidators.maxAddressLength + 1)),
        ProfileFieldIssue.addressTooLong,
      );
    });
  });

  group('ProfileValidators.birthDate', () {
    final DateTime now = DateTime(2026, 11, 2, 14, 30);

    test('accepts a date in the past, including today', () {
      expect(ProfileValidators.birthDate(null), isNull);
      expect(ProfileValidators.birthDate(DateTime(1996, 4, 17), now: now), isNull);
      expect(
        ProfileValidators.birthDate(DateTime(2026, 11, 2), now: now),
        isNull,
        reason: 'a newborn is still a person, however unlikely here',
      );
    });

    test('compares calendar days, not instants', () {
      // 23:59 today is not the future, even though it is later than `now`.
      expect(
        ProfileValidators.birthDate(DateTime(2026, 11, 2, 23, 59), now: now),
        isNull,
      );
      expect(
        ProfileValidators.birthDate(DateTime(2026, 11, 3), now: now),
        ProfileFieldIssue.birthDateInFuture,
      );
    });

    test('rejects a date before the sanity floor', () {
      expect(
        ProfileValidators.birthDate(DateTime(1899, 12, 31), now: now),
        ProfileFieldIssue.birthDateTooOld,
      );
      expect(
        ProfileValidators.birthDate(
          DateTime(ProfileValidators.earliestBirthYear),
          now: now,
        ),
        isNull,
      );
    });

    test('imposes no minimum age', () {
      // Eligibility is configuration, not a rule this layer may invent.
      expect(ProfileValidators.birthDate(DateTime(2020, 1, 1), now: now), isNull);
    });
  });

  group('ProfileValidators.bloodGroup', () {
    test('accepts a known group and an unanswered field', () {
      expect(ProfileValidators.bloodGroup(null, BloodGroups.all), isNull);
      expect(ProfileValidators.bloodGroup('', BloodGroups.all), isNull);
      for (final String group in BloodGroups.all) {
        expect(ProfileValidators.bloodGroup(group, BloodGroups.all), isNull);
      }
    });

    test('rejects a ninth group that came from somewhere else', () {
      expect(
        ProfileValidators.bloodGroup('C+', BloodGroups.all),
        ProfileFieldIssue.bloodGroupUnknown,
      );
      expect(
        ProfileValidators.bloodGroup('o+', BloodGroups.all),
        ProfileFieldIssue.bloodGroupUnknown,
        reason: 'case is part of the stored value',
      );
    });
  });

  group('ProfileValidators.validate', () {
    test('reports nothing for a valid form', () {
      final Map<ProfileFormField, ProfileFieldIssue> issues =
          ProfileValidators.validate(
            name: 'Ayesha Rahman',
            phone: '01712345678',
            area: 'Dhanmondi, Dhaka',
            address: 'House 12, Road 5',
            birthDate: DateTime(1996, 4, 17),
            bloodGroup: 'O+',
            knownBloodGroups: BloodGroups.all,
            now: DateTime(2026, 11, 2),
          );

      expect(issues, isEmpty);
    });

    test('names each broken field separately', () {
      final Map<ProfileFormField, ProfileFieldIssue> issues =
          ProfileValidators.validate(
            name: '',
            phone: '12345',
            area: 'A' * (ProfileValidators.maxAreaLength + 1),
            address: '',
            birthDate: DateTime(2030, 1, 1),
            bloodGroup: 'Z+',
            knownBloodGroups: BloodGroups.all,
            now: DateTime(2026, 11, 2),
          );

      expect(issues[ProfileFormField.name], ProfileFieldIssue.nameRequired);
      expect(issues[ProfileFormField.phone], ProfileFieldIssue.phoneInvalid);
      expect(issues[ProfileFormField.area], ProfileFieldIssue.areaTooLong);
      expect(
        issues[ProfileFormField.birthDate],
        ProfileFieldIssue.birthDateInFuture,
      );
      expect(
        issues[ProfileFormField.bloodGroup],
        ProfileFieldIssue.bloodGroupUnknown,
      );
      // An empty address is valid, so it must not appear at all.
      expect(issues.containsKey(ProfileFormField.address), isFalse);
    });

    test('every form field has a validator', () {
      // A field added to the enum without a rule would silently never be
      // validated; this fails the moment that happens.
      final Map<ProfileFormField, ProfileFieldIssue> issues =
          ProfileValidators.validate(
            name: '',
            phone: 'not-a-number',
            area: 'A' * (ProfileValidators.maxAreaLength + 1),
            address: 'A' * (ProfileValidators.maxAddressLength + 1),
            birthDate: DateTime(2030, 1, 1),
            bloodGroup: 'Z+',
            knownBloodGroups: BloodGroups.all,
            now: DateTime(2026, 11, 2),
          );

      expect(issues.keys.toSet(), ProfileFormField.values.toSet());
    });
  });
}
