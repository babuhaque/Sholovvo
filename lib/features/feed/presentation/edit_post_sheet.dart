import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/feed/application/compose_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/data/post_edit_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/compose_image_grid.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A bottom sheet for editing the text and photographs of an existing post.
///
/// Author-only: shows a pre-filled text field, the post's current photos in the
/// same grid the composer uses, and a Save button. Photos can be added (picked
/// and uploaded on the spot, exactly as a new post's are) and removed. On
/// success pops with `true` so the caller can refresh the feed; on failure
/// shows an inline error and stays open.
class EditPostSheet extends ConsumerStatefulWidget {
  const EditPostSheet({super.key, required this.post});

  final Post post;

  /// Shows the edit sheet. Returns a non-null value if the post was saved or deleted.
  static Future<Object?> show(BuildContext context, {required Post post}) {
    return showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => EditPostSheet(post: post),
    );
  }

  @override
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.post.text,
  );

  /// The photos the post will carry on save, seeded from what it carries now.
  ///
  /// A stored object needs both halves of a [StoredPostImage] to be re-published
  /// or deleted later, so a photo with no known path cannot be edited away and
  /// is left for the submit mapping to drop. In this app's own posts the two
  /// lists are always parallel (see `Post.imagePaths`), so every photo a donor
  /// can see is one they can remove; the gap only reaches posts written by
  /// another client, which this sheet never made.
  late final List<StoredPostImage> _images = <StoredPostImage>[
    for (int i = 0; i < widget.post.imageUrls.length; i++)
      if (i < widget.post.imagePaths.length)
        StoredPostImage(url: widget.post.imageUrls[i], path: widget.post.imagePaths[i]),
  ];

  bool _isSaving = false;
  bool _isUploading = false;
  int _pendingUploads = 0;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Picks one photo, validates it, and uploads it into the next slot — the
  /// same on-pick flow the composer runs, so a photo that fails on the way into
  /// the bucket is reported here rather than at Save. A cancelled picker is
  /// silence, not an error: `PhotoPicker` reports a cancel as a `Success(null)`.
  Future<void> _addImage(PhotoSource source) async {
    if (_images.length >= PostValidator.maxImages) {
      return;
    }
    setState(() {
      _isUploading = true;
      _pendingUploads++;
      _errorMessage = null;
    });

    final Result<PhotoCandidate?> picked = await ref
        .read(postPhotoPickerProvider)
        .pick(source);

    if (!mounted) {
      return;
    }

    void finishUpload(Failure? failure) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingUploads--;
        if (_pendingUploads <= 0) {
          _pendingUploads = 0;
          _isUploading = false;
        }
        if (failure != null) {
          _errorMessage = feedFailureMessage(context.l10n, failure);
        }
      });
    }

    final PhotoCandidate? candidate = picked.valueOrNull;
    if (candidate == null) {
      // Cancel, or a pick that failed. A cancel carries no failure to show.
      finishUpload(picked.failureOrNull);
      return;
    }

    final Result<ValidatedPhoto> validated = PhotoValidator.validate(candidate);
    final ValidatedPhoto? photo = validated.valueOrNull;
    if (photo == null) {
      finishUpload(validated.failureOrNull);
      return;
    }

    final Result<StoredPostImage> stored = await ref
        .read(postImageStorageProvider)
        .upload(photo);
    final StoredPostImage? image = stored.valueOrNull;

    if (!mounted) {
      return;
    }
    if (image != null) {
      setState(() => _images.add(image));
    }
    finishUpload(stored.failureOrNull);
  }

  /// Drops one photo from the post and deletes the object behind it.
  ///
  /// Removed from the list immediately so the slot empties under the donor's
  /// finger; the delete is best effort — a failure is a sentence about a file
  /// that is already off screen, so the Save path simply stops naming it.
  Future<void> _removeImage(StoredPostImage image) async {
    if (_isSaving) {
      return;
    }
    setState(() => _images.remove(image));

    final Result<bool> removed = await ref
        .read(postImageStorageProvider)
        .remove(image.path);
    final Failure? failure = removed.failureOrNull;
    if (failure != null) {
      debugPrint('edit_post: could not delete removed photo ${failure.code}');
    }
  }

  Future<void> _save() async {
    // The uid comes from the overridable seam, not `FirebaseAuth.instance`, so
    // the whole edit flow — sheet, photo add/remove, save, failure mapping — is
    // testable without a Firebase project, and a null (signed-out) uid simply
    // closes the sheet without a write.
    final String? uid = ref.read(authUidProvider);
    if (uid == null) return;

    setState(() => _isSaving = true);

    // Parallel lists built from the surviving photos, so the object paths stay
    // lined up with the URLs the rules count against.
    final List<String> urls = <String>[
      for (final StoredPostImage image in _images) image.url,
    ];
    final List<String> paths = <String>[
      for (final StoredPostImage image in _images) image.path,
    ];

    final PostEditService service = ref.read(postEditServiceProvider);
    final Result<void> result = await service.editPost(
      postId: widget.post.id,
      uid: uid,
      newText: _controller.text,
      imageUrls: urls,
      imagePaths: paths,
    );

    if (!mounted) return;

    switch (result) {
      case Success<void>():
        Navigator.of(context).pop(true);
      case FailureResult<void>(:final failure):
        // The read-then-write in `FirestorePostEditService` already turns a
        // permission-denied into a PermissionFailure and a bad body into a
        // ValidationFailure, so the donor is told which of the two went wrong
        // rather than a single "could not save" that hides an oversize post
        // behind the same sentence as a dropped connection.
        setState(() {
          _isSaving = false;
          _errorMessage = feedFailureMessage(context.l10n, failure);
        });
    }
  }

  Future<void> _delete() async {
    final AppLocalizations l10n = context.l10n;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(l10n.feedDeleteConfirmTitle),
        content: Text(l10n.feedDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.feedDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final String? uid = ref.read(authUidProvider);
    if (uid == null) return;

    setState(() => _isSaving = true);

    final PostEditService service = ref.read(postEditServiceProvider);
    final Result<void> result = await service.deletePost(
      postId: widget.post.id,
      uid: uid,
    );

    if (!mounted) return;

    switch (result) {
      case Success<void>():
        // Deleting the Firestore document does not touch the bucket, so the
        // photos it pointed at would orphan there forever. Remove them now —
        // best effort, exactly like the compose discard path: a leaked file is
        // not a reason to keep the sheet open on a post that no longer exists.
        // `_images` is the complete live set: the originals still attached plus
        // any photo uploaded during this session (which the doc never saved),
        // while anything removed earlier was already deleted by `_removeImage`.
        final PostImageStorage storage = ref.read(postImageStorageProvider);
        for (final StoredPostImage image in _images) {
          final Result<bool> removed = await storage.remove(image.path);
          final Failure? failure = removed.failureOrNull;
          if (failure != null) {
            debugPrint(
              'edit_post: could not delete post photo ${failure.code}',
            );
          }
        }
        if (!mounted) return;
        Navigator.of(context).pop('deleted');
      case FailureResult<void>():
        setState(() {
          _isSaving = false;
          _errorMessage = l10n.feedDeleteError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              l10n.feedEditTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _controller,
              maxLines: 6,
              minLines: 3,
              maxLength: PostValidator.maxTextLength,
              decoration: InputDecoration(
                hintText: l10n.feedEditHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.feedEditPhotosLabel,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            ComposeImageGrid(
              images: _images,
              isUploading: _isUploading,
              enabled: !_isSaving,
              onAdd: (PhotoSource source) => unawaited(_addImage(source)),
              onRemove: _removeImage,
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SolovvoButton(
              label: _isSaving ? l10n.feedEditSaving : l10n.feedEditSave,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
              expand: true,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _isSaving ? null : _delete,
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                child: Text(l10n.feedDeleteAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
