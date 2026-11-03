import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Post text that shows its first [maxLines] lines and offers the rest on
/// request.
///
/// The rule the Stage 8.0 design settled on is "collapsed after six lines with
/// an expand option", which means the toggle must appear **only** when the text
/// actually needs expanding. Measuring with a [TextPainter] is what makes that
/// decision honest: a post of four lines gets no "Read more", and one whose
/// seventh line holds a single word still gets one. Guessing from a character
/// count would get both cases wrong, because line length depends on the width
/// and on whether the text is Bangla or English.
class ExpandablePostText extends StatefulWidget {
  const ExpandablePostText({
    super.key,
    required this.text,
    this.maxLines = 6,
    this.style,
  });

  final String text;

  /// Lines shown before the collapse. Six is the approved design value.
  final int maxLines;

  /// Body style, so the caller keeps control of colour and size.
  final TextStyle? style;

  @override
  State<ExpandablePostText> createState() => _ExpandablePostTextState();
}

class _ExpandablePostTextState extends State<ExpandablePostText> {
  bool _expanded = false;

  /// Whether the full text needs more lines than the collapsed limit allows.
  ///
  /// The painter is disposed immediately: it holds a laid-out paragraph, which
  /// is the most expensive thing in this widget and is not needed afterwards.
  bool _needsExpanding({
    required BuildContext context,
    required TextStyle style,
    required double width,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final bool overflows = painter.didExceedMaxLines;
    painter.dispose();
    return overflows;
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextStyle style =
        widget.style ??
        Theme.of(context).textTheme.bodyMedium ??
        const TextStyle();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // An unbounded width here would be a layout mistake upstream. Measuring
        // against infinity would either throw or report nonsense, so the text is
        // drawn in full and the toggle is withheld rather than guessed at.
        final bool overflows = constraints.hasBoundedWidth
            ? _needsExpanding(
                context: context,
                style: style,
                width: constraints.maxWidth,
              )
            : false;
        final bool collapsed = overflows && !_expanded;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.text,
              style: style,
              maxLines: collapsed ? widget.maxLines : null,
              overflow: collapsed
                  ? TextOverflow.ellipsis
                  : TextOverflow.visible,
            ),
            if (overflows)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: palette.brandInk,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, AppSpacing.minTapTarget),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerLeft,
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(_expanded ? l10n.feedShowLess : l10n.feedReadMore),
              ),
          ],
        );
      },
    );
  }
}
