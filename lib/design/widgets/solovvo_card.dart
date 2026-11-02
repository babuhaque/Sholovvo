import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';

/// Surfaces content on the theme's raised surface with a soft shadow.
///
/// Used for every raised group of content: campaign cards, donor rows, form
/// sections. When [onTap] is supplied the card also gets a ripple that respects
/// the corner radius.
class SolovvoCard extends StatelessWidget {
  const SolovvoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.color,
    this.borderRadius = AppRadius.lgRadius,
    this.shadow,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Defaults to the theme's surface. Pass a colour only to override it for a
  /// tinted card.
  final Color? color;
  final BorderRadius borderRadius;

  /// Defaults to the theme's resting elevation.
  final List<BoxShadow>? shadow;

  /// Optional hairline border, for cards on coloured surfaces.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final Widget content = Padding(padding: padding, child: child);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? palette.surface,
        borderRadius: borderRadius,
        boxShadow: shadow ?? palette.cardShadow,
        border: borderColor == null
            ? null
            : Border.all(color: borderColor!, width: 1),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Material(
          color: Colors.transparent,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}
