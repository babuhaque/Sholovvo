import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Where a photo comes from.
enum PhotoSource { gallery, camera }

/// The platform image picker, behind a seam.
///
/// `image_picker` talks to a platform channel, which a widget test cannot
/// answer. Screens depend on this interface instead, so a whole photo flow —
/// sheet, validation, upload, failure handling — is testable without a device.
///
/// Feature-agnostic on purpose: the profile avatar and post photographs differ
/// in where the bytes end up, not in how they are chosen.
abstract interface class PhotoPicker {
  /// Opens the picker and returns the chosen image.
  ///
  /// A `Success(null)` means the donor cancelled: they closed the sheet without
  /// choosing anything, which is not an error and must not be reported as one.
  Future<Result<PhotoCandidate?>> pick(PhotoSource source);
}
