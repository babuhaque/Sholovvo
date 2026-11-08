import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_elevation.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// What the donor picked in [ProfilePhotoSheet].
enum ProfilePhotoAction { gallery, camera, remove }

/// Which image the sheet is managing. The choices are identical for both — the
/// only difference is the wording, so a donor is never told "your photo appears
/// on your donor card" while picking a banner.
enum ProfilePhotoKind { avatar, cover }

/// The photo choices, as a sheet that returns the choice instead of acting on it.
///
/// A plain widget with a `show` helper rather than an async-heavy sheet: picking
/// and uploading can take seconds and can fail, and a failure inside a route that
/// is already dismissing has nowhere to go. The screen performs the action after
/// this sheet has closed, so the busy state and the error banner belong to the
/// screen that is still on top.
class ProfilePhotoSheet extends StatelessWidget {
  const ProfilePhotoSheet({
    super.key,
    required this.hasPhoto,
    required this.isConfigured,
    this.kind = ProfilePhotoKind.avatar,
  });

  /// Whether there is a photo to remove. "Remove" is not offered otherwise.
  final bool hasPhoto;

  /// Whether this build can upload at all. When it cannot, the sheet says so
  /// instead of offering three controls that could only fail.
  final bool isConfigured;

  /// Whether this sheet manages the avatar or the cover banner.
  final ProfilePhotoKind kind;

  /// Opens the sheet and resolves with the chosen action, or `null` on dismiss.
  static Future<ProfilePhotoAction?> show(
    BuildContext context, {
    required bool hasPhoto,
    required bool isConfigured,
    ProfilePhotoKind kind = ProfilePhotoKind.avatar,
  }) {
    return showModalBottomSheet<ProfilePhotoAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      // Same reasoning as the appearance sheet: without a cap the sheet spans the
      // width of a tablet or browser window.
      constraints: const BoxConstraints(maxWidth: 520),
      // No `backgroundColor` either: the theme's `bottomSheetTheme` supplies the
      // surface, and it changes with the palette.
      builder: (BuildContext context) => ProfilePhotoSheet(
        hasPhoto: hasPhoto,
        isConfigured: isConfigured,
        kind: kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            kind == ProfilePhotoKind.cover
                ? l10n.profileCoverSheetTitle
                : l10n.profilePhotoSheetTitle,
            style: text.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            kind == ProfilePhotoKind.cover
                ? l10n.profileCoverSheetBody
                : l10n.profilePhotoSheetBody,
            style: text.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          if (!isConfigured)
            _NotConfigured(l10n: l10n)
          else ...<Widget>[
            _PhotoOption(
              icon: Icons.photo_library_outlined,
              label: l10n.profilePhotoFromGallery,
              onTap: () =>
                  Navigator.of(context).pop(ProfilePhotoAction.gallery),
            ),
            const SizedBox(height: AppSpacing.xs),
            _PhotoOption(
              icon: Icons.photo_camera_outlined,
              label: l10n.profilePhotoFromCamera,
              onTap: () => Navigator.of(context).pop(ProfilePhotoAction.camera),
            ),
            if (hasPhoto) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              Container(height: 1, color: context.palette.outline),
              const SizedBox(height: AppSpacing.xs),
              _PhotoOption(
                icon: Icons.delete_outline_rounded,
                label: kind == ProfilePhotoKind.cover
                    ? l10n.profileCoverRemove
                    : l10n.profilePhotoRemove,
                destructive: true,
                onTap: () =>
                    Navigator.of(context).pop(ProfilePhotoAction.remove),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// One row in the sheet: an icon in a tinted disc and a label.
class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Removal is the only irreversible choice here, so it is coloured and placed
  /// below a rule rather than sitting in the same list as the two safe ones.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final Color accent = destructive ? palette.danger : palette.onBrandTint;

    return Material(
      color: palette.surface,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.mdRadius,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: destructive ? palette.danger : palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The honest "not set up" state.
///
/// Not a disabled button: a donor who taps and gets nothing learns nothing. This
/// says what is missing, and it is the same message the failure banner shows if
/// an upload is attempted anyway.
class _NotConfigured extends StatelessWidget {
  const _NotConfigured({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      color: palette.surfaceMuted,
      borderRadius: AppRadius.mdRadius,
      shadow: AppElevation.none,
      borderColor: palette.outline,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: palette.textSecondary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.profilePhotoNotConfigured, style: text.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
