import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// Profile reads and writes, expressed without any SDK type.
///
/// Two properties are part of the contract rather than the implementation:
///
/// 1. **There is no uid parameter.** Every method reads and writes the signed-in
///    account, whose id comes from the session. A screen therefore has no way to
///    address another person's document, which is what "users can edit only
///    their own profile" means at this layer.
/// 2. **A payload naming anyone else is refused.** [saveProfile] still checks
///    the uid it is handed, so a future caller that builds a profile from the
///    wrong source fails loudly instead of writing to the wrong document.
abstract interface class ProfileRepository {
  /// The signed-in user's profile, or `null` while no profile document exists.
  ///
  /// `null` and "an empty profile" are different states: the first has no
  /// document at all (nothing has been saved yet), the second has one whose
  /// fields happen to be blank. The screens render them differently.
  Stream<UserProfile?> watchProfile();

  /// Creates or updates the signed-in user's profile.
  Future<Result<void>> saveProfile(UserProfile profile);

  /// The signed-in donor's own donation history, newest first.
  ///
  /// Owner-only: `firestore.rules` allows reading a record only when its
  /// `donorUid` is the caller, so this cannot be used to inspect anyone else.
  Future<Result<DonationHistory>> loadDonationHistory();

  /// Flips the donor's availability flag and nothing else.
  ///
  /// Separate from [saveProfile] because it is the one control on the screen a
  /// donor may use without opening a form, and because the rules match donors on
  /// this exact field: writing it alone keeps the write small enough to reason
  /// about, and keeps a half-finished form from changing who can be matched.
  Future<Result<void>> setAvailability(bool isAvailable);

  /// Points the donor card at [photoUrl], or removes the field when `null`.
  ///
  /// A narrow write for the same reason as [setAvailability]: the photo is
  /// chosen from the profile screen, not from the edit form, so publishing it
  /// must not carry the form's other fields along. Otherwise a half-filled form
  /// left open would overwrite a freshly uploaded URL with the stale one it was
  /// seeded from.
  Future<Result<void>> setPhotoUrl(String? photoUrl);

  /// Points the profile banner at [coverUrl], or removes the field when `null`.
  ///
  /// A narrow write for the same reason as [setPhotoUrl]: the cover is chosen
  /// from the profile screen rather than the edit form, so publishing it must
  /// not carry the form's other fields along. It writes only the public
  /// `coverUrl`; nothing in the private subcollection changes because a cover is
  /// a public banner, not PII.
  Future<Result<void>> setCoverUrl(String? coverUrl);
}
