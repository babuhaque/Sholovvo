import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// What other donors can see, and what they never can.
///
/// There is exactly one real switch here because there is exactly one field the
/// app ever publishes beyond the donor card: the area. The private subcollection
/// is unreadable by anyone but its owner under `firestore.rules`, so a "share my
/// phone with matches" toggle would be a control that changes nothing — the kind
/// of fake switch this stage is not allowed to ship.
class ProfilePrivacyCard extends StatelessWidget {
  const ProfilePrivacyCard({
    super.key,
    required this.publishArea,
    required this.hasArea,
    required this.isBusy,
    required this.onChanged,
  });

  /// Whether the area is currently projected onto the public donor card.
  final bool publishArea;

  /// Publishing needs something to publish. Without an area the switch is
  /// disabled rather than shown on and silently writing nothing.
  final bool hasArea;

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
                child: Text(l10n.profilePrivacyAreaTitle, style: text.titleMedium),
              ),
              Switch(
                value: publishArea,
                onChanged: isBusy || !hasArea ? null : onChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(l10n.profilePrivacyAreaBody, style: text.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: palette.outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.profilePrivacyPrivateTitle, style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(l10n.profilePrivacyPrivateBody, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
