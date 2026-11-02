import 'package:flutter/widgets.dart';

/// Elevation is a [SolovvoPalette] role now — the shadow colour differs between
/// light and dark (a 6% ink shadow is invisible on charcoal), so the shadow sets
/// live with the rest of the theme instead of here.
///
/// What remains is the one value that is not theme-dependent: no shadow at all.
abstract final class AppElevation {
  /// No shadow. Use for flat cards on coloured surfaces and disabled buttons.
  static const List<BoxShadow> none = <BoxShadow>[];
}
