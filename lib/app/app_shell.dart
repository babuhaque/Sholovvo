import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/tokens/app_spacing.dart';
import 'package:sholovvo_app/design/widgets/blood_drop_mark.dart';
import 'package:sholovvo_app/features/auth/domain/auth_user.dart';
import 'package:sholovvo_app/features/home/presentation/home_screen.dart';
import 'package:sholovvo_app/features/profile/presentation/profile_screen.dart';
import 'package:sholovvo_app/l10n/l10n.dart';

/// The destinations the signed-in shell can show.
///
/// The order is the order of the bar, and it is the only place a new destination
/// has to be announced: Home and Profile are the two that exist, so the bar has
/// two entries. Requests, notifications and chat join this enum when the stages
/// that build them land — not before, because a tab that opens a placeholder is
/// a dead end the user has to discover.
enum ShellTab { home, profile }

/// The signed-in container: one place that owns "which tab am I on".
///
/// It is a shell, not a router. Each tab keeps its own `Scaffold` (the dashboard
/// has no app bar at all, the profile has one with its own actions), so the
/// shell only supplies the bar and the box the tab is drawn in. Pushed screens —
/// the profile editor, Settings — still go above the whole shell on the root
/// navigator, which is why they cover the bar and slide away from it.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.user});

  final AuthUser user;

  /// At or above this *window* width the bar becomes a rail down the side.
  ///
  /// The number matches `HomeScreen.twoColumnBreakpoint` and
  /// `ProfileScreen.twoColumnBreakpoint`, but the three do not flip together.
  /// Those two measure the width left over *inside* this shell, because each
  /// screen lays itself out in the space a rail has already taken; this one
  /// measures the whole window. The rail is roughly 73 dp of chrome, so a window
  /// between 720 and about 790 dp gets a rail around content that is still
  /// single-column. Both transitions are intended; they are simply not the same
  /// transition, which the previous wording of this comment implied they were.
  static const double railBreakpoint = 720;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellTab _tab = ShellTab.home;

  void _select(ShellTab tab) {
    if (_tab == tab) {
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    // Both tabs are built and kept alive. That costs one extra profile query at
    // start-up — the profile screen reads the donation history Home does not —
    // and buys back the scroll position of both tabs, which is what makes going
    // to Settings and back feel like a page rather than a reload.
    final Widget pages = IndexedStack(
      index: _tab.index,
      children: <Widget>[
        HomeScreen(
          user: widget.user,
          onOpenProfile: () => _select(ShellTab.profile),
        ),
        ProfileScreen(user: widget.user),
      ],
    );

    final bool wide =
        MediaQuery.sizeOf(context).width >= AppShell.railBreakpoint;

    late final Widget shell;
    if (wide) {
      shell = Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _tab.index,
              onDestinationSelected: (int index) =>
                  _select(ShellTab.values[index]),
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: BloodDropMark(size: 28),
              ),
              destinations: <NavigationRailDestination>[
                for (final ShellTab tab in ShellTab.values)
                  NavigationRailDestination(
                    icon: Icon(_iconFor(tab)),
                    selectedIcon: Icon(_selectedIconFor(tab)),
                    label: Text(_labelFor(l10n, tab)),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: pages),
          ],
        ),
      );
    } else {
      shell = Scaffold(
        // The bar already sits above the home indicator, so the page inside must
        // not add that inset a second time under its own last row.
        body: MediaQuery.removePadding(
          context: context,
          removeBottom: true,
          child: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (int index) => _select(ShellTab.values[index]),
          destinations: <Widget>[
            for (final ShellTab tab in ShellTab.values)
              NavigationDestination(
                icon: Icon(_iconFor(tab)),
                selectedIcon: Icon(_selectedIconFor(tab)),
                label: _labelFor(l10n, tab),
              ),
          ],
        ),
      );
    }

    // Android's back press pops the route, and this shell's route is the app's
    // only one, so without this a back press on the Profile tab would close the
    // app. Blocking the pop while a later tab is showing turns that press into
    // "go home", which is what a tab bar is expected to do. On the Home tab the
    // pop is allowed through untouched, so back still leaves the app. A route
    // pushed above the shell (Settings) is the navigator's business: it is the
    // topmost route, so its own pop runs and this widget is never consulted.
    return PopScope<Object?>(
      canPop: _tab == ShellTab.home,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop && _tab != ShellTab.home) {
          _select(ShellTab.home);
        }
      },
      child: shell,
    );
  }

  static IconData _iconFor(ShellTab tab) => switch (tab) {
    ShellTab.home => Icons.home_outlined,
    ShellTab.profile => Icons.person_outline_rounded,
  };

  static IconData _selectedIconFor(ShellTab tab) => switch (tab) {
    ShellTab.home => Icons.home_rounded,
    ShellTab.profile => Icons.person_rounded,
  };

  static String _labelFor(AppLocalizations l10n, ShellTab tab) => switch (tab) {
    ShellTab.home => l10n.navHome,
    ShellTab.profile => l10n.profileTitle,
  };
}
