import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_colors.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';

/// Ambient field of blood drops drifting upward behind content.
///
/// Purely decorative: excluded from semantics and pointer events so it can never
/// interfere with a button or a screen reader. The whole field is one
/// [CustomPaint] driven by a single animation, which keeps it cheap compared to
/// animating dozens of widgets.
///
/// Motion is disabled when the platform reports "reduce motion", leaving a
/// static frame instead of animating anyway.
class FloatingBloodDrops extends StatefulWidget {
  const FloatingBloodDrops({
    super.key,
    this.dropCount = 16,
    this.seed = 11,
    this.maxOpacity = 0.30,
    this.minSize = 6,
    this.maxSize = 26,
  });

  final int dropCount;

  /// Fixed seed so the layout is identical on every launch and in tests.
  final int seed;

  /// Ceiling for a single drop's opacity, keeping the field subtle.
  final double maxOpacity;

  final double minSize;
  final double maxSize;

  @override
  State<FloatingBloodDrops> createState() => _FloatingBloodDropsState();
}

class _FloatingBloodDropsState extends State<FloatingBloodDrops>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.ambient,
  );
  late final List<_DropSpec> _drops = _generateDrops();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.32;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_DropSpec> _generateDrops() {
    final math.Random random = math.Random(widget.seed);
    return List<_DropSpec>.generate(widget.dropCount, (int index) {
      final double size =
          widget.minSize + random.nextDouble() * (widget.maxSize - widget.minSize);
      return _DropSpec(
        x: random.nextDouble(),
        offset: random.nextDouble(),
        speed: 0.35 + random.nextDouble() * 0.5,
        sway: 8 + random.nextDouble() * 24,
        phase: random.nextDouble() * math.pi * 2,
        size: size,
        opacity: 0.25 + random.nextDouble() * 0.6,
        rotation: (random.nextDouble() - 0.5) * 0.55,
        tint: random.nextBool() ? AppColors.burgundy : AppColors.bloodRed,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _DropsPainter(
              progress: _controller,
              drops: _drops,
              maxOpacity: widget.maxOpacity,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _DropSpec {
  const _DropSpec({
    required this.x,
    required this.offset,
    required this.speed,
    required this.sway,
    required this.phase,
    required this.size,
    required this.opacity,
    required this.rotation,
    required this.tint,
  });

  /// Horizontal position as a fraction of the field width.
  final double x;

  /// Starting point within the travel cycle, so drops are staggered.
  final double offset;

  /// Cycles completed per full loop of the ambient animation.
  final double speed;

  final double sway;
  final double phase;
  final double size;
  final double opacity;
  final double rotation;
  final Color tint;
}

class _DropsPainter extends CustomPainter {
  _DropsPainter({
    required this.progress,
    required this.drops,
    required this.maxOpacity,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_DropSpec> drops;
  final double maxOpacity;

  /// Unit teardrop, scaled per drop. Built once instead of per frame.
  static final Path _unitDrop = Path()
    ..moveTo(0.5, 1)
    ..cubicTo(0.02, 0.70, 0.16, 0.40, 0.5, 0)
    ..cubicTo(0.84, 0.40, 0.98, 0.70, 0.5, 1)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double t = progress.value;
    final Paint paint = Paint()..isAntiAlias = true;

    for (final _DropSpec drop in drops) {
      final double travel = (t * drop.speed + drop.offset) % 1.0;
      final double y = size.height * (1.10 - travel * 1.26);
      final double swayPhase = travel * math.pi * 2 + drop.phase;
      final double x = size.width * drop.x + math.sin(swayPhase) * drop.sway;

      // Fade in at the bottom and out at the top so drops never pop in or out.
      final double fade = travel < 0.12
          ? travel / 0.12
          : (travel > 0.88 ? (1 - travel) / 0.12 : 1);
      final double alpha = (drop.opacity * fade * maxOpacity).clamp(0.0, 1.0);
      if (alpha <= 0.003) {
        continue;
      }

      canvas
        ..save()
        ..translate(x, y)
        ..rotate(drop.rotation + math.sin(swayPhase) * 0.12)
        ..scale(drop.size)
        ..translate(-0.5, -0.5)
        ..drawPath(_unitDrop, paint..color = drop.tint.withValues(alpha: alpha))
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_DropsPainter oldDelegate) =>
      oldDelegate.drops != drops || oldDelegate.maxOpacity != maxOpacity;
}
