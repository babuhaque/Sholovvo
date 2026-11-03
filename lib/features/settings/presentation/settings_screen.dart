import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/appearance_sheet.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/section_header.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:sholovvo_app/features/settings/presentation/widgets/settings_tile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Everything that is about the app and the account rather than about blood.
///
/// This is the destination Stage 7 created, which is why three things now live
/// here instead of on the dashboard: **sign-out** (it was the last control on a
/// work surface, where a mis-tap costs a session), the **appearance sheet** (the
/// same widget Welcome and Home open, not a second copy), and the account's
/// identity, which until now only existed on the profile form.
///
/// What it deliberately does *not* have: a notification switch. There is no push
/// channel on the Spark plan and nothing reads such a flag until Stage 11, and a
/// switch that changes nothing is worse than no switch.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.user});

  final AuthUser user;

  /// Pushed above the shell, like every other form: the tab bar comes back when
  /// the user leaves, and the route stack stays one deep.
  static Route<void> route(AuthUser user) {
    return FadeSlidePageRoute<void>(page: SettingsScreen(user: user));
  }

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Failure? _failure;
  bool _busy = false;

  Future<void> _signOut() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
    });
    final Result<void> result = await ref
        .read(authRepositoryProvider)
        .signOut();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    result.fold(
      onSuccess: (void _) {
        // The gate swaps the signed-in surface for the welcome screen underneath
        // this route, but it cannot reach a route pushed on top of it: without
        // this pop the donor would be left staring at Settings, now signed out.
        if (mounted) {
          Navigator.of(context)
              .popUntil((Route<dynamic> route) => route.isFirst);
        }
      },
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppConfig config = ref.watch(appConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.gutter,
              AppSpacing.lg,
              AppSpacing.gutter,
              AppSpacing.xxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SectionHeader(title: l10n.settingsAccountSection),
                    const SizedBox(height: AppSpacing.xs),
                    _AccountCard(user: widget.user),
                    const SizedBox(height: AppSpacing.xl),
                    // A section, not a bare row: notifications and privacy join
                    // it in Stages 11 and 13, and a header now means those are
                    // one insertion each rather than a re-layout.
                    SectionHeader(title: l10n.settingsPreferencesSection),
                    const SizedBox(height: AppSpacing.xs),
                    SettingsTile(
                      icon: Icons.palette_outlined,
                      title: l10n.appearanceAndLanguage,
                      body: l10n.settingsAppearanceBody,
                      onTap: () => AppearanceSheet.show(context),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(title: l10n.settingsAboutSection),
                    const SizedBox(height: AppSpacing.xs),
                    _AboutCard(flavor: config.flavor),
                    const SizedBox(height: AppSpacing.xl),
                    if (_failure != null) ...<Widget>[
                      AuthErrorBanner(failure: _failure!),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    SolovvoButton(
                      label: l10n.signOut,
                      icon: Icons.logout_rounded,
                      variant: SolovvoButtonVariant.secondary,
                      isLoading: _busy,
                      onPressed: _busy ? null : _signOut,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.settingsSignOutBody,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The address this session signs in with.
///
/// Read-only on purpose: the address is the sign-in identity, so changing it is
/// a re-authentication flow rather than a field. Saying so is cheaper than a
/// greyed-out input that looks broken.
class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _DetailRow(
            label: l10n.emailLabel,
            // An account can exist without an address; an em dash says "nothing
            // here" without pretending a blank string is a value.
            value: user.email ?? '—',
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.profileEmailManaged,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// Who built this build.
///
/// The app name and tagline are brand constants rather than translated copy, so
/// they are read from [AppBrand] instead of an ARB file. There is no version
/// number yet: `pubspec.yaml` carries one, but nothing in the app can read it
/// without a platform plugin, and inventing a constant that drifts from the
/// manifest would be worse than omitting the row.
class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(AppBrand.name, style: text.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(AppBrand.tagline, style: text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          _DetailRow(
            label: l10n.settingsBuildLabel,
            // An exhaustive switch: adding a fourth flavour is a compile error
            // here rather than an English enum name leaking into a Bangla UI.
            value: switch (flavor) {
              AppFlavor.development => l10n.settingsBuildDevelopment,
              AppFlavor.staging => l10n.settingsBuildStaging,
              AppFlavor.production => l10n.settingsBuildProduction,
            },
          ),
        ],
      ),
    );
  }
}

/// A label on the left and a value on the right, wrapping rather than clipping.
class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final SolovvoPalette palette = context.palette;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: text.bodyMedium?.copyWith(color: palette.textSecondary),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(value, textAlign: TextAlign.end, style: text.bodyMedium),
        ),
      ],
    );
  }
}
