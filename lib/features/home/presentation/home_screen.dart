import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/error_banner.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/design/widgets/solovvo_button.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/feed/application/feed_providers.dart';
import 'package:sholovvo_app/features/feed/application/feed_state.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_messages.dart';
import 'package:sholovvo_app/features/feed/presentation/feed_screen.dart';
import 'package:sholovvo_app/features/home/application/home_providers.dart';
import 'package:sholovvo_app/features/home/domain/home_dashboard.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/donor_status_card.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_cards.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_header.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:sholovvo_app/features/home/presentation/widgets/home_section.dart';
import 'package:sholovvo_app/features/profile/application/profile_providers.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Where a verified, signed-in donor lands: their status, the two things they
/// came to do, and the two streams that will fill in as the app grows.
///
/// The donor strip and the header read the profile the donor edits in Stage 5,
/// and the community preview reads the feed Stage 8 built. The nearby requests
/// stay empty until their own stage. Every section says what it does not have in
/// its own words rather than showing a zero, a spinner or a sample row.
///
/// Since Stage 7 this is one tab of the app shell rather than the whole
/// signed-in surface, so it no longer owns a `Scaffold`, a sign-out button or
/// the push to the profile — the shell owns all three.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.onOpenProfile,
  });

  final AuthUser user;

  /// Supplied by the shell, which owns which tab is showing.
  ///
  /// Required rather than optional so a host that forgets to wire it cannot
  /// ship a header button that silently does nothing.
  final VoidCallback onOpenProfile;

  /// Above this width the two list sections sit side by side instead of
  /// stacking, which is what makes the dashboard worth opening on a tablet or
  /// the web build rather than a phone layout stretched thin.
  static const double twoColumnBreakpoint = 720;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // The community preview is the dashboard's only live read, and it is asked
    // for the way the feed screen asks: after the first frame, so no provider is
    // mutated while the tree is being built, and through the feed's own
    // controller rather than a second query. A donor who lands here and never
    // taps anything still sees what the community is saying.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      // Skipped once a page has been read in this session. The dashboard is
      // covered and uncovered every time a pushed screen opens and closes, so
      // without this a donor who walks into the feed and back would pay for the
      // same preview twice — and the state it is about to show is still on
      // screen. Pull-to-refresh on the feed is how a page is deliberately
      // re-read.
      if (ref.read(feedControllerProvider).loaded) {
        return;
      }
      unawaited(ref.read(feedControllerProvider.notifier).loadFirstPage());
    });
  }

  /// The one way into the feed, from every control in the community section that
  /// deserves one: a preview card, "See all", and the empty card's action.
  ///
  /// Not a per-post destination, because there is no per-post screen — the feed
  /// shows the whole list newest first, and the tapped post is in it.
  void _openFeed() {
    unawaited(Navigator.of(context).push(FeedScreen.route()));
  }

  /// The honest response for an action whose screen does not exist yet.
  ///
  /// A disabled button would read as a bug and a fake screen would be a lie, so
  /// the tap confirms it registered and says the feature is still coming.
  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.homeComingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final AuthUser user = widget.user;

    // The profile is the name the donor chose; the session name is only the
    // fallback for an account that has not created one yet.
    final UserProfile? profile = ref.watch(profileProvider).value;
    final String profileName = profile?.displayName.trim() ?? '';
    final String greetingName = profileName.isEmpty
        ? user.shortName
        : profileName.split(RegExp(r'\s+')).first;

    final DonorSnapshot? donor = ref.watch(donorSnapshotProvider);
    final List<NearbyRequestSummary> requests = ref.watch(
      nearbyRequestsProvider,
    );
    final List<FeedPostPreview> feed = ref.watch(feedPreviewProvider);

    final Widget requestsSection = _RequestsSection(
      requests: requests,
      onComingSoon: _comingSoon,
    );
    final Widget feedSection = _FeedSection(
      posts: feed,
      feed: ref.watch(feedControllerProvider),
      // The community preview is the dashboard's way into the feed, so every
      // control in this section opens that page rather than reporting "Coming
      // soon" about a feature that exists.
      onOpenFeed: _openFeed,
      onRetry: () =>
          unawaited(ref.read(feedControllerProvider.notifier).loadFirstPage()),
    );

    // The header's avatar is an `InkWell`, which needs a `Material` ancestor.
    // The shell's `Scaffold` provides one in the app, but this screen also gets
    // mounted on its own by tests, and a transparent material adds the ancestor
    // without painting over the glow below it.
    return Material(
      type: MaterialType.transparency,
      child: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= HomeScreen.twoColumnBreakpoint;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.gutter,
                  AppSpacing.lg,
                  AppSpacing.gutter,
                  AppSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 900 : 560),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        HomeHeader(
                          profile: profile,
                          onProfileTap: widget.onOpenProfile,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (user.isEmailVerified) ...<Widget>[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: VerifiedChip(),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        Text(
                          l10n.homeGreeting(greetingName),
                          style: text.displaySmall?.copyWith(fontSize: 30),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          l10n.homeDashboardSubtitle,
                          style: text.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        DonorStatusCard(donor: donor),
                        const SizedBox(height: AppSpacing.lg),
                        HomeQuickActions(
                          onRequestBlood: _comingSoon,
                          onFindDonors: _comingSoon,
                          isWide: wide,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        if (wide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(child: requestsSection),
                              const SizedBox(width: AppSpacing.xl),
                              Expanded(child: feedSection),
                            ],
                          )
                        else ...<Widget>[
                          requestsSection,
                          const SizedBox(height: AppSpacing.xl),
                          feedSection,
                        ],
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
}

/// Nearby requests: rows when there are any, one honest empty card when not.
class _RequestsSection extends StatelessWidget {
  const _RequestsSection({required this.requests, required this.onComingSoon});

  final List<NearbyRequestSummary> requests;
  final VoidCallback onComingSoon;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeSectionHeader(
          title: l10n.homeNearbyTitle,
          // No "See all" over an empty list: it would be a link to nothing.
          action: requests.isEmpty
              ? null
              : TextButton(
                  onPressed: onComingSoon,
                  child: Text(l10n.homeSeeAll),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (requests.isEmpty)
          HomeEmptyCard(
            icon: Icons.water_drop_outlined,
            title: l10n.homeNearbyEmptyTitle,
            body: l10n.homeNearbyEmptyBody,
          )
        else
          for (final NearbyRequestSummary request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: NearbyRequestCard(request: request, onTap: onComingSoon),
            ),
      ],
    );
  }
}

/// Community preview: the newest posts when there are any, and one honest card
/// for each reason there are not.
///
/// The five states are decided in one place because they are one question — *what
/// does this section have to show?* — and the order is the argument:
///
/// 1. Posts on screen win over anything the read is doing behind them. A preview
///    that is real but a second old is still real, and swapping readable cards
///    for a spinner on every rebuild is worse than a stale-looking one.
/// 2. A refused read with nothing behind it says so and offers the retry the
///    feed screen offers, in the same words.
/// 3. A read that succeeded but mapped nothing, with more documents still behind
///    them. This one is separated from state 5 on purpose, because the two say
///    opposite things: "nobody has posted" is a fact about the community, and
///    "this app could not read what it posted" is a fact about the app. Telling
///    a donor the first when the second is true is a false report about other
///    people, and it is the reason a fourth getter exists on [FeedState] rather
///    than a fourth string here.
/// 4. A read in flight spins, in the section's own height rather than over the
///    page: the donor's own status card above it is the reason they came.
/// 5. Nothing refused, nothing pending, nothing there: the empty card. It carries
///    a way into the feed, because a community with no posts is also a community
///    whose composer a first post would have to come from somewhere.
class _FeedSection extends StatelessWidget {
  const _FeedSection({
    required this.posts,
    required this.feed,
    required this.onOpenFeed,
    required this.onRetry,
  });

  final List<FeedPostPreview> posts;

  /// The feed's own state, watched so a refresh on the feed screen repaints this
  /// section too. The preview list is a projection of it.
  final FeedState feed;

  /// Opens the full feed — from a card, from "See all", and from the empty card.
  final VoidCallback onOpenFeed;

  /// Asks for the first page again after a refused read.
  ///
  /// Only ever wired to state 2. State 3 is not a refused read, so this would
  /// re-ask the same window and earn the same answer: a button that cannot work
  /// is worse than no button, and the way past unreadable documents is paging
  /// forward, which is what opening the feed lets the donor do.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        HomeSectionHeader(
          title: l10n.homeFeedTitle,
          // The same rule as the requests section: no link over a list with
          // nothing in it, because the dashboard has nothing to preview.
          action: posts.isEmpty
              ? null
              : TextButton(onPressed: onOpenFeed, child: Text(l10n.homeSeeAll)),
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._body(l10n),
      ],
    );
  }

  List<Widget> _body(AppLocalizations l10n) {
    if (posts.isNotEmpty) {
      return <Widget>[
        // A refresh that failed leaves the previewed posts up and says so here,
        // rather than replacing something readable with an error card.
        if (feed.failure != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: ErrorBanner(
              message: feedFailureMessage(l10n, feed.failure!),
            ),
          ),
        for (final FeedPostPreview post in posts)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: FeedPostCard(post: post, onTap: onOpenFeed),
          ),
      ];
    }

    if (feed.isFatalError) {
      return <Widget>[
        HomeEmptyCard(
          icon: Icons.cloud_off_rounded,
          title: l10n.feedErrorTitle,
          body: feedFailureMessage(l10n, feed.failure!),
          action: SolovvoButton(
            label: l10n.feedRetry,
            onPressed: onRetry,
            variant: SolovvoButtonVariant.secondary,
            size: SolovvoButtonSize.medium,
            icon: Icons.refresh_rounded,
            expand: false,
          ),
        ),
      ];
    }

    if (feed.isUnreadableResult) {
      return <Widget>[
        HomeEmptyCard(
          icon: Icons.cloud_off_rounded,
          title: l10n.feedUnreadableTitle,
          body: feed.skipped > 0
              ? l10n.feedSkippedNotice(feed.skipped)
              : l10n.feedUnreadableBody,
          // "Open the community" rather than "Try again", and the same control
          // the honest empty card already offers. The feed screen owns the cursor
          // and the "Load more" that consumes it; a dashboard button that paged
          // the feed from here would be a second, shallower copy of that
          // mechanism for no benefit to the donor, who is about to leave for the
          // page anyway.
          action: SolovvoButton(
            label: l10n.homeFeedOpenAction,
            onPressed: onOpenFeed,
            variant: SolovvoButtonVariant.secondary,
            size: SolovvoButtonSize.medium,
            icon: Icons.forum_outlined,
            expand: false,
          ),
        ),
      ];
    }

    if (feed.isInitialLoading) {
      // The same 22 dp mark the feed's own footer spins at, so the two screens
      // agree about what "still reading" looks like.
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      HomeEmptyCard(
        icon: Icons.forum_outlined,
        title: l10n.homeFeedEmptyTitle,
        body: l10n.homeFeedEmptyBody,
        // Not "See all": that promises a list to see, and there is none. This
        // promises the page, which is where a first post would be written.
        action: SolovvoButton(
          label: l10n.homeFeedOpenAction,
          onPressed: onOpenFeed,
          variant: SolovvoButtonVariant.secondary,
          size: SolovvoButtonSize.medium,
          icon: Icons.forum_outlined,
          expand: false,
        ),
      ),
    ];
  }
}
