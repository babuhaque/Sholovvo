import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One nearby request, as the dashboard lists it.
///
/// Shows only what the summary actually carries: no distance, no recipient name
/// and no live status, because none of those exist until the request itself is
/// read (Stage 9). A row that invents a distance would be worse than no row.
class NearbyRequestCard extends StatelessWidget {
  const NearbyRequestCard({super.key, required this.request, this.onTap});

  final NearbyRequestSummary request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final String neededBy = MaterialLocalizations.of(context)
        .formatShortMonthDay(request.neededBy.toLocal());

    return SolovvoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          BloodGroupBadge(
            bloodGroup: request.bloodGroup,
            variant: BloodGroupBadgeVariant.square,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  request.area,
                  style: text.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${l10n.homeUnitsNeeded(request.units)} · '
                  '${l10n.homeNeededBy(neededBy)}',
                  style: text.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
        ],
      ),
    );
  }
}

/// One community post, as the dashboard previews it.
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
