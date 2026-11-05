import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/feed/application/report_providers.dart';
import 'package:sholovvo_app/features/feed/data/report_service.dart';
import 'package:sholovvo_app/features/feed/domain/entities/report.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A bottom sheet for reporting a post or comment.
///
/// Write-only: submits a single `reports/{autoId}` document and dismisses.
/// The user sees a confirmation snackbar on success; on failure the sheet
/// stays open with an inline error so they can retry.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetId,
    required this.targetAuthorUid,
    this.targetType = ReportTarget.post,
  });

  final String targetId;
  final String targetAuthorUid;
  final ReportTarget targetType;

  /// Shows the report sheet over [context].
  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required String targetAuthorUid,
    ReportTarget targetType = ReportTarget.post,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext ctx) => ReportSheet(
        targetId: targetId,
        targetAuthorUid: targetAuthorUid,
        targetType: targetType,
      ),
    );
  }

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportReason? _selectedReason;
  final TextEditingController _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = context.l10n;
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _selectedReason == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final ReportService service = ref.read(reportServiceProvider);
    final Result<void> result = await service.submitReport(
      reporterUid: uid,
      target: widget.targetType,
      targetId: widget.targetId,
      targetAuthorUid: widget.targetAuthorUid,
      reason: _selectedReason!,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    if (!mounted) return;

    switch (result) {
      case Success<void>():
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.reportSuccess)));
      case FailureResult<void>():
        setState(() {
          _isSubmitting = false;
          _errorMessage = l10n.reportError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    // Map enum values to localized labels.
    final Map<ReportReason, String> labels = <ReportReason, String>{
      ReportReason.spam: l10n.reportReasonSpam,
      ReportReason.harassment: l10n.reportReasonHarassment,
      ReportReason.hateSpeech: l10n.reportReasonHateSpeech,
      ReportReason.misinformation: l10n.reportReasonMisinformation,
      ReportReason.other: l10n.reportReasonOther,
    };

    final double keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.targetType == ReportTarget.comment
                        ? l10n.reportCommentSheetTitle
                        : l10n.reportSheetTitle,
                    style: text.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Reason picker
            Text(l10n.reportReasonLabel, style: text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            RadioGroup<ReportReason>(
              groupValue: _selectedReason,
              onChanged: (ReportReason? val) =>
                  setState(() => _selectedReason = val),
              child: Column(
                children: <Widget>[
                  for (final ReportReason reason in ReportReason.values)
                    RadioListTile<ReportReason>(
                      title: Text(labels[reason]!),
                      value: reason,
                      dense: true,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Note field
            TextField(
              controller: _noteController,
              maxLines: 3,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: l10n.reportNoteHint,
                counterText: '',
              ),
            ),
            if (_errorMessage != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _errorMessage!,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            // Submit button
            SolovvoButton(
              label: _isSubmitting
                  ? l10n.reportSubmitting
                  : l10n.reportSubmitButton,
              onPressed:
                  _isSubmitting || _selectedReason == null ? null : _submit,
              expand: true,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
