import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';

/// A row that opens something, with a leading glyph and an optional second line.
///
/// The chevron is not decoration: it marks the row as a way through rather than
/// a value that can be read and left alone, which is why the read-only rows on
/// the same screen do not have one.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;

  /// Second line, for a row whose label alone does not say what it changes.
  final String? body;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSpacing.minTapTarget),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              Icon(icon, size: 22, color: palette.brandInk),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: text.titleMedium),
                    if (body != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(body!, style: text.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: palette.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
