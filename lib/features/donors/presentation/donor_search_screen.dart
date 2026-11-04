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
import 'package:sholovvo_app/design/widgets/solovvo_card.dart';
import 'package:sholovvo_app/design/widgets/solovvo_text_field.dart';
import 'package:sholovvo_app/features/donors/application/donor_search_providers.dart';
import 'package:sholovvo_app/features/donors/application/donor_search_state.dart';
import 'package:sholovvo_app/features/donors/domain/donor_query.dart';
import 'package:sholovvo_app/features/donors/domain/donor_repository.dart';
import 'package:sholovvo_app/features/donors/presentation/donor_search_messages.dart';
import 'package:sholovvo_app/features/donors/presentation/widgets/donor_card.dart';
import 'package:sholovvo_app/features/profile/domain/user_profile.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// Every discoverable donor this build can read, available first then by name.
///
/// **A page, not a tab.** Pushed above the shell like the requests screen, so it
/// starts on a fresh read every time it opens — right for a directory whose contents
/// change when a donor toggles their availability.
///
/// **This screen writes nothing.** It searches the public profiles and shows who has
/// consented to be found. Contacting a donor or requesting blood from them is Stage
/// 10's; there is no button for it here, only the note under the list. A screen that
/// looked actionable but was not would be worse than one that says what it can do.
///
/// **Filters re-run the window; there is no "load more".** The read is a bounded
/// window with no database-level sort ([DiscoveredDonors] explains why it cannot be
/// paged without a composite index nobody has deployed), so a filter change re-reads
/// and pull-to-refresh re-reads. The three refinements — group, availability, published
/// area — all go to the database as equality filters, so a shorter list means fewer
/// donors match, not that the app read them badly.
class DonorSearchScreen extends ConsumerStatefulWidget {
  const DonorSearchScreen({super.key});

  static Route<void> route() {
    return FadeSlidePageRoute<void>(page: const DonorSearchScreen());
  }

  static const double wideBreakpoint = 720;
  static const double narrowMaxWidth = 560;
  static const double wideMaxWidth = 900;

  @override
  ConsumerState<DonorSearchScreen> createState() => _DonorSearchScreenState();
}

