import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/result/result.dart';

/// A photograph that is now in storage, and where it lives.
///
/// Both halves are kept because they answer different questions. The URL is what
/// the document publishes and what a reader downloads; the path is what a delete
/// names. `Post.imagePaths` exists for exactly this reason — a URL alone cannot
/// be turned back into a path without parsing, and a parse that guesses wrong
/// deletes nothing while reporting success.
@immutable
final class StoredPostImage {
  const StoredPostImage({required this.url, required this.path});

  /// The public URL a feed card loads.
  final String url;

  /// The object path inside the bucket, e.g. `{uid}/post-1730000000000-0.jpg`.
  final String path;

  @override
  bool operator ==(Object other) =>
      other is StoredPostImage && other.url == url && other.path == path;

  @override
  int get hashCode => Object.hash(url, path);

  @override
  String toString() => 'StoredPostImage($path)';
}

/// Where post photographs are stored.
///
/// A port in the same shape as `ProfilePhotoStorage`: the compose screen can
/// upload, remove and be told whether this build can do either, without knowing
/// that Supabase exists. The two differ in one place — this one returns the path
/// as well as the URL, because a post has up to four objects to name later.
///
/// **Uploading is optional, publishing is not.** When [isConfigured] is false the
/// compose screen still opens, still accepts text, and never offers a photo
/// control that could only fail. That is the same honest state Stage 8.1 chose
/// for avatars, and it is why [upload] is not simply expected to work.
abstract interface class PostImageStorage {
  /// Whether this build carries a Supabase URL and publishable key.
  bool get isConfigured;

  /// Stores one already-validated photograph.
  ///
  /// Takes a [ValidatedPhoto] rather than raw bytes so the size, the magic-byte
  /// sniff and the content type were decided once, by the validator, before the
  /// network was involved.
  Future<Result<StoredPostImage>> upload(ValidatedPhoto photo);

  /// Deletes the object at [objectPath].
  ///
  /// Answers `true` when something was removed and `false` when the path was not
  /// an object of the caller's — a best-effort cleanup that found nothing is not
  /// a failure the donor should see.
  Future<Result<bool>> remove(String objectPath);
}
