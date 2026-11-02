import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// Durations are short on purpose: premium interfaces feel responsive, and long
/// decorative transitions are the fastest way to make an app feel slow.
abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 90);
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration base = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 420);

  /// Brand reveal on the splash screen (product brief: 2 seconds).
  static const Duration splash = Duration(milliseconds: 2000);

  /// One full loop of the floating blood drop field.
  static const Duration ambient = Duration(seconds: 14);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve entrance = Curves.easeOutQuart;

  /// Overshoots past 1.0 — safe for size and scale, never for opacity.
  static const Curve overshoot = Curves.easeOutBack;
}
