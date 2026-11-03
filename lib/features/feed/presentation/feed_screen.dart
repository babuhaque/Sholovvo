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
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';
import 'package:sholovvo_app/features/feed/presentation/compose_post_screen.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The community feed: every post, newest first, one page at a time.
///
/// **It is a page, not a tab.** The shell owns two destinations and Stage 7's
/// decision to keep it at two stands; the feed is pushed above the shell the way
/// Settings is, so it covers the bar and slides away from it. That also means it
/// starts from the first page every time it is opened, rather than resuming a
/// scroll position inside a tab the donor may have left hours ago.
///
/// **The feed itself writes nothing.** The one write in the feature belongs to
/// `ComposePostScreen`, pushed from the button below; the controller inserts the
/// published post into the list so the donor sees it without waiting for a
/// refresh. No like, no comment and no report: each is a rules decision this
/// stage does not take.
class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  /// The route the dashboard pushes.
  ///
  /// A static factory rather than a named route, matching `SettingsScreen.route`
  /// and `ProfileEditScreen.route`: a pushed screen in this app carries its own
  /// transition, and there is no route table to keep in step.
  static Route<void> route() {
    return FadeSlidePageRoute<void>(page: const FeedScreen());
  }

  /// Above this width the column widens from [narrowMaxWidth] to
  /// [wideMaxWidth]. The same 720 the dashboard and the profile use, so the
  /// three screens reflow together.
  static const double wideBreakpoint = 720;

  /// The reading measure on a phone. A feed is text, and text wider than this
  /// on a large phone forces the eye to track further than it wants to.
  static const double narrowMaxWidth = 560;

  /// The measure on a tablet or the web build, where one column of text would
  /// otherwise look like a stripe down the middle of a wide page.
  static const double wideMaxWidth = 900;

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  @override
  void initState() {
    super.initState();
    // Deferred to after the first frame: starting a read during build would
    // mutate a provider while the tree is being built. The controller's own
    // in-flight flag makes a remount harmless rather than a second paid read.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(feedControllerProvider.notifier).loadFirstPage());
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final FeedState state = ref.watch(feedControllerProvider);
    final FeedController controller = ref.read(feedControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.feedTitle)),
      // Labelled rather than a bare pencil: "Share an update" is the one thing a
      // donor comes to this screen to do besides reading, and an icon alone
      // would have to be guessed at.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            unawaited(Navigator.of(context).push(ComposePostScreen.route())),
        backgroundColor: context.palette.brandInk,
        foregroundColor: context.palette.onBrand,
        icon: const Icon(Icons.edit_outlined),
        label: Text(l10n.feedComposeAction),
      ),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= FeedScreen.wideBreakpoint;
              final double measure = wide
                  ? FeedScreen.wideMaxWidth
                  : FeedScreen.narrowMaxWidth;
              // Centring by padding rather than by a `ConstrainedBox` keeps the
              // scroll view itself as wide as the window, so a pull-to-refresh
              // can start anywhere on the page instead of only inside the
              // column.
              final double side = math.max(
                AppSpacing.gutter,
                (constraints.maxWidth - measure) / 2,
              );

              return RefreshIndicator(
                onRefresh: controller.refresh,
                color: context.palette.brandInk,
                backgroundColor: context.palette.surface,
                child: CustomScrollView(
                  // Everything except the list is short enough not to scroll,
                  // and a failed first load has to remain pullable.
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.sm,
                        side,
                        // Clears the floating button, which sits over the last
                        // card on a phone. Without it the end-of-feed sentence
                        // is readable but the post above it is not.
                        AppSpacing.huge + AppSpacing.xl,
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
  /// Written as a single function with early returns so the four states cannot
  /// be shown at once: every branch is exclusive, and the compiler makes sure
  /// the list case is the only one that reaches the posts.
  Widget _body(
    BuildContext context,
    FeedState state,
    FeedController controller,
  ) {
    final AppLocalizations l10n = context.l10n;

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
            title: l10n.feedErrorTitle,
            body: feedFailureMessage(l10n, state.failure!),
            action: SolovvoButton(
              label: l10n.feedRetry,
              onPressed: () => unawaited(controller.loadFirstPage()),
              variant: SolovvoButtonVariant.secondary,
              size: SolovvoButtonSize.medium,
              icon: Icons.refresh_rounded,
              expand: false,
            ),
          ),
        ),
      );
    }

    if (state.isEmptyResult) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: EmptyStateCard(
            icon: Icons.forum_outlined,
            title: l10n.feedEmptyTitle,
            body: l10n.feedEmptyBody,
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: <Widget>[
        // A refresh that failed leaves the posts above it on screen and says so
        // here, rather than replacing a readable list with an error page.
        if (state.failure != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: ErrorBanner(
                message: feedFailureMessage(l10n, state.failure!),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: state.posts.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: FeedPostTile(post: state.posts[index]),
          ),
        ),
        SliverToBoxAdapter(child: _footer(context, state, controller)),
      ],
    );
  }

  /// What sits under the last post: a spinner, a way to ask for more, or a
  /// sentence that says the list ended.
  Widget _footer(
    BuildContext context,
    FeedState state,
    FeedController controller,
  ) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    if (state.status == FeedStatus.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.2),
          ),
        ),
      );
    }

    if (state.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Center(
          child: SolovvoButton(
            label: l10n.feedLoadMore,
            onPressed: () => unawaited(controller.loadMore()),
            variant: SolovvoButtonVariant.secondary,
            size: SolovvoButtonSize.medium,
            icon: Icons.expand_more_rounded,
            expand: false,
          ),
        ),
      );
    }

    // Only worth saying once the donor has actually paged: a single screenful
    // that ends is obvious, and a label under it would be noise.
    if (state.posts.length <= FeedRepository.pageSize) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        l10n.feedEndOfFeed,
        textAlign: TextAlign.center,
        style: text.labelSmall,
      ),
    );
  }
}
