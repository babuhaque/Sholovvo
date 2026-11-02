import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo.dart';
import 'package:sholovvo_app/features/profile/domain/profile_validators.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Turns a broken profile rule into a sentence in the active language.
///
/// Declared on `ProfileFieldIssue?` so a form can pass the validator's result
/// straight through: a `null` issue yields a `null` message, which is exactly
/// what `SolovvoTextField.errorText` expects.
extension ProfileFieldIssueMessage on ProfileFieldIssue? {
  String? message(AppLocalizations l10n) => switch (this) {
    null => null,
    ProfileFieldIssue.nameRequired => l10n.errorNameRequired,
    ProfileFieldIssue.nameTooShort => l10n.errorNameTooShort,
    // The limits live in the validators, so the sentence quotes the rule rather
    // than repeating the number in two catalogues.
    ProfileFieldIssue.nameTooLong => l10n.errorNameTooLong(
      ProfileValidators.maxNameLength,
    ),
    ProfileFieldIssue.phoneInvalid => l10n.errorPhoneInvalid,
    ProfileFieldIssue.areaTooLong => l10n.errorAreaTooLong(
      ProfileValidators.maxAreaLength,
    ),
    ProfileFieldIssue.addressTooLong => l10n.errorAddressTooLong(
      ProfileValidators.maxAddressLength,
    ),
    ProfileFieldIssue.birthDateInFuture => l10n.errorDobFuture,
    ProfileFieldIssue.birthDateTooOld => l10n.errorDobTooOld(
      ProfileValidators.earliestBirthYear,
    ),
    ProfileFieldIssue.bloodGroupUnknown => l10n.errorBloodGroupUnknown,
  };
}

/// Sentence for a photo that was refused before it was uploaded.
///
/// Declared on `PhotoIssue?` for the same reason as [ProfileFieldIssueMessage]: a
/// `null` issue yields a `null` message, so a caller can fall back to the generic
/// sentence in one expression. The size limit is quoted from the validator, so
/// the two catalogues cannot drift from the rule that is actually enforced.
String? photoIssueMessage(AppLocalizations l10n, PhotoIssue? issue) {
  return switch (issue) {
    null => null,
    PhotoIssue.empty => l10n.errorPhotoEmpty,
    PhotoIssue.tooLarge => l10n.errorPhotoTooLarge(PhotoValidator.maxMegabytes),
    PhotoIssue.unsupportedType => l10n.errorPhotoUnsupported,
    PhotoIssue.accessDenied => l10n.errorPhotoAccessDenied,
    PhotoIssue.unreadable => l10n.errorPhotoUnreadable,
  };
}

/// Sentence for a rejected profile read or write.
///
/// Separate from `authFailureMessage` so the profile feature carries its own
/// vocabulary; [Failure] is the shared domain type, the words are not. The
/// switch is exhaustive on the sealed base, so a new failure type fails to
/// compile here instead of rendering a blank banner at runtime.
String profileFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    AuthFailure() => l10n.failureUnknownAuth,
    NetworkFailure() => l10n.failureNetwork,
    RateLimitedFailure() => l10n.failureRateLimited,
    // A profile write rejected by the rules means the request named another
    // account, which is the one thing this feature must never do quietly.
    PermissionFailure() => l10n.failurePermission,
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure() => l10n.failureConflict,
    // A photo the validator or the bucket refused names its own rule; every
    // other validated input falls back to the generic sentence.
    ValidationFailure() =>
      photoIssueMessage(l10n, PhotoValidator.issueOf(failure)) ??
          l10n.failureValidation,
    ConfigurationFailure() => l10n.profilePhotoNotConfigured,
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}

/// The name of a profile field, for completion lists.
String profileFieldLabel(AppLocalizations l10n, ProfileField field) {
  return switch (field) {
    ProfileField.photo => l10n.profileFieldPhoto,
    ProfileField.name => l10n.fullNameLabel,
    ProfileField.bloodGroup => l10n.bloodGroupLabel,
    ProfileField.area => l10n.profileAreaLabel,
    ProfileField.phone => l10n.profilePhoneLabel,
    ProfileField.dateOfBirth => l10n.profileDobLabel,
    ProfileField.gender => l10n.profileGenderLabel,
  };
}

/// The name of a gender option.
String profileGenderLabel(AppLocalizations l10n, ProfileGender gender) {
  return switch (gender) {
    ProfileGender.female => l10n.profileGenderFemale,
    ProfileGender.male => l10n.profileGenderMale,
    ProfileGender.other => l10n.profileGenderOther,
    ProfileGender.preferNotToSay => l10n.profileGenderPreferNotToSay,
  };
}
