import 'package:flutter/foundation.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';

/// Everything the compose form draws, in one immutable value.
///
/// The text and the uploaded images travel together because they are only
/// meaningful together: the draft is the pair, and a screen that held the text
/// in a controller and the images in local state would have two sources of truth
/// for "is this publishable?".
///
/// **Two busy flags, not one.** Uploading a photo and publishing a post are
/// different waits with different sentences, and a single flag would make the
/// publish button spin while a photo was still going up. Both block new work, so
/// [isBusy] is the one the screen asks before enabling anything.
@immutable
final class ComposeState {
  const ComposeState({
    this.text = '',
    this.images = const <StoredPostImage>[],
    this.isUploading = false,
    this.isPublishing = false,
    this.failure,
  });

  /// What has been typed, as typed. Trimmed only on publish.
  final String text;

  /// Uploaded photographs, in the order they will appear on the card.
  final List<StoredPostImage> images;

  final bool isUploading;
  final bool isPublishing;

  /// Why the last attempt failed, or `null`. Cleared when a new one starts.
  final Failure? failure;

  bool get isBusy => isUploading || isPublishing;

  /// Whether leaving now would discard work.
  ///
  /// Whitespace does not count: a form holding one space and nothing else has
  /// nothing worth confirming.
  bool get isDirty => text.trim().isNotEmpty || images.isNotEmpty;

  bool get canAddImage => images.length < PostValidator.maxImages;

  /// What still has to be fixed, or `null` when this could be published.
  ///
  /// The counters are zeros because a new post has none yet. The same
  /// [PostValidator] runs in the repository, so the button and the write cannot
  /// disagree about what is allowed.
  PostIssue? get issue => PostValidator.validate(
    text: text,
    imageCount: images.length,
    imagePathCount: images.length,
    likeCount: 0,
    commentCount: 0,
  );

  /// The trimmed length, which is what [PostValidator] measures and what the
  /// counter under the field shows.
  int get length => text.trim().length;

  ComposeState copyWith({
    String? text,
    List<StoredPostImage>? images,
    bool? isUploading,
    bool? isPublishing,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return ComposeState(
      text: text ?? this.text,
      images: images ?? this.images,
      isUploading: isUploading ?? this.isUploading,
      isPublishing: isPublishing ?? this.isPublishing,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  String toString() =>
      'ComposeState(${text.length} chars, ${images.length} images, '
      'uploading: $isUploading, publishing: $isPublishing)';
}
