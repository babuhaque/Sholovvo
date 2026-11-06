import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/error/failure.dart';
import 'package:sholovvo_app/core/media/photo_picker.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/section_header.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/profile/application/profile_photo_providers.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/donation_record.dart';
import 'package:sholovvo_app/features/profile/domain/profile_photo_storage.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_edit_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_messages.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/donation_history_section.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_availability_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_completion_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_cover_banner.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_details_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_identity_card.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_photo_sheet.dart';
import 'package:sholovvo_app/features/profile/presentation/widgets/profile_privacy_card.dart';
import 'package:sholovvo_app/features/settings/presentation/settings_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The signed-in donor's own profile: what others see, what only they see, and
/// the two switches that decide it.
///
/// Only ever opened for the session's own account. There is no `uid` parameter
/// here or in [ProfileRepository]: the documents are addressed from
/// `FirebaseAuth.currentUser`, and `firestore.rules` would reject any other
/// target. Editing therefore cannot be pointed at someone else's profile even by
/// mistake.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.user});

  /// The session user, for the email and verification state, which live in the
  /// identity provider rather than in Firestore.
  final AuthUser user;

  /// Above this width the cards sit in two columns, matching the dashboard's
  /// breakpoint so the two screens reflow together.
  static const double twoColumnBreakpoint = 720;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Failure? _failure;

  /// A switch write is in flight. Both switches are disabled meanwhile so two
  /// half-applied writes cannot race each other onto the same document.
  bool _busy = false;

  /// A photo upload or removal is in flight. Tracked separately from [_busy]
  /// because only the avatar shows a spinner, but both block each other: a
  /// photo write and a switch write on the same document must not overlap.
  bool _photoBusy = false;

  /// Guards against a double tap pushing two edit forms.
  bool _editing = false;

  bool get _anyBusy => _busy || _photoBusy;

  Future<void> _openEditor(UserProfile? profile) async {
    if (_editing) {
      return;
    }
    _editing = true;
    try {
      await Navigator.of(context).push(
        FadeSlidePageRoute<void>(
          page: ProfileEditScreen(
            user: widget.user,
            // A first save starts from a draft seeded with the name the account
            // registered with, so the form is not blank while the donor's own
            // name is already known to the app.
            initial:
                profile ??
                UserProfile.draft(
                  uid: widget.user.uid,
                  displayName: widget.user.displayName,
                ),
          ),
        ),
      );
    } finally {
      _editing = false;
    }
  }

  Future<void> _setAvailability(bool isAvailable) async {
    if (_anyBusy) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    final Result<void> result = await ref
        .read(profileControllerProvider.notifier)
        .setAvailability(isAvailable);
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    result.fold(
      onSuccess: (void _) {},
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  Future<void> _setPublishArea(UserProfile profile, bool publish) async {
    if (_anyBusy) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    // Saved through the full profile write: withdrawing publication has to
    // delete the public copy of the area, and only `saveProfile` knows how to do
    // that atomically with the private flag.
    final Result<void> result = await ref
        .read(profileControllerProvider.notifier)
        .save(profile.copyWith(publishAreaInSearch: publish));
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    result.fold(
      onSuccess: (void _) {},
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  /// Opting in or out of the Donor Search directory.
  ///
  /// Also routed through the full profile write, for the same reason as
  /// [_setPublishArea]: withdrawing consent must delete the public projection
  /// of `allowDonorDiscovery`, and only `saveProfile` writes the private
  /// source of truth and the public projection atomically in the same batch.
  /// The two copies must never diverge — a private `true` sitting next to a
  /// public copy that still lists the donor would mean the UI and the
  /// directory disagree about what the donor asked for.
  Future<void> _setDiscoverable(UserProfile profile, bool value) async {
    if (_anyBusy) {
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    final Result<void> result = await ref
        .read(profileControllerProvider.notifier)
        .save(profile.copyWith(allowDonorDiscovery: value));
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    result.fold(
      onSuccess: (void _) {},
      onFailure: (Failure failure) => setState(() => _failure = failure),
    );
  }

  /// Opens the photo sheet and performs whatever the donor chose there.
  ///
  /// The work happens after the sheet has closed, so the spinner and the error
  /// banner belong to this screen rather than to a route that is going away.
  Future<void> _managePhoto(UserProfile profile) async {
    if (_anyBusy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final ProfilePhotoStorage storage = ref.read(profilePhotoStorageProvider);
    final ProfilePhotoAction? action = await ProfilePhotoSheet.show(
      context,
      hasPhoto: profile.hasPhoto,
      isConfigured: storage.isConfigured,
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ProfilePhotoAction.gallery:
      case ProfilePhotoAction.camera:
        final Result<bool> result = await _runPhoto<bool>(
          () => ref
              .read(profilePhotoControllerProvider.notifier)
              .chooseAndUpload(
                action == ProfilePhotoAction.gallery
                    ? PhotoSource.gallery
                    : PhotoSource.camera,
              ),
        );
        if (!mounted) {
          return;
        }
        // `false` means the donor closed the picker: nothing happened, so
        // nothing is confirmed to them.
        if (result.valueOrNull == true) {
          _confirm(l10n.profilePhotoUpdated);
        }
      case ProfilePhotoAction.remove:
        final bool confirmed = await _confirmPhotoRemoval();
        if (!mounted || !confirmed) {
          return;
        }
        final Result<void> result = await _runPhoto<void>(
          () => ref
              .read(profilePhotoControllerProvider.notifier)
              .remove(profile.photoUrl),
        );
        if (!mounted) {
          return;
        }
        if (result.isSuccess) {
          _confirm(l10n.profilePhotoRemoved);
        }
    }
  }

  /// Opens the cover sheet and performs whatever the donor chose there.
  ///
  /// Mirrors [_managePhoto] exactly — same sheet, same busy flag, same
  /// compensate-in-the-controller ordering — because a cover is the same kind of
  /// object in the same bucket; only the field it publishes to differs.
  Future<void> _manageCover(UserProfile profile) async {
    if (_anyBusy) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final ProfilePhotoStorage storage = ref.read(profilePhotoStorageProvider);
    final ProfilePhotoAction? action = await ProfilePhotoSheet.show(
      context,
      hasPhoto: profile.hasCover,
      isConfigured: storage.isConfigured,
      kind: ProfilePhotoKind.cover,
    );
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case ProfilePhotoAction.gallery:
      case ProfilePhotoAction.camera:
        final Result<bool> result = await _runPhoto<bool>(
          () => ref
              .read(profilePhotoControllerProvider.notifier)
              .chooseAndUploadCover(
                action == ProfilePhotoAction.gallery
                    ? PhotoSource.gallery
                    : PhotoSource.camera,
              ),
        );
        if (!mounted) {
          return;
        }
        if (result.valueOrNull == true) {
          _confirm(l10n.profileCoverUpdated);
        }
      case ProfilePhotoAction.remove:
        final bool confirmed = await _confirmCoverRemoval();
        if (!mounted || !confirmed) {
          return;
        }
        final Result<void> result = await _runPhoto<void>(
          () => ref
              .read(profilePhotoControllerProvider.notifier)
              .removeCover(profile.coverUrl),
        );
        if (!mounted) {
          return;
        }
        if (result.isSuccess) {
          _confirm(l10n.profileCoverRemoved);
        }
    }
  }

  /// Runs one photo operation with the screen's busy and error state around it.
  ///
  /// The banner is set here rather than inside the controller so that every photo
  /// failure lands in the same place as a failed switch write: one banner at the
  /// top of the screen, in the active language.
  Future<Result<T>> _runPhoto<T>(Future<Result<T>> Function() operation) async {
    setState(() {
      _photoBusy = true;
      _failure = null;
    });
    final Result<T> result = await operation();
    if (!mounted) {
      return result;
    }
    setState(() {
      _photoBusy = false;
      _failure = result.failureOrNull;
    });
    return result;
  }

  /// A second deliberate tap: removing the photo deletes the stored image, which
  /// no undo in this app can bring back.
  Future<bool> _confirmPhotoRemoval() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.profilePhotoRemoveConfirmTitle),
        content: Text(l10n.profilePhotoRemoveConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profilePhotoRemove),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// A second deliberate tap: removing the cover deletes the stored image, which
  /// no undo in this app can bring back.
  Future<bool> _confirmCoverRemoval() async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.profileCoverRemoveConfirmTitle),
        content: Text(l10n.profileCoverRemoveConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileCoverRemove),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _confirm(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<UserProfile?> profileAsync = ref.watch(profileProvider);
    final AsyncValue<Result<DonationHistory>> historyAsync = ref.watch(
      donationHistoryProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        // No back arrow: since Stage 7 this screen is a tab of the shell rather
        // than a page pushed on top of the dashboard, so there is nothing behind
        // it to go back to. Pushed screens still get theirs from the framework.
        automaticallyImplyLeading: false,
        actions: <Widget>[
          IconButton(
            onPressed: () => unawaited(
              Navigator.of(context).push(SettingsScreen.route(widget.user)),
            ),
            tooltip: l10n.settingsTitle,
            icon: const Icon(Icons.settings_outlined),
          ),
          // Creating the first profile and editing a later one are the same
          // form, so the action is enabled as soon as the screen knows whether a
          // document exists.
          TextButton(
            onPressed: profileAsync.hasValue
                ? () => unawaited(_openEditor(profileAsync.value))
                : null,
            child: Text(l10n.profileEditAction),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= ProfileScreen.twoColumnBreakpoint;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.sm,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 900 : 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (_failure != null) ...<Widget>[
                          ErrorBanner(
                            message: profileFailureMessage(l10n, _failure!),
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        _content(context, profileAsync, historyAsync, wide),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _content(
    BuildContext context,
    AsyncValue<UserProfile?> profileAsync,
    AsyncValue<Result<DonationHistory>> historyAsync,
    bool wide,
  ) {
    final AppLocalizations l10n = context.l10n;

    if (profileAsync.hasError && !profileAsync.hasValue) {
      return EmptyStateCard(
        icon: Icons.cloud_off_outlined,
        title: l10n.profileLoadErrorTitle,
        body: profileFailureMessage(
          l10n,
          mapExceptionToFailure(profileAsync.error!, profileAsync.stackTrace),
        ),
        action: TextButton(
          onPressed: () => ref.invalidate(profileProvider),
          child: Text(l10n.tryAgain),
        ),
      );
    }

    if (!profileAsync.hasValue) {
      // A thin bar rather than a full-page spinner: the app bar and the frame
      // around it are already on screen, and flashing a centred spinner for one
      // document read is more movement than the wait deserves.
      return const SolovvoCard(
        padding: EdgeInsets.all(AppSpacing.md),
        child: LinearProgressIndicator(minHeight: 3),
      );
    }

    final UserProfile? profile = profileAsync.value;
    if (profile == null) {
      return _CreateProfileCard(
        onAdd: () => unawaited(_openEditor(null)),
      );
    }

    final Widget leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ProfileIdentityCard(
          profile: profile,
          email: widget.user.email ?? l10n.notSetYet,
          isVerified: widget.user.isEmailVerified,
          onChangePhoto: () => unawaited(_managePhoto(profile)),
          isPhotoBusy: _photoBusy,
        ),
        const SizedBox(height: AppSpacing.lg),
        ProfileCompletionCard(
          profile: profile,
          onEdit: () => unawaited(_openEditor(profile)),
        ),
        const SizedBox(height: AppSpacing.lg),
        ProfileAvailabilityCard(
          isAvailable: profile.isAvailable,
          hasBloodGroup: BloodGroups.isKnown(profile.bloodGroup),
          isBusy: _anyBusy,
          onChanged: (bool value) => unawaited(_setAvailability(value)),
        ),
      ],
    );

    final Widget rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(
          title: l10n.profileSectionDetails,
          action: TextButton(
            onPressed: () => unawaited(_openEditor(profile)),
            child: Text(l10n.profileEditAction),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        ProfileDetailsCard(profile: profile, email: widget.user.email ?? ''),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: l10n.profileSectionPrivacy),
        const SizedBox(height: AppSpacing.xs),
        ProfilePrivacyCard(
          discoverable: profile.allowDonorDiscovery,
          publishArea: profile.publishAreaInSearch,
          hasArea: (profile.area ?? '').trim().isNotEmpty,
          isBusy: _anyBusy,
          onDiscoverableChanged: (bool value) =>
              unawaited(_setDiscoverable(profile, value)),
          onChanged: (bool value) => unawaited(_setPublishArea(profile, value)),
        ),
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: l10n.profileSectionHistory),
        const SizedBox(height: AppSpacing.xs),
        DonationHistorySection(
          history: historyAsync,
          onRetry: () => ref.invalidate(donationHistoryProvider),
        ),
      ],
    );

    // The cover spans the full content width above the columns in both layouts:
    // it is the banner the whole profile sits under, not a card in one column.
    final Widget cover = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ProfileCoverBanner(
          hasCover: profile.hasCover,
          coverUrl: profile.coverUrl,
          onChanged: () => unawaited(_manageCover(profile)),
          isBusy: _photoBusy,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          cover,
          leftColumn,
          const SizedBox(height: AppSpacing.xl),
          rightColumn,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        cover,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: leftColumn),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: rightColumn),
          ],
        ),
      ],
    );
  }
}

/// Shown when the account has no profile document at all.
///
/// Not an empty card with dashes: there is genuinely nothing to show yet, and the
/// one useful thing here is the way to create it.
class _CreateProfileCard extends StatelessWidget {
  const _CreateProfileCard({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final SolovvoPalette palette = context.palette;
    final TextTheme text = Theme.of(context).textTheme;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.person_add_alt_1_outlined,
                size: 22,
                color: palette.brandInk,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(l10n.profileNotSetCtaTitle, style: text.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.profileNotSetCtaBody, style: text.bodySmall),
          const SizedBox(height: AppSpacing.lg),
          SolovvoButton(
            label: l10n.profileAddDetails,
            icon: Icons.edit_outlined,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}
