import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

/// Scaffold wrapper rendered by `StatefulShellRoute.indexedStack` in
/// `core/router.dart`. Hosts the persistent bottom navigation across the
/// four main tabs (Home, Tasks, History, Profile) and includes a Scan cell
/// that pushes a modal route over the shell.
class AppShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScaffold({super.key, required this.navigationShell});

  // The four cells that correspond to shell branches. Indexes here MUST line
  // up with the branch order declared in `appRouter`.
  static const _tabs = <_TabSpec>[
    _TabSpec(
      branchIndex: 0,
      label: 'Home',
      inactiveIcon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _TabSpec(
      branchIndex: 1,
      label: 'Tasks',
      inactiveIcon: Icons.checklist_rtl_outlined,
      activeIcon: Icons.checklist_rtl_rounded,
    ),
    // Scan is inserted between Tasks and History in the rendered row, but
    // it's not a branch — it pushes /scan as a modal over the shell.
    _TabSpec(
      branchIndex: 2,
      label: 'History',
      inactiveIcon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
    ),
    _TabSpec(
      branchIndex: 3,
      label: 'Profile',
      inactiveIcon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.cardBorder),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                _NavCell(
                  spec: _tabs[0],
                  selected: navigationShell.currentIndex == 0,
                  onTap: () => _goBranch(0),
                ),
                _NavCell(
                  spec: _tabs[1],
                  selected: navigationShell.currentIndex == 1,
                  onTap: () => _goBranch(1),
                ),
                // Scan is centred between the two halves. Never marked
                // active because it isn't a shell branch.
                _NavCell(
                  spec: const _TabSpec(
                    branchIndex: -1,
                    label: 'Scan',
                    inactiveIcon: Icons.document_scanner_outlined,
                    activeIcon: Icons.document_scanner_rounded,
                  ),
                  selected: false,
                  onTap: () => context.push('/scan'),
                ),
                _NavCell(
                  spec: _tabs[2],
                  selected: navigationShell.currentIndex == 2,
                  onTap: () => _goBranch(2),
                ),
                _NavCell(
                  spec: _tabs[3],
                  selected: navigationShell.currentIndex == 3,
                  onTap: () => _goBranch(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBranch(int index) {
    // `initialLocation: true` resets the branch to its root on re-tap, which
    // matches the common bottom-nav UX (tap the active tab to pop back).
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _TabSpec {
  final int branchIndex;
  final String label;
  final IconData inactiveIcon;
  final IconData activeIcon;

  const _TabSpec({
    required this.branchIndex,
    required this.label,
    required this.inactiveIcon,
    required this.activeIcon,
  });
}

class _NavCell extends StatelessWidget {
  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;

  const _NavCell({
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    final icon = selected ? spec.activeIcon : spec.inactiveIcon;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              spec.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
