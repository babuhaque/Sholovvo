import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The personal details, each marked with who can read it.
///
/// The lock marks are not decoration: they mirror the document split in
/// `ProfileDocuments`. Phone, address, date of birth and gender live in
/// `users/{uid}/private/profile`, which `firestore.rules` lets only the owner
/// read. Area is the one field that can be published, and the privacy card owns
/// that switch.
class ProfileDetailsCard extends StatelessWidget {
  const ProfileDetailsCard({
    super.key,
    required this.profile,
    required this.email,
  });

  final UserProfile profile;
  final String email;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;

    return SolovvoCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: <Widget>[
          ProfileDetailRow(
            icon: Icons.phone_outlined,
            label: l10n.profilePhoneLabel,
            value: _orPlaceholder(profile.phone, l10n),
            isPrivate: true,
          ),
          _Divider(color: palette.outline),
          ProfileDetailRow(
            icon: Icons.place_outlined,
            label: l10n.profileAreaLabel,
            value: _orPlaceholder(profile.area, l10n),
          ),
          _Divider(color: palette.outline),
          ProfileDetailRow(
            icon: Icons.home_outlined,
            label: l10n.profileAddressLabel,
            value: _orPlaceholder(profile.addressLine, l10n),
            isPrivate: true,
          ),
          _Divider(color: palette.outline),
          ProfileDetailRow(
            icon: Icons.cake_outlined,
            label: l10n.profileDobLabel,
            value: _formatDate(context, profile.dateOfBirth, l10n),
            isPrivate: true,
          ),
          _Divider(color: palette.outline),
          ProfileDetailRow(
            icon: Icons.wc_outlined,
            label: l10n.profileGenderLabel,
            value: profile.gender == null
                ? l10n.notSetYet
                : profileGenderLabel(l10n, profile.gender!),
            isPrivate: true,
          ),
          _Divider(color: palette.outline),
          ProfileDetailRow(
            icon: Icons.mail_outline_rounded,
            label: l10n.emailLabel,
            value: email,
            helper: l10n.profileEmailManaged,
          ),
        ],
      ),
    );
  }

  /// A blank field reads as "not set yet", never as an invented value.
  static String _orPlaceholder(String? value, AppLocalizations l10n) {
    final String? trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? l10n.notSetYet : trimmed;
  }

  /// Flutter's own localisation delegate rather than `intl.DateFormat`, so no
  /// locale data has to be initialised before the first frame.
  static String _formatDate(
    BuildContext context,
    DateTime? date,
    AppLocalizations l10n,
  ) {
    if (date == null) {
      return l10n.notSetYet;
    }
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

/// One label/value pair with an icon and an optional privacy marker.
class ProfileDetailRow extends StatelessWidget {
  const ProfileDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isPrivate = false,
    this.helper,
  });

  final IconData icon;
  final String label;
  final String value;

  /// Renders the "Private" marker next to the label: this field is only ever
  /// readable by the account that owns it.
  final bool isPrivate;

  final String? helper;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: palette.textSecondary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // A Wrap, not a Row: "Always private" and the Bengali label are
                // both long enough to need a second line at 320 dp.
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      label.toUpperCase(),
                      style: text.labelSmall?.copyWith(letterSpacing: 1.1),
                    ),
                    if (isPrivate)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 12,
                            color: palette.textSecondary,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            l10n.profileContactPrivateBadge,
                            style: text.labelSmall?.copyWith(
                              color: palette.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: palette.textPrimary,
                  ),
                ),
                if (helper != null)
                  Text(helper!, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: color);
  }
}
