import 'package:firebase_auth/firebase_auth.dart';
import 'package:sholovvo_app/core/config/supabase_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/error/storage_error_mapper.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:storage_client/storage_client.dart';

/// Supabase Storage implementation of [PostImageStorage].
///
/// Deliberately the same shape as `SupabasePhotoStorage`, because the identity
/// model is identical: no Supabase user and no Supabase session exist, each
/// operation builds a short-lived client from a freshly read Firebase ID token,
/// and the bucket's policies independently require the JWT's `sub` to equal the
/// object's first path segment. Ownership is therefore the server's decision,
/// not this file's.
///
/// Two things differ from avatars, and both come from a post being a list of
/// objects rather than one:
///
/// * **The path carries a sequence number.** Several photos picked in the same
///   second would otherwise share a timestamp, and a second upload would
///   overwrite the first. `{uid}/post-{millis}-{n}.{ext}` makes every upload a
///   new object, which is also why the URL behind each one is immutable and can
///   be cached for a year.
/// * **Removal names the path, not the URL.** `Post.imagePaths` is stored beside
///   the URLs for exactly this, so a cleanup never has to parse a URL and guess.
///   [ownPath] still refuses anything outside the caller's own folder, so a
///   corrupt document cannot turn into a delete attempt on someone else's file.
class SupabasePostImageStorage implements PostImageStorage {
  SupabasePostImageStorage(this._auth, this._config, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final FirebaseAuth _auth;
  final SupabaseConfig _config;
  final DateTime Function() _clock;

  /// Distinguishes two uploads that land in the same millisecond. Per instance,
  /// so it only has to be unique inside one compose screen.
  int _sequence = 0;

  /// One year. Every upload gets a new path, so the object behind a URL never
  /// changes and may be cached hard — for free, on Supabase's CDN.
  static const String _cacheControlSeconds = '31536000';

  @override
  bool get isConfigured => _config.isConfigured;

  @override
  Future<Result<StoredPostImage>> upload(ValidatedPhoto photo) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const FailureResult<StoredPostImage>(
        AuthFailure(debugMessage: 'A post photo requires a signed-in user'),
      );
    }

    final String path = objectPath(
      uid: uid,
      now: _clock(),
      format: photo.format,
      index: _sequence++,
    );

    try {
      final SupabaseStorageClient client = await _createClient();
      final StorageFileApi bucket = client.from(_config.postImagesBucket);
      await bucket.uploadBinary(
        path,
        photo.bytes,
        fileOptions: FileOptions(
          contentType: photo.mimeType,
          cacheControl: _cacheControlSeconds,
        ),
      );
      return Success<StoredPostImage>(
        StoredPostImage(url: bucket.getPublicUrl(path), path: path),
      );
    } on StorageException catch (error, stackTrace) {
      return FailureResult<StoredPostImage>(
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
      return FailureResult<StoredPostImage>(
        mapExceptionToFailure(error, stackTrace),
      );
    }
  }

  @override
  Future<Result<bool>> remove(String objectPath) async {
    final String? uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return const FailureResult<bool>(
        AuthFailure(debugMessage: 'A post photo removal requires a signed-in user'),
      );
    }

    final String? path = ownPath(objectPath, uid: uid);
    if (path == null) {
      // Not an object of ours: another account's folder, a nested path the
      // bucket policy would refuse anyway, or a blank string. Deleting is
      // refused locally *and* by the policies, and "there was nothing of ours to
      // delete" is not a failure the donor needs to see.
      return const Success<bool>(false);
    }

    try {
      final SupabaseStorageClient client = await _createClient();
      final List<FileObject> removed = await client
          .from(_config.postImagesBucket)
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

  /// `{uid}/post-{millis}-{index}.{ext}`.
  ///
  /// One folder level, because the bucket policy checks
  /// `array_length(storage.foldername(name), 1) = 1` and compares that single
  /// folder to the token's `sub`. A deeper path would be refused by the server.
  static String objectPath({
    required String uid,
    required DateTime now,
    required PhotoFormat format,
    int index = 0,
  }) {
    return '$uid/post-${now.millisecondsSinceEpoch}-$index.${format.extension}';
  }

  /// [objectPath] when it is an object of [uid]'s, and `null` otherwise.
  ///
  /// Pure and public so the guard is testable without a bucket: it is the only
  /// thing standing between a corrupt `imagePaths` entry and a delete attempt on
  /// somebody else's photograph.
  static String? ownPath(String objectPath, {required String uid}) {
    if (uid.isEmpty) {
      return null;
    }
    final String path = objectPath.trim();
    if (path.isEmpty) {
      return null;
    }
    final List<String> segments = path.split('/');
    if (segments.length != 2 || segments.first != uid) {
      return null;
    }
    final String name = segments.last;
    if (name.isEmpty || name == '.' || name == '..') {
      return null;
    }
    return path;
  }
}
