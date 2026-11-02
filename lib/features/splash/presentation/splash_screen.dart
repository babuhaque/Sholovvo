import 'package:flutter/material.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/tokens/app_typography.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/design/widgets/floating_blood_drops.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Brand reveal shown while the app settles.
///
/// Timing comes from [AppMotion.splash] (2 s per the product brief) and is
/// driven by an [AnimationController] rather than `Future.delayed`, so tests can
/// advance it deterministically with `tester.pump` and no timer outlives the
/// widget.
///
/// The screen owns no destination. It reports completion through
/// [onRevealComplete] and stays put when no callback is supplied, which is what
/// lets [AuthGate] hold it on screen while a stored session is still being
/// resolved, and lets a signed-in donor go straight past the welcome screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onRevealComplete});

  /// Invoked once, when the reveal finishes. Null keeps the splash up.
  final VoidCallback? onRevealComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: AppMotion.splash)
        ..addStatusListener(_onStatus)
        ..forward();

  late final Animation<double> _markScale = Tween<double>(
    begin: 0.82,
    end: 1,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.45, curve: AppMotion.overshoot),
    ),
  );

  late final Animation<double> _markFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.3, curve: Curves.easeOut),
  );

  late final Animation<double> _wordFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.18, 0.6, curve: Curves.easeOut),
  );

  late final Animation<Offset> _wordSlide = Tween<Offset>(
    begin: const Offset(0, 0.35),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.18, 0.65, curve: AppMotion.entrance),
    ),
  );

  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.2, 1, curve: Curves.easeInOut),
  );

  bool _revealed = false;

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatus)
      ..dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _reveal();
    }
  }

  /// Guards against a double callback if the status fires twice during a
  /// rebuild.
  void _reveal() {
    if (_revealed || !mounted) {
      return;
    }
    _revealed = true;
    widget.onRevealComplete?.call();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final SolovvoPalette palette = context.palette;

    return Scaffold(
      body: SoftGlowBackground(
        // Expand, not loose: a loose Stack lets the Column shrink to its widest
        // child and the whole brand block ends up pinned to the left edge.
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(
              child: FloatingBloodDrops(
                dropCount: 10,
                maxOpacity: 0.15,
                maxSize: 18,
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const Spacer(),
                  FadeTransition(
                    opacity: _markFade,
                    child: ScaleTransition(
                      scale: _markScale,
                      child: const _BrandMedallion(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeTransition(
                    opacity: _wordFade,
                    child: SlideTransition(
                      position: _wordSlide,
                      child: Column(
                        children: <Widget>[
                          Text(
                            AppBrand.name,
                            style: AppTypography.wordmark(palette).copyWith(
                              fontSize: 32,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            context.l10n.appTagline,
                            style: text.bodySmall?.copyWith(
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                    child: _LoadingRule(progress: _progress),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White disc holding the brand mark, with a soft pink halo behind it.
class _BrandMedallion extends StatelessWidget {
  const _BrandMedallion();

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return SizedBox(
      width: 148,
      height: 148,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 148,
            height: 148,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.brandTint.withValues(alpha: 0.55),
            ),
          ),
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.surface,
              boxShadow: palette.floatingShadow,
            ),
            child: const Center(child: BloodDropMark(size: 52)),
          ),
        ],
      ),
    );
  }
}

/// Thin indeterminate-then-complete rule along the bottom of the splash.
class _LoadingRule extends StatelessWidget {
  const _LoadingRule({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return ExcludeSemantics(
      child: SizedBox(
        width: 132,
        height: 4,
        child: ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: Stack(
            children: <Widget>[
              // Both layers are positioned: an unpositioned ColoredBox in a
              // loose Stack collapses to zero height and the rule disappears.
              Positioned.fill(child: ColoredBox(color: palette.outline)),
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: progress,
                  builder: (BuildContext context, Widget? child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.value.clamp(0.02, 1.0),
                      child: child,
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: palette.brandGradient),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
