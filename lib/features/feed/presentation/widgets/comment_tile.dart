import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/features/feed/domain/entities/comment.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One row in a comment thread.
///
/// A compact read-and-reply presentation: avatar, name, time, text. A reply
/// shows a "Reply to X" prefix. Tapping the row (or the inline "Reply" button)
/// invokes [onReply], which the sheet uses to set the reply-to context.
/// The comment author sees an inline "Delete" button ([onDelete]).
/// Other comments show a "Report" label ([onReport]).
class CommentTile extends StatelessWidget {
  const CommentTile({
    super.key,
    required this.comment,
    this.now,
    this.onReply,
    this.onDelete,
    this.onReport,
  });

  final Comment comment;

  /// Reference time for the relative label. Null = build-time clock.
  final DateTime? now;

  /// Called when the user wants to reply to this comment.
  final VoidCallback? onReply;

  /// Called when the author taps "Delete". Null hides the label.
  final VoidCallback? onDelete;

  /// Called when a non-author taps "Report". Null hides the label.
  final VoidCallback? onReport;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    final String timeLabel = feedRelativeTime(
      l10n,
      comment.createdAt,
      olderDate: MaterialLocalizations.of(context)
          .formatShortMonthDay(comment.createdAt.toLocal()),
      now: now,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InitialsAvatar(
            name: comment.authorName,
            photoUrl: comment.authorPhotoUrl,
            size: 32,
            variant: InitialsAvatarVariant.muted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        comment.authorName,
                        style: text.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Text(
                      timeLabel,
                      style: text.labelSmall?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                if (comment.isReply && comment.replyToName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      l10n.commentsReplyPrefix(comment.replyToName!),
                      style: text.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(comment.text, style: text.bodySmall),
                if (onReply != null || onDelete != null || onReport != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: <Widget>[
                        if (onReply != null)
                          GestureDetector(
                            onTap: onReply,
                            child: Text(
                              l10n.commentsReplyAction,
                              style: text.labelSmall?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        if (onReply != null &&
                            (onDelete != null || onReport != null))
                          const SizedBox(width: AppSpacing.sm),
                        if (onDelete != null)
                          GestureDetector(
                            onTap: onDelete,
                            child: Text(
                              l10n.commentsDeleteAction,
                              style: text.labelSmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        if (onDelete != null && onReport != null)
                          const SizedBox(width: AppSpacing.sm),
                        if (onReport != null)
                          GestureDetector(
                            onTap: onReport,
                            child: Text(
                              l10n.reportTooltip,
                              style: text.labelSmall?.copyWith(
                                color: context.palette.textSecondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
