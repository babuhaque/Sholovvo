import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/app_shell.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/auth/presentation/verify_email_screen.dart';
import 'package:sholovvo_app/features/splash/presentation/splash_screen.dart';
import 'package:sholovvo_app/features/welcome/presentation/welcome_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Decides which surface a session belongs on, and keeps deciding.
///
/// This is the only place that knows the signed-out → signed-in → signed-out
/// transitions. Screens therefore never push a "logged in" destination: the
/// sign-in form pops back here, and the gate renders whatever the auth stream
/// now says. A session restored from disk, a verification completed in a mail
/// client and a sign-out all land on the same decision without extra plumbing.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  /// The two second brand reveal is part of the product brief, so it runs to
  /// the end even when the session resolves instantly from disk.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<AuthUser?> auth = ref.watch(authStateProvider);

    if (!_revealed) {
      return SplashScreen(
        onRevealComplete: () {
          if (mounted) {
            setState(() => _revealed = true);
          }
        },
      );
    }

    // The stream failed before it ever produced a value. Retrying re-listens;
    // showing the welcome screen here would silently sign the user out.
    if (auth.hasError && !auth.hasValue) {
      return AuthStreamErrorView(
        failure: mapExceptionToFailure(auth.error!, auth.stackTrace),
        onRetry: () => ref.invalidate(authStateProvider),
      );
    }

    // `hasValue` rather than a null check: the payload itself is nullable, so
    // "signed out" and "not resolved yet" are only distinguishable this way.
    // Keeping the splash up while a stored session resolves avoids flashing the
    // welcome screen at a donor who is already signed in.
    if (!auth.hasValue) {
      return const SplashScreen();
    }

    final AuthUser? user = auth.value;
    if (user == null) {
      return const WelcomeScreen();
    }
    if (!user.isEmailVerified) {
      return VerifyEmailScreen(user: user);
    }
    // The shell, not the dashboard: since Stage 7 a verified session owns a tab
    // bar, and the dashboard is only the first of its two tabs.
    return AppShell(user: user);
  }
}

/// Shown when the identity stream fails, so the failure is visible instead of
/// looking like a fresh install.
class AuthStreamErrorView extends StatelessWidget {
  const AuthStreamErrorView({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: SolovvoCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Icon(
                          Icons.lock_person_outlined,
                          color: context.palette.danger,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.sessionRestoreTitle,
                            style: text.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.sessionRestoreBody, style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      failure.code.name,
                      style: text.labelSmall?.copyWith(letterSpacing: 0.8),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: FilledButton(
                            onPressed: onRetry,
                            child: Text(l10n.tryAgain),
                          ),
                        ),
                      ],
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
