import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/domain/photo_picker.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo.dart';

/// [PhotoPicker] backed by the `image_picker` plugin.
///
/// The only place in the app that talks to a platform channel for photos. It is
/// covered by the seam rather than by a test: a widget test cannot answer that
/// channel, so everything downstream of [PhotoCandidate] is tested against a
/// fake picker instead.
class ImagePickerPhotoPicker implements PhotoPicker {
  ImagePickerPhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Downscaled and re-encoded before it ever reaches the validator.
  ///
  /// 1024 px is four times the largest place an avatar appears (64 dp at 3x),
  /// so the result is sharp on every screen while a 12-megapixel phone photo
  /// becomes roughly 100 KB instead of 4 MB. The re-encode is also what turns
  /// an iOS HEIC capture into a JPEG, which is why HEIC never needs supporting.
  static const double maxDimension = 1024;

  /// High enough that the downscale is the visible quality loss, not this.
  static const int imageQuality = 85;

  @override
  Future<Result<PhotoCandidate?>> pick(PhotoSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: switch (source) {
          PhotoSource.gallery => ImageSource.gallery,
          PhotoSource.camera => ImageSource.camera,
        },
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: imageQuality,
        // Not reading EXIF. A phone photo carries the capture date and often GPS
        // coordinates; a profile picture has no use for either, and the
        // metadata is dropped here rather than being uploaded and forgotten.
        requestFullMetadata: false,
      );
      if (file == null) {
        // The donor closed the picker. Not an error.
        return const Success<PhotoCandidate?>(null);
      }
      final Uint8List bytes = await file.readAsBytes();
      return Success<PhotoCandidate?>(
        PhotoCandidate(bytes: bytes, fileName: file.name),
      );
    } on PlatformException catch (error, stackTrace) {
      return FailureResult<PhotoCandidate?>(
        _issue(
          _isDenial(error.code)
              ? PhotoIssue.accessDenied
              : PhotoIssue.unreadable,
          debugMessage: '${error.code}: ${error.message}',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } on MissingPluginException catch (error, stackTrace) {
      // A platform without the plugin (desktop test builds, an unregistered
      // web plugin). Reported as "no picker here" rather than as a crash.
      return FailureResult<PhotoCandidate?>(
        _issue(
          PhotoIssue.accessDenied,
          debugMessage: error.message ?? 'No image picker on this platform',
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    } catch (error, stackTrace) {
      return FailureResult<PhotoCandidate?>(
        _issue(
          PhotoIssue.unreadable,
          debugMessage: error.toString(),
          cause: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  /// The codes `image_picker` uses when permission is refused rather than
  /// something merely going wrong.
  static bool _isDenial(String code) {
    return code == 'photo_access_denied' ||
        code == 'camera_access_denied' ||
        code == 'camera_access_restricted' ||
        code.contains('access_denied');
  }

  static ValidationFailure _issue(
    PhotoIssue issue, {
    required String debugMessage,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return ValidationFailure(
      messageKey: issue.name,
      debugMessage: debugMessage,
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}
