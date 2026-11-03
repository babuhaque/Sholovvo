import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/feed/application/compose_providers.dart';
import 'package:sholovvo_app/features/feed/application/compose_state.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_draft.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/features/feed/presentation/compose_messages.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/compose_image_grid.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Writes one post: some text, up to four photographs, and a publish.
///
/// **The form is the smallest thing that can produce a valid document.** No
/// title, no tags, no visibility, no scheduling — every one of those is a field
/// the rules would have to allow before it could be used, and none of them is in
/// §14.1. What is here maps one-to-one onto `PostDocument.toCreateMap`.
///
/// **Photos upload as they are picked**, so the publish is a single small
/// document write. See `ComposeController` for why, and for what happens to the
/// objects when the draft is abandoned.
///
/// **Leaving is guarded, not blocked.** A donor who typed something and reaches
/// for the back gesture gets a question; an untouched form closes immediately,
/// because a confirmation over an empty form is an obstacle with no purpose.
class ComposePostScreen extends ConsumerStatefulWidget {
  const ComposePostScreen({super.key});

  /// The route the feed pushes.
  ///
  /// A static factory rather than a named route, matching [FeedScreen] and the
  /// profile editor: a pushed screen in this app carries its own transition.
  static Route<void> route() {
    return FadeSlidePageRoute<void>(page: const ComposePostScreen());
  }

  /// The reading measure. The same 560 the feed and the profile editor use, so
  /// the three text screens share one column width.
  static const double maxContentWidth = 560;

  @override
  ConsumerState<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends ConsumerState<ComposePostScreen> {
  late final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final PostAuthor author = ref.read(composeAuthorProvider);
    final Result<Post> result = await ref
        .read(composeControllerProvider.notifier)
        .publish(author: author);
    if (!mounted || result.isFailure) {
      // The banner explains a failure and the draft survives it, so a retry is
      // one tap rather than retyping the post.
      return;
    }

    final AppLocalizations l10n = context.l10n;
    // The messenger belongs to the app, not this route, so the confirmation
    // survives the pop and lands on the feed the donor returns to.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.feedComposePublished)));
    Navigator.of(context).pop();
  }

  /// Asks before throwing away a draft, then deletes whatever was uploaded for
  /// it — an abandoned draft has no document to own its objects.
  Future<void> _confirmDiscard() async {
    final AppLocalizations l10n = context.l10n;
    final bool? discard = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.feedComposeDiscardTitle),
        content: Text(l10n.feedComposeDiscardBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.feedComposeKeepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.feedComposeDiscardConfirm),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) {
      return;
    }

    await ref.read(composeControllerProvider.notifier).discard();
    if (!mounted) {
      return;
    }
    // Imperative pop, so the guard that just refused the back gesture does not
    // refuse this one too.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ComposeState state = ref.watch(composeControllerProvider);
    final ComposeController controller = ref.read(
      composeControllerProvider.notifier,
    );
    final bool canUpload = ref.watch(postImageStorageProvider).isConfigured;

    // Only the one rule a donor can break while typing is shown live. An empty
    // box is not an error yet — the publish button being disabled already says
    // so — but a post that has just passed the limit is.
    final PostIssue? issue = state.issue;
    final String? textError = issue == PostIssue.textTooLong
        ? postIssueMessage(l10n, issue)
        : null;

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        unawaited(_confirmDiscard());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.feedComposeTitle)),
        body: SoftGlowBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.gutter,
                AppSpacing.sm,
                AppSpacing.gutter,
                AppSpacing.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ComposePostScreen.maxContentWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (state.failure != null) ...<Widget>[
                        ErrorBanner(
                          message: composeFailureMessage(l10n, state.failure!),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      SolovvoTextField(
                        controller: _text,
                        label: l10n.feedComposeTextLabel,
                        hintText: l10n.feedComposeTextHint,
                        maxLines: 6,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !state.isPublishing,
                        errorText: textError,
                        helperText: l10n.feedComposeLimit(
                          PostValidator.maxTextLength,
                        ),
                        onChanged: controller.updateText,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(label: l10n.feedComposePhotosLabel),
                      const SizedBox(height: AppSpacing.xs),
                      if (canUpload)
                        ComposeImageGrid(
                          images: state.images,
                          isUploading: state.isUploading,
                          enabled: !state.isPublishing,
                          onAdd: (PhotoSource source) =>
                              unawaited(controller.addImage(source)),
                          onRemove: (StoredPostImage image) =>
                              unawaited(controller.removeImage(image)),
                        )
                      else
                        _Unavailable(message: l10n.feedComposePhotosNotConfigured),
                      const SizedBox(height: AppSpacing.xl),
                      SolovvoButton(
                        label: l10n.feedComposePublish,
                        icon: Icons.send_rounded,
                        isLoading: state.isPublishing,
                        // Disabled while uploading as well: publishing a post
                        // whose fourth photo is still in flight would write a
                        // document that is missing it.
                        onPressed: issue == null && !state.isBusy
                            ? () => unawaited(_publish())
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The uppercase caption above a group of controls, matching the form fields.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.1,
        color: palette.textSecondary,
      ),
    );
  }
}

/// The honest "no photo bucket in this build" state.
///
/// Not a disabled add tile: a donor who taps and gets nothing learns nothing.
/// This says what is missing, and the text half of the form still works, so the
/// screen is not a dead end.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: palette.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
