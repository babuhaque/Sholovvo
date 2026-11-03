import 'dart:async';

import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/post_writer.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/features/feed/domain/post_repository.dart';

import 'fake_photo_services.dart';

/// The public URL a post image at [path] would have on a demo project.
String postImageUrl(String path) =>
    'https://demo.supabase.co/storage/v1/object/public/post-images/$path';

/// A [StoredPostImage] named the way `SupabasePostImageStorage.objectPath`
/// names the [index]th upload of a session.
StoredPostImage storedImage([int index = 0]) {
  const String uid = 'uid-verified';
  final String path = '$uid/post-${1730000000000 + index}-$index.jpg';
  return StoredPostImage(url: postImageUrl(path), path: path);
}

/// A [ValidatedPhoto] built through the real validator.
///
/// The constructor of `ValidatedPhoto` is private on purpose, so a fake has to
/// earn one the way the app does: by handing the validator bytes that sniff as
/// a JPEG.
ValidatedPhoto validatedJpeg() {
  final ValidatedPhoto? photo = PhotoValidator.validate(
    PhotoCandidate(bytes: jpegBytes()),
  ).valueOrNull;
  if (photo == null) {
    throw StateError('The fixture bytes no longer validate as a JPEG');
  }
  return photo;
}

/// An in-memory [PostRepository].
///
/// Derives the returned post from the draft it was given, so a test that
/// publishes sees the text it typed come back rather than a canned document.
class FakePostRepository implements PostRepository {
  FakePostRepository({this.fixed});

  /// Returned instead of a post derived from the draft.
  Post? fixed;

  /// Returned instead of a post when set.
  Failure? failure;

  /// Holds the call open, so a test can watch the publishing state.
  Completer<void>? gate;

  int calls = 0;
  PostDraft? lastDraft;

  @override
  Future<Result<Post>> publish(PostDraft draft) async {
    calls++;
    lastDraft = draft;

    final Completer<void>? pending = gate;
    if (pending != null) {
      await pending.future;
    }

    if (failure != null) {
      return FailureResult<Post>(failure!);
    }
    if (fixed != null) {
      return Success<Post>(fixed!);
    }

    final DateTime stamp = DateTime.utc(2026, 11, 2, 9);
    return Success<Post>(
      Post(
        id: 'post-published-$calls',
        authorUid: 'uid-verified',
        authorName: draft.author.name,
        authorPhotoUrl: draft.author.photoUrl,
        text: draft.text,
        imageUrls: draft.imageUrls,
        imagePaths: draft.imagePaths,
        createdAt: stamp,
        updatedAt: stamp,
      ),
    );
  }
}

/// An in-memory [PostImageStorage].
///
/// Names each upload after the order it arrived in, which is what lets a test
/// assert that a removal named the path of the photo it dropped rather than
/// whatever happened to be first.
class FakePostImageStorage implements PostImageStorage {
  FakePostImageStorage({this.isConfigured = true});

  @override
  bool isConfigured;

  /// When set, the matching call returns this failure instead of succeeding.
  Failure? uploadFailure;
  Failure? removeFailure;

  /// What a successful removal reports.
  bool removeResult = true;

  /// Holds both calls open, so the uploading spinner can be seen.
  Completer<void>? gate;

  int uploadCalls = 0;
  final List<ValidatedPhoto> uploaded = <ValidatedPhoto>[];
  final List<String> removedPaths = <String>[];

  @override
  Future<Result<StoredPostImage>> upload(ValidatedPhoto photo) async {
    final int index = uploadCalls++;
    uploaded.add(photo);
    await _waitForGate();
    if (uploadFailure != null) {
      return FailureResult<StoredPostImage>(uploadFailure!);
    }
    return Success<StoredPostImage>(storedImage(index));
  }

  @override
  Future<Result<bool>> remove(String objectPath) async {
    removedPaths.add(objectPath);
    await _waitForGate();
    if (removeFailure != null) {
      return FailureResult<bool>(removeFailure!);
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

/// One document a [FakePostWriter] was asked to create.
typedef CreatedPost = ({String id, Map<String, Object?> fields});

/// An in-memory [PostWriter]: the seam the repository is tested across.
///
/// Records the fields rather than writing them, so the repository test can check
/// the exact shape that would have gone to Firestore — which is the only place
/// that shape is decided.
class FakePostWriter implements PostWriter {
  FakePostWriter({this.authorUid = 'uid-verified', this.newId = 'post-new'});

  @override
  String? authorUid;

  /// The id [newPostId] hands out.
  String newId;

  /// When set, [createPost] returns this failure instead of succeeding.
  Failure? createFailure;

  int idCalls = 0;
  final List<CreatedPost> created = <CreatedPost>[];

  @override
  String newPostId() {
    idCalls++;
    return newId;
  }

  @override
  Future<Result<void>> createPost(String id, Map<String, Object?> fields) async {
    created.add((id: id, fields: fields));
    if (createFailure != null) {
      return FailureResult<void>(createFailure!);
    }
    return const Success<void>(null);
  }
}
