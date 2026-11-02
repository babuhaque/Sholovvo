import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// Why a chosen image could not be used, before anything reached the network.
///
/// A closed set rather than an error string, because each value needs a
/// sentence in two languages and the screen must be able to tell "your file is
/// the wrong kind" apart from "the upload failed" — one is the donor's to fix,
/// the other is not.
enum PhotoIssue {
  /// Zero bytes. A picker that returned an empty file is not a photo.
  empty,

  /// Larger than [PhotoValidator.maxBytes].
  tooLarge,

  /// Not JPEG, PNG or WebP, decided by content rather than by file name.
  unsupportedType,

  /// The platform refused the picker (library or camera access), or the donor
  /// has no picker at all. Not about the image: nothing was chosen.
  accessDenied,

  /// The chosen file could not be read off the device.
  unreadable,
}

/// The three image formats profile photos are accepted in.
///
/// Chosen for what every target renders: the three platforms decode all three
/// natively, and none of them needs a transcoding step on the client. HEIC is
/// deliberately absent even though iOS produces it — the picker re-encodes a
/// HEIC capture to JPEG when `maxWidth` or `imageQuality` is set, and a HEIC
/// that reaches this code has no reliable renderer on Android or web.
enum PhotoFormat {
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png'),
  webp('image/webp', 'webp');

  const PhotoFormat(this.mimeType, this.extension);

  /// The value sent as the object's `Content-Type`.
  final String mimeType;

  /// The extension used in the storage path.
  final String extension;
}

/// An image the picker handed over, before any checks.
@immutable
final class PhotoCandidate {
  const PhotoCandidate({required this.bytes, this.fileName});

  final Uint8List bytes;

  /// The picker's file name, if it had one. Kept for diagnostics only: the
  /// stored object is named from the format that was sniffed, never from this.
  final String? fileName;

  @override
  String toString() =>
      'PhotoCandidate(${bytes.length} bytes, name: ${fileName ?? '(none)'})';
}

/// An image that passed [PhotoValidator].
///
/// The private constructor is the point: nothing outside this library can
/// manufacture one from unchecked bytes, so a storage implementation that takes
/// a `ValidatedPhoto` cannot be handed something that skipped the checks.
@immutable
final class ValidatedPhoto {
  const ValidatedPhoto._({required this.bytes, required this.format});

  final Uint8List bytes;
  final PhotoFormat format;

  int get byteLength => bytes.length;

  String get mimeType => format.mimeType;

  String get extension => format.extension;

  @override
  String toString() => 'ValidatedPhoto(${format.name}, $byteLength bytes)';
}

/// The rules an uploaded profile photo must satisfy on this side.
///
/// Client-side validation is a courtesy, never a security boundary: the bucket
/// itself carries `file_size_limit` and `allowed_mime_types`, so a caller that
/// bypasses the app is still stopped by the server. These checks exist so a
/// donor gets an answer immediately instead of after a 5 MB round trip.
abstract final class PhotoValidator {
  /// 5 MB. Well under the bucket limit in `docs/storage/`, and far more than a
  /// 1024 px avatar needs — the picker downscales before this point.
  static const int maxBytes = 5 * 1024 * 1024;

  static const int maxMegabytes = maxBytes ~/ (1024 * 1024);

  /// Magic-number prefixes. A renamed `virus.exe` saying it is a JPEG is a
  /// four-byte lie; a file that starts with these bytes is really a JPEG.
  static const List<int> _jpeg = <int>[0xFF, 0xD8, 0xFF];
  static const List<int> _png = <int>[
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  ];
  static const List<int> _riff = <int>[0x52, 0x49, 0x46, 0x46]; // "RIFF"
  static const List<int> _webp = <int>[0x57, 0x45, 0x42, 0x50]; // "WEBP"

  /// Checks size and content, in that order: size is the cheaper test and the
  /// one whose message a donor can act on.
  static Result<ValidatedPhoto> validate(PhotoCandidate candidate) {
    final Uint8List bytes = candidate.bytes;
    if (bytes.isEmpty) {
      return FailureResult<ValidatedPhoto>(_reject(PhotoIssue.empty));
    }
    if (bytes.length > maxBytes) {
      return FailureResult<ValidatedPhoto>(_reject(PhotoIssue.tooLarge));
    }
    final PhotoFormat? format = sniff(bytes);
    if (format == null) {
      return FailureResult<ValidatedPhoto>(_reject(PhotoIssue.unsupportedType));
    }
    return Success<ValidatedPhoto>(ValidatedPhoto._(bytes: bytes, format: format));
  }

  /// The format the bytes actually are, or `null` when it is none of the three.
  static PhotoFormat? sniff(Uint8List bytes) {
    if (_startsWith(bytes, _jpeg)) {
      return PhotoFormat.jpeg;
    }
    if (_startsWith(bytes, _png)) {
      return PhotoFormat.png;
    }
    // WebP is RIFF....WEBP: a 4-byte container tag, a 4-byte length, then the
    // form type. Checking both ends is what separates it from every other RIFF
    // payload (wav, avi).
    if (bytes.length >= 12 && _startsWith(bytes, _riff)) {
      for (int i = 0; i < _webp.length; i++) {
        if (bytes[8 + i] != _webp[i]) {
          return null;
        }
      }
      return PhotoFormat.webp;
    }
    return null;
  }

  /// The issue a [ValidationFailure] from [validate] is carrying, if any.
  ///
  /// The failure type is shared with every other validated input in the app, so
  /// it travels as a key (`Failure.messageKey`) and is read back here. An
  /// unrecognised key yields `null`, which callers render with the generic
  /// validation sentence rather than a wrong one.
  static PhotoIssue? issueOf(Failure failure) {
    if (failure is! ValidationFailure) {
      return null;
    }
    for (final PhotoIssue issue in PhotoIssue.values) {
      if (issue.name == failure.messageKey) {
        return issue;
      }
    }
    return null;
  }

  static ValidationFailure _reject(PhotoIssue issue) {
    return ValidationFailure(
      messageKey: issue.name,
      debugMessage: 'Profile photo rejected: ${issue.name}',
    );
  }

  static bool _startsWith(Uint8List bytes, List<int> prefix) {
    if (bytes.length < prefix.length) {
      return false;
    }
    for (int i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) {
        return false;
      }
    }
    return true;
  }
}
