import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/data/request_edit_service.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A form that edits an existing open `blood_requests` document.
///
/// **Scope, and why it is narrower than Create.** The edit rule
/// (`firestore.rules` L125-131) permits the owner to change eight keys while
/// the request is `open`: group, bags, hospital, date, request type, notes,
/// latitude and longitude. This form writes only three of those — group, bags
/// and hospital.
///
/// `requiredDateTime` is deliberately not on the form. The stored shape is
/// ambiguous in production (`Timestamp`, `DateTime`, or free text like
/// `'2026-11-10 10:00 AM'` — see [BloodRequest.neededByText]); a re-typed
/// timestamp would silently replace a text the requester wrote, and a text
/// re-entry would fail to preserve an instant the mapper had already parsed.
/// The safe path is a separate date-change stage rather than an "edit" that
/// quietly rewrites the medical urgency.
///
/// `notes` is not on the form either, because the [BloodRequest] entity does
/// not carry it — Stage 9.5's decision that notes are free text whose
/// semantics have not yet been settled. A form cannot pre-populate what the
/// read model does not read, and a form that clears a `notes` value the donor
/// never sees would be worse than one that leaves it alone. Firestore's
/// `update()` merges, so an absent key stays put — which is what this screen
/// relies on for `notes`, `requestType`, `latitude` and `longitude` all four.
///
/// **Ownership and precondition.** The rules refuse an edit by a stranger and
/// refuse any edit on a request that has already moved past `open`. This
/// screen is only reachable from [RequestDetailScreen]'s owner branch, and the
/// whole app currently reads only open requests, so both preconditions hold
/// by construction at the moment the "Save changes" button is enabled.
class EditRequestScreen extends ConsumerStatefulWidget {
  const EditRequestScreen({super.key, required this.request});

  final BloodRequest request;

  /// The route a caller pushes from the detail screen.
  ///
  /// Pops with the edited request id on success — the same sentinel [RequestDetailScreen.route]
  /// uses for a cancel, so a detail screen that launched this route can bubble
  /// the id up one more level to the list, which refreshes on a non-null
  /// result.
  static Route<String?> route(BloodRequest request) {
    return FadeSlidePageRoute<String?>(
      page: EditRequestScreen(request: request),
    );
  }

  @override
  ConsumerState<EditRequestScreen> createState() => _EditRequestScreenState();
}

class _EditRequestScreenState extends ConsumerState<EditRequestScreen> {
  late final TextEditingController _hospital;
  late final TextEditingController _bags;

  late String? _bloodGroup;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-populated from the entity, which the caller already read. There is
    // no second read here because the read model carries everything the three
    // editable fields are, and a re-fetch by id would need a repository
    // method that does not exist and a stale-window problem the list already
    // owns.
    _hospital = TextEditingController(text: widget.request.hospitalName);
    _bags = TextEditingController(text: widget.request.units.toString());
    _bloodGroup = widget.request.bloodGroup;
  }

  @override
  void dispose() {
    _hospital.dispose();
    _bags.dispose();
    super.dispose();
  }

  bool _validate() {
    final AppLocalizations l10n = context.l10n;
    if (_bloodGroup == null) {
      setState(
        () =>
            _errorMessage =
                '${l10n.requestsBloodGroup}: ${l10n.requestsRequired}',
      );
      return false;
    }
    final int bags = int.tryParse(_bags.text.trim()) ?? 0;
    if (bags < 1) {
      setState(
        () =>
            _errorMessage = '${l10n.requestsBags}: ${l10n.requestsRequired}',
      );
      return false;
    }
    if (_hospital.text.trim().isEmpty) {
      setState(
        () =>
            _errorMessage =
                '${l10n.requestsHospital}: ${l10n.requestsRequired}',
      );
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    if (!_validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Three keys, all inside the eight the rules allow. Anything the caller
    // did not open a field for is left untouched, because `update()` merges
    // and does not clear absent keys.
    final Map<String, Object?> fields = <String, Object?>{
      'bloodGroup': _bloodGroup,
      'bloodBags': int.parse(_bags.text.trim()),
      'hospitalName': _hospital.text.trim(),
    };

    final RequestEditService service = ref.read(requestEditServiceProvider);
    final Result<void> result = await service.editRequest(
      requestId: widget.request.id,
      fields: fields,
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
          _errorMessage = context.l10n.requestsEditError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsEditTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String>(
                  initialValue: _bloodGroup,
                  decoration: InputDecoration(
                    labelText: l10n.requestsBloodGroup,
                    border: const OutlineInputBorder(),
                  ),
                  items: BloodGroups.all
                      .map(
                        (String g) =>
                            DropdownMenuItem<String>(value: g, child: Text(g)),
                      )
                      .toList(),
                  onChanged: (String? v) => setState(() => _bloodGroup = v),
                ),
                const SizedBox(height: AppSpacing.sm),
                SolovvoTextField(
                  controller: _bags,
                  label: l10n.requestsBags,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.sm),
                SolovvoTextField(
                  controller: _hospital,
                  label: l10n.requestsHospital,
                  textCapitalization: TextCapitalization.words,
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
                      ? l10n.requestsEditSaving
                      : l10n.requestsEditSubmit,
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
