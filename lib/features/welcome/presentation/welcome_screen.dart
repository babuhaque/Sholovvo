import 'package:flutter/material.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/design/tokens/app_colors.dart';
import 'package:sholovvo_app/design/tokens/app_motion.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/tokens/app_typography.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/design/widgets/floating_blood_drops.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// First screen the user interacts with.
///
/// The content is scrollable behind a minimum-height constraint: on a short
/// device (320x568) the column overflows into scrolling instead of throwing a
/// RenderFlex overflow, and on a tall device it still distributes space evenly.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.1, 1, curve: AppMotion.entrance),
  );

  late final Animation<Offset> _rise = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(
    CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.1, 1, curve: AppMotion.entrance),
    ),
  );

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  /// The two calls to action lead to different forms on purpose: someone who
  /// has never registered starts at "create an account", and the sign-in link
  /// goes straight to the login form rather than making them hunt for it.
  void _openRegister() {
    Navigator.of(context).pushNamed(AppRoutes.register);
  }

  void _openSignIn() {
    Navigator.of(context).pushNamed(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      body: SoftGlowBackground(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const Positioned.fill(child: FloatingBloodDrops()),
            SafeArea(
              // Brand on top, hero in the free middle, actions pinned to the
              // bottom. Only the middle scrolls, so the primary action and the
              // "Sign in" link can never be pushed below the fold on a short
              // window or a landscape phone.
              child: Column(
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.lg,
                      AppSpacing.gutter,
                      0,
                    ),
                    child: _BrandRow(),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (
                            BuildContext context,
                            BoxConstraints middle,
                          ) {
                            return Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.gutter,
                                  vertical: AppSpacing.lg,
                                ),
                                child: FadeTransition(
                                  opacity: _fade,
                                  child: SlideTransition(
                                    position: _rise,
                                    child: _Hero(
                                      text: text,
                                      availableHeight: middle.maxHeight,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.gutter,
                      AppSpacing.md,
                      AppSpacing.gutter,
                      AppSpacing.xxl,
                    ),
                    child: FadeTransition(
                      opacity: _fade,
                      child: _Actions(
                        onGetStarted: _openRegister,
                        onSignIn: _openSignIn,
                      ),
                    ),
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

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const BloodDropMark(size: 26),
        const SizedBox(width: AppSpacing.xs),
        Text(
          AppBrand.name,
          style: AppTypography.wordmark(context.palette).copyWith(fontSize: 20),
        ),
        const Spacer(),
        // Reachable before signing in: a Bengali speaker should not have to
        // finish an English sign-up before the app speaks their language.
        const AppearanceButton(),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.text, required this.availableHeight});

  final TextTheme text;

  /// Height of the band between the brand row and the actions.
  final double availableHeight;

  /// The medallion takes a proportional slice of the band. On a tall phone it
  /// is the full 200px statement piece; on a short one it shrinks, and below
  /// [_medallionFloor] it is dropped altogether, because the headline is the
  /// message and the medallion is decoration. The supporting paragraph goes the
  /// same way below [_subtitleFloor]: a truncated sentence reads as a bug.
  static const double _maxDrop = 200;
  static const double _minDrop = 132;
  static const double _medallionFloor = 340;
  static const double _subtitleFloor = 230;

  @override
  Widget build(BuildContext context) {
    final bool showMedallion = availableHeight > _medallionFloor;
    final bool showSubtitle = availableHeight >= _subtitleFloor;
    final double dropSize = (availableHeight * 0.45).clamp(
      _minDrop,
      _maxDrop,
    );
    final double heroGap = availableHeight < 700
        ? AppSpacing.lg
        : AppSpacing.xxxl;
    final double headlineSize = availableHeight < 260 ? 26 : 32;
    final AppLocalizations l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showMedallion) ...<Widget>[
          _GlowingDrop(size: dropSize),
          SizedBox(height: heroGap),
        ],
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            l10n.welcomeHeadline,
            textAlign: TextAlign.center,
            style: text.displaySmall?.copyWith(
              fontSize: headlineSize,
              height: 1.2,
            ),
          ),
        ),
        if (showSubtitle) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              l10n.welcomeSubtitle,
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
          ),
        ],
      ],
    );
  }
}

/// The hero visual: a gradient disc with the drop mark inside and two orbit
/// rings, echoing the "premium medical" reference language.
class _GlowingDrop extends StatelessWidget {
  const _GlowingDrop({required this.size});

  /// Outer diameter; the rings, disc and drop scale from this.
  final double size;

  @override
  Widget build(BuildContext context) {
    final double innerRing = size * 0.82;
    final double disc = size * 0.66;
    final SolovvoPalette palette = context.palette;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          for (final double ring in <double>[size, innerRing])
            Container(
              width: ring,
              height: ring,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: palette.brandInk.withValues(alpha: 0.10),
                  width: 1.2,
                ),
              ),
            ),
          Container(
            width: disc,
            height: disc,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // The disc is a brand surface in both themes, so it keeps the
              // same deep gradient; only the shadow under it changes.
              gradient: palette.deepGradient,
              boxShadow: palette.floatingShadow,
            ),
            child: Center(
              child: BloodDropMark(
                size: disc * 0.41,
                // Cream to rose stays put: this mark is drawn *on* the deep
                // disc, which does not change with the theme either.
                gradient: const LinearGradient(
                  colors: <Color>[AppColors.onBrand, AppColors.rose],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onGetStarted, required this.onSignIn});

  final VoidCallback onGetStarted;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SolovvoButton(
          label: l10n.getStarted,
          icon: Icons.arrow_forward_rounded,
          onPressed: onGetStarted,
        ),
        const SizedBox(height: AppSpacing.sm),
        // A Wrap, not a Row: with large text scaling the prompt and the link
        // together outgrow a narrow phone, and reflowing onto two centred
        // lines is preferable to a RenderFlex overflow.
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.xxs,
          children: <Widget>[
            Text(l10n.alreadyHaveAccount, style: Theme.of(context).textTheme.bodySmall),
            TextButton(
              onPressed: onSignIn,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xxs,
                ),
                minimumSize: const Size(0, AppSpacing.minTapTarget),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(l10n.signIn),
            ),
          ],
        ),
      ],
    );
  }
}
