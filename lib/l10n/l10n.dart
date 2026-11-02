import 'package:flutter/widgets.dart';
import 'package:sholovvo_app/l10n/generated/app_localizations.dart';

export 'package:sholovvo_app/l10n/generated/app_localizations.dart';

/// One import for every screen and widget that needs copy.
///
/// Screens ask `context.l10n.homeGreeting(name)` rather than reaching into
/// `AppLocalizations` by hand, which keeps the call sites short and makes it
/// obvious when a widget reads text instead of only laying it out.
extension SolovvoLocalisations on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
