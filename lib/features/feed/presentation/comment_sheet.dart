import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/features/feed/application/comment_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';
import 'package:sholovvo_app/features/feed/domain/entities/report.dart';
import 'package:sholovvo_app/features/feed/presentation/report_sheet.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/comment_tile.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A modal bottom sheet showing one post's comment thread.
///
/// Opened from the feed tile when the donor taps "N comments". Reads the
/// [commentControllerProvider] for the given [postId]; the controller
/// auto-loads on first access and the sheet renders whatever state it is in.
///
/// The compose bar at the bottom submits through the same controller.
/// Tapping "Reply" on any comment sets a reply-to context, shown as a banner
/// above the compose bar; the next submission passes `parentId`/`replyToName`
/// to the controller.
class CommentSheet extends ConsumerStatefulWidget {
  const CommentSheet({super.key, required this.postId});

  final String postId;

  /// Shows the sheet on top of [context]. Returns when dismissed.
  static Future<void> show(BuildContext context, String postId) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => CommentSheet(postId: postId),
    );
  }

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  /// The comment being replied to, or null for a top-level comment.
  Comment? _replyTo;

  @override
  void initState() {
    super.initState();
    // Load the thread on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commentControllerProvider.notifier).open(widget.postId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    // Author snapshot from the profile stream.
    final profile = ref.read(profileProvider).value;
    final String authorName = profile?.displayName ?? '';
    final String? photoUrl = profile?.photoUrl;

    _controller.clear();
    final bool success = await ref
        .read(commentControllerProvider.notifier)
        .submitComment(
          authorUid: uid,
          authorName: authorName,
          authorPhotoUrl: photoUrl,
          text: text,
          parentId: _replyTo?.id,
          replyToName: _replyTo?.authorName,
        );

    if (success) {
      setState(() => _replyTo = null);
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final state = ref.watch(commentControllerProvider);

    // Adjust the sheet height for the keyboard.
    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          children: <Widget>[
            _Header(title: l10n.commentsSheetTitle),
            const Divider(height: 1),
            Expanded(
              child: _buildBody(context, l10n, state),
            ),
            if (_replyTo != null)
              _ReplyBanner(
                replyToName: _replyTo!.authorName,
                onCancel: () => setState(() => _replyTo = null),
              ),
            _ComposeBar(
              controller: _controller,
              isSubmitting: state.isSubmitting,
              hintText: _replyTo != null
                  ? l10n.commentsReplyHint
                  : l10n.commentsHintText,
              sendTooltip: l10n.commentsSendTooltip,
              onSend: _submit,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CommentState state,
  ) {
    if (state.isLoading && state.comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: AppSpacing.sm),
            Text(l10n.commentsLoading, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      );
    }

    if (state.failure != null && state.comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, size: 32),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.commentsErrorTitle,
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () =>
                    ref.read(commentControllerProvider.notifier).retry(),
                child: Text(l10n.feedRetry),
              ),
            ],
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return Center(
        child: Text(
          l10n.commentsEmptyBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: state.comments.length,
      itemBuilder: (BuildContext context, int index) {
        final Comment comment = state.comments[index];
        final String? uid = FirebaseAuth.instance.currentUser?.uid;
        return CommentTile(
          comment: comment,
          onReply: () => setState(() => _replyTo = comment),
          onDelete: comment.authorUid == uid
              ? () async {
                  await ref
                      .read(commentControllerProvider.notifier)
                      .deleteComment(comment.id);
                }
              : null,
          onReport: comment.authorUid != uid
              ? () => unawaited(ReportSheet.show(
                    context,
                    targetId: comment.id,
                    targetAuthorUid: comment.authorUid,
                    targetType: ReportTarget.comment,
                  ))
              : null,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _ComposeBar extends StatelessWidget {
  const _ComposeBar({
    required this.controller,
    required this.isSubmitting,
    required this.hintText,
    required this.sendTooltip,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSubmitting;
  final String hintText;
  final String sendTooltip;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 500,
                maxLines: 1,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: hintText,
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filledTonal(
              onPressed: isSubmitting ? null : onSend,
              tooltip: sendTooltip,
              icon: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.send_rounded, color: colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A contextual banner above the compose bar, indicating the user is replying
/// to a specific comment. Shows "Replying to {name}" and a cancel button.
class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.replyToName, required this.onCancel});

  final String replyToName;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.primaryContainer.withAlpha(80),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.reply_rounded, size: 14, color: colors.primary),
          const SizedBox(width: AppSpacing.xxs),
          Expanded(
            child: Text(
              l10n.commentsReplyingTo(replyToName),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.primary,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            tooltip: l10n.actionCancel,
          ),
        ],
      ),
    );
  }
}
