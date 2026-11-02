import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';

/// Page background with two soft radial glows behind the content.
///
/// Gives the near-flat surface depth so cards read as raised, without resorting
/// to a heavy gradient that would fight the design language. The base colour and
/// both glows come from the theme, so the same widget draws cream by day and
/// charcoal at night.
class SoftGlowBackground extends StatelessWidget {
  const SoftGlowBackground({
    super.key,
    required this.child,
    this.topGlowColor,
    this.bottomGlowColor,
    this.topGlowOpacity,
    this.bottomGlowOpacity,
  });

  final Widget child;

  /// Overrides for the theme's glow colours, for a screen that wants a
  /// different accent. Null means "use the theme".
  final Color? topGlowColor;
  final Color? bottomGlowColor;
  final double? topGlowOpacity;
  final double? bottomGlowOpacity;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return ColoredBox(
      color: palette.background,
      child: ClipRect(
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -160,
              right: -120,
              child: _GlowBlob(
                color: topGlowColor ?? palette.glowTop,
                opacity: topGlowOpacity ?? palette.glowTopOpacity,
                diameter: 380,
              ),
            ),
            Positioned(
              bottom: -180,
              left: -140,
              child: _GlowBlob(
                color: bottomGlowColor ?? palette.glowBottom,
                opacity: bottomGlowOpacity ?? palette.glowBottomOpacity,
                diameter: 400,
              ),
            ),
            Positioned.fill(child: child),
          ],
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.color,
    required this.opacity,
    required this.diameter,
  });

  final Color color;
  final double opacity;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: <Color>[
                color.withValues(alpha: opacity),
                color.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
