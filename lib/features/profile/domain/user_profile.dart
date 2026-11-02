import 'package:flutter/foundation.dart';

/// The eight groups a donor can hold.
///
/// The same eight strings `firestore.rules` accepts on
/// `donation_history.bloodGroup`; a ninth value here would be a group the
/// backend rejects, so the list is closed rather than free text.
abstract final class BloodGroups {
  static const List<String> all = <String>[
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static bool isKnown(String? group) => group != null && all.contains(group);
}

/// Gender as the profile records it.
///
/// An enum rather than free text so the value cannot become a spelling variant
/// of itself, and `preferNotToSay` is a real option instead of an empty field
/// that looks like an unanswered question.
enum ProfileGender { female, male, other, preferNotToSay }

/// Which part of the profile is filled in.
///
/// Used only for the completion indicator. Booleans are deliberately absent: a
/// switch always has a value, so counting one would inflate a brand-new profile
/// to "1 of 8 complete" before the donor has told us anything.
enum ProfileField { photo, name, bloodGroup, area, phone, dateOfBirth, gender }

/// Everything the owner of a profile can see and edit.
///
/// One model for two documents, because the split between them is a storage
/// concern rather than a product one: `users/{uid}` is readable by every
/// signed-in user, `users/{uid}/private/profile` only by its owner (see
/// `firestore.rules`). `ProfileRepository` decides which field goes where.
///
/// Every field except [uid] is nullable or defaulted on purpose. A profile that
/// has never been filled in is a real state, and the screen says "Not set yet"
/// rather than inventing a placeholder blood group — a wrong group on a donor
/// profile is a medical-severity mistake, not a cosmetic one.
@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    this.displayName = '',
    this.bloodGroup,
    this.photoUrl,
    this.isAvailable = false,
    this.area,
    this.addressLine,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.publishAreaInSearch = false,
    this.updatedAt,
  });

  /// The profile a first edit starts from: the account's registration name and
  /// nothing else.
  ///
  /// Seeding the name from the auth account is not an invented value — it is
  /// what the person typed when they registered, carried across so the form is
  /// not blank in its first field.
  factory UserProfile.draft({required String uid, String? displayName}) {
    return UserProfile(uid: uid, displayName: displayName?.trim() ?? '');
  }

  /// Firebase Auth uid. The document is always addressed by this value, and the
  /// repository refuses a payload that names anyone else.
  final String uid;

  final String displayName;

  /// One of [BloodGroups.all], or null when the donor has not chosen one.
  final String? bloodGroup;

  /// Absolute URL of the profile photo.
  ///
  /// Written only by the photo flow (Stage 6), and only after an upload has
  /// succeeded: the URL is published by a narrow write of its own, so a failed
  /// upload can never leave this field pointing at something that is not there.
  final String? photoUrl;

  /// The donor's own switch. Nothing in the app may flip it on their behalf.
  final bool isAvailable;

  /// Coarse location ("Dhanmondi, Dhaka"). Stored privately; published to the
  /// public document only when [publishAreaInSearch] is on.
  final String? area;

  /// Street-level address. Always private, never published by any switch.
  final String? addressLine;

  final String? phone;

  final DateTime? dateOfBirth;
  final ProfileGender? gender;

  /// Whether [area] is copied into the publicly readable document.
  ///
  /// Off by default. When off the area exists only in the owner-only
  /// subcollection, so no other account can read it — the absence is enforced
  /// by `firestore.rules`, not by a client-side branch.
  final bool publishAreaInSearch;

  final DateTime? updatedAt;

  /// The seven facts the completion indicator counts.
  List<ProfileField> get missingFields => <ProfileField>[
    if (!_hasPhoto) ProfileField.photo,
    if (displayName.trim().length < 2) ProfileField.name,
    if (!BloodGroups.isKnown(bloodGroup)) ProfileField.bloodGroup,
    if (_isBlank(area)) ProfileField.area,
    if (_isBlank(phone)) ProfileField.phone,
    if (dateOfBirth == null) ProfileField.dateOfBirth,
    if (gender == null) ProfileField.gender,
  ];

  int get completedCount => ProfileField.values.length - missingFields.length;

  bool get isComplete => missingFields.isEmpty;

  bool get hasPhoto => _hasPhoto;

  // A URL typed into a text field can be an empty string; treat that as absent
  // rather than letting it count as a completed field.
  bool get _hasPhoto {
    final String? url = photoUrl?.trim();
    return url != null && url.isNotEmpty;
  }

  static bool _isBlank(String? value) => (value?.trim() ?? '').isEmpty;

  /// Narrow on purpose: only the two flags are ever changed in place. Editing
  /// text fields builds a fresh [UserProfile] from the form, which makes it
  /// impossible for a `copyWith` to silently drop a field it forgot to forward.
  UserProfile copyWith({bool? isAvailable, bool? publishAreaInSearch}) {
    return UserProfile(
      uid: uid,
      displayName: displayName,
      bloodGroup: bloodGroup,
      photoUrl: photoUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      area: area,
      addressLine: addressLine,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      publishAreaInSearch: publishAreaInSearch ?? this.publishAreaInSearch,
      updatedAt: updatedAt,
    );
  }

  /// The same profile pointing at a different photo, or at none.
  ///
  /// A named method rather than another `copyWith` parameter: `photoUrl` is
  /// nullable, so `copyWith(photoUrl: null)` could not say whether it means
  /// "clear it" or "leave it", and telling those two apart is exactly what the
  /// removal flow does.
  UserProfile withPhoto(String? photoUrl) {
    return UserProfile(
      uid: uid,
      displayName: displayName,
      bloodGroup: bloodGroup,
      photoUrl: photoUrl,
      isAvailable: isAvailable,
      area: area,
      addressLine: addressLine,
      phone: phone,
      dateOfBirth: dateOfBirth,
      gender: gender,
      publishAreaInSearch: publishAreaInSearch,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.uid == uid &&
      other.displayName == displayName &&
      other.bloodGroup == bloodGroup &&
      other.photoUrl == photoUrl &&
      other.isAvailable == isAvailable &&
      other.area == area &&
      other.addressLine == addressLine &&
      other.phone == phone &&
      other.dateOfBirth == dateOfBirth &&
      other.gender == gender &&
      other.publishAreaInSearch == publishAreaInSearch;

  @override
  int get hashCode => Object.hash(
    uid,
    displayName,
    bloodGroup,
    photoUrl,
    isAvailable,
    area,
    addressLine,
    phone,
    dateOfBirth,
    gender,
    publishAreaInSearch,
  );

  @override
  String toString() =>
      'UserProfile(uid: $uid, bloodGroup: $bloodGroup, '
      'available: $isAvailable, complete: $isComplete)';
}
