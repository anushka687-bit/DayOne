import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme/app_theme.dart';
import 'context_screen.dart';
import 'dashboard_screen.dart';
import 'device_controls_screen.dart';
import 'modes_screen.dart';
import 'privacy_screen.dart';
import 'routines_screen.dart';
import 'smart_environment_screen.dart';
import 'why_this_mode_screen.dart';

/// The post-onboarding shell — laid out the way DayOne_Review2_Demo (the
/// browser prototype) is: a left navigation rail with a brand mark and a
/// "local session" footer badge on wide windows, collapsing to a bottom
/// bar on narrow ones, same as the demo's own CSS breakpoint. Overview,
/// Device controls, and Smart environment are the demo's own three top
/// nav items, in the demo's own order; Context, Modes, Routines, Why this
/// mode, and Privacy are this app's own screens, layered on after —
/// Routines and Why this mode used to be reachable only by pushing from
/// another screen.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _NavEntry {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const _NavEntry(this.icon, this.selectedIcon, this.label);
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _screens = [
    DashboardScreen(),
    DeviceControlsScreen(),
    SmartEnvironmentScreen(),
    ContextScreen(),
    ModesScreen(),
    RoutinesScreen(),
    WhyThisModeScreen(),
    PrivacyScreen(),
  ];

  static const _destinations = [
    _NavEntry(Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
    _NavEntry(Icons.brightness_6_outlined, Icons.brightness_6, 'Device controls'),
    _NavEntry(Icons.home_outlined, Icons.home, 'Smart environment'),
    _NavEntry(Icons.sensors_outlined, Icons.sensors, 'Context'),
    _NavEntry(Icons.tune_outlined, Icons.tune, 'Modes'),
    _NavEntry(Icons.schedule_outlined, Icons.schedule, 'Routines'),
    _NavEntry(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Why this mode'),
    _NavEntry(Icons.shield_outlined, Icons.shield, 'Privacy'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 760;

    if (!wide) {
      return Scaffold(
        body: IndexedStack(index: _tab, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          backgroundColor: Colors.white,
          indicatorColor: AppColors.accentLight,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon, color: AppColors.accent),
                label: d.label,
              ),
          ],
        ),
      );
    }

    final extended = width >= 1080;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: AppColors.ink,
            minWidth: 72,
            extended: extended,
            labelType: extended ? NavigationRailLabelType.none : NavigationRailLabelType.selected,
            useIndicator: true,
            indicatorColor: Colors.white.withOpacity(0.08),
            unselectedIconTheme: IconThemeData(color: AppColors.paper.withOpacity(0.6)),
            selectedIconTheme: const IconThemeData(color: AppColors.accent),
            unselectedLabelTextStyle: TextStyle(color: AppColors.paper.withOpacity(0.7), fontSize: 12),
            selectedLabelTextStyle:
                const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12),
            leading: const _RailBrand(),
            trailing: const Expanded(
              child: Align(alignment: Alignment.bottomCenter, child: _LocalSessionBadge()),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, thickness: 1, color: AppColors.line),
          Expanded(child: IndexedStack(index: _tab, children: _screens)),
        ],
      ),
    );
  }
}

/// The "D" brand mark above the rail — mirrors the demo sidebar's
/// `.brand-mark` + "DayOne / Learn. Adapt. Privately." lockup.
class _RailBrand extends StatelessWidget {
  const _RailBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 24, 12, 16),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const Text(
          'D',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ),
    );
  }
}

/// The dark, bordered "LOCAL SESSION" card pinned to the bottom of the
/// rail — mirrors the demo sidebar's `.sidebar-bottom` badge, but with a
/// real figure (learned corrections so far) instead of static copy.
class _LocalSessionBadge extends StatelessWidget {
  const _LocalSessionBadge();

  @override
  Widget build(BuildContext context) {
    final updateCount = context.watch<AppState>().model?.updateCount ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 190),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'LOCAL SESSION',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'No account. No cloud profile.\n'
              '$updateCount learned correction${updateCount == 1 ? '' : 's'} on this device.',
              style: TextStyle(color: AppColors.paper.withOpacity(0.65), fontSize: 10, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
