import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The sentence for a post that breaks one of the field rules.
///
/// Declared on `PostIssue?` for the same reason as `photoIssueMessage`: a `null`
/// issue yields a `null` message, so a field can hand the result straight to
/// `errorText` and render nothing when there is nothing wrong. The limits are
/// quoted from [PostValidator], so the two catalogues cannot drift from the rule
/// that is actually enforced.
String? postIssueMessage(AppLocalizations l10n, PostIssue? issue) {
  return switch (issue) {
    null => null,
    PostIssue.textRequired => l10n.errorPostTextRequired,
    PostIssue.textTooLong => l10n.errorPostTextTooLong(
      PostValidator.maxTextLength,
    ),
    PostIssue.tooManyImages ||
    PostIssue.tooManyImagePaths => l10n.errorPostTooManyImages(
      PostValidator.maxImages,
    ),
    // Raised by the document mapper, never by the form: a post that cannot be
    // read back is not something the author can fix here, so it falls back to
    // the generic sentence rather than inventing a field-level one.
    PostIssue.counterNegative ||
    PostIssue.idMissing ||
    PostIssue.authorUidMissing ||
    PostIssue.createdAtMissing ||
    PostIssue.updatedAtMissing ||
    PostIssue.fieldMalformed => l10n.failureValidation,
  };
}

/// The sentence for a photo refused before or during upload.
///
/// A deliberate copy of the function of the same name in the profile feature's
/// presentation layer, not an import of it: presentation belongs to a feature,
/// and the feed may not reach into the profile's. The catalogue keys are shared,
/// so the two screens still say exactly the same thing about the same file.
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

/// The sentence for a publish, or for an upload inside it, that failed.
///
/// Separate from `feedFailureMessage` for two reasons: a read that fails leaves
/// a list on screen and a write that fails leaves a draft, and the two most
/// likely failures mean different things here. A `ConfigurationFailure` is not
/// "something went wrong" — it is this build having no photo bucket — and a
/// `ValidationFailure` names the rule that refused the post.
String composeFailureMessage(AppLocalizations l10n, Failure failure) {
  return switch (failure) {
    AuthFailure() => l10n.failureUnknownAuth,
    NetworkFailure() => l10n.failureNetwork,
    RateLimitedFailure() => l10n.failureRateLimited,
    PermissionFailure() => l10n.failurePermission,
    NotFoundFailure() => l10n.failureNotFound,
    ConflictFailure() => l10n.failureConflict,
    ValidationFailure() =>
      photoIssueMessage(l10n, PhotoValidator.issueOf(failure)) ??
          postIssueMessage(l10n, PostValidator.issueOf(failure)) ??
          l10n.failureValidation,
    ConfigurationFailure() => l10n.feedComposePhotosNotConfigured,
    UnexpectedFailure() => l10n.failureUnexpected,
  };
}
