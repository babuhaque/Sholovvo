import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/profile/data/profile_documents.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// A profile with every field set, so each assertion about the split has a value
/// to find (or to prove absent).
final UserProfile _profile = UserProfile(
  uid: 'uid-verified',
  displayName: '  Ayesha Rahman  ',
  bloodGroup: 'O+',
  photoUrl: 'https://example.test/ayesha.jpg',
  isAvailable: true,
  area: 'Dhanmondi, Dhaka',
  addressLine: 'House 12, Road 5',
  phone: '01712345678',
  dateOfBirth: DateTime(1996, 4, 17, 15, 30),
  gender: ProfileGender.female,
  publishAreaInSearch: true,
);

void main() {
  group('publicFields', () {
    test('writes exactly the fields the public document may hold', () {
      final Map<String, Object?> fields = ProfileDocuments.publicFields(_profile);

      expect(fields.keys.toSet(), <String>{
        'displayName',
        'role',
        'isAvailable',
        'updatedAt',
        'bloodGroup',
        'photoUrl',
        'area',
      });
      expect(fields['displayName'], 'Ayesha Rahman');
      expect(fields['role'], 'donor');
      expect(fields['isAvailable'], isTrue);
      expect(fields['bloodGroup'], 'O+');
      expect(fields['photoUrl'], 'https://example.test/ayesha.jpg');
      expect(fields['updatedAt'], FieldValue.serverTimestamp());
    });

    test('never writes a private field into the publicly readable document', () {
      final Map<String, Object?> fields = ProfileDocuments.publicFields(_profile);

      // `users/{uid}` is readable by every signed-in account: a mistake here is
      // a leak, not a layout bug.
      for (final String field in <String>[
        'phone',
        'addressLine',
        'dateOfBirth',
        'gender',
        'publishAreaInSearch',
      ]) {
        expect(fields.containsKey(field), isFalse, reason: field);
      }
    });

    test('publishes the area only while the switch is on', () {
      expect(
        ProfileDocuments.publicFields(_profile)['area'],
        'Dhanmondi, Dhaka',
      );

      // Off writes a deletion rather than a false flag: the value stops being
      // readable at all, which is what `firestore.rules` can enforce.
      expect(
        ProfileDocuments.publicFields(
          _profile.copyWith(publishAreaInSearch: false),
        )['area'],
        FieldValue.delete(),
      );
    });

    test('deletes the optional fields when they are absent or blank', () {
      final Map<String, Object?> fields = ProfileDocuments.publicFields(
        const UserProfile(
          uid: 'uid-verified',
          displayName: 'Ayesha Rahman',
          bloodGroup: '  ',
          photoUrl: '   ',
          area: 'Dhanmondi',
        ),
      );

      expect(fields['bloodGroup'], FieldValue.delete());
      expect(fields['photoUrl'], FieldValue.delete());
      // The switch is off, so the area it holds is not published either.
      expect(fields['area'], FieldValue.delete());
    });
  });

  group('privateFields', () {
    test('writes exactly the owner-only fields', () {
      final Map<String, Object?> fields = ProfileDocuments.privateFields(
        _profile,
      );

      expect(fields.keys.toSet(), <String>{
        'publishAreaInSearch',
        'updatedAt',
        'area',
        'addressLine',
        'phone',
        'gender',
        'dateOfBirth',
      });
      expect(fields['area'], 'Dhanmondi, Dhaka');
      expect(fields['addressLine'], 'House 12, Road 5');
      expect(fields['phone'], '01712345678');
      expect(fields['gender'], 'female');
      expect(fields['publishAreaInSearch'], isTrue);
      expect(fields['updatedAt'], FieldValue.serverTimestamp());
    });

    test('keeps the canonical area whatever the switch says', () {
      // The public copy is a projection; this one is the source of truth, so
      // withdrawing publication must not lose the value.
      expect(
        ProfileDocuments.privateFields(
          _profile.copyWith(publishAreaInSearch: false),
        )['area'],
        'Dhanmondi, Dhaka',
      );
    });

    test('pins a date of birth to its calendar day in UTC', () {
      final Object? stored = ProfileDocuments.privateFields(_profile)['dateOfBirth'];

      expect(stored, isA<Timestamp>());
      // A device-local instant would shift the day when read elsewhere.
      expect(
        (stored! as Timestamp).toDate().toUtc(),
        DateTime.utc(1996, 4, 17),
      );
    });

    test('deletes a cleared date of birth, gender and contact details', () {
      final Map<String, Object?> fields = ProfileDocuments.privateFields(
        const UserProfile(uid: 'uid-verified', publishAreaInSearch: true),
      );

      expect(fields['dateOfBirth'], FieldValue.delete());
      expect(fields['gender'], FieldValue.delete());
      expect(fields['area'], FieldValue.delete());
      expect(fields['addressLine'], FieldValue.delete());
      expect(fields['phone'], FieldValue.delete());
      expect(fields['publishAreaInSearch'], isTrue);
    });

    test('never duplicates the identity the public document owns', () {
      final Map<String, Object?> fields = ProfileDocuments.privateFields(
        _profile,
      );

      for (final String field in <String>[
        'displayName',
        'bloodGroup',
        'photoUrl',
        'isAvailable',
        'role',
      ]) {
        expect(fields.containsKey(field), isFalse, reason: field);
      }
    });
  });

  group('availabilityFields', () {
    test('touches only the flag, the role and the timestamp', () {
      final Map<String, Object?> fields = ProfileDocuments.availabilityFields(
        false,
      );

      expect(fields.keys.toSet(), <String>{
        'isAvailable',
        'role',
        'updatedAt',
      });
      expect(fields['isAvailable'], isFalse);
      // A rules-side donor check requires both fields, so a switch flipped on a
      // profile that was never saved still ends up matchable.
      expect(fields['role'], 'donor');
    });
  });

  group('fromDocuments', () {
    test('no public document means no profile at all', () {
      expect(
        ProfileDocuments.fromDocuments(
          uid: 'uid-verified',
          public: null,
          private: <String, dynamic>{'phone': '01712345678'},
        ),
        isNull,
      );
    });

    test('rebuilds every field from the two documents', () {
      final UserProfile? profile = ProfileDocuments.fromDocuments(
        uid: 'uid-verified',
        public: <String, dynamic>{
          'displayName': 'Ayesha Rahman',
          'bloodGroup': 'O+',
          'photoUrl': 'https://example.test/ayesha.jpg',
          'isAvailable': true,
          'area': 'Dhanmondi, Dhaka',
          'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 1)),
        },
        private: <String, dynamic>{
          'area': 'Mirpur, Dhaka',
          'addressLine': 'House 12, Road 5',
          'phone': '01712345678',
          'gender': 'female',
          'dateOfBirth': Timestamp.fromDate(DateTime.utc(1996, 4, 17)),
          'publishAreaInSearch': true,
        },
      );

      expect(profile, isNotNull);
      expect(profile!.uid, 'uid-verified');
      expect(profile.displayName, 'Ayesha Rahman');
      expect(profile.bloodGroup, 'O+');
      expect(profile.photoUrl, 'https://example.test/ayesha.jpg');
      expect(profile.isAvailable, isTrue);
      // The private copy is canonical: the public one is only a projection.
      expect(profile.area, 'Mirpur, Dhaka');
      expect(profile.addressLine, 'House 12, Road 5');
      expect(profile.phone, '01712345678');
      expect(profile.gender, ProfileGender.female);
      expect(profile.dateOfBirth, Timestamp.fromDate(DateTime.utc(1996, 4, 17)).toDate());
      expect(profile.publishAreaInSearch, isTrue);
      expect(profile.updatedAt, Timestamp.fromDate(DateTime.utc(2026, 10, 1)).toDate());
    });

    test('a profile saved before the subcollection existed still loads', () {
      final UserProfile? profile = ProfileDocuments.fromDocuments(
        uid: 'uid-verified',
        public: <String, dynamic>{
          'displayName': 'Rafiq Hasan',
          'bloodGroup': 'B+',
          'isAvailable': false,
          'area': 'Uttara, Dhaka',
        },
        private: null,
      );

      expect(profile, isNotNull);
      expect(profile!.displayName, 'Rafiq Hasan');
      // The published area is what is legitimately visible, so it is kept.
      expect(profile.area, 'Uttara, Dhaka');
      expect(profile.phone, isNull);
      expect(profile.dateOfBirth, isNull);
      expect(profile.gender, isNull);
      expect(profile.publishAreaInSearch, isFalse);
    });

    test('reads a value of the wrong type as absent rather than as a guess', () {
      final UserProfile? profile = ProfileDocuments.fromDocuments(
        uid: 'uid-verified',
        public: <String, dynamic>{
          'displayName': 42,
          'bloodGroup': 7,
          'isAvailable': 'true',
        },
        private: <String, dynamic>{
          'gender': 'unknown-value',
          'dateOfBirth': '1996-04-17',
          'phone': 1712345678,
        },
      );

      expect(profile, isNotNull);
      expect(profile!.displayName, '');
      expect(profile.bloodGroup, isNull);
      expect(profile.isAvailable, isFalse, reason: 'only a real bool counts');
      expect(profile.gender, isNull);
      expect(profile.dateOfBirth, isNull);
      expect(profile.phone, isNull);
    });

    test('trims a stored value and treats blanks as absent', () {
      final UserProfile? profile = ProfileDocuments.fromDocuments(
        uid: 'uid-verified',
        public: <String, dynamic>{'displayName': '  Ayesha  '},
        private: <String, dynamic>{'phone': '   '},
      );

      expect(profile!.displayName, 'Ayesha');
      expect(profile.phone, isNull);
    });
  });

  group('donationRecord', () {
    test('reads a confirmed record', () {
      final DonationRecord record = ProfileDocuments.donationRecord(
        'don-1',
        <String, dynamic>{
          'bloodGroup': 'O+',
          'hospitalName': 'Square Hospital',
          'status': 'confirmed',
          'donationDate': Timestamp.fromDate(DateTime.utc(2026, 3, 4)),
          'createdAt': Timestamp.fromDate(DateTime.utc(2026, 3, 5)),
        },
      );

      expect(record.id, 'don-1');
      expect(record.bloodGroup, 'O+');
      expect(record.hospitalName, 'Square Hospital');
      expect(record.status, DonationStatus.confirmed);
      expect(record.donatedAt, isNotNull);
      expect(record.recordedAt, isNotNull);
    });

    test('treats a status this build does not know as pending', () {
      // A statistic must never be inflated by a value it cannot interpret.
      for (final Object? status in <Object?>[null, 'rejected', 'CONFIRMED', 1]) {
        final DonationRecord record = ProfileDocuments.donationRecord(
          'don-1',
          <String, dynamic>{'status': status},
        );

        expect(record.status, DonationStatus.pending, reason: '$status');
      }
    });

    test('tolerates a record with no dates and no hospital', () {
      final DonationRecord record = ProfileDocuments.donationRecord(
        'don-1',
        <String, dynamic>{},
      );

      expect(record.bloodGroup, '');
      expect(record.hospitalName, '');
      expect(record.donatedAt, isNull);
      expect(record.recordedAt, isNull);
      expect(record.effectiveDate, isNull);
    });
  });

  group('sortNewestFirst', () {
    test('orders by the date each row is shown with', () {
      final List<DonationRecord> sorted = ProfileDocuments.sortNewestFirst(
        <DonationRecord>[
          _record('b', DateTime(2026, 3, 4)),
          _record('c', DateTime(2026, 9, 12)),
          _record('a', DateTime(2026, 1, 1)),
        ],
      );

      expect(
        sorted.map((DonationRecord r) => r.id),
        <String>['c', 'b', 'a'],
      );
    });

    test('sinks undated rows to the bottom instead of the top', () {
      final List<DonationRecord> sorted = ProfileDocuments.sortNewestFirst(
        <DonationRecord>[
          _undated('undated-1'),
          _record('old', DateTime(2026, 1, 1)),
          _undated('undated-2'),
          _record('new', DateTime(2026, 9, 12)),
        ],
      );

      expect(sorted.first.id, 'new');
      expect(sorted[1].id, 'old');
      expect(sorted.skip(2).map((DonationRecord r) => r.id), <String>[
        'undated-1',
        'undated-2',
      ]);
    });

    test('does not reorder the list it was given', () {
      final List<DonationRecord> original = <DonationRecord>[
        _record('old', DateTime(2026, 1, 1)),
        _record('new', DateTime(2026, 9, 12)),
      ];

      ProfileDocuments.sortNewestFirst(original);

      expect(original.first.id, 'old');
    });

    test('handles an empty list', () {
      expect(ProfileDocuments.sortNewestFirst(<DonationRecord>[]), isEmpty);
    });
  });
}

DonationRecord _record(String id, DateTime date) {
  return DonationRecord(
    id: id,
    bloodGroup: 'O+',
    hospitalName: 'Dhaka Medical College Hospital',
    status: DonationStatus.confirmed,
    donatedAt: date,
    recordedAt: date,
  );
}

DonationRecord _undated(String id) {
  return DonationRecord(
    id: id,
    bloodGroup: 'O+',
    hospitalName: 'United Hospital',
    status: DonationStatus.pending,
  );
}
