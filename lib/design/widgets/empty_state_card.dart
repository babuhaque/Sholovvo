import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';

/// The "nothing here yet" card a section shows before its data exists.
///
/// Muted and borderless-of-shadow on purpose: an empty section should read as
/// calm and finished, not as a broken card or a loading state that never ends.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Optional control below the body, e.g. "Try again" on a failed read. Omitted
  /// by empty-by-definition sections, which have nothing to retry.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      color: palette.surfaceMuted,
      shadow: const <BoxShadow>[],
      borderColor: palette.outline,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 22, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Left unbounded, this column is only as tall as its text and the
              // card hugs it. Inside a bounded-height parent — the feed's
              // `SliverFillRemaining` — the default would stretch the card to
              // the whole viewport, which reads as a broken card rather than a
              // calm empty state.
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: text.titleMedium?.copyWith(color: palette.textPrimary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(body, style: text.bodySmall),
                if (action != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
