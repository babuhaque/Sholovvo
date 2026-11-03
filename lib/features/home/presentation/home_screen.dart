import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/soft_glow_background.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
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
/// The donor strip and the header now read the profile the donor edits in Stage
/// 5. The nearby requests and the feed stay empty until their own stages, and
/// every section says so in its own words rather than showing a zero, a spinner
/// or a sample row.
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
      onComingSoon: _comingSoon,
      // The community preview is the dashboard's way into the feed, so its
      // "See all" is the one placeholder on this screen that now opens a real
      // page instead of reporting "Coming soon".
      onSeeAll: () => unawaited(Navigator.of(context).push(FeedScreen.route())),
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

/// Community preview: posts when there are any, one honest empty card when not.
class _FeedSection extends StatelessWidget {
  const _FeedSection({
    required this.posts,
    required this.onComingSoon,
    required this.onSeeAll,
  });

  final List<FeedPostPreview> posts;
  final VoidCallback onComingSoon;

  /// Opens the full feed. Supplied by the screen, which owns the navigator.
  final VoidCallback onSeeAll;

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
              : TextButton(onPressed: onSeeAll, child: Text(l10n.homeSeeAll)),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (posts.isEmpty)
          HomeEmptyCard(
            icon: Icons.forum_outlined,
            title: l10n.homeFeedEmptyTitle,
            body: l10n.homeFeedEmptyBody,
          )
        else
          for (final FeedPostPreview post in posts)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: FeedPostCard(post: post, onTap: onComingSoon),
            ),
      ],
    );
  }
}
