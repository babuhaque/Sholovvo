import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// The exact shape written to each document, and the exact shape read back.
///
/// Kept as pure functions over plain maps so both directions can be tested
/// against literal maps — no emulator, no network, no Firebase app. That matters
/// here more than usual: a field written to the wrong document is not a
/// cosmetic bug in this app, it is a privacy leak (`users/{uid}` is readable by
/// every signed-in account) or a profile that silently loses data.
///
/// **The split (enforced by `firestore.rules`, not by this file):**
///
/// | Document | Readable by | Holds |
/// | --- | --- | --- |
/// | `users/{uid}` | any signed-in user | display name, role, blood group, availability, photo URL, the discovery-consent flag *only* while the donor has opted in, and the area *only* when the donor published it |
/// | `users/{uid}/private/profile` | the owner only | area, street address, phone, date of birth, gender, the publication flag, the discoverability flag |
///
/// `area` appears in both on purpose: the private copy is the source of truth,
/// the public copy is a projection that exists only while the donor has switched
/// publication on. Un-publishing writes `FieldValue.delete()` for the public
/// copy, so the value becomes unreadable rather than merely hidden.
///
/// `allowDonorDiscovery` uses the same shape as `area`: the private document
/// carries the source-of-truth boolean, the public document carries a
/// projection that exists only while the donor has opted in. Opting out writes
/// `FieldValue.delete()` for the public copy so the discovery query
/// `where('allowDonorDiscovery', isEqualTo: true)` stops matching, and a legacy
/// document that predates Stage 9.5 has no field at all, which the query also
/// does not match. Existing donors are therefore not silently re-listed on
/// upgrade — explicit, per-donor opt-in is the only path to the directory.
abstract final class ProfileDocuments {
  static const String privateCollection = 'private';
  static const String privateDocument = 'profile';

  /// The only role this app currently has. `firestore.rules` matches donors on
  /// `role == 'donor'`, so the field is written from the first save rather than
  /// left absent until a later stage notices.
  static const String donorRole = 'donor';

