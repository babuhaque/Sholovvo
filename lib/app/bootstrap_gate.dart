import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/app/auth_gate.dart';
import 'package:sholovvo_app/core/brand/app_brand.dart';
import 'package:sholovvo_app/core/config/app_config.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/firebase/firebase_bootstrap.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Chooses the first real screen based on the **actual** bootstrap outcome.
///
/// Success hands over to the [AuthGate], which picks between the welcome screen,
/// the verification screen and the signed-in home. Failure shows a diagnostic
/// surface instead of pretending the backend exists — an app that silently
/// degrades here would present empty donor lists later with no explanation.
class BootstrapGate extends ConsumerWidget {
  const BootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FirebaseBootstrapResult result = ref.watch(firebaseBootstrapProvider);

    return switch (result) {
      FirebaseReady() => const AuthGate(),
      FirebaseUnavailable(:final failure) => FirebaseUnavailableView(
        failure: failure,
      ),
    };
  }
}

/// Renders a classified Firebase initialisation failure.
class FirebaseUnavailableView extends ConsumerWidget {
  const FirebaseUnavailableView({super.key, required this.failure});

  final Failure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme text = Theme.of(context).textTheme;
    final AppConfig config = ref.watch(appConfigProvider);
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
                          Icons.cloud_off_rounded,
                          color: context.palette.danger,
                          size: 26,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            l10n.firebaseUnavailableTitle,
                            style: text.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.firebaseUnavailableBody, style: text.bodyMedium),
                    const SizedBox(height: AppSpacing.md),
                    _DiagnosticRow(
                      label: l10n.diagnosticReason,
                      value: failure.code.name,
                    ),
                    if (failure.debugMessage != null)
                      _DiagnosticRow(
                        label: l10n.diagnosticDetail,
                        value: failure.debugMessage!,
                      ),
                    _DiagnosticRow(
                      label: l10n.diagnosticProject,
                      value: AppBrand.firebaseProjectId,
                    ),
                    _DiagnosticRow(
                      label: l10n.diagnosticFlavor,
                      value: config.flavor.name,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: <Widget>[
                        const BloodDropMark(size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            l10n.reconnectHint,
                            style: text.bodySmall,
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

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 66,
            child: Text(
              label,
              style: text.labelSmall?.copyWith(letterSpacing: 0.8),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: text.bodySmall?.copyWith(
                color: context.palette.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
