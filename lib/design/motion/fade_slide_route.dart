import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';

/// Standard page transition: a short fade with a small upward slide.
///
/// Opacity uses a curve that never overshoots 1.0 — [AppMotion.overshoot] would
/// push the value past 1 and trip the Opacity assertion.
class FadeSlidePageRoute<T> extends PageRouteBuilder<T> {
  FadeSlidePageRoute({required Widget page, super.settings})
    : super(
        transitionDuration: AppMotion.slow,
        reverseTransitionDuration: AppMotion.base,
        pageBuilder: (_, _, _) => page,
        transitionsBuilder: (_, Animation<double> animation, _, Widget child) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.entrance,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.05),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}
