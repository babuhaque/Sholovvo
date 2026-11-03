import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/config/supabase_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/media/image_picker_photo_picker.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/features/feed/application/compose_state.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/data/firestore_post_repository.dart';
import 'package:sholovvo_app/features/feed/data/firestore_post_writer.dart';
import 'package:sholovvo_app/features/feed/data/supabase_post_image_storage.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/features/feed/domain/post_repository.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';

/// The write backend.
///
/// Constructed lazily, like [feedRepositoryProvider], so a tree that never opens
/// the composer never touches `FirebaseFirestore.instance`.
final Provider<PostRepository> postRepositoryProvider =
    Provider<PostRepository>((Ref ref) {
      return FirestorePostRepository(
        FirestorePostWriter(
          FirebaseAuth.instance,
          FirebaseFirestore.instance,
        ),
      );
    });

/// Where post photographs are stored.
///
/// Builds the Supabase adapter even when the build carries no credentials: the
/// adapter answers `isConfigured: false` and the screen says so, which is the
/// same honest state the avatar sheet shows rather than a control that can only
/// fail.
final Provider<PostImageStorage> postImageStorageProvider =
    Provider<PostImageStorage>((Ref ref) {
      return SupabasePostImageStorage(
        FirebaseAuth.instance,
        ref.watch(supabaseConfigProvider),
      );
    });

/// The platform picker.
///
/// The same adapter the profile uses; declared here rather than imported from
/// the profile feature so the feed does not depend on another feature's
/// application layer for a one-line construction.
final Provider<PhotoPicker> postPhotoPickerProvider = Provider<PhotoPicker>(
  (Ref ref) => ImagePickerPhotoPicker(),
);

/// The author snapshot a new post is written with.
///
/// Projected from the profile stream rather than read at publish time, so the
/// screen can name the author before the write and the document repeats exactly
/// what was shown. A profile that has not arrived yet yields
/// [PostAuthor.unknown] — posting is not blocked on a name.
final Provider<PostAuthor> composeAuthorProvider = Provider<PostAuthor>((
  Ref ref,
) {
  // `.value` rather than awaiting: a profile that has not loaded yet is not an
  // error here, it is a post by somebody who has not filled it in.
  final UserProfile? profile = ref.watch(profileProvider).value;
  if (profile == null) {
    return const PostAuthor.unknown();
  }
  final String? photoUrl = profile.photoUrl?.trim();
  return PostAuthor(
    name: profile.displayName.trim(),
    photoUrl: photoUrl == null || photoUrl.isEmpty ? null : photoUrl,
  );
});

/// Owns the compose form: the text, the uploaded photos, and the one publish.
///
/// **Photos upload on pick, not on publish.** A donor who attaches four
/// photographs and then waits for a single five-megabyte-each request at the end
/// has no idea which one is stuck. Uploading immediately means the publish is
/// one small document write, and a photo that fails fails on its own while the
/// text is still editable.
///
/// **One operation at a time.** [_busy] guards the whole flow rather than each
/// method's own flag, because the gaps matter: `pick` awaits the platform before
/// any state changes, so two fast taps on the add tile could otherwise open two
/// pickers and race two uploads into the same four slots.
class ComposeController extends Notifier<ComposeState> {
  bool _busy = false;

  static const AppLogger _logger = AppLogger('feed.compose');

  @override
  ComposeState build() => const ComposeState();

  /// Records what was typed. The field's controller owns the caret; this is the
  /// copy the validator and the publish read.
  void updateText(String value) {
    if (state.text == value) {
      return;
    }
    state = state.copyWith(text: value);
  }

  /// Picks one photo, validates it, and uploads it into the next slot.
  ///
  /// A cancelled picker is silence, not an error: [PhotoPicker] reports a cancel
  /// as a successful `null`, and a donor who changed their mind should not be
  /// told something went wrong.
  Future<void> addImage(PhotoSource source) async {
    if (_busy || !state.canAddImage) {
      return;
    }
    _busy = true;
    try {
      final Result<PhotoCandidate?> picked = await ref
          .read(postPhotoPickerProvider)
          .pick(source);

      final PhotoCandidate? candidate = picked.valueOrNull;
      if (candidate == null) {
        final Failure? failure = picked.failureOrNull;
        if (failure != null) {
          state = state.copyWith(failure: failure);
        }
        return;
      }

      // Validated before the network is involved, using the same size and
      // magic-byte rules the bucket enforces. A file refused here costs nothing.
      final Result<ValidatedPhoto> validated = PhotoValidator.validate(candidate);
      final ValidatedPhoto? photo = validated.valueOrNull;
      if (photo == null) {
        state = state.copyWith(failure: validated.failureOrNull);
        return;
      }

      state = state.copyWith(isUploading: true, clearFailure: true);
      final Result<StoredPostImage> stored = await ref
          .read(postImageStorageProvider)
          .upload(photo);

      final StoredPostImage? image = stored.valueOrNull;
      state = image == null
          ? state.copyWith(isUploading: false, failure: stored.failureOrNull)
          : state.copyWith(
              isUploading: false,
              images: <StoredPostImage>[...state.images, image],
            );
    } finally {
      _busy = false;
    }
  }