class _DonorSearchScreenState extends ConsumerState<DonorSearchScreen> {
  final TextEditingController _area = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Deferred past the first frame: starting a read during build would mutate a
    // provider while the tree is being built. The controller's in-flight flag makes a
    // remount a no-op rather than a second paid read.
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted) {
        return;
      }
      unawaited(ref.read(donorSearchControllerProvider.notifier).load());
    });
  }

  @override
  void dispose() {
    _area.dispose();
    super.dispose();
  }

  void _apply(DonorQuery query) {
    unawaited(ref.read(donorSearchControllerProvider.notifier).search(query));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final DonorSearchState state = ref.watch(donorSearchControllerProvider);
    final DonorSearchController controller = ref.read(
      donorSearchControllerProvider.notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.donorSearchTitle)),
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide =
                  constraints.maxWidth >= DonorSearchScreen.wideBreakpoint;
              final double measure = wide
                  ? DonorSearchScreen.wideMaxWidth
                  : DonorSearchScreen.narrowMaxWidth;
              final double side = math.max(
                AppSpacing.gutter,
                (constraints.maxWidth - measure) / 2,
              );
              return RefreshIndicator(
                onRefresh: controller.refresh,
                color: context.palette.brandInk,
                backgroundColor: context.palette.surface,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: <Widget>[
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(side, AppSpacing.sm, side, 0),
                      sliver: _filterSliver(context, state),
                    ),
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

  /// The refinement bar. It scrolls with the list rather than pinning: a fixed-height
  /// header would clip the chip wrap when a locale or a narrow width reflows it, and
  /// reads the *applied* query from the state, not a local copy, so the chips and the
  /// switch can never disagree with the list under them.
  Widget _filterSliver(BuildContext context, DonorSearchState state) {
    return SliverToBoxAdapter(
      child: _FilterBar(
        query: state.query,
        areaController: _area,
        onGroup: (String? group) => _apply(
          group == null
              ? state.query.copyWith(clearBloodGroup: true)
              : state.query.copyWith(bloodGroup: group),
        ),
        onAvailability: (bool only) =>
            _apply(state.query.copyWith(availableOnly: only)),
        onAreaSubmit: () => _apply(
          _area.text.trim().isEmpty
              ? state.query.copyWith(clearArea: true)
              : state.query.copyWith(area: _area.text.trim()),
        ),
        onClearArea: () {
          _area.clear();
          _apply(state.query.copyWith(clearArea: true));
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    DonorSearchState state,
    DonorSearchController controller,
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
            title: l10n.donorErrorTitle,
            body: donorFailureMessage(l10n, state.failure!),
            action: SolovvoButton(
              label: l10n.donorRetry,
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
            title: l10n.donorUnreadableTitle,
            body: state.skipped > 0
                ? l10n.donorSkippedNotice(state.skipped)
                : l10n.donorUnreadableBody,
          ),
        ),
      );
    }

    if (state.isEmptyResult) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: EmptyStateCard(
            icon: Icons.person_search_rounded,
            title: state.hasActiveFilters
                ? l10n.donorEmptyFilteredTitle
                : l10n.donorEmptyAllTitle,
            body: state.hasActiveFilters
                ? l10n.donorEmptyFilteredBody
                : l10n.donorEmptyAllBody,
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
              child: ErrorBanner(message: donorFailureMessage(l10n, state.failure!)),
            ),
          ),
        SliverList.builder(
          itemCount: state.donors.length,
          itemBuilder: (BuildContext context, int index) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: DonorCard(donor: state.donors[index]),
          ),
        ),
        if (state.skipped > 0 || state.truncated)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Column(
                children: <Widget>[
                  if (state.skipped > 0)
                    Text(
                      l10n.donorSkippedNotice(state.skipped),
                      textAlign: TextAlign.center,
                      style: text.labelSmall,
                    ),
                  if (state.truncated)
                    Text(
                      l10n.donorTruncatedNotice(DonorRepository.window),
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

  /// Why there is no contact control, and who appears at all. Said once, quietly.
  Widget _footer(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Text(
        l10n.donorContactNote,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// The refinement bar: group chips, an availability switch, and an area field.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.query,
    required this.areaController,
    required this.onGroup,
    required this.onAvailability,
    required this.onAreaSubmit,
    required this.onClearArea,
  });

  final DonorQuery query;
  final TextEditingController areaController;
  final void Function(String? group) onGroup;
  final void Function(bool only) onAvailability;
  final VoidCallback onAreaSubmit;
  final VoidCallback onClearArea;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return SolovvoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: <Widget>[
              ChoiceChip(
                label: Text(l10n.donorFilterAllGroups),
                selected: query.bloodGroup == null,
                onSelected: (bool _) => onGroup(null),
              ),
              for (final String group in BloodGroups.all)
                ChoiceChip(
                  label: Text(group),
                  selected: query.bloodGroup == group,
                  onSelected: (bool _) => onGroup(group),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.donorAvailabilityFilter),
            value: query.availableOnly,
            onChanged: onAvailability,
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: SolovvoTextField(
                  controller: areaController,
                  label: l10n.donorAreaFieldLabel,
                  hintText: l10n.donorAreaFieldHint,
                  prefixIcon: Icons.location_searching_rounded,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (String _) => onAreaSubmit(),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if ((query.area ?? '').isNotEmpty)
                IconButton(
                  onPressed: onClearArea,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: l10n.donorClearArea,
                )
              else
                SolovvoButton(
                  label: l10n.donorSearchButton,
                  size: SolovvoButtonSize.medium,
                  variant: SolovvoButtonVariant.secondary,
                  expand: false,
                  onPressed: onAreaSubmit,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
