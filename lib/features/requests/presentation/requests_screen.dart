import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_palette.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/application/requests_state.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_messages.dart';
import 'package:sholovvo_app/features/requests/presentation/widgets/request_tile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Every open blood request this build can read, soonest needed first.
///
/// **It is a page, not a tab.** Like the feed and Settings, it is pushed above the
/// shell rather than added to it: the shell owns two destinations and that decision
/// stands. It therefore starts from a fresh read every time it opens, which is also
/// the right behaviour for a list whose contents change when somebody claims a
/// request.
///
/// **This screen writes nothing.** It reads `blood_requests` and shows what is
/// needed, where, and by when. Accepting a request is Stage 10's transaction —
/// `request_responses`, `response_claims` and the donor branch of the request update
/// rule, which `firestore.rules` already enforces — and there is no button for it
/// here, only the sentence below the list that says it is not in this build. A
/// screen that looked actionable but was not would be worse than one that says what
/// it can do.
///
/// **There is no "Load more".** The read is a window, not a page
/// ([OpenRequests] and [RequestRepository.window] explain why an unordered window
/// cannot be paged without an index nobody has deployed), so the honest control is
/// pull-to-refresh and the honest notice is [RequestsState.truncated].
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  /// The route the dashboard pushes.
  ///
  /// A static factory rather than a named route, matching `FeedScreen.route` and
  /// `SettingsScreen.route`: a pushed screen in this app carries its own transition,
  /// and there is no route table to keep in step.
  static Route<void> route() {
    return FadeSlidePageRoute<void>(page: const RequestsScreen());
  }

  /// The same 720 the dashboard, the feed and the profile reflow at.
  static const double wideBreakpoint = 720;

  /// The reading measure on a phone.
  static const double narrowMaxWidth = 560;

  /// The measure on a tablet or the web build.
  static const double wideMaxWidth = 900;

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: starting a read during build would mutate
    // a provider while the tree is being built. The controller's own in-flight flag
    // makes a remount harmless rather than a second paid read.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(requestsControllerProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RequestsState state = ref.watch(requestsControllerProvider);
    final RequestsController controller = ref.read(
      requestsControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= RequestsScreen.wideBreakpoint;
              final double measure = wide
                  ? RequestsScreen.wideMaxWidth
                  : RequestsScreen.narrowMaxWidth;
              // Centring by padding rather than by a `ConstrainedBox` keeps the
              // scroll view as wide as the window, so a pull-to-refresh can start
              // anywhere on the page instead of only inside the column.
              final double side = math.max(
                AppSpacing.gutter,
                (constraints.maxWidth - measure) / 2,
              );

              return RefreshIndicator(
                onRefresh: controller.refresh,
                color: context.palette.brandInk,
                backgroundColor: context.palette.surface,
                child: CustomScrollView(
                  // A failed read has to remain pullable, and a short list should
                  // still be draggable enough to refresh.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.sm,
                        side,
                        AppSpacing.xxl,
                      ),
                      sliver: _body(context, state, controller),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// The one sliver the page is made of, decided by the state.
  ///
  /// Written as a single function with early returns so the states cannot be shown
  /// at once. [RequestsState.isUnreadableResult] comes before
  /// [RequestsState.isEmptyResult] even though the two getters are mutually
  /// exclusive by construction: the order is what makes the argument visible to a
  /// reader, and it is the order the feed's section uses.
  Widget _body(
    BuildContext context,
    RequestsState state,
    RequestsController controller,
  ) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    if (state.isInitialLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.isFatalError) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: EmptyStateCard(
            icon: Icons.cloud_off_rounded,
            title: l10n.requestsErrorTitle,
            body: requestsFailureMessage(l10n, state.failure!),
            action: SolovvoButton(
              label: l10n.requestsRetry,
              onPressed: () => unawaited(controller.load()),
              variant: SolovvoButtonVariant.secondary,
              size: SolovvoButtonSize.medium,
              icon: Icons.refresh_rounded,
              expand: false,
            ),
          ),
        ),
      );
    }

    if (state.isUnreadableResult) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: EmptyStateCard(
            icon: Icons.cloud_off_rounded,
            title: l10n.requestsUnreadableTitle,
            body: state.skipped > 0
                ? l10n.requestsSkippedNotice(state.skipped)
                : l10n.requestsUnreadableBody,
            // Deliberately no button. A retry would re-ask the same window and earn
            // the same documents, which is a control that cannot work; what might
            // change is the *order* the window fills in, and pull-to-refresh above
            // this card is the honest way to ask again. The feed's dashboard section
            // makes the same argument for the same reason.
          ),
        ),
      );
    }

    if (state.isEmptyResult) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: EmptyStateCard(
            icon: Icons.water_drop_outlined,
            title: l10n.requestsEmptyTitle,
            body: l10n.requestsEmptyBody,
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: <Widget>[
        // A refresh that failed leaves the requests above it on screen and says so
        // here, rather than replacing a readable list with an error page.
        if (state.failure != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ErrorBanner(
                message: requestsFailureMessage(l10n, state.failure!),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: state.requests.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: RequestTile(request: state.requests[index]),
          ),
        ),
        // The two things this list is not, said separately because they are
        // different sentences: documents the app could not read, and documents it
        // never looked at. Neither is a failure — the list above is real — and
        // neither is silence, because a donor who thinks they have seen everything
        // stops looking.
        if (state.skipped > 0 || state.truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Column(
                children: <Widget>[
                  if (state.skipped > 0)
                    Text(
                      l10n.requestsSkippedNotice(state.skipped),
                      textAlign: TextAlign.center,
                      style: text.labelSmall,
                    ),
                  if (state.truncated)
                    Text(
                      l10n.requestsTruncatedNotice(RequestRepository.window),
                      textAlign: TextAlign.center,
                      style: text.labelSmall,
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(child: _footer(context)),
      ],
    );
  }

  /// Why the list has no button on it. Said once, in the same quiet register as the
  /// notices above it, so a donor who came here expecting to tap "yes" is told the
  /// truth rather than hunting for a control that is not there.
  Widget _footer(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        l10n.requestsNoActionNote,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}
