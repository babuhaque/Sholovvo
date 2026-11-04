import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';

/// One community post, as the dashboard previews it.
///
/// The other row of this file's former pair — the nearby request — moved to
/// `RequestTile` in the requests feature when Stage 9 gave the dashboard a real
/// read: the same widget now draws the row on the dashboard and on the requests
/// screen, so the two cannot disagree about what a request carries.
class FeedPostCard extends StatelessWidget {
  const FeedPostCard({super.key, required this.post, this.onTap});

  final FeedPostPreview post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final String postedOn = MaterialLocalizations.of(context)
        .formatShortMonthDay(post.createdAt.toLocal());

    return SolovvoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          InitialsAvatar(
            name: post.authorName,
            size: 40,
            variant: InitialsAvatarVariant.muted,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        post.authorName,
                        style: text.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(postedOn, style: text.labelSmall),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  post.excerpt,
                  style: text.bodySmall?.copyWith(color: palette.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
