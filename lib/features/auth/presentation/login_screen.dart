import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/router/app_routes.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/auth/application/auth_providers.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/auth/domain/auth_validators.dart';
import 'package:sholovvo_app/features/auth/presentation/auth_messages.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:sholovvo_app/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Email and password sign-in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  // The *rule* that failed is kept, not the sentence. Switching language while
  // an error is on screen then re-renders it in the new language instead of
  // leaving one stale English line behind.
  AuthFieldIssue? _emailIssue;
  AuthFieldIssue? _passwordIssue;
  Failure? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final AuthFieldIssue? emailIssue = AuthValidators.email(_email.text);
    final AuthFieldIssue? passwordIssue = AuthValidators.signInPassword(
      _password.text,
    );
    setState(() {
      _emailIssue = emailIssue;
      _passwordIssue = passwordIssue;
      _failure = null;
    });
    if (emailIssue != null || passwordIssue != null) {
      return;
    }

    setState(() => _busy = true);
    final Result<AuthUser> result = await ref
        .read(authRepositoryProvider)
        .signIn(email: _email.text.trim(), password: _password.text);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    result.fold(
      onSuccess: (AuthUser user) => _leaveAuthFlow(),
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  /// Returns to the gate rather than pushing a destination itself.
  ///
  /// The gate watches the auth stream, so it decides what a signed-in user sees
  /// — home, or the verification screen for an account that never confirmed its
  /// email. Pushing `HomeScreen` from here would bypass that check.
  void _leaveAuthFlow() {
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.loginTitle,
      subtitle: l10n.loginSubtitle,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xxs,
        children: <Widget>[
          Text(l10n.newToSolovvo, style: text.bodySmall),
          TextButton(
            onPressed: _busy ? null : () => _open(AppRoutes.register),
            child: Text(l10n.createAnAccount),
          ),
        ],
      ),
      children: <Widget>[
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
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.username, AutofillHints.email],
          enabled: !_busy,
          errorText: _emailIssue.message(l10n),
          onSubmitted: (String _) => _passwordFocus.requestFocus(),
          onChanged: (String value) {
            if (_emailIssue != null) {
              setState(() => _emailIssue = AuthValidators.email(value));
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SolovvoTextField(
          controller: _password,
          focusNode: _passwordFocus,
          label: l10n.passwordLabel,
          hintText: l10n.passwordHint,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          showObscureToggle: true,
          showPasswordLabel: l10n.showPassword,
          hidePasswordLabel: l10n.hidePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.password],
          enabled: !_busy,
          errorText: _passwordIssue.message(l10n),
          onSubmitted: (String _) => _submit(),
          onChanged: (String value) {
            if (_passwordIssue != null) {
              setState(
                () => _passwordIssue = AuthValidators.signInPassword(value),
              );
            }
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : () => _open(AppRoutes.forgotPassword),
            child: Text(l10n.forgotPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SolovvoButton(
          label: l10n.signIn,
          icon: Icons.login_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : _submit,
        ),
      ],
    );
  }

  void _open(String route) {
    Navigator.of(context).pushNamed(route);
  }
}
