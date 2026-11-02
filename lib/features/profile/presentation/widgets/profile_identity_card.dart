import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Who this donor is, as the rest of the app will see them.
///
/// Everything shown here lives in the public `users/{uid}` document (name, blood
/// group, area when published) or comes from the sign-in session (email). No
/// private field is rendered here, because this is the card that answers "what
/// do others see".
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.profile,
    required this.email,
    required this.isVerified,
    required this.onChangePhoto,
    this.isPhotoBusy = false,
  });

  final UserProfile profile;

  /// The account address. Not in Firestore: it is the identity provider's, so it
  /// is displayed from the session and marked as managed elsewhere.
  final String email;

  final bool isVerified;

  /// Opens the photo sheet. Lives on this card because the photo is the first
  /// thing anyone else sees of this donor, and this card is "what others see".
  final VoidCallback onChangePhoto;

  /// A upload or removal is in flight. The button is disabled and the avatar
  /// carries a spinner rather than the card appearing to have done nothing.
  final bool isPhotoBusy;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final String? area = profile.area;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AvatarWithProgress(
                name: profile.displayName,
                photoUrl: profile.photoUrl,
                isBusy: isPhotoBusy,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      profile.displayName.trim().isEmpty
                          ? l10n.notSetYet
                          : profile.displayName.trim(),
                      style: text.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    // The badge only exists for one of the eight real groups;
                    // an empty pill would look like a group nobody can match.
                    if (BloodGroups.isKnown(profile.bloodGroup)) ...<Widget>[
                      BloodGroupBadge(
                        bloodGroup: profile.bloodGroup!,
                        large: true,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                    ],
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: palette.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            area ?? l10n.notSetYet,
                            style: text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isVerified) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: palette.success,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.verified,
                            style: text.labelSmall?.copyWith(
                              color: palette.success,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(height: 1, color: palette.outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.mail_outline_rounded,
                size: 18,
                color: palette.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(email, style: text.bodyMedium),
                    Text(l10n.profileEmailManaged, style: text.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // A labelled control rather than a tappable avatar: "Add photo" is
          // readable in both languages and is one unambiguous tap target.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: isPhotoBusy ? null : onChangePhoto,
              icon: Icon(
                profile.hasPhoto
                    ? Icons.photo_camera_outlined
                    : Icons.add_a_photo_outlined,
                size: 18,
              ),
              label: Text(
                profile.hasPhoto
                    ? l10n.profilePhotoChange
                    : l10n.profilePhotoAdd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The avatar, plus a spinner while a photo operation is in flight.
///
/// The spinner sits over the existing photo rather than replacing it: the donor
/// is waiting to see a new picture, and blanking the old one during the upload
/// would look like it had already been replaced.
class _AvatarWithProgress extends StatelessWidget {
  const _AvatarWithProgress({
    required this.name,
    required this.photoUrl,
    required this.isBusy,
  });

  final String name;
  final String? photoUrl;
  final bool isBusy;

  static const double _size = 64;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          InitialsAvatar(name: name, photoUrl: photoUrl, size: _size),
          if (isBusy) ...<Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(width: _size, height: _size),
            ),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }
}
