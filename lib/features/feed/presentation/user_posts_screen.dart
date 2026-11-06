import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/empty_state_card.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/initials_avatar.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/application/user_posts_providers.dart';
import 'package:sholovvo_app/features/feed/domain/entities/post.dart';
import 'package:sholovvo_app/features/feed/domain/feed_repository.dart';
import 'package:sholovvo_app/features/feed/presentation/comment_sheet.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/features/feed/presentation/report_sheet.dart';
import 'package:sholovvo_app/features/feed/presentation/widgets/feed_post_tile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// One author's posts, newest first — what tapping a name in the feed opens.
///
/// **Why a fresh controller per open.** The author uid is handed to
/// [UserPostsController.open] from the first frame, and the controller is an
/// autoDispose provider: popping the wall drops its instance, so opening
/// another author starts with a clean list, cursor, and liked set rather than
/// inheriting the previous one. That is what makes the screen safe to push
/// repeatedly without a route-keyed family provider.
///
/// **A view, not a second feed.** Same [FeedPostTile], same derived-count
/// hydration, same optimistic likes — but no compose button and no saved
/// filter, because those describe the community, not one person's wall.
class UserPostsScreen extends ConsumerStatefulWidget {
  const UserPostsScreen({
    super.key,
    required this.authorUid,
    required this.authorName,
  });

  /// The stable identity the wall filters by. Passed to [UserPostsController.open].
  final String authorUid;

  /// The author whose wall this is. Carried for the header only; the controller
  /// filters by [authorUid], which is what a name can't be relied on to be.
  final String authorName;

  /// Pushes the author's wall. A static factory like every other pushed screen
  /// here; the transition travels with the page and there is no route table to
  /// keep in step.
  static Route<void> route({
    required String authorUid,
    required String authorName,
  }) {
    return FadeSlidePageRoute<void>(
      page: UserPostsScreen(authorUid: authorUid, authorName: authorName),
    );
  }

  static const double wideBreakpoint = 720;
  static const double narrowMaxWidth = 560;
  static const double wideMaxWidth = 900;

  @override
  ConsumerState<UserPostsScreen> createState() => _UserPostsScreenState();
}

class _UserPostsScreenState extends ConsumerState<UserPostsScreen> {
  late final ScrollController _scrollController;

  static const double _paginationThreshold = 300;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref.read(userPostsControllerProvider.notifier).open(widget.authorUid),
      );
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final double maxExtent = _scrollController.position.maxScrollExtent;
    if (_scrollController.position.pixels >= maxExtent - _paginationThreshold) {
      final FeedState feedState = ref.read(userPostsControllerProvider);
      if (feedState.hasMore &&
          feedState.status != FeedStatus.loadingMore &&
          feedState.status != FeedStatus.loading) {
        unawaited(ref.read(userPostsControllerProvider.notifier).loadMore());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FeedState state = ref.watch(userPostsControllerProvider);
    final UserPostsController controller = ref.read(
      userPostsControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            InitialsAvatar(name: widget.authorName, size: 30),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                widget.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= UserPostsScreen.wideBreakpoint;
              final double measure = wide
                  ? UserPostsScreen.wideMaxWidth
                  : UserPostsScreen.narrowMaxWidth;
              final double side = math.max(
                AppSpacing.gutter,
                (constraints.maxWidth - measure) / 2,
              );

              return RefreshIndicator(
                onRefresh: controller.refresh,
                color: Theme.of(context).colorScheme.primary,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        side,
                        AppSpacing.sm,
                        side,
                        AppSpacing.xl,
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

  Widget _body(
    BuildContext context,
    FeedState state,
    UserPostsController controller,
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
            title: l10n.userPostsEmptyTitle,
            body: l10n.userPostsEmptyBody,
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
                message: feedFailureMessage(l10n, state.failure!),
              ),
            ),
          ),
        SliverList.builder(
          itemCount: state.posts.length,
          itemBuilder: (BuildContext context, int index) {
            final Post post = state.posts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: FeedPostTile(
                post: post,
                isLiked: state.likedPostIds.contains(post.id),
                onLikeToggle: () {
                  final String? uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    unawaited(controller.toggleLike(post.id, uid));
                  }
                },
                onCommentTap: () =>
                    unawaited(CommentSheet.show(context, post.id)),
                onReportTap: () => unawaited(
                  ReportSheet.show(
                    context,
                    targetId: post.id,
                    targetAuthorUid: post.authorUid,
                  ),
                ),
                isSaved: state.savedPostIds.contains(post.id),
                onSaveToggle: () => controller.toggleSave(post.id),
                // No author tap here: this screen already IS the author, so the
                // header stays a plain label rather than a self-link.
              ),
            );
          },
        ),
        if (state.skipped > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                l10n.feedSkippedNotice(state.skipped),
                textAlign: TextAlign.center,
                style: text.labelSmall,
              ),
            ),
          ),
        SliverToBoxAdapter(child: _footer(context, state, controller)),
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    FeedState state,
    UserPostsController controller,
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
