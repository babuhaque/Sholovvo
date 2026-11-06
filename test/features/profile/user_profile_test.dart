import 'package:flutter_test/flutter_test.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

import '../../support/fake_profile_repository.dart';

/// Every field filled in, so the completion indicator has something complete to
/// count. Deliberately built here rather than imported: the fixture profiles are
/// partial on purpose, and `DateTime` cannot be a const value.
final UserProfile _completeProfile = UserProfile(
  uid: 'uid-verified',
  displayName: 'Ayesha Rahman',
  bloodGroup: 'O+',
  photoUrl: 'https://example.test/ayesha.jpg',
  isAvailable: true,
  area: 'Dhanmondi, Dhaka',
  addressLine: 'House 12, Road 5',
  phone: '01712345678',
  dateOfBirth: DateTime(1996, 4, 17),
  gender: ProfileGender.female,
  publishAreaInSearch: true,
);

void main() {
  group('BloodGroups', () {
    test('holds the eight groups the rules accept', () {
      expect(BloodGroups.all, hasLength(8));
      expect(BloodGroups.all.toSet(), hasLength(8));
      for (final String group in <String>['A+', 'AB-', 'O-', 'B+']) {
        expect(BloodGroups.isKnown(group), isTrue, reason: group);
      }
    });

    test('rejects null, empty and near-miss values', () {
      expect(BloodGroups.isKnown(null), isFalse);
      expect(BloodGroups.isKnown(''), isFalse);
      expect(BloodGroups.isKnown('C+'), isFalse);
      expect(BloodGroups.isKnown('o+'), isFalse);
      expect(BloodGroups.isKnown('O'), isFalse);
    });
  });

  group('UserProfile.draft', () {
    test('starts from the registration name and nothing else', () {
      final UserProfile draft = UserProfile.draft(
        uid: 'uid-new',
        displayName: '  Rafiq Hasan  ',
      );

      expect(draft.uid, 'uid-new');
      expect(draft.displayName, 'Rafiq Hasan');
      expect(draft.bloodGroup, isNull);
      expect(draft.phone, isNull);
      expect(draft.isAvailable, isFalse);
      expect(draft.publishAreaInSearch, isFalse);
      // Stage 9.5: a fresh draft is not discoverable. Directory listing needs
      // an explicit opt-in, so nothing the onboarding flow can do by default
      // should place a new donor in front of other users' searches.
      expect(draft.allowDonorDiscovery, isFalse);
      // The name carried over from registration is the only field that counts.
      expect(draft.completedCount, 1);
      expect(draft.missingFields, isNot(contains(ProfileField.name)));
    });

    test('survives an account with no name', () {
      final UserProfile draft = UserProfile.draft(uid: 'uid-new');

      expect(draft.displayName, '');
      expect(draft.missingFields, contains(ProfileField.name));
    });
  });

  group('completion', () {
    test('counts nothing for a profile with no data', () {
      const UserProfile blank = UserProfile(uid: 'uid-verified');

      expect(blank.missingFields, ProfileField.values);
      expect(blank.completedCount, 0);
      expect(blank.isComplete, isFalse);
      expect(blank.hasPhoto, isFalse);
    });

    test('counts every field of a complete profile', () {
      expect(_completeProfile.missingFields, isEmpty);
      expect(
        _completeProfile.completedCount,
        ProfileField.values.length,
      );
      expect(_completeProfile.isComplete, isTrue);
    });

    test('names exactly what a partial profile is missing', () {
      // Name, blood group and gender are set; the other four are not.
      expect(partialProfile.missingFields, <ProfileField>[
        ProfileField.photo,
        ProfileField.area,
        ProfileField.phone,
        ProfileField.dateOfBirth,
      ]);
      expect(partialProfile.completedCount, 3);
      expect(partialProfile.isComplete, isFalse);
    });

    test('a blank string is an absent value, not a filled one', () {
      const UserProfile blankStrings = UserProfile(
        uid: 'uid-verified',
        displayName: 'Ayesha Rahman',
        photoUrl: '   ',
        area: '  ',
        phone: '',
        bloodGroup: 'O+',
        gender: ProfileGender.female,
        dateOfBirth: null,
      );

      expect(blankStrings.hasPhoto, isFalse);
      expect(blankStrings.missingFields, contains(ProfileField.photo));
      expect(blankStrings.missingFields, contains(ProfileField.area));
      expect(blankStrings.missingFields, contains(ProfileField.phone));
    });

    test('a one-letter name does not count as set', () {
      const UserProfile initials = UserProfile(
        uid: 'uid-verified',
        displayName: ' A ',
      );

      expect(initials.missingFields, contains(ProfileField.name));
    });

    test('an unknown blood group does not count as set', () {
      const UserProfile wrongGroup = UserProfile(
        uid: 'uid-verified',
        displayName: 'Ayesha Rahman',
        bloodGroup: 'C+',
      );

      expect(wrongGroup.missingFields, contains(ProfileField.bloodGroup));
    });

    test('a switch is not one of the counted fields', () {
      // Availability defaults to off and is still the same 0 of 7: a flag that
      // always has a value would otherwise inflate a brand-new profile.
      const UserProfile available = UserProfile(
        uid: 'uid-verified',
        isAvailable: true,
      );

      expect(available.completedCount, 0);
    });
  });

  group('copyWith', () {
    test('changes only the three flags it is allowed to touch', () {
      final UserProfile hidden = _completeProfile.copyWith(
        publishAreaInSearch: false,
      );

      expect(hidden.publishAreaInSearch, isFalse);
      expect(hidden.isAvailable, isTrue);
      expect(hidden.allowDonorDiscovery, isFalse);
      // Everything else is carried over exactly, including the nullable fields.
      expect(hidden.uid, _completeProfile.uid);
      expect(hidden.displayName, _completeProfile.displayName);
      expect(hidden.bloodGroup, _completeProfile.bloodGroup);
      expect(hidden.photoUrl, _completeProfile.photoUrl);
      expect(hidden.coverUrl, _completeProfile.coverUrl);
      expect(hidden.area, _completeProfile.area);
      expect(hidden.addressLine, _completeProfile.addressLine);
      expect(hidden.phone, _completeProfile.phone);
      expect(hidden.dateOfBirth, _completeProfile.dateOfBirth);
      expect(hidden.gender, _completeProfile.gender);
    });

    test('leaves a flag alone when it is not named', () {
      expect(_completeProfile.copyWith().isAvailable, isTrue);
      expect(_completeProfile.copyWith().publishAreaInSearch, isTrue);
      expect(_completeProfile.copyWith().allowDonorDiscovery, isFalse);
      expect(
        _completeProfile.copyWith(isAvailable: false).publishAreaInSearch,
        isTrue,
      );
      // Availability and discovery are independent — flipping one must not
      // disturb the other, and neither should disturb publication of the area.
      expect(
        _completeProfile.copyWith(isAvailable: false).allowDonorDiscovery,
        isFalse,
      );
      expect(
        _completeProfile.copyWith(allowDonorDiscovery: true).isAvailable,
        isTrue,
      );
      expect(
        _completeProfile.copyWith(allowDonorDiscovery: true).publishAreaInSearch,
        isTrue,
      );
    });

    test('toggles allowDonorDiscovery without disturbing the other flags', () {
      final UserProfile optedIn = _completeProfile.copyWith(
        allowDonorDiscovery: true,
      );

      expect(optedIn.allowDonorDiscovery, isTrue);
      expect(optedIn.isAvailable, _completeProfile.isAvailable);
      expect(
        optedIn.publishAreaInSearch,
        _completeProfile.publishAreaInSearch,
      );
    });
  });

  group('withPhoto', () {
    test('carries every flag across, including allowDonorDiscovery', () {
      final UserProfile original = _completeProfile.copyWith(
        allowDonorDiscovery: true,
      );
      final UserProfile rePhotoed = original.withPhoto(
        'https://example.test/new.jpg',
      );

      expect(rePhotoed.photoUrl, 'https://example.test/new.jpg');
      expect(rePhotoed.allowDonorDiscovery, isTrue);
      expect(rePhotoed.publishAreaInSearch, isTrue);
      expect(rePhotoed.isAvailable, isTrue);
    });

    test('clearing the photo does not clear consent', () {
      final UserProfile optedIn = _completeProfile.copyWith(
        allowDonorDiscovery: true,
      );
      final UserProfile cleared = optedIn.withPhoto(null);

      expect(cleared.photoUrl, isNull);
      expect(cleared.allowDonorDiscovery, isTrue);
    });

    test('does not disturb the cover', () {
      final UserProfile withCover = _completeProfile.withCover(
        'https://example.test/cover.jpg',
      );
      final UserProfile rePhotoed = withCover.withPhoto(
        'https://example.test/new.jpg',
      );

      expect(rePhotoed.photoUrl, 'https://example.test/new.jpg');
      expect(rePhotoed.coverUrl, 'https://example.test/cover.jpg');
    });
  });

  group('withCover', () {
    test('carries every other field across, including the avatar', () {
      final UserProfile reCovered = _completeProfile.withCover(
        'https://example.test/new-cover.jpg',
      );

      expect(reCovered.coverUrl, 'https://example.test/new-cover.jpg');
      expect(reCovered.hasCover, isTrue);
      expect(reCovered.photoUrl, _completeProfile.photoUrl);
      expect(reCovered.displayName, _completeProfile.displayName);
      expect(reCovered.isAvailable, isTrue);
    });

    test('clearing the cover leaves the avatar untouched', () {
      final UserProfile withCover = _completeProfile.withCover(
        'https://example.test/cover.jpg',
      );
      final UserProfile cleared = withCover.withCover(null);

      expect(cleared.coverUrl, isNull);
      expect(cleared.hasCover, isFalse);
      expect(cleared.photoUrl, _completeProfile.photoUrl);
    });

    test('a cover alone does not count toward completion', () {
      // Completion is about the seven facts that make a donor matchable; a cover
      // is decoration, so a profile with a cover but no photo still misses the
      // photo and its total count is unchanged.
      final UserProfile coverOnly = UserProfile.draft(uid: 'uid-verified')
          .withCover('https://example.test/cover.jpg');

      expect(coverOnly.hasCover, isTrue);
      expect(coverOnly.hasPhoto, isFalse);
      expect(coverOnly.missingFields, contains(ProfileField.photo));
      expect(
        coverOnly.completedCount,
        UserProfile.draft(uid: 'uid-verified').completedCount,
      );
    });
  });

  group('equality', () {
    test('is by value', () {
      expect(_completeProfile, equals(_completeProfile.copyWith()));
      expect(_completeProfile.hashCode, _completeProfile.copyWith().hashCode);
    });

    test('distinguishes a changed flag and a changed field', () {
      expect(
        _completeProfile,
        isNot(equals(_completeProfile.copyWith(isAvailable: false))),
      );
      expect(
        _completeProfile,
        isNot(equals(_completeProfile.copyWith(allowDonorDiscovery: true))),
      );
      // Sanity: two profiles that differ only in a shared consent flag are
      // equal, and one that differs on the flag from the base is not.
      expect(
        _completeProfile.copyWith(allowDonorDiscovery: true),
        equals(_completeProfile.copyWith(allowDonorDiscovery: true)),
      );
      expect(
        _completeProfile,
        isNot(equals(UserProfile.draft(uid: 'uid-verified'))),
      );
      expect(
        const UserProfile(uid: 'uid-a'),
        isNot(equals(const UserProfile(uid: 'uid-b'))),
      );
      // A cover is part of the value: two otherwise identical profiles that
      // differ only by their banner are not equal.
      expect(
        _completeProfile,
        isNot(equals(_completeProfile.withCover('https://example.test/c.jpg'))),
      );
    });
  });
}
