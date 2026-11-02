import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// How much of the profile is filled in, and exactly what is missing.
///
/// The count is derived from [UserProfile.missingFields] — the same predicate the
/// save path uses — so this indicator cannot drift from what the form accepts.
/// Every field it names is now one the donor can actually fill in, the photo
/// included: Stage 6 added the upload, so the photo chip no longer carries a
/// "not yet" caveat.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({
    super.key,
    required this.profile,
    required this.onEdit,
  });

  final UserProfile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    final List<ProfileField> missing = profile.missingFields;
    final int done = profile.completedCount;
    final int total = ProfileField.values.length;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.profileCompletionTitle, style: text.titleMedium),
              ),
              const SizedBox(width: AppSpacing.xs),
              // Flexible, not a plain Text: the Bangla count is long enough to
              // overflow a 320 dp phone when the two are laid out side by side.
              Flexible(
                child: Text(
                  l10n.profileCompletionCount(done, total),
                  textAlign: TextAlign.end,
                  style: text.labelSmall?.copyWith(
                    color: palette.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _CompletionBar(value: total == 0 ? 0 : done / total),
          const SizedBox(height: AppSpacing.sm),
          if (missing.isEmpty)
            Text(l10n.profileCompletionAllDone, style: text.bodySmall)
          else ...<Widget>[
            Text(
              l10n.profileCompletionMissingTitle.toUpperCase(),
              style: text.labelSmall?.copyWith(
                color: palette.textSecondary,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xxs,
              children: <Widget>[
                for (final ProfileField field in missing)
                  _MissingChip(label: profileFieldLabel(l10n, field)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.profileAddDetails),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Progress drawn by hand rather than with `LinearProgressIndicator` so it can
/// use the brand gradient and the theme's own track colour in both themes.
class _CompletionBar extends StatelessWidget {
  const _CompletionBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final double clamped = value.clamp(0, 1).toDouble();

    return ClipRRect(
      borderRadius: AppRadius.pillRadius,
      child: SizedBox(
        height: 8,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Stack(
              children: <Widget>[
                ColoredBox(color: palette.surfaceMuted, child: const SizedBox.expand()),
                SizedBox(
                  width: constraints.maxWidth * clamped,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: palette.brandGradient,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One field that is still empty. A chip, not a row: the list is short and
/// scanning it horizontally is faster than reading six lines.
class _MissingChip extends StatelessWidget {
  const _MissingChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: AppRadius.pillRadius,
        border: Border.all(color: palette.outline),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.textSecondary,
        ),
      ),
    );
  }
}