  static Map<String, Object?> publicFields(UserProfile profile) {
    final Map<String, Object?> fields = <String, Object?>{
      'displayName': profile.displayName.trim(),
      'role': donorRole,
      'isAvailable': profile.isAvailable,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _putText(fields, 'bloodGroup', profile.bloodGroup);
    _putText(fields, 'photoUrl', profile.photoUrl);
    // Published only while the switch is on. `_putText` collapses a null or
    // blank value to a field deletion, which is what makes switching it off
    // actually remove the data instead of hiding it behind a flag.
    _putText(
      fields,
      'area',
      profile.publishAreaInSearch ? profile.area : null,
    );
    // Discovery consent is projected onto the public document only when the
    // donor has explicitly opted in. Off writes a deletion, not a false flag:
    // the field stops being present, which is what the discovery query
    // (`where('allowDonorDiscovery', isEqualTo: true)`) matches against. A
    // legacy document that has never carried this key remains opted-out, so
    // upgrading the app does not silently re-list anyone.
    fields['allowDonorDiscovery'] = profile.allowDonorDiscovery
        ? true
        : FieldValue.delete();
    return fields;
  }

  static Map<String, Object?> privateFields(UserProfile profile) {
    final Map<String, Object?> fields = <String, Object?>{
      'publishAreaInSearch': profile.publishAreaInSearch,
      'allowDonorDiscovery': profile.allowDonorDiscovery,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // The canonical copy of the area lives here whatever the switch says.
    _putText(fields, 'area', profile.area);
    _putText(fields, 'addressLine', profile.addressLine);
    _putText(fields, 'phone', profile.phone);
    _putText(fields, 'gender', profile.gender?.name);
    fields['dateOfBirth'] = profile.dateOfBirth == null
        ? FieldValue.delete()
        : Timestamp.fromDate(_asUtcDate(profile.dateOfBirth!));
    return fields;
  }

  /// The narrow write used by the availability switch.
  ///
  /// Only fields the switch is allowed to touch. `role` is included so a donor
  /// who flips the switch on a profile that was never saved still ends up
  /// matchable, because a rules-side donor check requires both fields. The
  /// availability switch deliberately does NOT touch `allowDonorDiscovery`:
  /// a donor who becomes available has not thereby opted into directory
  /// listing, and a donor who becomes unavailable has not thereby withdrawn
  /// consent either. Those are two independent decisions.
  static Map<String, Object?> availabilityFields(bool isAvailable) {
    return <String, Object?>{
      'isAvailable': isAvailable,
      'role': donorRole,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// The narrow write used by the photo sheet.
  ///
  /// `_putText` collapses a null or blank value to a field deletion, so removing
  /// a photo removes the field instead of storing an empty string that every
  /// reader downstream would have to special-case. `updatedAt` is refreshed so
  /// the document still records when it last changed.
  static Map<String, Object?> photoFields(String? photoUrl) {
    final Map<String, Object?> fields = <String, Object?>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    _putText(fields, 'photoUrl', photoUrl);
    return fields;
  }

  /// Rebuilds a profile from the two documents.
  ///
  /// Returns `null` when the public document does not exist: that is "nothing
  /// has been saved yet", and it is not the same thing as a profile whose fields
  /// are blank. A missing private document is tolerated — a profile saved before
  /// the subcollection existed is still a profile — and the public area is used
  /// as a fallback so the screen does not lose what it can still legitimately
  /// show.
  static UserProfile? fromDocuments({
    required String uid,
    required Map<String, dynamic>? public,
    required Map<String, dynamic>? private,
  }) {
    if (public == null) {
      return null;
    }

    final Map<String, dynamic> privateData = private ?? <String, dynamic>{};
    final String? privateArea = _text(privateData['area']);

    return UserProfile(
      uid: uid,
      displayName: _text(public['displayName']) ?? '',
      bloodGroup: _text(public['bloodGroup']),
      photoUrl: _text(public['photoUrl']),
      isAvailable: public['isAvailable'] == true,
      area: privateArea ?? _text(public['area']),
      addressLine: _text(privateData['addressLine']),
      phone: _text(privateData['phone']),
      dateOfBirth: _date(privateData['dateOfBirth']),
      gender: _gender(privateData['gender']),
      publishAreaInSearch: privateData['publishAreaInSearch'] == true,
      // The private copy is the source of truth; a missing or non-bool value
      // reads as opted-out, so a legacy document that predates Stage 9.5
      // stays hidden from the directory until its owner opts in explicitly.
      allowDonorDiscovery: privateData['allowDonorDiscovery'] == true,
      updatedAt: _date(public['updatedAt']),
    );
  }

  /// One `donation_history` document.
  ///
  /// An unknown `status` is read as `pending`, never as `confirmed`: a statistic
  /// must not be inflated by a value this build does not understand.
  static DonationRecord donationRecord(
    String id,
    Map<String, dynamic> data,
  ) {
    return DonationRecord(
      id: id,
      bloodGroup: _text(data['bloodGroup']) ?? '',
      hospitalName: _text(data['hospitalName']) ?? '',
      status: data['status'] == 'confirmed'
          ? DonationStatus.confirmed
          : DonationStatus.pending,
      donatedAt: _date(data['donationDate']),
      recordedAt: _date(data['createdAt']),
    );
  }

  /// Newest first, by the date the row is shown with.
  ///
  /// Sorted on the client rather than with `orderBy` because Firestore would
  /// need a composite index for "equality on donorUid + order by createdAt",
  /// and creating an index means deploying configuration — something this stage
  /// is not allowed to do. A donor's history is small enough that sorting it in
  /// memory costs nothing.
  static List<DonationRecord> sortNewestFirst(List<DonationRecord> records) {
    final List<DonationRecord> sorted = List<DonationRecord>.of(records);
    sorted.sort((DonationRecord a, DonationRecord b) {
      final DateTime? left = a.effectiveDate;
      final DateTime? right = b.effectiveDate;
      if (left == null && right == null) {
        return 0;
      }
      // Undated rows sink to the bottom rather than jumping to the top.
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return right.compareTo(left);
    });
    return sorted;
  }

  /// Writes a trimmed string, or deletes the field when there is nothing to
  /// store. Deleting rather than writing `null` keeps a document free of empty
  /// keys, so "has a phone number" is a presence check everywhere downstream.
  static void _putText(
    Map<String, Object?> fields,
    String key,
    String? value,
  ) {
    final String? trimmed = value?.trim();
    fields[key] = (trimmed == null || trimmed.isEmpty)
        ? FieldValue.delete()
        : trimmed;
  }

  static String? _text(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime? _date(Object? value) {
    return switch (value) {
      Timestamp() => value.toDate(),
      DateTime() => value,
      _ => null,
    };
  }

  static ProfileGender? _gender(Object? value) {
    if (value is! String) {
      return null;
    }
    for (final ProfileGender gender in ProfileGender.values) {
      if (gender.name == value) {
        return gender;
      }
    }
    return null;
  }

  // A date of birth is a calendar day. Storing the device's instant would shift
  // it by a time zone when read on another device, so the day is pinned to UTC
  // midnight exactly once, here.
  static DateTime _asUtcDate(DateTime value) {
    return DateTime.utc(value.year, value.month, value.day);
  }
}
