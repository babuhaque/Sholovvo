import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// What other donors can see, and what they never can.
///
/// Two real switches, one per privacy decision the app actually makes:
///
/// * [discoverable] is the Stage 9.5 consent gate. A donor who leaves it off
///   is not listed in the Donor Search directory at all — their public
///   document carries no `allowDonorDiscovery` key, so the discovery query
///   cannot reach them. Turning it off does not remove the donor role, does
///   not change the availability switch, and does not touch any other field
///   of the public document; the donor simply is not searchable. The default
///   is off, and a legacy `users/{uid}` document that has never carried the
///   key is treated as off too, so no existing donor is silently re-listed
///   on upgrade.
/// * [publishArea] projects the coarse area onto the donor card *only if* the
///   donor is discoverable. It is deliberately independent: an opted-out
///   donor can flip it on without appearing in the directory (their area is
///   published but nobody is querying them), and an opted-in donor can flip
///   it off and still be listed — just without an area.
///
/// There is no "share my phone with matches" toggle because a phone is
/// never on the public document to begin with: the private subcollection is
/// unreadable by anyone but its owner under `firestore.rules`, so such a
/// switch would change nothing — the kind of fake control this stage is not
/// allowed to ship.
class ProfilePrivacyCard extends StatelessWidget {
  const ProfilePrivacyCard({
    super.key,
    required this.discoverable,
    required this.publishArea,
    required this.hasArea,
    required this.isBusy,
    required this.onDiscoverableChanged,
    required this.onChanged,
  });

  /// Whether this donor has opted into the directory. Off by default; a
  /// missing key on a legacy document reads as off too.
  final bool discoverable;

  /// Whether the area is currently projected onto the public donor card.
  final bool publishArea;

  /// Publishing needs something to publish. Without an area the switch is
  /// disabled rather than shown on and silently writing nothing.
  final bool hasArea;

  final bool isBusy;

  /// Called with the new consent state. Writes through the full profile save
  /// because withdrawing consent must delete the public projection of the
  /// flag, and only `saveProfile` knows how to do that atomically with the
  /// private source of truth.
  final ValueChanged<bool> onDiscoverableChanged;

  /// Called with the new area-publication state.
  final ValueChanged<bool> onChanged;

  /// Keys so tests and the widget tree can tell the two switches apart.
  static const Key discoverableSwitchKey = ValueKey<String>(
    'privacy-discoverable-switch',
  );
  static const Key publishAreaSwitchKey = ValueKey<String>(
    'privacy-publish-area-switch',
  );

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
                child: Text(
                  l10n.profilePrivacyDiscoveryTitle,
                  style: text.titleMedium,
                ),
              ),
              Switch(
                key: discoverableSwitchKey,
                value: discoverable,
                onChanged: isBusy ? null : onDiscoverableChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(l10n.profilePrivacyDiscoveryBody, style: text.bodySmall),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: palette.outline),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(l10n.profilePrivacyAreaTitle, style: text.titleMedium),
              ),
              Switch(
                key: publishAreaSwitchKey,
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
