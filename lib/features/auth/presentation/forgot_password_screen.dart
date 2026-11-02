import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_validators.dart';
import 'package:sholovvo_app/features/auth/presentation/auth_messages.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Requests a password reset link.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();

  AuthFieldIssue? _emailIssue;
  Failure? _failure;
  bool _busy = false;

  /// Set once the request has been accepted, which swaps the form for the
  /// confirmation panel.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final AuthFieldIssue? emailIssue = AuthValidators.email(_email.text);
    setState(() {
      _emailIssue = emailIssue;
      _failure = null;
    });
    if (emailIssue != null) {
      return;
    }

    final String address = _email.text.trim();
    setState(() => _busy = true);
    final Result<void> result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(address);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    result.fold(
      onSuccess: (void _) => setState(() => _sentTo = address),
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.forgotTitle,
      subtitle: l10n.forgotSubtitle,
      footer: _sentTo != null
          ? null
          : Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(l10n.backToSignIn),
              ),
            ),
      children: <Widget>[
        ...(_sentTo != null
            ? <Widget>[_SentPanel(email: _sentTo!)]
            : _form(l10n)),
      ],
    );
  }

  List<Widget> _form(AppLocalizations l10n) {
    return <Widget>[
      if (_failure != null) ...<Widget>[
        AuthErrorBanner(failure: _failure!),
        const SizedBox(height: AppSpacing.md),
      ],
      SolovvoTextField(
        controller: _email,
        label: l10n.emailLabel,
        hintText: l10n.emailHint,
        prefixIcon: Icons.mail_outline,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autofillHints: const <String>[AutofillHints.email],
        enabled: !_busy,
        errorText: _emailIssue.message(l10n),
        onSubmitted: (String _) => _submit(),
        onChanged: (String value) {
          if (_emailIssue != null) {
            setState(() => _emailIssue = AuthValidators.email(value));
          }
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      SolovvoButton(
        label: l10n.sendResetLink,
        icon: Icons.send_rounded,
        isLoading: _busy,
        onPressed: _busy ? null : _submit,
      ),
    ];
  }
}

/// Confirmation shown after the request is accepted.
///
/// The wording is deliberately neutral ("if an account exists"): the backend
/// does not disclose whether an address is registered, and this panel must not
/// leak it either.
class _SentPanel extends StatelessWidget {
  const _SentPanel({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              Icons.mark_email_read_outlined,
              size: 22,
              color: context.palette.success,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(l10n.resetSentTitle, style: text.titleMedium),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.resetSentBody(email), style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        SolovvoButton(
          label: l10n.backToSignIn,
          variant: SolovvoButtonVariant.secondary,
          onPressed: () {
            // Replace, do not pop: this screen has nothing left to do, and
            // popping back would land on the form that was just submitted.
            Navigator.of(context).pushReplacementNamed(AppRoutes.login);
          },
        ),
      ],
    );
  }
}
