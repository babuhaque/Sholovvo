import 'package:flutter/material.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/tokens/app_typography.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';

/// Shared frame for the authentication screens.
///
/// Owns the cream background, the back affordance, the title block and the white
/// card, so sign-in, registration, password reset and verification differ only
/// in their fields and actions. A single frame also means the keyboard cannot
/// hide an input on one screen while it can on another: everything below the
/// title lives in one scroll view.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;

  /// Body of the card: fields, banner and the primary action.
  final List<Widget> children;

  /// Optional links below the card.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    const EdgeInsets padding = EdgeInsets.fromLTRB(
      AppSpacing.gutter,
      AppSpacing.md,
      AppSpacing.gutter,
      AppSpacing.xxl,
    );

    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints viewport) {
              return SingleChildScrollView(
                padding: padding,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // Give the column at least a viewport's worth of room so it
                    // can sit in the middle on a tall screen. When the form is
                    // taller than that - a short window, or a phone with the
                    // keyboard open - the box simply grows and the scroll view
                    // starts at the title instead of clipping it away.
                    minHeight: viewport.maxHeight - padding.vertical,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      // Keeps the form readable on a tablet or in a desktop
                      // browser window instead of stretching inputs across the
                      // whole width.
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const _TopBar(),
                          const SizedBox(height: AppSpacing.xl),
                          Text(
                            title,
                            style: text.displaySmall?.copyWith(fontSize: 26),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(subtitle, style: text.bodyMedium),
                          const SizedBox(height: AppSpacing.lg),
                          SolovvoCard(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: children,
                            ),
                          ),
                          if (footer != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.lg),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Back button plus the wordmark.
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    // `canPop` is false when the gate rendered this screen as the root, which
    // is why the back affordance is conditional rather than a blank space.
    final bool canGoBack = Navigator.of(context).canPop();
    final SolovvoPalette palette = context.palette;

    return Row(
      children: <Widget>[
        if (canGoBack) ...<Widget>[
          SizedBox(
            width: AppSpacing.minTapTarget,
            height: AppSpacing.minTapTarget,
            child: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              // From MaterialLocalizations rather than the catalogue: the
              // framework already carries this one in every language it ships.
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: palette.surface,
                shape: const CircleBorder(),
                side: BorderSide(color: palette.outline),
              ),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: palette.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        const BloodDropMark(size: 22),
        const SizedBox(width: AppSpacing.xs),
        Text(
          AppBrand.name,
          style: AppTypography.wordmark(palette).copyWith(fontSize: 18),
        ),
      ],
    );
  }
}
