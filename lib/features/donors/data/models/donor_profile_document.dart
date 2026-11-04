import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/donors/domain/entities/donor.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// Why a `users/{uid}` public document was not turned into a [Donor].
enum DonorIssue {
  idMissing,
  notADonor,
  bloodGroupUnknown,
  fieldMalformed,
}

/// Reads a discoverable donor from a public `users/{uid}` document.
///
/// Pure function over a plain map, in the same style as `BloodRequestDocument` and
/// `ProfileDocuments`, so both the Firestore shape and the plain-Dart shape can be
/// exercised against literals with no emulator, no network and no Firebase app.
///
/// **Where the field list comes from.** Not a schema file and not a live collection:
/// it is the write side of the profile layer, `ProfileDocuments.publicFields`, which
/// is the only thing that populates this document. It writes `displayName`, `role`,
/// `isAvailable`, `updatedAt`, and — when they are present — `bloodGroup`, `photoUrl`
/// and `area` (the last only while the donor has published it). Phone, street
/// address, date of birth and gender are written to the *private* subcollection and
/// never land here, so there is nothing in this document for the mapper to leak. The
/// mapper nonetheless reads only the fields it names, so a document that somehow
/// grew a phone key would still not put it on a [Donor].
///
/// **What is refused and what is degraded, and the line between them.** A document
/// is refused when it is not a donor profile at all (`role != 'donor'`) or when its
/// blood group is a ninth spelling the backend would reject — a group badge next to
/// a donor's own that cannot be matched is a medical-severity mistake, exactly as in
/// `blood_requests`. Everything else is degraded: a blank display name is still a
/// donor, and an absent area simply means the donor did not publish one.
abstract final class DonorProfileDocument {
  /// The collection this document belongs to. Kept here so the query, the tests and
  /// `firestore.rules` all quote one string, and so the profile layer and the search
  /// layer cannot drift onto different collection names.
  static const String collection = 'users';

  /// The only role that may appear in a directory. `ProfileDocuments` writes it as
  /// `donorRole`; the rules match donors on the same value.
  static const String donorRole = 'donor';

  static Result<Donor> fromUserDoc({
    required String id,
    required Map<String, Object?> data,
  }) {
    final String uid = id.trim();
    if (uid.isEmpty) {
      return FailureResult<Donor>(
        _reject(DonorIssue.idMissing, 'document id is empty'),
      );
    }

    // Re-checked here even though the query filters on it: the seam that feeds this
    // mapper in a test hands over literal maps, and a directory that listed a
    // recipient or an unroled account as a donor would be showing the wrong people.
    if (data['role'] != donorRole) {
      return FailureResult<Donor>(
        _reject(DonorIssue.notADonor, 'role: ${_describe(data['role'])}'),
      );
    }

    final Object? group = data['bloodGroup'];
    // An absent group is degraded, not refused: a donor mid-onboarding has no group
    // yet and is still a consenting donor. A group that is *present* but is not one
    // of the eight is corrupt and is refused, so no row can show a badge the backend
    // would reject.
    if (group != null && (group is! String || !BloodGroups.isKnown(group))) {
      return FailureResult<Donor>(
        _reject(DonorIssue.bloodGroupUnknown, 'bloodGroup: ${_describe(group)}'),
      );
    }

    return Success<Donor>(
      Donor(
        uid: uid,
        displayName: _text(data['displayName']) ?? '',
        bloodGroup: group as String?,
        isAvailable: data['isAvailable'] == true,
        area: _text(data['area']),
        photoUrl: _text(data['photoUrl']),
      ),
    );
  }

  /// A trimmed non-empty string, or `null`. Blank and absent are the same thing to
  /// a reader: there is nothing to show, so the field is treated as unpublished
  /// rather than rendered as an empty line.
  static String? _text(Object? value) {
    if (value is! String) {
      return null;
    }
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// What a value *is*, for a debug message — never what it contains. A donor's
  /// name and area must not end up in a log line or a test report.
  static String _describe(Object? value) {
    if (value == null) {
      return 'absent';
    }
    return value.runtimeType.toString();
  }

  static ValidationFailure _reject(DonorIssue issue, String detail) {
    return ValidationFailure(
      messageKey: issue.name,
      debugMessage: 'Donor profile rejected: ${issue.name} ($detail)',
    );
  }
}
