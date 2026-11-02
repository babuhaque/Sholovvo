import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';

/// Reports a rejected action, already worded, above the form it belongs to.
///
/// A banner rather than a snack bar: a failed save is a state of the form, not a
/// transient event, and it has to stay visible while the user fixes the cause.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final Color danger = context.palette.danger;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: danger.withValues(alpha: 0.06),
          borderRadius: AppRadius.smRadius,
          border: Border.all(color: danger.withValues(alpha: 0.24)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.error_outline, size: 18, color: danger),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: text.bodySmall?.copyWith(color: danger),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
