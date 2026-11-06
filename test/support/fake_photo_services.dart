import 'dart:async';
import 'dart:typed_data';

import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/gallery_saver.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo_storage.dart';

/// In-memory [ProfilePhotoStorage] for tests.
///
/// Behaves like the Supabase implementation where the ordering matters: a
/// configured failure returns the failure instead of storing anything, so the
/// controller's "nothing changed" path is exercised for real.
class FakePhotoStorage implements ProfilePhotoStorage {
  FakePhotoStorage({
    this.isConfigured = true,
    this.uploadUrl = defaultUploadUrl,
    this.coverUrl = defaultCoverUploadUrl,
  });

  static const String defaultUploadUrl =
      'https://demo.supabase.co/storage/v1/object/public/avatars/'
      'uid-verified/avatar-1730000000000.jpg';

  static const String defaultCoverUploadUrl =
      'https://demo.supabase.co/storage/v1/object/public/avatars/'
      'uid-verified/cover-1730000000000.jpg';

  @override
  bool isConfigured;

  /// The URL a successful upload returns. Public so a test can point the profile
  /// at a specific object when it asserts on the removal path.
  String uploadUrl;

  /// The URL a successful cover upload returns.
  String coverUrl;

  /// When set, the matching call returns this failure instead of succeeding.
  Failure? uploadFailure;
  Failure? removeFailure;
  Failure? coverUploadFailure;
  Failure? coverRemoveFailure;

  /// What a successful removal reports: `true` removed something, `false` found
  /// nothing of ours at that URL.
  bool removeResult = true;

  int uploadCalls = 0;
  ValidatedPhoto? lastUpload;
  final List<String> removedUrls = <String>[];

  int coverUploadCalls = 0;
  ValidatedPhoto? lastCoverUpload;
  final List<String> coverRemovedUrls = <String>[];

  /// When set, both calls wait on it before answering.
  ///
  /// A real upload spends seconds on the network; without a gate a test can
  /// only see the two ends of it, never the busy state a donor sits in.
  Completer<void>? gate;

  @override
  Future<Result<String>> uploadAvatar(ValidatedPhoto photo) async {
    uploadCalls++;
    lastUpload = photo;
    await _waitForGate();
    if (uploadFailure != null) {
      return FailureResult<String>(uploadFailure!);
    }
    return Success<String>(uploadUrl);
  }

  @override
  Future<Result<bool>> removeAvatar(String publicUrl) async {
    removedUrls.add(publicUrl);
    await _waitForGate();
    if (removeFailure != null) {
      return FailureResult<bool>(removeFailure!);
    }
    return Success<bool>(removeResult);
  }

  @override
  Future<Result<String>> uploadCover(ValidatedPhoto photo) async {
    coverUploadCalls++;
    lastCoverUpload = photo;
    await _waitForGate();
    if (coverUploadFailure != null) {
      return FailureResult<String>(coverUploadFailure!);
    }
    return Success<String>(coverUrl);
  }

  @override
  Future<Result<bool>> removeCover(String publicUrl) async {
    coverRemovedUrls.add(publicUrl);
    await _waitForGate();
    if (coverRemoveFailure != null) {
      return FailureResult<bool>(coverRemoveFailure!);
    }
    return Success<bool>(removeResult);
  }

  Future<void> _waitForGate() async {
    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }
  }
}

/// In-memory [PhotoPicker]: hands back one prepared candidate.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker({this.candidate});

  /// What the picker returns. `null` is a cancel.
  PhotoCandidate? candidate;

  /// When set, the pick fails instead — a denied permission, an unreadable file.
  Failure? failure;

  /// When set, [pick] waits on it before answering, so a test can sit inside the
  /// picker the way a donor sits in front of a grid of thumbnails.
  ///
  /// Left null the call answers on the same microtask it always did, so no
  /// existing test shifts its timing.
  Completer<void>? gate;

  /// Completed the first time [pick] is entered.
  ///
  /// The counterpart of `FakePostImageStorage.uploadStarted`: it lets a test
  /// prove which wait it is measuring instead of assuming how many microtasks the
  /// code under test needed to get here.
  Completer<void> entered = Completer<void>();

  int calls = 0;
  PhotoSource? lastSource;

  @override
  Future<Result<PhotoCandidate?>> pick(PhotoSource source) async {
    calls++;
    lastSource = source;
    if (!entered.isCompleted) {
      entered.complete();
    }
    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }
    if (failure != null) {
      return FailureResult<PhotoCandidate?>(failure!);
    }
    return Success<PhotoCandidate?>(candidate);
  }
}

/// Bytes that sniff as a JPEG.
///
/// The validator decides the format from the first bytes and nothing else, so a
/// real encoded image would only make the tests slower.
Uint8List jpegBytes({int length = 64}) {
  return _prefixed(<int>[0xFF, 0xD8, 0xFF, 0xE0], length);
}

/// Bytes that sniff as a PNG.
Uint8List pngBytes({int length = 64}) {
  return _prefixed(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], length);
}

/// Bytes that sniff as a WebP (`RIFF....WEBP`).
Uint8List webpBytes({int length = 64}) {
  return _prefixed(<int>[
    0x52, 0x49, 0x46, 0x46, // RIFF
    0x00, 0x00, 0x00, 0x00, // size, not inspected
    0x57, 0x45, 0x42, 0x50, // WEBP
  ], length);
}

/// Bytes that are none of the three — a text file renamed to `.jpg`.
Uint8List textBytes({int length = 64}) {
  return Uint8List.fromList(
    List<int>.generate(length, (int i) => 'not an image'.codeUnits[i % 12]),
  );
}

Uint8List _prefixed(List<int> prefix, int length) {
  final Uint8List bytes = Uint8List(length < prefix.length ? prefix.length : length);
  bytes.setRange(0, prefix.length, prefix);
  return bytes;
}

/// In-memory [GallerySaver]: records the url it was asked to save.
///
/// `gal` and `http` both reach the platform, so the viewer's download control
/// is tested through this seam rather than a real fetch-and-write. When [failure]
/// is set the save reports it instead of succeeding, which is how the denied
/// and failed toast paths are reached without a device refusing permission.
class FakeGallerySaver implements GallerySaver {
  FakeGallerySaver({this.failure});

  /// Returned instead of a success when set.
  Failure? failure;

  /// Holds the call open so a test can watch the in-flight spinner.
  Completer<void>? gate;

  int calls = 0;
  String? lastUrl;

  @override
  Future<Result<void>> saveImageFromUrl(String url) async {
    calls++;
    lastUrl = url;
    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }
    if (failure != null) {
      return FailureResult<void>(failure!);
    }
    return const Success<void>(null);
  }
}
