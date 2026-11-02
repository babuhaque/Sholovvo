import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_colors.dart';

/// Vector brand mark: a blood drop with a soft inner highlight.
///
/// The supplied `Images/logo.jpeg` is a raster on a black background, which
/// cannot sit on the cream surface without a visible box. This vector mark gives
/// a crisp equivalent at any size and is used wherever the logo would otherwise
/// appear.
class BloodDropMark extends StatelessWidget {
  const BloodDropMark({
    super.key,
    this.size = 48,
    this.gradient = AppColors.dropGradient,
    this.semanticLabel,
  });

  final double size;
  final Gradient gradient;

  /// When null the mark is treated as decorative and hidden from screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final Widget mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BloodDropPainter(gradient: gradient)),
    );

    if (semanticLabel == null) {
      return ExcludeSemantics(child: mark);
    }
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _BloodDropPainter extends CustomPainter {
  const _BloodDropPainter({required this.gradient});

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;

    // Teardrop: a sharp tip at the top easing into a round belly at the bottom.
    final Path drop = Path()
      ..moveTo(cx, h * 0.99)
      ..cubicTo(w * 0.01, h * 0.70, w * 0.15, h * 0.41, cx, h * 0.02)
      ..cubicTo(w * 0.85, h * 0.41, w * 0.99, h * 0.70, cx, h * 0.99)
      ..close();

    canvas.drawPath(
      drop,
      Paint()
        ..isAntiAlias = true
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Specular highlight, offset upper-left, to read as a liquid surface.
    final Paint highlight = Paint()
      ..isAntiAlias = true
      ..color = Colors.white.withValues(alpha: 0.26)
      ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 3.5);

    canvas
      ..save()
      ..translate(w * 0.37, h * 0.47)
      ..rotate(-0.45)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: w * 0.15,
          height: h * 0.26,
        ),
        highlight,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_BloodDropPainter oldDelegate) =>
      oldDelegate.gradient != gradient;
}
