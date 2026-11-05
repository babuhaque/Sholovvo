import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/requests/application/requests_providers.dart';
import 'package:sholovvo_app/features/requests/application/requests_state.dart';
import 'package:sholovvo_app/features/requests/domain/entities/blood_request.dart';
import 'package:sholovvo_app/features/requests/domain/request_repository.dart';
import 'package:sholovvo_app/features/requests/presentation/request_detail_screen.dart';
import 'package:sholovvo_app/features/requests/presentation/requests_messages.dart';
import 'package:sholovvo_app/features/requests/presentation/widgets/request_tile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Every open request the signed-in account raised, with the same per-row
/// destination the list has (tap → detail → cancel).
///
/// **Why a screen for what is already in [RequestsScreen].** The all-requests
/// list answers "who needs blood". This one answers "what did I ask for",
/// which is a different question and needs a different empty state, a
/// different retry path, and a place a donor returns to after closing the
/// app. Both screens read the same underlying window through
/// [requestsControllerProvider]; the projection lives on
/// [myOpenRequestsProvider] so the two never disagree about what is open.
///
/// **What this stage does not do.** It does not show closed requests — the
/// window the repository reads is filtered to `status == 'open'` at the
/// database layer, and pulling history in would need a second query and a
/// second repository method. A cancelled request therefore disappears from
/// this list as soon as it disappears from the all-requests list, which is
/// honest about the current build and a natural next stage.
class MyRequestsScreen extends ConsumerStatefulWidget {
  const MyRequestsScreen({super.key});

  /// The route a caller pushes.
  ///
  /// A static factory like every other pushed screen here, matching
  /// `RequestsScreen.route` and `FeedScreen.route`; the transition travels
  /// with the page and there is no route table to keep in step.
  static Route<void> route() {
    return FadeSlidePageRoute<void>(page: const MyRequestsScreen());
  }

  /// Same 720 the dashboard, the feed and the requests list reflow at.
  static const double wideBreakpoint = 720;

  /// The reading measure on a phone.
  static const double narrowMaxWidth = 560;

  /// The measure on a tablet or the web build.
  static const double wideMaxWidth = 900;

  @override
  ConsumerState<MyRequestsScreen> createState() => _MyRequestsScreenState();
}

class _MyRequestsScreenState extends ConsumerState<MyRequestsScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame so no provider is mutated while the
    // tree is being built. The `loaded` check mirrors the dashboard's: this
    // screen is entered from the all-requests list, which has already read
    // the window, and a second read on entry would pay for the same data a
    // moment after receiving it. Pull-to-refresh is how a re-read is asked
    // for deliberately.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      if (ref.read(requestsControllerProvider).loaded) {
        return;
      }
      unawaited(ref.read(requestsControllerProvider.notifier).load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final RequestsState state = ref.watch(requestsControllerProvider);
    final List<BloodRequest> mine = ref.watch(myOpenRequestsProvider);
    final RequestsController controller = ref.read(
      requestsControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.requestsMyTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= MyRequestsScreen.wideBreakpoint;
              final double measure = wide
                  ? MyRequestsScreen.wideMaxWidth
                  : MyRequestsScreen.narrowMaxWidth;
              final double side = math.max(
                AppSpacing.gutter,
                (constraints.maxWidth - measure) / 2,
              );

              return RefreshIndicator(
                onRefresh: controller.refresh,
                color: Theme.of(context).colorScheme.primary,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.sm,
                        side,
                        AppSpacing.xxl,
                      ),
                      sliver: _body(context, state, mine, controller),
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

  /// The one sliver, decided by the underlying state and then by the filtered
  /// list.
  ///
  /// The order matters. A fatal read is a fact about the whole window and
  /// outranks an empty projection; an initial load is a spinner regardless of
  /// whether the projected list has anything in it yet; a projection with
  /// content shows the tiles whether or not the underlying window is
  /// truncated; and only after all three does "empty" get its own card. The
  /// all-requests screen makes the same argument in the same order.
  Widget _body(
    BuildContext context,
    RequestsState state,
    List<BloodRequest> mine,
    RequestsController controller,
  ) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

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

    if (state.isInitialLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (mine.isEmpty && state.loaded) {
      // Reachable only when a full window has come back and none of the
      // requests in it were raised by this account. If the uid provider is
      // null the projection is empty for a different reason (nobody to
      // match against), which is not a state the app can actually land on
      // here because the auth gate prevents an anonymous read. The
      // `state.loaded` guard means "we did ask and got an answer" — a
      // screen entered before any read resolves would show this card too
      // eagerly otherwise.
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: EmptyStateCard(
            icon: Icons.person_outline_rounded,
            title: l10n.requestsMyEmptyTitle,
            body: l10n.requestsMyEmptyBody,
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: <Widget>[
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
          itemCount: mine.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: RequestTile(
              request: mine[index],
              onTap: () async {
                final String? cancelledId = await Navigator.of(
                  context,
                ).push<String?>(
                  RequestDetailScreen.route(mine[index]),
                );
                if (cancelledId != null && mounted) {
                  unawaited(
                    ref.read(requestsControllerProvider.notifier).refresh(),
                  );
                }
              },
            ),
          ),
        ),
        // The window truncation belongs to the shared underlying read, not
        // to this projection, so the copy is the shared one and the notice
        // is only truthful about the window it was measured on. A "mine"
        // that fell outside the top-25 is invisible here for exactly the
        // reason the all-requests screen says it is invisible there.
        if (state.truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                l10n.requestsTruncatedNotice(RequestRepository.window),
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
            ),
          ),
      ],
    );
  }
}
