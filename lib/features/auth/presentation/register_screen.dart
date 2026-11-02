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

/// Creates a donor account and sends the verification email.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  // Rules, not sentences: see the note in `login_screen.dart`.
  AuthFieldIssue? _nameIssue;
  AuthFieldIssue? _emailIssue;
  AuthFieldIssue? _passwordIssue;
  AuthFieldIssue? _confirmIssue;
  Failure? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final AuthFieldIssue? nameIssue = AuthValidators.displayName(_name.text);
    final AuthFieldIssue? emailIssue = AuthValidators.email(_email.text);
    final AuthFieldIssue? passwordIssue = AuthValidators.newPassword(
      _password.text,
    );
    final AuthFieldIssue? confirmIssue = AuthValidators.confirmPassword(
      _confirm.text,
      _password.text,
    );
    setState(() {
      _nameIssue = nameIssue;
      _emailIssue = emailIssue;
      _passwordIssue = passwordIssue;
      _confirmIssue = confirmIssue;
      _failure = null;
    });
    if (nameIssue != null ||
        emailIssue != null ||
        passwordIssue != null ||
        confirmIssue != null) {
      return;
    }

    setState(() => _busy = true);
    final Result<AuthUser> result = await ref
        .read(authRepositoryProvider)
        .register(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    result.fold(
      onSuccess: (AuthUser user) {
        // The account exists but is unverified, so the gate underneath renders
        // the verification screen; this route only has to get out of the way.
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      },
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppLocalizations l10n = context.l10n;

    return AuthScaffold(
      title: l10n.registerTitle,
      subtitle: l10n.registerSubtitle,
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.xxs,
        children: <Widget>[
          Text(l10n.alreadyRegistered, style: text.bodySmall),
          TextButton(
            onPressed: _busy ? null : () => _replaceWith(AppRoutes.login),
            child: Text(l10n.signIn),
          ),
        ],
      ),
      children: <Widget>[
        if (_failure != null) ...<Widget>[
          AuthErrorBanner(failure: _failure!),
          const SizedBox(height: AppSpacing.md),
        ],
        SolovvoTextField(
          controller: _name,
          label: l10n.fullNameLabel,
          hintText: l10n.fullNameHint,
          prefixIcon: Icons.person_outline_rounded,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.name],
          enabled: !_busy,
          errorText: _nameIssue.message(l10n),
          onSubmitted: (String _) => _emailFocus.requestFocus(),
          onChanged: (String value) {
            if (_nameIssue != null) {
              setState(() => _nameIssue = AuthValidators.displayName(value));
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SolovvoTextField(
          controller: _email,
          focusNode: _emailFocus,
          label: l10n.emailLabel,
          hintText: l10n.emailHint,
          prefixIcon: Icons.mail_outline,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.email],
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
          hintText: l10n.newPasswordHint,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          showObscureToggle: true,
          showPasswordLabel: l10n.showPassword,
          hidePasswordLabel: l10n.hidePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const <String>[AutofillHints.newPassword],
          enabled: !_busy,
          errorText: _passwordIssue.message(l10n),
          helperText: l10n.passwordRule,
          onSubmitted: (String _) => _confirmFocus.requestFocus(),
          onChanged: (String value) {
            if (_passwordIssue != null) {
              setState(
                () => _passwordIssue = AuthValidators.newPassword(value),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.md),
        SolovvoTextField(
          controller: _confirm,
          focusNode: _confirmFocus,
          label: l10n.confirmPasswordLabel,
          hintText: l10n.confirmPasswordHint,
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
          textInputAction: TextInputAction.done,
          autofillHints: const <String>[AutofillHints.newPassword],
          enabled: !_busy,
          errorText: _confirmIssue.message(l10n),
          onSubmitted: (String _) => _submit(),
          onChanged: (String value) {
            if (_confirmIssue != null) {
              setState(
                () => _confirmIssue = AuthValidators.confirmPassword(
                  value,
                  _password.text,
                ),
              );
            }
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        SolovvoButton(
          label: l10n.createAccount,
          icon: Icons.arrow_forward_rounded,
          isLoading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.verificationEmailNote,
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }

  /// Swaps this route for [route] so register and sign-in do not pile up.
  void _replaceWith(String route) {
    Navigator.of(context).pushReplacementNamed(route);
  }
}
