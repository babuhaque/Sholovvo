import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Object storage for profile photos, expressed without any storage SDK type.
///
/// Two properties are part of the contract rather than the implementation, and
/// both mirror `ProfileRepository`:
///
/// 1. **There is no uid parameter.** The owner is the signed-in account, read
///    from the Firebase session inside the implementation. The object path is
///    built as `{uid}/avatar-{timestamp}.{ext}`, and the bucket's policies
///    require that first path segment to equal the JWT's `sub` claim — so a
///    client cannot write into, or delete from, anyone else's folder even if a
///    caller is added later that tries.
/// 2. **Only objects this app owns can be deleted.** [removeAvatar] takes the
///    URL that is currently published and refuses to act on anything that is
///    not an object in this bucket under the caller's own folder. A profile
///    that still points at an external image keeps pointing at it.
abstract interface class ProfilePhotoStorage {
  /// Whether the build carries a usable Supabase URL and publishable key.
  ///
  /// When false the feature is unavailable rather than broken, and the sheet
  /// says so — no control is offered that could only ever fail.
  bool get isConfigured;

  /// Uploads [photo] to the caller's own folder and returns its public URL.
  ///
  /// The URL is only returned, never written: publishing it is `ProfileRepository`'s
  /// job, so a failed profile write cannot leave a stored photo unaccounted for.
  Future<Result<String>> uploadAvatar(ValidatedPhoto photo);

  /// Deletes the object [publicUrl] points at.
  ///
  /// Returns `true` when an object was removed, `false` when there was nothing
  /// of ours to remove (an external URL, or an object already gone). Callers use
  /// the flag to distinguish "cleaned up" from "nothing to clean up"; neither is
  /// an error.
  Future<Result<bool>> removeAvatar(String publicUrl);

  /// Uploads the cover [photo] to the caller's own folder and returns its public
  /// URL.
  ///
  /// Same contract as [uploadAvatar] — the URL is only returned, never written —
  /// and the same `{uid}/...` ownership namespace, so one bucket policy governs
  /// both an avatar and a cover. The object is named `cover-{timestamp}`.
  Future<Result<String>> uploadCover(ValidatedPhoto photo);

  /// Deletes the cover object [publicUrl] points at.
  ///
  /// The cover counterpart of [removeAvatar]: refuses to act on anything that is
  /// not an object in this bucket under the caller's own folder.
  Future<Result<bool>> removeCover(String publicUrl);
}
