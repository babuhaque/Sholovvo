import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/config/supabase_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/data/storage_error_mapper.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo_storage.dart';
import 'package:storage_client/storage_client.dart';

/// Supabase Storage implementation of [ProfilePhotoStorage].
///
/// Three things are deliberate here and each one is a guardrail:
///
/// * **Identity is Firebase's, borrowed.** No Supabase Auth session is created
///   and no Supabase user exists. Each operation builds a short-lived
///   `StorageClient` carrying a freshly read Firebase ID token, which the
///   Supabase project verifies as a third-party auth JWT. Nothing is cached, so
///   a rotated or revoked token cannot linger in a long-lived client.
/// * **Only the publishable key is sent.** The secret/service-role key never
///   reaches this class; `SupabaseConfig` refuses to carry one.
/// * **The object path starts with the caller's own uid**, and the bucket's
///   policies independently require the JWT's `sub` claim to equal that first
///   segment. Ownership is therefore enforced by the server, not by this file.
class SupabasePhotoStorage implements ProfilePhotoStorage {
  SupabasePhotoStorage(this._auth, this._config, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FirebaseAuth _auth;
  final SupabaseConfig _config;
  final DateTime Function() _clock;

  /// One year. Every upload gets a new path, so the object behind a URL is
  /// immutable and may be cached hard — for free, on Supabase's CDN.
  static const String _cacheControlSeconds = '31536000';

  /// `.../storage/v1/object/public/...`, the path prefix public URLs share.
  static const List<String> _publicPrefix = <String>[
    'storage',
    'v1',
    'object',
    'public',
  ];

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<Result<String>> uploadAvatar(ValidatedPhoto photo) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const FailureResult<String>(
        AuthFailure(
          debugMessage: 'A photo upload requires a signed-in user',
        ),
      );
    }

    final String path = objectPath(
      uid: uid,
      now: _clock(),
      format: photo.format,
    );

    try {
      final SupabaseStorageClient client = await _createClient();
      final StorageFileApi bucket = client.from(_config.avatarBucket);
      await bucket.uploadBinary(
        path,
        photo.bytes,
        fileOptions: FileOptions(
          contentType: photo.mimeType,
          cacheControl: _cacheControlSeconds,
        ),
      );
      return Success<String>(bucket.getPublicUrl(path));
    } on StorageException catch (error, stackTrace) {
      return FailureResult<String>(
        mapStorageErrorToFailure(
          message: error.message,
          statusCode: error.statusCode,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      // Includes the [Failure] thrown by [_createClient] when the build carries
      // no configuration; `mapExceptionToFailure` returns those untouched.
      return FailureResult<String>(mapExceptionToFailure(error, stackTrace));
    }
  }

  @override
  Future<Result<bool>> removeAvatar(String publicUrl) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const FailureResult<bool>(
        AuthFailure(
          debugMessage: 'A photo removal requires a signed-in user',
        ),
      );
    }

    final String? path = objectPathOf(
      publicUrl,
      storageUrl: _config.storageUrl,
      bucket: _config.avatarBucket,
      uid: uid,
    );
    if (path == null) {
      // Not an object of ours: an external image, another bucket, or another
      // account's folder. Deleting is refused locally *and* by the policies,
      // and "there was nothing of ours to delete" is not a failure.
      return const Success<bool>(false);
    }

    try {
      final SupabaseStorageClient client = await _createClient();
      final List<FileObject> removed = await client
          .from(_config.avatarBucket)
          .remove(<String>[path]);
      return Success<bool>(removed.isNotEmpty);
    } on StorageException catch (error, stackTrace) {
      return FailureResult<bool>(
        mapStorageErrorToFailure(
          message: error.message,
          statusCode: error.statusCode,
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<bool>(mapExceptionToFailure(error, stackTrace));
    }
  }

  /// Builds a client for one operation, authenticated as the signed-in donor.
  ///
  /// Throws a [ConfigurationFailure] or an [AuthFailure] rather than returning
  /// a client that would only fail later with an opaque 401.
  Future<SupabaseStorageClient> _createClient() async {
    final String? storageUrl = _config.storageUrl;
    if (storageUrl == null) {
      throw ConfigurationFailure(
        setting: _config.rejection == null
            ? 'SUPABASE_URL / SUPABASE_ANON_KEY'
            : 'SUPABASE_ANON_KEY (${_config.rejection!.name})',
        debugMessage: 'Supabase Storage is not configured for this build',
      );
    }

    // Read on every call: Firebase rotates ID tokens hourly and revokes them on
    // a password change, so a stored token would eventually fail as if the
    // donor had been signed out.
    final String? token = await _auth.currentUser?.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure(
        debugMessage: 'Firebase returned no ID token for the storage request',
      );
    }

    return SupabaseStorageClient(storageUrl, <String, String>{
      // The publishable key identifies the project; the bearer token carries
      // the identity the policies check.
      'apikey': _config.publishableKey,
      'Authorization': 'Bearer $token',
    });
  }

  /// `{uid}/avatar-{millis}.{ext}`.
  ///
  /// The timestamp is what makes replacement safe: a new upload never overwrites
  /// the object the donor still has on screen, so if the profile write fails
  /// afterwards the old photo is still there, intact.
  static String objectPath({
    required String uid,
    required DateTime now,
    required PhotoFormat format,
  }) {
    return '$uid/avatar-${now.millisecondsSinceEpoch}.${format.extension}';
  }

  /// The object path inside the bucket for [publicUrl], or `null` when the URL
  /// is not an object of [uid]'s in [bucket].
  ///
  /// Parsed rather than stored alongside the profile: `users/{uid}.photoUrl` is
  /// the single field the whole app agrees on, and deriving the path from it
  /// means the two can never disagree. Anything unrecognised — an older external
  /// avatar, a transformed image URL, a different project — yields `null` and is
  /// left alone.
  static String? objectPathOf(
    String publicUrl, {
    required String? storageUrl,
    required String bucket,
    required String uid,
  }) {
    if (storageUrl == null || uid.isEmpty) {
      return null;
    }
    final Uri? url = Uri.tryParse(publicUrl.trim());
    final Uri? base = Uri.tryParse(storageUrl);
    if (url == null || base == null) {
      return null;
    }
    // Compared piece by piece rather than with `Uri.origin`: `origin` throws for
    // anything that is not an http(s) URL, and `photoUrl` is whatever the
    // document holds — including a relative path someone once put there. A
    // wrong-origin URL is refused, not fatal.
    if (url.scheme != base.scheme ||
        url.host != base.host ||
        url.port != base.port) {
      return null;
    }

    final List<String> segments = url.pathSegments;
    // Prefix, bucket, uid, file name — anything shorter cannot be ours.
    if (segments.length < _publicPrefix.length + 3) {
      return null;
    }
    for (int i = 0; i < _publicPrefix.length; i++) {
      if (segments[i] != _publicPrefix[i]) {
        return null;
      }
    }
    if (segments[_publicPrefix.length] != bucket) {
      return null;
    }

    final List<String> rest = segments.sublist(_publicPrefix.length + 1);
    if (rest.first != uid) {
      return null;
    }
    return rest.join('/');
  }
}
