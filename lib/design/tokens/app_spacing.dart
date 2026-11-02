/// Spacing scale, in logical pixels.
///
/// A 4-point base grid. Screens compose these instead of ad-hoc numbers so
/// vertical rhythm stays consistent across every screen.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 56;

  /// Standard horizontal screen gutter.
  static const double gutter = xl;

  /// Minimum tappable dimension for accessibility (Material recommends 48).
  static const double minTapTarget = 48;
}
