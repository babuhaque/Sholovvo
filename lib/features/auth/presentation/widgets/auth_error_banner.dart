import 'package:flutter/material.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/features/auth/presentation/auth_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Reports a rejected sign-in attempt above the form.
///
/// The auth-specific wording lives in `auth_messages.dart`; the banner itself is
/// shared with every other feature that needs to show a [Failure].
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context) {
    return ErrorBanner(message: authFailureMessage(context.l10n, failure));
  }
}
