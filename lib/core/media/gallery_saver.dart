import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Copies one stored photograph into the device's own gallery.
///
/// A seam in the same shape as [PhotoPicker]: `gal` and `http` both talk to the
/// platform (a MediaStore / Photos write and an HTTPS fetch), which a widget
/// test cannot answer. The viewer depends on this interface instead, so the
/// download control, its success toast and every failure path are testable
/// without a device or a live bucket.
abstract interface class GallerySaver {
  /// Downloads the image at [url] and saves it to the system gallery.
  ///
  /// Returns a [Success] once the bytes are handed to the gallery, or a
  /// [Failure] describing why they were not: a broken [url], an unreachable or
  /// refused fetch ([NetworkFailure]), a payload that is not a storable still
  /// image ([ValidationFailure]), or a denied gallery permission
  /// ([PermissionFailure]).
  Future<Result<void>> saveImageFromUrl(String url);
}

/// Fetches the bytes over HTTPS and writes them with `gal`.
///
/// **One path for every platform.** `gal` saves to MediaStore on Android, to
/// the Photos library on iOS, and issues a browser download on web, so the same
/// fetch-then-put flow serves each target the viewer is opened on. The still
/// image is checked by magic bytes rather than by the URL's extension, because
/// a Supabase public URL carries no reliable suffix and a file the gallery
/// refuses is worse to explain after a tap than to refuse up front.
final class HttpGallerySaver implements GallerySaver {
  // The public `client` name is deliberate (a caller passes `client:`), while
  // the field is private and nullable so "no client given" means "build a
  // throwaway one per save" — which `this._client` cannot express.
  // ignore: prefer_initializing_formals
  const HttpGallerySaver({http.Client? client}) : _client = client;

  // The injected client is nullable on purpose: null means "build one per
  // save", which is what the app wants (a short-lived fetch), while a test
  // hands in a mock it reuses across calls and closes itself.
  final http.Client? _client;

  @override
  Future<Result<void>> saveImageFromUrl(String url) async {
    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.isScheme('http') && !uri.isScheme('https')) {
      return const FailureResult<void>(
        ValidationFailure(
          messageKey: 'imageDownloadUrlInvalid',
          debugMessage: 'Gallery save rejected a non-http(s) url',
        ),
      );
    }

    final http.Client client = _client ?? http.Client();
    final http.Response response;
    try {
      response = await client.get(uri);
    } catch (error, stackTrace) {
      return FailureResult<void>(
        NetworkFailure(
          debugMessage: 'Gallery save fetch failed',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      // Only a client built here is closed here; an injected client belongs to
      // the caller (a test reuses one across several saves).
      if (_client == null) {
        client.close();
      }
    }

    if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
      return FailureResult<void>(
        NetworkFailure(
          debugMessage:
              'Gallery save fetch returned [${response.statusCode}] with '
              '${response.bodyBytes.length} bytes',
        ),
      );
    }

    final Uint8List bytes = response.bodyBytes;
    if (!_looksLikeStorableImage(bytes)) {
      return const FailureResult<void>(
        ValidationFailure(
          messageKey: 'imageDownloadNotStorable',
          debugMessage: 'Gallery save rejected a non-image payload',
        ),
      );
    }

    try {
      // `putImageBytes` asks for write access itself on iOS and web, so no
      // separate request/preflight is needed on the save path.
      await Gal.putImageBytes(bytes, name: 'solovvo-photo');
    } on GalException catch (e, stackTrace) {
      return FailureResult<void>(
        e.type == GalExceptionType.accessDenied
            ? PermissionFailure(
                debugMessage: 'Gallery save denied by permission',
                cause: e,
                stackTrace: stackTrace,
              )
            : UnexpectedFailure(
                debugMessage: 'Gallery save failed [${e.type.code}]',
                cause: e,
                stackTrace: stackTrace,
              ),
      );
    } catch (error, stackTrace) {
      return FailureResult<void>(
        UnexpectedFailure(
          debugMessage: 'Gallery save threw an unclassified error',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }

    return const Success<void>(null);
  }

  /// JPEG, PNG and WebP — the formats `PhotoValidator` lets into the bucket, so
  /// anything stored was one of these and a mismatch here means the fetch landed
  /// somewhere unexpected rather than on a photo.
  static bool _looksLikeStorableImage(Uint8List bytes) {
    if (bytes.length < 12) {
      return false;
    }
    final bool jpeg = bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    final bool png =
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    final bool webp =
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50; // P
    return jpeg || png || webp;
  }
}
