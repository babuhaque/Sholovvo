import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
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
    final String neededBy = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(request.neededBy.toLocal());

    return SolovvoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: <Widget>[
          BloodGroupBadge(group: request.bloodGroup),
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
    final String postedOn = MaterialLocalizations.of(
      context,
    ).formatShortMonthDay(post.createdAt.toLocal());

    return SolovvoCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _InitialsAvatar(name: post.authorName),
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

/// The blood group drawn as the row's leading mark.
///
/// A tinted disc rather than a red one: brand red means "action" everywhere else
/// in the app, and a list of five red discs reads as five alerts.
class BloodGroupBadge extends StatelessWidget {
  const BloodGroupBadge({super.key, required this.group});

  final String group;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.brandTint,
        borderRadius: AppRadius.mdRadius,
      ),
      child: Text(
        group,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: palette.onBrandTint,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        shape: BoxShape.circle,
        border: Border.all(color: palette.outline),
      ),
      child: Text(
        _initials(name),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: palette.textPrimary,
          letterSpacing: 0,
        ),
      ),
    );
  }

  /// One letter per word, first two words: "Ayesha Rahman" → "AR".
  static String _initials(String name) {
    final List<String> words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    return words
        .take(2)
        .map((String word) => word.characters.first.toUpperCase())
        .join();
  }
}