  /// Drops one photo from the form and deletes the object behind it.
  ///
  /// The slot is emptied first: the donor asked for it to go, and a list that
  /// still shows it while a delete round-trips looks ignored. The delete itself
  /// is best effort — a failure would be a sentence about a file that is no
  /// longer on screen, so it is logged instead.
  Future<void> removeImage(StoredPostImage image) async {
    if (state.isPublishing) {
      return;
    }
    state = state.copyWith(
      images: <StoredPostImage>[
        for (final StoredPostImage existing in state.images)
          if (existing != image) existing,
      ],
      clearFailure: true,
    );

    final Result<bool> removed = await ref
        .read(postImageStorageProvider)
        .remove(image.path);
    final Failure? failure = removed.failureOrNull;
    if (failure != null) {
      _logger.warning('Could not delete a removed post photo', error: failure);
    }
  }

  /// Abandons the draft, deleting any photo already uploaded for it.
  ///
  /// Called when the donor confirms the discard prompt. Without it, every
  /// abandoned compose would leave up to four objects in the bucket that no
  /// document names — the free tier counts bytes, not intentions.
  Future<void> discard() async {
    if (state.isPublishing) {
      return;
    }
    final List<StoredPostImage> orphaned = state.images;
    state = const ComposeState();
    if (orphaned.isEmpty) {
      return;
    }

    final PostImageStorage storage = ref.read(postImageStorageProvider);
    for (final StoredPostImage image in orphaned) {
      final Result<bool> removed = await storage.remove(image.path);
      final Failure? failure = removed.failureOrNull;
      if (failure != null) {
        _logger.warning(
          'Could not delete an abandoned post photo',
          error: failure,
        );
      }
    }
  }

  /// Publishes the draft and puts the result at the top of the feed.
  ///
  /// [author] is passed in rather than read here so the screen can show who the
  /// post will be attributed to, and so a test can pin the snapshot without a
  /// profile stream.
  ///
  /// The form is reset on success **before** returning: the screen pops right
  /// after, and a draft left behind would let a back-navigation publish the same
  /// post twice.
  Future<Result<Post>> publish({required PostAuthor author}) async {
    if (_busy || state.isBusy) {
      return const FailureResult<Post>(
        ConflictFailure(debugMessage: 'A compose operation is already running'),
      );
    }

    final PostIssue? issue = state.issue;
    if (issue != null) {
      return FailureResult<Post>(
        ValidationFailure(
          messageKey: issue.name,
          debugMessage: 'Compose rejected the draft: ${issue.name}',
        ),
      );
    }

    _busy = true;
    state = state.copyWith(isPublishing: true, clearFailure: true);
    try {
      final PostDraft draft = PostDraft(
        author: author,
        // Trimmed once, here: the form is the last place that knows which
        // whitespace the donor meant, and the document stores what they wrote.
        text: state.text.trim(),
        images: state.images,
      );

      final Result<Post> result = await ref
          .read(postRepositoryProvider)
          .publish(draft);
      final Post? post = result.valueOrNull;

      if (post == null) {
        // The draft survives a failure intact, so the retry is one tap rather
        // than retyping the post.
        state = state.copyWith(
          isPublishing: false,
          failure: result.failureOrNull,
        );
        return result;
      }

      state = const ComposeState();
      // Shown immediately rather than waiting for a refresh the donor did not
      // ask for. A feed that has not loaded ignores this and picks the post up
      // with its own first page.
      ref.read(feedControllerProvider.notifier).prepend(post);
      return result;
    } finally {
      _busy = false;
    }
  }
}

final NotifierProvider<ComposeController, ComposeState>
composeControllerProvider = NotifierProvider<ComposeController, ComposeState>(
  ComposeController.new,
);
