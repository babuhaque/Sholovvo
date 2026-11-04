import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_radius.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/profile_validators.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_messages.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_privacy_card.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Creates or edits the signed-in donor's own profile.
///
/// [initial] is required rather than read from the stream inside the form: a
/// form that re-initialises itself whenever the document changes would wipe what
/// the user is typing the moment any write lands.
class ProfileEditScreen extends StatelessWidget {
  const ProfileEditScreen({
    super.key,
    required this.user,
    required this.initial,
  });

  final AuthUser user;
  final UserProfile initial;

  @override
  Widget build(BuildContext context) {
    return _ProfileEditForm(user: user, initial: initial);
  }
}

class _ProfileEditForm extends ConsumerStatefulWidget {
  const _ProfileEditForm({required this.user, required this.initial});

  final AuthUser user;
  final UserProfile initial;

  @override
  ConsumerState<_ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<_ProfileEditForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.displayName,
  );
  late final TextEditingController _phone = TextEditingController(
    text: widget.initial.phone ?? '',
  );
  late final TextEditingController _area = TextEditingController(
    text: widget.initial.area ?? '',
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.initial.addressLine ?? '',
  );

  /// Read-only, but still a field with a controller: a `SolovvoTextField` owns
  /// its text, and creating a controller inside `build` would allocate one per
  /// frame.
  late final TextEditingController _email = TextEditingController(
    text: widget.user.email ?? '',
  );

  late String? _bloodGroup = widget.initial.bloodGroup;
  late DateTime? _dateOfBirth = widget.initial.dateOfBirth;
  late ProfileGender? _gender = widget.initial.gender;
  late bool _publishArea = widget.initial.publishAreaInSearch;
  late bool _discoverable = widget.initial.allowDonorDiscovery;

  final Map<ProfileFormField, ProfileFieldIssue?> _issues =
      <ProfileFormField, ProfileFieldIssue?>{};

  Failure? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _area.dispose();
    _address.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Re-checks one field, but only once it has shown an error: a form that turns
  /// red while someone is still typing their first character is hostile.
  void _revalidate(
    ProfileFormField field,
    ProfileFieldIssue? Function() check,
  ) {
    if (_issues[field] == null) {
      return;
    }
    setState(() => _issues[field] = check());
  }

  Future<void> _pickDateOfBirth() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      // The picker needs a starting month; it is not a value that gets saved
      // unless the user confirms it.
      initialDate: _dateOfBirth ?? DateTime(now.year - 20),
      firstDate: DateTime(ProfileValidators.earliestBirthYear),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: context.l10n.profilePickerDate,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _dateOfBirth = DateTime(picked.year, picked.month, picked.day);
      _issues[ProfileFormField.birthDate] = ProfileValidators.birthDate(
        _dateOfBirth,
      );
    });
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }

    final Map<ProfileFormField, ProfileFieldIssue> found =
        ProfileValidators.validate(
          name: _name.text,
          phone: _phone.text,
          area: _area.text,
          address: _address.text,
          birthDate: _dateOfBirth,
          bloodGroup: _bloodGroup,
          knownBloodGroups: BloodGroups.all,
        );

    setState(() {
      _issues
        ..clear()
        ..addAll(found);
      _failure = null;
    });
    if (found.isNotEmpty) {
      return;
    }

    final UserProfile profile = UserProfile(
      uid: widget.initial.uid,
      displayName: _name.text.trim(),
      bloodGroup: _bloodGroup,
      // Not editable in this stage: photo upload arrives with storage.
      photoUrl: widget.initial.photoUrl,
      isAvailable: widget.initial.isAvailable,
      area: _area.text.trim(),
      addressLine: _address.text.trim(),
      phone: _phone.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender,
      publishAreaInSearch: _publishArea,
      allowDonorDiscovery: _discoverable,
    );

    final AppLocalizations l10n = context.l10n;
    setState(() => _busy = true);
    final Result<void> result = await ref
        .read(profileControllerProvider.notifier)
        .save(profile);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);

    result.fold(
      onSuccess: (void _) {
        // The messenger belongs to the app, not this route, so the confirmation
        // survives the pop and lands on the profile screen the user returns to.
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.profileSaved)));
        Navigator.of(context).pop();
      },
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasArea = _area.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileEditTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.gutter,
            AppSpacing.sm,
            AppSpacing.gutter,
            AppSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_failure != null) ...<Widget>[
                    ErrorBanner(
                      message: profileFailureMessage(l10n, _failure!),
                    ),
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
                    errorText: _issues[ProfileFormField.name].message(l10n),
                    onChanged: (String value) => _revalidate(
                      ProfileFormField.name,
                      () => ProfileValidators.name(value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ChoicePicker(
                    label: l10n.bloodGroupLabel,
                    options: <String, String>{
                      for (final String group in BloodGroups.all) group: group,
                    },
                    selected: _bloodGroup,
                    enabled: !_busy,
                    errorText: _issues[ProfileFormField.bloodGroup].message(l10n),
                    onSelected: (String? value) => setState(() {
                      _bloodGroup = value;
                      _issues[ProfileFormField.bloodGroup] =
                          ProfileValidators.bloodGroup(
                            value,
                            BloodGroups.all,
                          );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SolovvoTextField(
                    controller: _phone,
                    label: l10n.profilePhoneLabel,
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.telephoneNumber],
                    enabled: !_busy,
                    errorText: _issues[ProfileFormField.phone].message(l10n),
                    // Says where the number is stored rather than implying it is
                    // shared with whoever asks for blood.
                    helperText: l10n.profilePrivacyPrivateTitle,
                    onChanged: (String value) => _revalidate(
                      ProfileFormField.phone,
                      () => ProfileValidators.phone(value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SolovvoTextField(
                    controller: _area,
                    label: l10n.profileAreaLabel,
                    prefixIcon: Icons.place_outlined,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    enabled: !_busy,
                    errorText: _issues[ProfileFormField.area].message(l10n),
                    onChanged: (String value) {
                      _revalidate(
                        ProfileFormField.area,
                        () => ProfileValidators.area(value),
                      );
                      // The publication switch needs a value to publish.
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SolovvoTextField(
                    controller: _address,
                    label: l10n.profileAddressLabel,
                    prefixIcon: Icons.home_outlined,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.words,
                    enabled: !_busy,
                    errorText: _issues[ProfileFormField.address].message(l10n),
                    helperText: l10n.profilePrivacyPrivateTitle,
                    onChanged: (String value) => _revalidate(
                      ProfileFormField.address,
                      () => ProfileValidators.address(value),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DateOfBirthField(
                    value: _dateOfBirth,
                    enabled: !_busy,
                    errorText: _issues[ProfileFormField.birthDate].message(l10n),
                    onTap: _pickDateOfBirth,
                    onClear: () => setState(() {
                      _dateOfBirth = null;
                      _issues.remove(ProfileFormField.birthDate);
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _ChoicePicker(
                    label: l10n.profileGenderLabel,
                    options: <String, String>{
                      for (final ProfileGender gender in ProfileGender.values)
                        gender.name: profileGenderLabel(l10n, gender),
                    },
                    selected: _gender?.name,
                    enabled: !_busy,
                    onSelected: (String? value) => setState(() {
                      _gender = value == null ? null : _genderFrom(value);
                    }),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SolovvoCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.profilePrivacyDiscoveryTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.profilePrivacyDiscoveryBody,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: ProfilePrivacyCard.discoverableSwitchKey,
                          value: _discoverable,
                          onChanged: _busy
                              ? null
                              : (bool value) =>
                                    setState(() => _discoverable = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SolovvoCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                l10n.profilePrivacyAreaTitle,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.profilePrivacyAreaBody,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          key: ProfilePrivacyCard.publishAreaSwitchKey,
                          value: _publishArea,
                          onChanged: _busy || !hasArea
                              ? null
                              : (bool value) =>
                                    setState(() => _publishArea = value),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Read-only, and shown as such: the address is the identity
                  // provider's, so this form must not imply it can change it.
                  SolovvoTextField(
                    controller: _email,
                    label: l10n.emailLabel,
                    prefixIcon: Icons.mail_outline_rounded,
                    enabled: false,
                    helperText: l10n.profileEmailManaged,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SolovvoButton(
                    label: l10n.profileSaveAction,
                    icon: Icons.check_rounded,
                    isLoading: _busy,
                    onPressed: _busy ? null : () => unawaited(_submit()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Maps a stored `ProfileGender` name back to its value.
  static ProfileGender? _genderFrom(String name) {
    for (final ProfileGender gender in ProfileGender.values) {
      if (gender.name == name) {
        return gender;
      }
    }
    return null;
  }
}

/// A row of single-choice chips with the same label and error treatment as
/// [SolovvoTextField].
///
/// Chips rather than a dropdown: eight blood groups and four gender options are
/// all visible at once, which is one tap fewer and impossible to mistype.
class _ChoicePicker extends StatelessWidget {
  const _ChoicePicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.errorText,
  });

  final String label;

  /// Ordered value → label. Blood groups map to themselves.
  final Map<String, String> options;

  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onSelected;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasError = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: text.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: hasError ? palette.danger : palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xxs,
          children: <Widget>[
            for (final MapEntry<String, String> option in options.entries)
              ChoiceChip(
                label: Text(option.value),
                selected: selected == option.key,
                showCheckmark: false,
                onSelected: enabled
                    // Tapping the selected chip clears it: every field here is
                    // optional, and a choice nobody can undo is a trap.
                    ? (bool isSelected) =>
                          onSelected(isSelected ? option.key : null)
                    : null,
              ),
          ],
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, size: 14, color: palette.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorText!,
                  style: text.bodySmall?.copyWith(color: palette.danger),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The date of birth field: a tappable surface plus a clear button.
///
/// Not a text field: a date typed by hand is a date with a typo, and the picker
/// already enforces the same range the validator does.
class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
    this.errorText,
  });

  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;
    final bool hasError = errorText != null;
    final Color border = hasError ? palette.danger : palette.outlineStrong;
    final String display = value == null
        ? l10n.profilePickerDate
        : MaterialLocalizations.of(context).formatMediumDate(value!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.profileDobLabel.toUpperCase(),
          style: text.labelSmall?.copyWith(
            letterSpacing: 1.1,
            color: hasError ? palette.danger : palette.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Material(
          color: enabled ? palette.surface : palette.surfaceMuted,
          borderRadius: AppRadius.mdRadius,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: AppRadius.mdRadius,
            child: Container(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: value == null ? AppSpacing.md : AppSpacing.xs,
                top: AppSpacing.xs,
                bottom: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: border, width: 1.2),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.cake_outlined,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      display,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: value == null
                            ? palette.textSecondary
                            : palette.textPrimary,
                      ),
                    ),
                  ),
                  if (value == null)
                    Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: palette.textSecondary,
                    )
                  else
                    IconButton(
                      onPressed: enabled ? onClear : null,
                      tooltip: l10n.profilePickerClear,
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (hasError)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline, size: 14, color: palette.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  errorText!,
                  style: text.bodySmall?.copyWith(color: palette.danger),
                ),
              ),
            ],
          )
        else
          Text(l10n.profilePrivacyPrivateTitle, style: text.bodySmall),
      ],
    );
  }
}
