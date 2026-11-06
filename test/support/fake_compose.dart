import 'dart:async';

import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/data/post_edit_service.dart';
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

  /// Completed the first time [upload] is entered.
  ///
  /// A [gate] can show how long an upload takes; it cannot show that one has
  /// started. Without this a busy-state test has to guess how many microtasks the
  /// code under test needs to reach the network, which is precisely the
  /// assumption a test about an in-flight state must not make.
  Completer<void> uploadStarted = Completer<void>();

  int uploadCalls = 0;
  final List<ValidatedPhoto> uploaded = <ValidatedPhoto>[];
  final List<String> removedPaths = <String>[];

  @override
  Future<Result<StoredPostImage>> upload(ValidatedPhoto photo) async {
    final int index = uploadCalls++;
    uploaded.add(photo);
    if (!uploadStarted.isCompleted) {
      uploadStarted.complete();
    }
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

/// An in-memory [PostEditService]: the seam the edit sheet is tested across.
///
/// Records the text and the two image lists it was handed rather than writing
/// them, so a test can assert that a save submitted the surviving photos as
/// parallel url/path lists — the exact normalisation that fixes a legacy post
/// whose document carried neither key. When the matching failure is set the
/// call reports it, which is how the sheet's error paths are reached.
class FakePostEditService implements PostEditService {
  FakePostEditService({this.authorUid = 'uid-verified'});

  /// The uid the stored posts are attributed to, checked the way the real
  /// service checks it before any write.
  String authorUid;

  /// Returned instead of a success from [editPost] when set.
  Failure? editFailure;

  /// Returned instead of a success from [deletePost] when set.
  Failure? deleteFailure;

  int editCalls = 0;
  int deleteCalls = 0;
  String? lastEditedText;
  List<String>? lastImageUrls;
  List<String>? lastImagePaths;
  String? lastPostId;
  String? lastEditUid;

  @override
  Future<Result<void>> editPost({
    required String postId,
    required String uid,
    required String newText,
    required List<String> imageUrls,
    required List<String> imagePaths,
  }) async {
    editCalls++;
    lastPostId = postId;
    lastEditUid = uid;
    lastEditedText = newText.trim();
    lastImageUrls = imageUrls;
    lastImagePaths = imagePaths;
    if (editFailure != null) {
      return FailureResult<void>(editFailure!);
    }
    if (uid.isEmpty || postId.isEmpty) {
      return const FailureResult<void>(
        AuthFailure(debugMessage: 'Missing uid or postId'),
      );
    }
    if (lastEditedText!.isEmpty) {
      return const FailureResult<void>(
        ValidationFailure(messageKey: 'textRequired'),
      );
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<void>> deletePost({
    required String postId,
    required String uid,
  }) async {
    deleteCalls++;
    lastPostId = postId;
    lastEditUid = uid;
    if (deleteFailure != null) {
      return FailureResult<void>(deleteFailure!);
    }
    return const Success<void>(null);
  }
}
