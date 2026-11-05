import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:sholovvo_app/features/requests/data/request_create_service.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// A form that creates a new `blood_requests` document.
///
/// Pushed from [RequestsScreen]'s FAB. On success, pops with the new request id
/// so the list can refresh. Writes only the public document; the private/contact
/// PII subcollection is a separate owner action not handled here.
class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  static Route<String> route() {
    return FadeSlidePageRoute<String>(
      page: const CreateRequestScreen(),
    );
  }

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final TextEditingController _hospital = TextEditingController();
  final TextEditingController _bags = TextEditingController(text: '1');
  final TextEditingController _notes = TextEditingController();

  String? _bloodGroup;
  DateTime? _date;
  TimeOfDay? _time;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _hospital.dispose();
    _bags.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool _validate() {
    final AppLocalizations l10n = context.l10n;
    if (_bloodGroup == null) {
      setState(() => _errorMessage = '${l10n.requestsBloodGroup}: ${l10n.requestsRequired}');
      return false;
    }
    final int bags = int.tryParse(_bags.text.trim()) ?? 0;
    if (bags < 1) {
      setState(() => _errorMessage = '${l10n.requestsBags}: ${l10n.requestsRequired}');
      return false;
    }
    if (_hospital.text.trim().isEmpty) {
      setState(() => _errorMessage = '${l10n.requestsHospital}: ${l10n.requestsRequired}');
      return false;
    }
    if (_date == null) {
      setState(() => _errorMessage = '${l10n.requestsDate}: ${l10n.requestsRequired}');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    // Combine date + time into a single Timestamp.
    final DateTime date = _date ?? DateTime.now();
    final TimeOfDay time = _time ?? const TimeOfDay(hour: 9, minute: 0);
    final DateTime combined =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    final Timestamp ts = Timestamp.fromDate(combined);

    final int bags = int.tryParse(_bags.text.trim()) ?? 0;

    final RequestCreateService service = ref.read(requestCreateServiceProvider);
    final result = await service.createRequest(
      uid: uid,
      bloodGroup: _bloodGroup!,
      bloodBags: bags,
      hospitalName: _hospital.text,
      requiredDateTime: ts,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );

    if (!mounted) return;

    switch (result) {
      case Success<String>(:final value):
        Navigator.of(context).pop(value);
      case FailureResult<String>():
        setState(() {
          _isSubmitting = false;
          _errorMessage = context.l10n.requestsCreateError;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsCreateTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Blood group dropdown
                  DropdownButtonFormField<String>(
                    initialValue: _bloodGroup,
                    decoration: InputDecoration(
                      labelText: l10n.requestsBloodGroup,
                      border: const OutlineInputBorder(),
                    ),
                    items: BloodGroups.all
                        .map(
                          (String g) => DropdownMenuItem<String>(
                            value: g,
                            child: Text(g),
                          ),
                        )
                        .toList(),
                    onChanged: (String? v) => setState(() => _bloodGroup = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Bags
                  SolovvoTextField(
                    controller: _bags,
                    label: l10n.requestsBags,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Hospital name
                  SolovvoTextField(
                    controller: _hospital,
                    label: l10n.requestsHospital,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Date picker
                  _DateTile(
                    label: l10n.requestsDate,
                    value: _date,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _date ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() => _date = picked);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Time picker
                  _TimeTile(
                    label: l10n.requestsTime,
                    value: _time,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: _time ?? const TimeOfDay(hour: 9, minute: 0),
                      );
                      if (picked != null) {
                        setState(() => _time = picked);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Notes
                  SolovvoTextField(
                    controller: _notes,
                    label: l10n.requestsNotes,
                    hintText: l10n.requestsNotesHint,
                    maxLines: 3,
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
                        ? l10n.requestsCreating
                        : l10n.requestsCreateSubmit,
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

/// A read-only input-like tile that opens a date picker on tap.
class _DateTile extends StatelessWidget {
  const _DateTile({required this.label, required this.value, required this.onTap});

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String display = value != null
        ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
        : l10n.requestsRequired;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
            Text(
              value != null ? display : '--',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Icon(Icons.calendar_today_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

/// A read-only input-like tile that opens a time picker on tap.
class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.value, required this.onTap});

  final String label;
  final TimeOfDay? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String display = value?.format(context) ?? '--';
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: <Widget>[
            Expanded(child: Text(label, style: Theme.of(context).textTheme.labelSmall)),
            Text(
              display,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Icon(Icons.access_time_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}
