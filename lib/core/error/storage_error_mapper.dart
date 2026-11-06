import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';

/// Translates a Supabase Storage error into a [Failure].
///
/// Takes the **status code and message**, not `StorageException`, for the same
/// reason `firestore_error_mapper` takes a code string: the mapping is then a
/// pure function a unit test can enumerate, instead of something only
/// demonstrable against a live project.
///
/// Storage answers with four different vocabularies in practice — HTTP status,
/// an RLS violation sentence, a size/mime violation sentence, and a raw socket
/// error turned into a message by `storage_client` — so both the status and the
/// text are inspected here rather than trusting either alone.
///
/// It lives in `core/error` rather than in one feature for the same reason as
/// `firestore_error_mapper`: two features upload images (profile avatars since
/// Stage 8.1, feed post photos since Stage 8.3) and two copies of this switch is
/// how a rejected upload ends up as "check your connection" on one screen and
/// "your file is too large" on the other. Nothing here imports
/// `storage_client`: the mapping is over strings.
Failure mapStorageErrorToFailure({
  required String message,
  String? statusCode,
  Object? cause,
  StackTrace? stackTrace,
}) {
  final int? status = int.tryParse(statusCode ?? '');
  final String text = message.toLowerCase();

  // A missing, expired or unverifiable token. Retrying as the same user cannot
  // help; signing in again can.
  if (status == 401 ||
      text.contains('invalid jwt') ||
      text.contains('jwt expired')) {
    return AuthFailure(
      debugMessage: 'Storage rejected the bearer token: $message',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  // Signed in, but the policy refused this exact object path — the storage
  // equivalent of a Firestore `permission-denied`.
  if (status == 403 ||
      text.contains('row-level security') ||
      text.contains('not allowed') ||
      text.contains('insufficient privilege')) {
    return PermissionFailure(
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  // A bucket that does not exist (`NoSuchBucket`, "Bucket not found") is not a
  // missing account and not a missing object: it is a build pointed at a
  // project where the delivery SQL in `docs/storage/` was never applied. The
  // screens already carry the honest sentence for that
  // (`profilePhotoNotConfigured` / `feedComposePhotosNotConfigured`), so it
  // surfaces as a ConfigurationFailure rather than the misleading
  // "We could not find that account" a NotFoundFailure would render.
  if (text.contains('bucket not found') || text.contains('nosuchbucket')) {
    return ConfigurationFailure(
      setting: 'Supabase Storage bucket',
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  if (status == 404 || text.contains('object not found')) {
    return NotFoundFailure(
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  if (status == 409 || text.contains('already exists')) {
    return ConflictFailure(
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  // The bucket's own limits. Reported with the same sentences as the client-side
  // checks, because to a donor they are the same answer: pick a different file.
  if (status == 413 || text.contains('maximum allowed size')) {
    return ValidationFailure(
      messageKey: PhotoIssue.tooLarge.name,
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
  if (text.contains('mime type') || text.contains('content type')) {
    return ValidationFailure(
      messageKey: PhotoIssue.unsupportedType.name,
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  if (status == 429 || text.contains('rate limit')) {
    return RateLimitedFailure(
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  // 5xx and transport failures are the same thing to the caller: it did not
  // land, and it is worth trying again later.
  if ((status != null && status >= 500) ||
      text.contains('failed host lookup') ||
      text.contains('connection') ||
      text.contains('socket') ||
      text.contains('timed out')) {
    return NetworkFailure(
      code: text.contains('timed out')
          ? FailureCode.timeout
          : FailureCode.network,
      debugMessage: message,
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  return UnexpectedFailure(
    debugMessage: '${statusCode ?? 'no status'}: $message',
    cause: cause,
    stackTrace: stackTrace,
  );
}
