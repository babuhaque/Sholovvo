import 'package:flutter/material.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/tokens/app_typography.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The dashboard's own header: wordmark on the left, appearance control and the
/// way into the profile on the right.
///
/// The avatar shows initials only once a profile name exists. Before that it is
/// the same person outline every empty avatar uses, because a letter derived from
/// an email address would be a name this app invented.
///
/// Still no notification bell: it would have nothing behind it until Stage 11.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, this.profile, this.onProfileTap});

  /// `null` until a profile document exists.
  final UserProfile? profile;

  /// Opens the profile screen. Omitted by tests that only render the header.
  final VoidCallback? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final AppLocalizations l10n = context.l10n;
    final String name = profile?.displayName.trim() ?? '';

    return Row(
      children: <Widget>[
        const BloodDropMark(size: 24),
        const SizedBox(width: AppSpacing.xs),
        // Flexible so the wordmark gives way on a 320 dp phone rather than
        // overflowing the row by a fraction of a pixel.
        Flexible(
          child: Text(
            AppBrand.name,
            style: AppTypography.wordmark(palette).copyWith(fontSize: 20),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Spacer(),
        const AppearanceButton(),
        if (onProfileTap != null) ...<Widget>[
          const SizedBox(width: AppSpacing.xxs),
          Tooltip(
            message: l10n.profileTitle,
            child: InkWell(
              onTap: onProfileTap,
              customBorder: const CircleBorder(),
              child: Semantics(
                button: true,
                label: l10n.profileTitle,
                child: InitialsAvatar(
                  name: name,
                  photoUrl: profile?.photoUrl,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Verified" pill.
///
/// Only rendered when the address really is confirmed: an unverified account
/// that still reads "Verified" would undercut the one claim the badge makes.
class VerifiedChip extends StatelessWidget {
  const VerifiedChip({super.key});

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.verified_rounded, size: 14, color: palette.success),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            context.l10n.verified,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: palette.success, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}
