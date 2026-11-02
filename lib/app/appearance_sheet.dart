import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/preferences/app_preferences.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The two things a user can change about the app itself, in one place.
///
/// Reachable from the welcome screen (before signing in, so a Bengali speaker
/// is not forced through an English sign-up flow) and from home. Stage 7 hosts
/// the same widget inside Settings rather than growing a second copy.
class AppearanceSheet extends ConsumerWidget {
  const AppearanceSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      // Without this the sheet spans the whole width of a tablet or the web
      // window, which puts the two language choices a hand-width apart.
      constraints: const BoxConstraints(maxWidth: 520),
      // Deliberately no `backgroundColor`: the sheet's surface comes from
      // `AppTheme`'s `bottomSheetTheme`, which is rebuilt per palette. Passing
      // a colour captured here would freeze it at open time, and because this
      // sheet is where the user picks Dark, the surface would stay cream while
      // the content inside it turned pale.
      builder: (BuildContext context) => const AppearanceSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    // The *resolved* locale, not the stored one. They differ while the user
    // follows the device, and highlighting the language currently on screen is
    // the only honest answer to "which one is selected?".
    final String activeLanguage = Localizations.localeOf(context).languageCode;
    final ThemeMode themeMode = ref.watch(themeModeProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        0,
        AppSpacing.gutter,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(l10n.appearanceAndLanguage, style: text.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(l10n.languageLabel),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: _Choice(
                  label: l10n.languageEnglish,
                  selected: activeLanguage == 'en',
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .select(const Locale('en')),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Choice(
                  label: l10n.languageBangla,
                  selected: activeLanguage == 'bn',
                  onTap: () => ref
                      .read(localeProvider.notifier)
                      .select(const Locale('bn')),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _SectionLabel(l10n.themeLabel),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: <Widget>[
              Expanded(
                child: _Choice(
                  label: l10n.themeSystem,
                  selected: themeMode == ThemeMode.system,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).select(ThemeMode.system),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Choice(
                  label: l10n.themeLight,
                  selected: themeMode == ThemeMode.light,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).select(ThemeMode.light),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _Choice(
                  label: l10n.themeDark,
                  selected: themeMode == ThemeMode.dark,
                  onTap: () =>
                      ref.read(themeModeProvider.notifier).select(ThemeMode.dark),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(letterSpacing: 0.8),
    );
  }
}

/// One option in a group of two or three.
///
/// A custom tile rather than `ChoiceChip`: the selected state needs to read as
/// brand in both themes, and the default chip computes its own label colour
/// from a `ColorScheme` that knows nothing about the brand tint.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextStyle style =
        (Theme.of(context).textTheme.labelLarge ?? const TextStyle()).copyWith(
          color: selected ? palette.onBrandTint : palette.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        );

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      // The tile below is excluded from semantics so the option is one node
      // rather than a button that contains a stray text node — but that means
      // the label has to be declared here instead, or a screen reader
      // announces an unnamed "button, selected".
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? palette.brandTint : palette.surfaceMuted,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.mdRadius,
            side: BorderSide(
              color: selected ? palette.brandInk : palette.outline,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.mdRadius,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppSpacing.minTapTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                // Two lines: a Bengali option label can be wider than the
                // English one, and wrapping beats an ellipsis on a choice.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Header control that opens [AppearanceSheet].
///
/// A glyph rather than a labelled button: it belongs in the top-right corner of
/// screens that have no app bar, where a second full-width button would compete
/// with the screen's actual primary action.
class AppearanceButton extends StatelessWidget {
  const AppearanceButton({super.key});

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;

    return IconButton(
      onPressed: () => AppearanceSheet.show(context),
      tooltip: context.l10n.appearanceAndLanguage,
      icon: const Icon(Icons.palette_outlined),
      color: palette.textSecondary,
      style: IconButton.styleFrom(
        backgroundColor: palette.surface,
        side: BorderSide(color: palette.outline),
        minimumSize: const Size.square(AppSpacing.minTapTarget),
      ),
    );
  }
}
