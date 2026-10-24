import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'context_screen.dart';
import 'dashboard_screen.dart';
import 'modes_screen.dart';
import 'privacy_screen.dart';

/// The post-onboarding shell: Dashboard (the adaptive experience), Context
/// (the simulated sensor + routine-simulation panel), Modes (the dynamic
/// mode list), and Privacy Center.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _screens = [
    DashboardScreen(),
    ContextScreen(),
    ModesScreen(),
    PrivacyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.accentLight,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: AppColors.accent),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.sensors_outlined),
            selectedIcon: Icon(Icons.sensors, color: AppColors.accent),
            label: 'Context',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune, color: AppColors.accent),
            label: 'Modes',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: AppColors.accent),
            label: 'Privacy',
          ),
        ],
      ),
    );
  }
}
