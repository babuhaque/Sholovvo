/// Which rule a profile field broke.
///
/// Values only: the domain says *what* is wrong, presentation says how to write
/// it. The same split as `AuthFieldIssue`, and for the same reason — a domain
/// that returns prose hard-codes one language into the layer that knows nothing
/// about the user.
enum ProfileFieldIssue {
  nameRequired,
  nameTooShort,
  nameTooLong,
  phoneInvalid,
  areaTooLong,
  addressTooLong,
  birthDateInFuture,
  birthDateTooOld,
  bloodGroupUnknown,
}

/// Field rules for the profile form.
///
/// Pure functions returning `null` when valid and the broken rule when not, so
/// the rules can be tested without a widget tree and the same function decides
/// what the form shows and what it submits.
abstract final class ProfileValidators {
  static const int minNameLength = 2;
  static const int maxNameLength = 60;
  static const int maxAreaLength = 80;
  static const int maxAddressLength = 160;

  /// Nothing in this app can be older than the country's telephone network
  /// having dates at all; 1900 is a sanity floor, not a medical claim.
  static const int earliestBirthYear = 1900;

  /// Bangladeshi mobile numbers in their common written forms:
  /// `01712345678`, `+8801712345678`, `8801712345678`, with spaces or dashes.
  ///
  /// Deliberately strict about the prefix (`1[3-9]`) because that is what the
  /// operators actually issue, and deliberately silent about anything else: a
  /// number this app cannot dial is better rejected at the field than stored and
  /// shown to a recipient who then cannot reach the donor.
  static final RegExp _bangladeshMobile = RegExp(
    r'^(?:\+?880|0)1[3-9]\d{8}$',
  );

  static ProfileFieldIssue? name(String? value) {
    final String name = value?.trim() ?? '';
    if (name.isEmpty) {
      return ProfileFieldIssue.nameRequired;
    }
    if (name.length < minNameLength) {
      return ProfileFieldIssue.nameTooShort;
    }
    if (name.length > maxNameLength) {
      return ProfileFieldIssue.nameTooLong;
    }
    return null;
  }

  /// Optional: an empty field is not an error, it is a donor who has not shared
  /// a number. Only a *filled* field has to be a number we could dial.
  static ProfileFieldIssue? phone(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (digits.isEmpty) {
      return null;
    }
    if (!_bangladeshMobile.hasMatch(digits)) {
      return ProfileFieldIssue.phoneInvalid;
    }
    return null;
  }

  static ProfileFieldIssue? area(String? value) {
    final String area = value?.trim() ?? '';
    if (area.length > maxAreaLength) {
      return ProfileFieldIssue.areaTooLong;
    }
    return null;
  }

  static ProfileFieldIssue? address(String? value) {
    final String address = value?.trim() ?? '';
    if (address.length > maxAddressLength) {
      return ProfileFieldIssue.addressTooLong;
    }
    return null;
  }

  /// [now] is injected so "the future" is testable without waiting for a clock
  /// to roll over, and so a device with a wrong clock cannot make every date
  /// invalid in a way no test reproduces.
  ///
  /// There is deliberately **no minimum age here**. Donation eligibility is
  /// configuration rather than code (`docs/ARCHITECTURE.md` §9), so a hard-coded
  /// 18 in a validator would be a medical claim this layer is not qualified to
  /// make. This only rejects dates that cannot be someone's date of birth.
  static ProfileFieldIssue? birthDate(DateTime? value, {DateTime? now}) {
    if (value == null) {
      return null;
    }
    final DateTime today = now ?? DateTime.now();
    final DateTime date = DateTime(value.year, value.month, value.day);
    final DateTime ceiling = DateTime(today.year, today.month, today.day);
    if (date.isAfter(ceiling)) {
      return ProfileFieldIssue.birthDateInFuture;
    }
    if (date.year < earliestBirthYear) {
      return ProfileFieldIssue.birthDateTooOld;
    }
    return null;
  }

  /// Only ever called with a value picked from [BloodGroups.all]; the check is
  /// here so a document edited elsewhere cannot put a ninth group on screen.
  static ProfileFieldIssue? bloodGroup(String? value, List<String> known) {
    if (value == null || value.isEmpty) {
      return null;
    }
    if (!known.contains(value)) {
      return ProfileFieldIssue.bloodGroupUnknown;
    }
    return null;
  }

  /// Runs the whole form at once and returns the first issue per field.
  static Map<ProfileFormField, ProfileFieldIssue> validate({
    required String name,
    required String? phone,
    required String? area,
    required String? address,
    required DateTime? birthDate,
    required String? bloodGroup,
    required List<String> knownBloodGroups,
    DateTime? now,
  }) {
    final Map<ProfileFormField, ProfileFieldIssue> issues =
        <ProfileFormField, ProfileFieldIssue>{};

    void record(ProfileFormField field, ProfileFieldIssue? issue) {
      if (issue != null) {
        issues[field] = issue;
      }
    }

    record(ProfileFormField.name, ProfileValidators.name(name));
    record(ProfileFormField.phone, ProfileValidators.phone(phone));
    record(ProfileFormField.area, ProfileValidators.area(area));
    record(ProfileFormField.address, ProfileValidators.address(address));
    record(
      ProfileFormField.birthDate,
      ProfileValidators.birthDate(birthDate, now: now),
    );
    record(
      ProfileFormField.bloodGroup,
      ProfileValidators.bloodGroup(bloodGroup, knownBloodGroups),
    );
    return issues;
  }
}

/// The fields a validation report can name, so the form can attach each issue
/// to the widget that owns it.
enum ProfileFormField { name, phone, area, address, birthDate, bloodGroup }
