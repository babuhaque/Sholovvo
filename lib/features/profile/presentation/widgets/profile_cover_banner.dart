import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The banner across the top of a profile.
///
/// The cover counterpart of the avatar in [ProfileIdentityCard]: it shows the
/// donor's [coverUrl] when one is published and an honest brand placeholder when
/// there is none, rather than a blank strip or a stock image nobody chose. The
/// only control is the way to add or change the picture; removal lives in the
/// sheet the button opens, exactly as it does for the avatar.
///
/// This widget owns no state and reads none: the URL comes from the profile the
/// screen is already showing, and a tap is handed back through [onChanged].
class ProfileCoverBanner extends StatelessWidget {
  const ProfileCoverBanner({
    super.key,
    required this.hasCover,
    required this.coverUrl,
    required this.onChanged,
    this.isBusy = false,
  });

  /// Whether a cover is currently published. Drives only the button wording —
  /// "Add cover photo" reads differently from "Change cover photo", and offering
  /// the first when a banner is already up would look like the app cannot see it.
  final bool hasCover;

  /// The published cover URL. Rendered only when it is non-empty; a stale or
  /// unreadable one falls back to the placeholder rather than a broken box.
  final String? coverUrl;

  /// Opens the cover sheet.
  final VoidCallback onChanged;

  /// An upload or removal is in flight. The button is disabled and a spinner sits
  /// over the banner so the tap is visibly doing something.
  final bool isBusy;

  /// The banner height at the widest layout; it is scaled down by aspect ratio on
  /// narrower screens so it keeps the same shape rather than a fixed band.
  static const double _aspectRatio = 3.2;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final String? url = coverUrl?.trim();
    final bool showImage = url != null && url.isNotEmpty;

    final Widget background = showImage
        ? Image.network(
            url,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            // The banner stands for the donor's profile, so a screen reader gets
            // a name rather than an unlabelled picture.
            semanticLabel: l10n.profileCoverSheetTitle,
            errorBuilder:
                (BuildContext context, Object error, StackTrace? stack) =>
                    _Placeholder(palette: palette),
          )
        : _Placeholder(palette: palette);

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: ClipRRect(
        borderRadius: AppRadius.lgRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            background,
            // A scrim under the control so the label stays legible over any
            // photograph the donor might choose.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    palette.surface.withValues(alpha: 0.72),
                  ],
                ),
              ),
              child: const SizedBox.expand(),
            ),
            if (isBusy)
              const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
            else
              Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: TextButton.icon(
                    onPressed: onChanged,
                    icon: Icon(
                      hasCover
                          ? Icons.edit_outlined
                          : Icons.add_photo_alternate_outlined,
                      size: 18,
                    ),
                    label: Text(
                      hasCover
                          ? l10n.profileCoverChange
                          : l10n.profileCoverAdd,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The honest "no cover yet" fill: a muted brand field with a picture icon.
///
/// Not a random stock banner: the app does not know what this donor wants behind
/// their name, so it says "nothing chosen here" instead of choosing for them.
class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.palette});

  final SolovvoPalette palette;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[palette.brandTint, palette.surfaceMuted],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.landscape_outlined,
          size: 40,
          color: palette.onBrandTint.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
