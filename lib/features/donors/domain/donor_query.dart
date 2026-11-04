import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// What a donor search is asking for.
///
/// Three optional refinements over the one invariant every discovery read
/// carries — `role == 'donor'` — because the public profile document is the only
/// thing a search may read, and a document is only a donor's public profile when
/// the role says so. Everything else narrows that set:
///
/// * [bloodGroup] is `null` for "any group" or one of the eight the rules accept.
///   A free-text ninth spelling is not a search, it is a typo that would return
///   nothing, so [normalised] drops it to `null` rather than firing a query that
///   cannot match. The group is matched by equality in the query, never filtered
///   after the read, which keeps the result exact and the read cheap.
/// * [availableOnly] defaults to `true`: someone looking for blood wants the
///   donors who are offering it right now. Turning it off widens to everyone who
///   has ever consented, which is the honest "show all" of the switch.
/// * [area] is a coarse, case-insensitive-equality match on the *published* area.
///   Firestore matches it exactly, so [normalised] only trims and blank-checks it;
///   a donor who published "Dhanmondi" is found by "Dhanmondi" and not by
///   "dhankundi", and no spelling is silently corrected into a place the donor
///   did not write. Distance and "near me" are not here on purpose: this stage
///   only has a text area on the public document, not coordinates, and a radius
///   query over a field that does not exist would be a claim the data cannot
///   support.
///
/// This is a value object. It is compared by identity so a controller can tell
/// whether a filter tap actually changed the question before paying for a read.
@immutable
final class DonorQuery {
  const DonorQuery({
    this.bloodGroup,
    this.area,
    this.availableOnly = true,
  });

  /// The default ask the screen opens with: available donors, any group, any area.
  static const DonorQuery any = DonorQuery();

  final String? bloodGroup;
  final String? area;
  final bool availableOnly;

  /// Whether this search narrows the donor pool at all. The empty state reads this
  /// to decide between "no donors found" and the quieter truth that the whole
  /// consented directory is genuinely empty, which are different sentences to a
  /// person who just tapped "Find donors".
  bool get isDefault => bloodGroup == null && (area == null || area!.isEmpty);

  /// The query as it should go to the database: trimmed, blanks collapsed to
  /// `null`, and a blood group that is not one of the eight dropped so a stray
  /// spelling cannot produce an empty result the screen would report as "nobody".
  ///
  /// Idempotent: normalising an already-normalised query returns an equal one.
  DonorQuery normalised() {
    final String? group = bloodGroup?.trim();
    final String? trimmedArea = area?.trim();
    return DonorQuery(
      bloodGroup: group == null || group.isEmpty || !BloodGroups.isKnown(group)
          ? null
          : group,
      area: trimmedArea == null || trimmedArea.isEmpty ? null : trimmedArea,
      availableOnly: availableOnly,
    );
  }

  DonorQuery copyWith({
    String? bloodGroup,
    bool clearBloodGroup = false,
    String? area,
    bool clearArea = false,
    bool? availableOnly,
  }) {
    return DonorQuery(
      bloodGroup: clearBloodGroup ? null : bloodGroup ?? this.bloodGroup,
      area: clearArea ? null : area ?? this.area,
      availableOnly: availableOnly ?? this.availableOnly,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DonorQuery &&
      other.bloodGroup == bloodGroup &&
      other.area == area &&
      other.availableOnly == availableOnly;

  @override
  int get hashCode => Object.hash(bloodGroup, area, availableOnly);

  @override
  String toString() =>
      'DonorQuery(group: ${bloodGroup ?? 'any'}, '
      'area: ${area ?? 'any'}, availableOnly: $availableOnly)';
}
