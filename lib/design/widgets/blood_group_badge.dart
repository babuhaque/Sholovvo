import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';

/// ABO/Rh group as a pill.
///
/// Only ever built for a real group: callers check `BloodGroups.isKnown` first,
/// because an empty pill or a placeholder letter where a blood group belongs is
/// the one cosmetic problem in this app that can become a medical one.
class BloodGroupBadge extends StatelessWidget {
  const BloodGroupBadge({
    super.key,
    required this.bloodGroup,
    this.large = false,
  });

  final String bloodGroup;

  /// The profile header uses the large size; lists and records use the default.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

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
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: large ? 20 : 13,
          fontWeight: FontWeight.w700,
          color: palette.onBrandTint,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
