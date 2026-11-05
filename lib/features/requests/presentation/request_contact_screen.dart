import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/data/request_contact_service.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/entities/request_contact.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Where the owner-contact form is in its life. The form is a read-then-write, so
/// it opens in [loading], settles into [ready] (blank when there is no saved
/// contact yet, pre-filled when there is), and can land in [loadFailure] — which
/// is a state the owner cannot save out of, precisely because a blank overwrite
/// would destroy contact they did get to see.
enum _FormStatus { loading, ready, loadFailure }

/// A form that reads and edits the owner's private contact record for one request.
///
/// **Reads what the owner saved, then writes it back.** On open this screen reads
/// `blood_requests/{id}/private/contact` through [RequestContactService.loadContact]
/// — the app's first and only contact read, gated to the owner by `firestore.rules`
/// L234-236 — and pre-fills the three fields. With no saved contact the form opens
/// blank (a first capture); with one it opens filled so the owner can correct it.
/// This is the round-trip that makes the earlier capture honest: an owner can now
/// see what they stored, not only write it.
///
/// **Why a failed read does not fall through to a blank form.** [saveContact] is
/// `set` (replace) of all three keys, so submitting a blank form over a contact the
/// read merely *failed to fetch* would silently erase real PII the owner never saw.
/// That is unacceptable, so a read failure shows a retry and disables the save until
/// the read succeeds — the form never lets the owner overwrite what it could not
/// first confirm is empty.
///
/// **Scope, and what it is not.** This is the owner read/write of the contact story.
/// It is not the donor read half: no matched donor can see this data (the M3-C2
/// blocker), and the intro sentence says exactly that rather than promising a contact
/// the app cannot deliver. Reaching a donor is a Stage-10 architecture decision the
/// rules block, not something this screen changes.
///
/// **Ownership and precondition.** Only reachable from [RequestDetailScreen]'s owner
/// branch, and the rules refuse a read or write by anyone but the parent document's
/// `userId` — so the affordance and the authority agree.
class RequestContactScreen extends ConsumerStatefulWidget {
  const RequestContactScreen({super.key, required this.request});

  final BloodRequest request;

  /// The route a caller pushes from the detail screen's owner branch.
  ///
  /// Pops with the request id on success — the same sentinel
  /// [EditRequestScreen.route] uses — so a detail screen that launched this
  /// route can bubble the id up to the list.
  static Route<String?> route(BloodRequest request) {
    return FadeSlidePageRoute<String?>(
      page: RequestContactScreen(request: request),
    );
  }

  @override
  ConsumerState<RequestContactScreen> createState() =>
      _RequestContactScreenState();
}

class _RequestContactScreenState extends ConsumerState<RequestContactScreen> {
  final TextEditingController _patientName = TextEditingController();
  final TextEditingController _phoneNumber = TextEditingController();
  final TextEditingController _hospitalAddress = TextEditingController();

  _FormStatus _status = _FormStatus.loading;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _patientName.dispose();
    _phoneNumber.dispose();
    _hospitalAddress.dispose();
    super.dispose();
  }

  /// Reads the owner's saved contact and opens the form. `null` (no document yet)
  /// and a present-but-partial document both land in [ready] — the former blank,
  /// the latter with whatever the mapper could coerce — because neither is a
  /// reason to stop the owner editing. Only a genuine read failure is a reason.
  Future<void> _load() async {
    setState(() {
      _status = _FormStatus.loading;
      _errorMessage = null;
    });

    final Result<RequestContact?> result = await ref
        .read(requestContactServiceProvider)
        .loadContact(requestId: widget.request.id);

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success<RequestContact?>(:final value):
        // Fill from what exists, leave blank otherwise. `value` null means
        // "no contact saved yet"; a non-null value with empty fields means the
        // owner saved blanks — both render the same way.
        _patientName.text = value?.patientName ?? '';
        _phoneNumber.text = value?.phoneNumber ?? '';
        _hospitalAddress.text = value?.hospitalAddress ?? '';
        setState(() => _status = _FormStatus.ready);
      case FailureResult<RequestContact?>():
        // Do not open a form the owner could use to clobber unseen data.
        setState(() => _status = _FormStatus.loadFailure);
    }
  }

  bool _validate() {
    final AppLocalizations l10n = context.l10n;
    if (_patientName.text.trim().isEmpty) {
      setState(
        () =>
            _errorMessage =
                '${l10n.requestsPatientName}: ${l10n.requestsRequired}',
      );
      return false;
    }
    // The rule constrains only a non-empty string here, not a phone format —
    // so this is a presence check, not a validation of the number's shape. The
    // app has no locale-correct phone pattern and inventing one would reject a
    // real number the owner typed.
    if (_phoneNumber.text.trim().isEmpty) {
      setState(
        () =>
            _errorMessage =
                '${l10n.requestsPhoneNumber}: ${l10n.requestsRequired}',
      );
      return false;
    }
    // hospitalAddress is the one field the rule does not require to be non-empty
    // (only `is string`), so an empty address is valid and needs no guard here.
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _status != _FormStatus.ready) {
      return;
    }
    if (!_validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final RequestContactService service = ref.read(
      requestContactServiceProvider,
    );
    final Result<void> result = await service.saveContact(
      requestId: widget.request.id,
      patientName: _patientName.text,
      phoneNumber: _phoneNumber.text,
      hospitalAddress: _hospitalAddress.text,
    );

    if (!mounted) {
      return;
    }

    switch (result) {
      case Success<void>():
        Navigator.of(context).pop<String>(widget.request.id);
      case FailureResult<void>():
        setState(() {
          _isSubmitting = false;
          _errorMessage = context.l10n.requestsContactError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsContactTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: switch (_status) {
            _FormStatus.loading => Center(
              child: CircularProgressIndicator(
                semanticsLabel: l10n.requestsContactLoading,
              ),
            ),
            _FormStatus.loadFailure => _LoadFailure(
              onRetry: _load,
              message: l10n.requestsContactLoadError,
              retryLabel: l10n.requestsContactRetry,
            ),
            _FormStatus.ready => _form(l10n, theme),
          },
        ),
      ),
    );
  }

  Widget _form(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l10n.requestsContactIntro,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          SolovvoTextField(
            controller: _patientName,
            label: l10n.requestsPatientName,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.sm),
          SolovvoTextField(
            controller: _phoneNumber,
            label: l10n.requestsPhoneNumber,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.sm),
          SolovvoTextField(
            controller: _hospitalAddress,
            label: l10n.requestsHospitalAddress,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          if (_errorMessage != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SolovvoButton(
            label: _isSubmitting
                ? l10n.requestsContactSaving
                : l10n.requestsContactSubmit,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _submit,
            expand: true,
          ),
        ],
      ),
    );
  }
}

/// The load-failure state: a message and a retry, and no path to a save.
///
/// Split out because it is the whole safety story of this increment — the owner
/// is offered a way to try the read again, never a way to write over a contact the
/// app could not first read.
class _LoadFailure extends StatelessWidget {
  const _LoadFailure({
    required this.onRetry,
    required this.message,
    required this.retryLabel,
  });

  final VoidCallback onRetry;
  final String message;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.gutter),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            message,
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.lg),
          SolovvoButton(
            label: retryLabel,
            onPressed: onRetry,
            variant: SolovvoButtonVariant.secondary,
            expand: false,
          ),
        ],
      ),
    );
  }
}
