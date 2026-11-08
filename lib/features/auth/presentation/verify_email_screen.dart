import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_elevation.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The two confirmations this screen can show.
///
/// Stored as a value rather than a sentence so the message is rendered in the
/// language that is active when it is *shown*, not the one active when the
/// request finished.
enum _Notice { linkSent, notConfirmed }

/// Blocks the app until the account's email address is confirmed.
///
/// The gate routes here for a signed-in but unverified account, so this is not
/// an optional nag: it is the reason a newly registered user does not reach a
/// donor profile that could claim a request and then never respond to it.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.user});

  final AuthUser user;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  /// Seconds the resend action stays disabled after a successful send. Firebase
  /// throttles itself, but a visible countdown stops the user from tapping into
  /// a wall of failures.
  static const int _resendCooldownSeconds = 60;

  Failure? _failure;
  _Notice? _notice;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_busy || _cooldown > 0) {
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
      _notice = null;
    });
    final Result<void> result = await ref
        .read(authRepositoryProvider)
        .sendEmailVerification();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    result.fold(
      onSuccess: (void _) {
        setState(() => _notice = _Notice.linkSent);
        _startCooldown();
      },
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  /// Re-reads the profile from the server, then re-subscribes the auth stream.
  ///
  /// A plain reload updates the SDK's cached user but does not make the gate
  /// rebuild; invalidating the stream provider re-listens, and `userChanges`
  /// emits the current profile immediately.
  Future<void> _checkVerified() async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _failure = null;
      _notice = null;
    });
    final Result<void> result = await ref
        .read(authRepositoryProvider)
        .reloadUser();
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    result.fold(
      onSuccess: (void _) {
        final AuthUser? current = ref.read(authRepositoryProvider).currentUser;
        if (current != null && current.isEmailVerified) {
          ref.invalidate(authStateProvider);
          return;
        }
        setState(() => _notice = _Notice.notConfirmed);
      },
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

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
    // No navigation: the gate sees the sign-out on the auth stream and returns
    // to the welcome screen by itself.
    result.fold(
      onSuccess: (void _) {},
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = _resendCooldownSeconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final String address = widget.user.email ?? l10n.unknownEmail;

    return AuthScaffold(
      title: l10n.verifyTitle,
      subtitle: l10n.verifySubtitle,
      footer: Center(
        child: TextButton(
          onPressed: _busy ? null : _signOut,
          child: Text(l10n.signOut),
        ),
      ),
      children: <Widget>[
        if (_failure != null) ...<Widget>[
          AuthErrorBanner(failure: _failure!),
          const SizedBox(height: AppSpacing.md),
        ],
        SolovvoCard(
          color: palette.surfaceMuted,
          shadow: AppElevation.none,
          borderColor: palette.outline,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.brandTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 22,
                  color: palette.onBrandTint,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(l10n.sentToLabel, style: text.labelSmall),
                    const SizedBox(height: 2),
                    Text(address, style: text.titleMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.verifyLockedBody, style: text.bodyMedium),
        if (_notice != null) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Text(switch (_notice!) {
            _Notice.linkSent => l10n.freshLinkSent,
            _Notice.notConfirmed => l10n.notConfirmedYet,
          }, style: text.bodySmall?.copyWith(color: palette.success)),
        ],
        const SizedBox(height: AppSpacing.lg),
        SolovvoButton(
          label: l10n.confirmedCta,
          icon: Icons.verified_outlined,
          isLoading: _busy,
          onPressed: _busy ? null : _checkVerified,
        ),
        const SizedBox(height: AppSpacing.sm),
        SolovvoButton(
          label: _cooldown > 0 ? l10n.resendIn(_cooldown) : l10n.resendEmail,
          variant: SolovvoButtonVariant.secondary,
          onPressed: _busy || _cooldown > 0 ? null : _resend,
        ),
      ],
    );
  }
}
