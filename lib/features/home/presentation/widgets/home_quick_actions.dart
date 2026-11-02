import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The dashboard's two headline actions.
///
/// "Request blood" first and filled, because a request is time-critical and is
/// the reason someone opens this screen in a hurry. Both are wired to the
/// caller's handler so the screen decides what happens while their screens do
/// not exist yet.
///
/// Stacked on a phone, side by side once there is width for it: two buttons
/// stretched across 850 dp read as banners rather than as actions.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    required this.onRequestBlood,
    required this.onFindDonors,
    this.isWide = false,
  });

  final VoidCallback onRequestBlood;
  final VoidCallback onFindDonors;

  /// Set by the screen once it has enough width for a row.
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    final Widget requestBlood = SolovvoButton(
      label: l10n.homeRequestBlood,
      icon: Icons.bloodtype_outlined,
      onPressed: onRequestBlood,
    );
    final Widget findDonors = SolovvoButton(
      label: l10n.homeFindDonors,
      icon: Icons.person_search_outlined,
      variant: SolovvoButtonVariant.secondary,
      onPressed: onFindDonors,
    );

    if (!isWide) {
      return Column(
        children: <Widget>[
          requestBlood,
          const SizedBox(height: AppSpacing.sm),
          findDonors,
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: requestBlood),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: findDonors),
      ],
    );
  }
}
