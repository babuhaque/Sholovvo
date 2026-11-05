import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/core/logging/app_logger.dart';
import 'package:sholovvo_app/core/result/result.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_group_badge.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/presentation/edit_request_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/request_contact_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_messages.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One blood request, shown in full, with owner (edit/cancel) and donor
/// (accept) affordances gated at the client the same way the rules gate
/// the writes at the server.
///
/// **Why this screen exists now and not sooner.** Stage 9.1 shipped the list and
/// pinned, in its own widget test, that a `RequestTile` has no tap target —
/// because a chevron on a row that goes nowhere is a promise the app cannot
/// keep. Stage 14's accept/claim path is the last transaction this screen was
/// waiting for: the rule at `firestore.rules` L147-150 permits an eligible
/// donor to transition `open → accepted` with a single document write, and
/// this screen now carries that button for exactly that audience.
///
/// **What it deliberately does not show.** No patient name, no phone number, no
/// street address, no notes. As of Stage 9.5 (M3-C1) those fields live in
/// `blood_requests/{id}/private/contact`, gated at the rules layer so a public
/// read never carries them. This screen reads [BloodRequest], which is that
/// public projection — the fields are absent by construction, not by omission
/// here.
///
/// **Three audiences.**
///
/// - The **owner** (`uid == request.userId`) sees Edit, Contact and Cancel.
/// - An **eligible donor** (signed-in, not the owner, has a profile with
///   `isAvailable == true` and a matching `bloodGroup`) sees Accept.
/// - Everyone else (anonymous browse, no profile, mismatched group, or
///   unavailable) sees neither. The footer note says what is not available
///   in this build (contacting), which is true for every audience.
///
/// The eligibility gate mirrors the rules' precondition (L157-160) exactly:
/// the rules check `role == 'donor'`, `isAvailable == true`, and
/// `bloodGroup == resource.data.bloodGroup`; the client reads the same three
/// from `profileProvider` (which streams the `users/{uid}` document the
/// profile-edit screen writes, and whose `publicFields` always carry
/// `role: 'donor'`). A race where another donor claims first still fails at
/// the rules layer with a `permission-denied` or `aborted` exception, and the
/// user sees an error SnackBar rather than a silent overwrite.
///
/// **Route contract.** [RequestDetailScreen.route] is a `Route<String?>` so a
/// successful accept, edit, or cancel can pop with the request id. Callers
/// refresh their list when the pop returns non-null.
class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final BloodRequest request;

  /// The route a tappable `RequestTile` pushes.
  ///
  /// Same shape as `RequestsScreen.route` and `FeedScreen.route`: a static
  /// factory rather than a named route, so the transition travels with the
  /// screen and there is no route table to keep in step. The `<String?>` type
  /// is the pop-time sentinel described above.
  static Route<String?> route(BloodRequest request) {
    return FadeSlidePageRoute<String?>(
      page: RequestDetailScreen(request: request),
    );
  }

  /// The reading measure on a phone.
  static const double narrowMaxWidth = 560;

  /// The measure on a tablet or the web build.
  static const double wideBreakpoint = 720;

  /// The measure on the web build.
  static const double wideMaxWidth = 720;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  static const AppLogger _logger = AppLogger('requests.cancel');

  /// Whether a cancel write is in flight. Drives the button's `isLoading` and
  /// disables the confirmation dialog's "Yes" from turning into a second write
  /// when the user taps twice.
  bool _cancelling = false;

  /// Whether an accept write is in flight. Same double-tap guard as
  /// [_cancelling]; the two are separate fields because they are
  /// mutually exclusive audiences (the owner cannot accept, a donor cannot
  /// cancel) and a shared flag would imply the two buttons could coexist.
  bool _accepting = false;

  /// Pushes [EditRequestScreen] and bubbles a successful edit's sentinel up
  /// one more level.
  ///
  /// Same shape as the cancel pop: a caller list sees a non-null `String?`
  /// when the detail route closes and refreshes. Bubbling is what makes the
  /// caller's view correct — the entity this screen has been showing is
  /// stale the moment Firestore writes, and re-fetching by id would need a
  /// repository method that does not exist and a second window nobody asked
  /// for. Backing out to the caller is the honest answer.
  ///
  /// A failed edit never reaches here: [EditRequestScreen] shows its own
  /// validation error and stays open, so the await resolves only when the
  /// write succeeded or the user cancelled the form with the system back
  /// button (which returns null).
  Future<void> _onEditPressed() async {
    final String? editedId = await Navigator.of(
      context,
    ).push<String?>(EditRequestScreen.route(widget.request));
    if (editedId != null && mounted) {
      Navigator.of(context).pop<String>(editedId);
    }
  }

  /// Pushes [RequestContactScreen] and bubbles a successful capture's sentinel
  /// up one more level, exactly as [_onEditPressed] does.
  ///
  /// The owner's private-contact capture (`blood_requests/{id}/private/contact`) —
  /// the write `firestore.rules` L219-228 permits for the owner and nothing else.
  /// A contact save leaves the public projection untouched, so a refresh is not
  /// strictly needed, but the route shares the owner actions' single pop contract
  /// for consistency.
  Future<void> _onContactPressed() async {
    final String? contactId = await Navigator.of(
      context,
    ).push<String?>(RequestContactScreen.route(widget.request));
    if (contactId != null && mounted) {
      Navigator.of(context).pop<String>(contactId);
    }
  }

  Future<void> _onCancelPressed() async {
    if (_cancelling) {
      return;
    }
    // Capture l10n and ScaffoldMessenger before any await, so a
    // use_build_context_synchronously warning does not fire and so the
    // messages we surface stay tied to the locale the user was reading when
    // they tapped the button, not whatever locale a hot-reload might switch to
    // during the write.
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations local = dialogContext.l10n;
        return AlertDialog(
          title: Text(local.requestsCancelConfirmTitle),
          content: Text(local.requestsCancelConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop<bool>(false),
              child: Text(local.requestsCancelConfirmNo),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop<bool>(true),
              child: Text(local.requestsCancelConfirmYes),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _cancelling = true);

    final Result<void> result = await ref
        .read(requestCancelServiceProvider)
        .cancelRequest(requestId: widget.request.id);

    if (!mounted) {
      return;
    }
    setState(() => _cancelling = false);

    switch (result) {
      case Success<void>():
        // The pop-time sentinel; callers refresh their list when non-null.
        Navigator.of(context).pop<String>(widget.request.id);
      case FailureResult<void>():
        // Failure is logged once, surfaced as a SnackBar, and the user stays
        // on the detail screen — the request is still open (nothing changed),
        // and closing the screen here would look like the cancel succeeded.
        _logger.warning(
          'Cancel failed for request ${widget.request.id}',
        );
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.requestsCancelError),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Future<void> _onAcceptPressed(String? uid) async {
    if (_accepting || uid == null) {
      return;
    }
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final AppLocalizations local = dialogContext.l10n;
        return AlertDialog(
          title: Text(local.requestsAcceptConfirmTitle),
          content: Text(local.requestsAcceptConfirmBody),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop<bool>(false),
              child: Text(local.requestsAcceptConfirmNo),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop<bool>(true),
              child: Text(local.requestsAcceptConfirmYes),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _accepting = true);

    final Result<void> result = await ref
        .read(requestAcceptServiceProvider)
        .acceptRequest(requestId: widget.request.id, donorUid: uid);

    if (!mounted) {
      return;
    }
    setState(() => _accepting = false);

    switch (result) {
      case Success<void>():
        Navigator.of(context).pop<String>(widget.request.id);
      case FailureResult<void>():
        _logger.warning(
          'Accept failed for request ${widget.request.id}',
        );
        messenger?.showSnackBar(
          SnackBar(
            content: Text(l10n.requestsAcceptError),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    // Whether the signed-in account is the one that raised this request. Null
    // from the provider means either no Firebase app or no signed-in user;
    // both produce `isMine == false`, which is the safe default in tests and
    // in an anonymous browse.
    final String? currentUid = ref.watch(requestsAuthUidProvider);
    final bool isMine = currentUid != null && currentUid == widget.request.userId;

    // Whether the signed-in account is an eligible donor for this request.
    // Mirrors the rules' precondition at L157-160: the caller's `users/{uid}`
    // doc must carry `isAvailable == true` and a `bloodGroup` that matches.
    // `role == 'donor'` is also checked by the rules, but the app always
    // writes it (see `ProfileDocuments.publicFields`), so a profile that
    // exists has the role. The profile stream may still be loading; in that
    // case `canAccept` is false, which is the safe default (a donor sees the
    // button one frame later rather than tapping a write that is about to
    // fail).
    final UserProfile? profile = ref.watch(profileProvider).value;
    final bool canAccept = !isMine &&
        currentUid != null &&
        profile != null &&
        profile.isAvailable &&
        profile.bloodGroup == widget.request.bloodGroup;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsDetailTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= RequestDetailScreen.wideBreakpoint;
              final double measure = wide
                  ? RequestDetailScreen.wideMaxWidth
                  : RequestDetailScreen.narrowMaxWidth;
              final double side = wide
                  ? (constraints.maxWidth - measure) / 2
                  : AppSpacing.gutter;

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  side,
                  AppSpacing.md,
                  side,
                  AppSpacing.xxl,
                ),
                children: <Widget>[
                  // The badge carries the group; the row under it is the
                  // hospital, in the same voice as the list row so a donor who
                  // opened here from a row recognises the request immediately.
                  SolovvoCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        BloodGroupBadge(
                          bloodGroup: widget.request.bloodGroup,
                          variant: BloodGroupBadgeVariant.square,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.request.bloodGroup,
                                style: text.titleLarge,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.request.hospitalName,
                                style: text.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DetailField(
                    label: l10n.requestsBags,
                    value: l10n.homeUnitsNeeded(widget.request.units),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailField(
                    label: l10n.requestsHospital,
                    value: widget.request.hospitalName,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _DetailField(
                    label: l10n.requestsDate,
                    value: requestsNeededByLabel(context, widget.request),
                  ),
                  // The donor's accept affordance. Mutually exclusive with
                  // the owner's branch: `canAccept` is false when `isMine` is
                  // true (a person cannot accept their own request), so the
                  // two sets of buttons never coexist.
                  if (canAccept) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    SolovvoButton(
                      label: l10n.requestsAcceptAction,
                      onPressed: _accepting ? null : () => _onAcceptPressed(currentUid),
                      isLoading: _accepting,
                      variant: SolovvoButtonVariant.primary,
                      size: SolovvoButtonSize.large,
                      icon: Icons.favorite_rounded,
                      expand: false,
                    ),
                  ],
                  // The owner's affordance. Nothing here is a Stage-10
                  // transaction — accepting, claiming, and a donor *reading*
                  // the contact all still require `request_responses` and
                  // `response_claims` writes the app does not yet make (and the
                  // M3-C2 blocker keeps the donor read closed) — but withdrawing
                  // one's own open request and recording one's own contact are
                  // available now because the rules allow them and the create
                  // flow makes the request reachable. The Contact button is the
                  // owner *writing* their private record, not a stranger reading
                  // it: no one else can see what this form stores yet.
                  if (isMine) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    SolovvoButton(
                      label: l10n.requestsEditAction,
                      onPressed: _cancelling ? null : _onEditPressed,
                      variant: SolovvoButtonVariant.secondary,
                      size: SolovvoButtonSize.medium,
                      icon: Icons.edit_outlined,
                      expand: false,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SolovvoButton(
                      label: l10n.requestsContactAction,
                      onPressed: _cancelling ? null : _onContactPressed,
                      variant: SolovvoButtonVariant.secondary,
                      size: SolovvoButtonSize.medium,
                      icon: Icons.contact_page_outlined,
                      expand: false,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SolovvoButton(
                      label: l10n.requestsCancelAction,
                      onPressed: _cancelling ? null : _onCancelPressed,
                      isLoading: _cancelling,
                      variant: SolovvoButtonVariant.secondary,
                      size: SolovvoButtonSize.medium,
                      icon: Icons.close_rounded,
                      expand: false,
                    ),
                  ],
                  // The two things this screen is not. It is not the list's
                  // footer verbatim — the row on the list said "This list"; a
                  // detail page has to say what it itself is — and it is not
                  // the Stage 10 transaction surface. For an owner who can
                  // cancel, the note still holds in the accept/claim sense;
                  // for a stranger, the sentence describes exactly what they
                  // are looking at.
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Text(
                      l10n.requestsDetailNoActionNote,
                      textAlign: TextAlign.center,
                      style: text.labelSmall,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One labelled value in the detail list.
///
/// Deliberately not a form field: this is a read, and a `SolovvoTextField`
/// disabled into display would carry the visual grammar of an input the donor
/// cannot use. The label sits above the value in `labelSmall`, and the value
/// below in `bodyLarge`, so the pair reads as data rather than as a form row.
class _DetailField extends StatelessWidget {
  const _DetailField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: text.labelSmall),
        const SizedBox(height: 2),
        Text(value, style: text.bodyLarge),
      ],
    );
  }
}
