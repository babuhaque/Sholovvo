import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_elevation.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';

/// Visual weight of a [SolovvoButton].
enum SolovvoButtonVariant {
  /// Gradient brand fill. One per screen, for the single most important action.
  primary,

  /// White with a brand outline. For secondary actions beside a primary.
  secondary,

  /// Text only, no surface. For low-emphasis actions.
  ghost,
}

/// Height presets for [SolovvoButton].
enum SolovvoButtonSize { large, medium }

/// The app's button.
///
/// Differences from `FilledButton` that matter here: a brand gradient with a
/// burgundy glow, a press-scale micro-interaction, and a loading state that
/// blocks double submission — the last one prevents duplicate emergency
/// requests, which is a correctness concern rather than a cosmetic one.
class SolovvoButton extends StatefulWidget {
  const SolovvoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SolovvoButtonVariant.primary,
    this.size = SolovvoButtonSize.large,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;

  /// A null callback renders the button disabled.
  final VoidCallback? onPressed;

  final SolovvoButtonVariant variant;
  final SolovvoButtonSize size;
  final IconData? icon;
  final bool isLoading;

  /// Stretch to the full width of the parent.
  final bool expand;

  @override
  State<SolovvoButton> createState() => _SolovvoButtonState();
}

class _SolovvoButtonState extends State<SolovvoButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  double get _height => widget.size == SolovvoButtonSize.large ? 58 : 48;

  Color _foreground(SolovvoPalette palette) => switch (widget.variant) {
    SolovvoButtonVariant.primary => palette.onBrand,
    SolovvoButtonVariant.secondary => palette.brandInk,
    SolovvoButtonVariant.ghost => palette.brandInk,
  };

  BoxDecoration _decoration(SolovvoPalette palette) =>
      switch (widget.variant) {
        SolovvoButtonVariant.primary => BoxDecoration(
          gradient: palette.brandGradient,
          borderRadius: AppRadius.pillRadius,
          boxShadow: _enabled ? palette.brandShadow : AppElevation.none,
        ),
        SolovvoButtonVariant.secondary => BoxDecoration(
          color: palette.surface,
          borderRadius: AppRadius.pillRadius,
          border: Border.all(
            color: palette.brandInk.withValues(alpha: 0.32),
            width: 1.4,
          ),
          boxShadow: palette.cardShadow,
        ),
        SolovvoButtonVariant.ghost => const BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppRadius.pillRadius,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final Color foreground = _foreground(palette);
    final TextStyle labelStyle =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
          color: foreground,
          fontSize: widget.size == SolovvoButtonSize.large ? 16 : 15,
          letterSpacing: 0.2,
        );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: ExcludeSemantics(
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          child: AnimatedOpacity(
            opacity: _enabled || widget.isLoading ? 1 : 0.45,
            duration: AppMotion.fast,
            child: SizedBox(
              width: widget.expand ? double.infinity : null,
              height: _height,
              child: DecoratedBox(
                decoration: _decoration(palette),
                child: ClipRRect(
                  borderRadius: AppRadius.pillRadius,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _enabled ? widget.onPressed : null,
                      onHighlightChanged: (bool highlighted) {
                        if (_enabled) {
                          setState(() => _pressed = highlighted);
                        }
                      },
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (widget.isLoading)
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    foreground,
                                  ),
                                ),
                              )
                            else if (widget.icon != null)
                              Icon(widget.icon, size: 20, color: foreground),
                            if (widget.isLoading || widget.icon != null)
                              const SizedBox(width: 10),
                            // Flexible, not a bare Text: a long or translated
                            // label (Bangla runs longer than English) would
                            // otherwise overflow this Row on a narrow phone.
                            Flexible(
                              child: Text(
                                widget.label,
                                style: labelStyle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
