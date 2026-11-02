import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The donor's own availability flag, and the only control that ever changes it.
///
/// `firestore.rules` matches donors on `users.isAvailable == true`, and nothing
/// in the app flips this field except a tap here. It is deliberately not derived
/// from the last donation date: eligibility is a medical judgement, and a client
/// computing "it has been 90 days" would be guessing at someone's health.
class ProfileAvailabilityCard extends StatelessWidget {
  const ProfileAvailabilityCard({
    super.key,
    required this.isAvailable,
    required this.hasBloodGroup,
    required this.isBusy,
    required this.onChanged,
  });

  final bool isAvailable;
  final bool hasBloodGroup;

  /// While a write is in flight the switch is disabled rather than optimistic:
  /// a flag that visibly flopped back after a failed write is worse than a
  /// switch that waited 300 ms.
  final bool isBusy;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.profileAvailabilityTitle, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      isAvailable
                          ? l10n.availableNow
                          : l10n.notAvailableNow,
                      style: text.labelSmall?.copyWith(
                        color: isAvailable
                            ? palette.success
                            : palette.textSecondary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isAvailable,
                onChanged: isBusy ? null : onChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            isAvailable
                ? l10n.profileAvailabilityOnBody
                : l10n.profileAvailabilityOffBody,
            style: text.bodySmall,
          ),
          if (!hasBloodGroup) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            // On is still allowed: the flag records what the donor said. But a
            // request is matched on group *and* availability, so saying "on"
            // without a group would read as matchable when it is not.
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.warning.withValues(alpha: 0.08),
                borderRadius: AppRadius.smRadius,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: palette.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.profileAvailabilityNeedsGroup,
                      style: text.bodySmall?.copyWith(color: palette.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
