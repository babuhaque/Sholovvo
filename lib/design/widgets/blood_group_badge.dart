import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';

/// How a blood group is drawn.
///
/// Two approved appearances rather than one: the pill is an inline label beside
/// a name, the square is a list row's leading mark. They were written in two
/// places, so one of them could drift from the other's contrast or radius
/// without anybody noticing. The variant keeps both looks and keeps them in one
/// file.
enum BloodGroupBadgeVariant {
  /// An inline label sized by its own padding. Lists, records, profile header.
  pill,

  /// A square tile, the same height as the two-line row it sits beside.
  square,
}

/// ABO/Rh group, drawn as one of the two approved marks.
///
/// Only ever built for a real group: callers check `BloodGroups.isKnown` first,
/// because an empty pill or a placeholder letter where a blood group belongs is
/// the one cosmetic problem in this app that can become a medical one.
class BloodGroupBadge extends StatelessWidget {
  const BloodGroupBadge({
    super.key,
    required this.bloodGroup,
    this.variant = BloodGroupBadgeVariant.pill,
    this.large = false,
    this.size = defaultSquareSize,
  });

  /// The square variant's default edge length — the size the dashboard's
  /// request rows are approved at.
  static const double defaultSquareSize = 44;

  final String bloodGroup;

  final BloodGroupBadgeVariant variant;

  /// The profile header uses the large pill; lists and records use the default.
  /// Ignored by [BloodGroupBadgeVariant.square], which is sized by [size].
  final bool large;

  /// Edge length of the square variant. Ignored by the pill, which is sized by
  /// its text and padding at any width.
  final double size;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    if (variant == BloodGroupBadgeVariant.square) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: palette.brandTint,
          borderRadius: AppRadius.mdRadius,
        ),
        child: Text(
          bloodGroup,
          style: text.titleMedium?.copyWith(
            color: palette.onBrandTint,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? AppSpacing.md : AppSpacing.xs,
        vertical: large ? AppSpacing.xs : 3,
      ),
      decoration: BoxDecoration(
        color: palette.brandTint,
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        bloodGroup,
        style: text.labelLarge?.copyWith(
          fontSize: large ? 20 : 13,
          fontWeight: FontWeight.w700,
          color: palette.onBrandTint,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
