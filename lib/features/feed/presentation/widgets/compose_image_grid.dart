import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/post_image_storage.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The four photo slots of a new post.
///
/// **Always four cells, never fewer.** The grid is the statement of capacity:
/// a donor sees two photos, one way to add a third, and one slot left, without a
/// caption explaining that the limit is four. The limit itself is
/// [PostValidator.maxImages], the same constant the validator and the rules
/// stage will use.
///
/// The add tile opens a sheet rather than offering gallery and camera side by
/// side. On a 152 dp cell the two labels do not fit in either language — Bangla
/// is the longer of the two — and a target that truncates "গ্যালারি থেকে বেছে
/// নিন" to "গ্যালারি…" is a target nobody can tell apart from the other one.
class ComposeImageGrid extends StatelessWidget {
  const ComposeImageGrid({
    super.key,
    required this.images,
    required this.isUploading,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<StoredPostImage> images;

  /// An upload is in flight: the add tile becomes a spinner in place.
  final bool isUploading;

  /// False while publishing, when every control on the screen is inert.
  final bool enabled;

  final ValueChanged<PhotoSource> onAdd;
  final ValueChanged<StoredPostImage> onRemove;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cells = <Widget>[
      for (int index = 0; index < PostValidator.maxImages; index++)
        Expanded(child: _cell(context, index)),
    ];

    return Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            cells[0],
            const SizedBox(width: AppSpacing.xs),
            cells[1],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            cells[2],
            const SizedBox(width: AppSpacing.xs),
            cells[3],
          ],
        ),
      ],
    );
  }

  /// What the slot at [index] is: a photo, the add tile, or empty space.
  ///
  /// The order is positional, not a list of widgets: the filled photos are
  /// always followed by the single add tile, which is why removing the second of
  /// three photos shifts the third left instead of leaving a hole.
  Widget _cell(BuildContext context, int index) {
    if (index < images.length) {
      final StoredPostImage image = images[index];
      return AspectRatio(
        aspectRatio: 1,
        child: _FilledSlot(
          image: image,
          enabled: enabled,
          onRemove: () => onRemove(image),
        ),
      );
    }
    if (index == images.length) {
      return AspectRatio(
        aspectRatio: 1,
        child: _AddSlot(
          isUploading: isUploading,
          enabled: enabled && !isUploading,
          onAdd: onAdd,
        ),
      );
    }
    return const AspectRatio(aspectRatio: 1, child: _EmptySlot());
  }
}

/// One uploaded photo, with the control that takes it back out.
class _FilledSlot extends StatelessWidget {
  const _FilledSlot({
    required this.image,
    required this.enabled,
    required this.onRemove,
  });

  final StoredPostImage image;
  final bool enabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final AppLocalizations l10n = context.l10n;

    return ClipRRect(
      borderRadius: AppRadius.mdRadius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          ColoredBox(
            color: palette.surfaceMuted,
            child: Image.network(
              image.url,
              fit: BoxFit.cover,
              // The word the grid already uses for its contents, chosen over the
              // object path or a coordinate: a listener needs to know a photo is
              // here, and which of the four slots it is in is a question the
              // "Remove photo" button in this same cell already answers.
              semanticLabel: l10n.feedComposePhotosLabel,
              // The object was uploaded seconds ago, so a failure here means it
              // is genuinely unreachable — not that a reader is offline. The
              // slot stays, because the URL is already in the draft and silently
              // dropping a photo the donor can see a placeholder for is worse.
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) =>
                      Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 22,
                          color: palette.textSecondary,
                        ),
                      ),
            ),
          ),
          PositionedDirectional(
            top: AppSpacing.xxs,
            end: AppSpacing.xxs,
            child: IconButton(
              onPressed: enabled ? onRemove : null,
              tooltip: l10n.feedComposeRemovePhoto,
              iconSize: 18,
              padding: EdgeInsets.zero,
              // 44 rather than the 48 minimum: this control sits on top of a
              // photograph that is itself the target the donor is looking at,
              // and a 48 disc would cover a fifth of the cell.
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              style: IconButton.styleFrom(
                backgroundColor: palette.brandInk.withValues(alpha: 0.82),
                foregroundColor: palette.onBrand,
                disabledBackgroundColor: palette.outline,
                disabledForegroundColor: palette.surface,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

/// The one place a photo can be added. Doubles as the upload indicator.
class _AddSlot extends StatelessWidget {
  const _AddSlot({
    required this.isUploading,
    required this.enabled,
    required this.onAdd,
  });

  final bool isUploading;
  final bool enabled;
  final ValueChanged<PhotoSource> onAdd;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    final Widget content = isUploading
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.feedComposeUploading,
                style: text.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.add_a_photo_outlined,
                size: 22,
                color: palette.brandInk,
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(
                  l10n.feedComposeAddPhoto,
                  style: text.bodySmall,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    return Material(
      color: palette.brandTint,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        // Tapping during an upload would queue a second pick behind a first one
        // the donor cannot see the end of.
        onTap: enabled ? () => unawaited(_chooseSource(context)) : null,
        borderRadius: AppRadius.mdRadius,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTapTarget,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: palette.brandInk.withValues(alpha: 0.35)),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }

  Future<void> _chooseSource(BuildContext context) async {
    final PhotoSource? source = await _PhotoSourceSheet.show(context);
    if (source != null) {
      onAdd(source);
    }
  }
}

/// A slot with nothing in it yet. Present so the grid keeps its shape.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(color: palette.outline),
      ),
    );
  }
}

/// Gallery or camera, as a sheet that returns the choice instead of acting on
/// it — the same split the profile's photo sheet uses, for the same reason: an
/// upload can take seconds and fail, and a failure inside a dismissing route has
/// nowhere to go.
class _PhotoSourceSheet extends StatelessWidget {
  const _PhotoSourceSheet();

  static Future<PhotoSource?> show(BuildContext context) {
    return showModalBottomSheet<PhotoSource>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      // Without a cap the sheet spans a tablet or a browser window.
      constraints: const BoxConstraints(maxWidth: 520),
      builder: (BuildContext context) => const _PhotoSourceSheet(),
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
          Text(l10n.feedComposeAddPhoto, style: text.titleLarge),
          const SizedBox(height: AppSpacing.md),
          _SourceOption(
            icon: Icons.photo_library_outlined,
            label: l10n.feedComposeFromGallery,
            onTap: () => Navigator.of(context).pop(PhotoSource.gallery),
          ),
          const SizedBox(height: AppSpacing.xs),
          _SourceOption(
            icon: Icons.photo_camera_outlined,
            label: l10n.feedComposeFromCamera,
            onTap: () => Navigator.of(context).pop(PhotoSource.camera),
          ),
        ],
      ),
    );
  }
}

/// One row: an icon in a tinted disc and a label.
class _SourceOption extends StatelessWidget {
  const _SourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

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
                child: Icon(icon, size: 20, color: palette.onBrandTint),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: palette.textPrimary,
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
