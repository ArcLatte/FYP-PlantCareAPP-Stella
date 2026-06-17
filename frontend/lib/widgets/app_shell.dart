import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

/// Scaffold wrapper rendered by `StatefulShellRoute.indexedStack` in
/// `core/router.dart`. Hosts the persistent **floating pill bar** for the
/// main tabs (Home, Tasks, Library, Profile) plus a Scan cell that pushes a
/// modal route over the shell. (History isn't a tab — it's reached from the
/// Tasks page header and pushed over the shell.)
///
/// Visual: a rounded surface bar floats above the bottom safe-area with
/// horizontal margin. Each cell shows icon-above-label; the active cell
/// just changes color (primary green) — no expansion.
class AppShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScaffold({super.key, required this.navigationShell});

  // The cells that correspond to shell branches. Each spec's `branchIndex`
  // MUST line up with the branch order declared in `appRouter` (the list
  // position here is independent of the on-screen order in the Row below).
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
    // Scan is inserted between Tasks and Library in the rendered row, but
    // it's not a branch — it pushes /scan as a modal over the shell.
    _TabSpec(
      branchIndex: 2,
      label: 'Profile',
      inactiveIcon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
    _TabSpec(
      branchIndex: 3,
      label: 'Library',
      inactiveIcon: Icons.menu_book_outlined,
      activeIcon: Icons.menu_book_rounded,
    ),
  ];

  static const _TabSpec _scanSpec = _TabSpec(
    branchIndex: -1,
    label: 'Scan',
    inactiveIcon: Icons.document_scanner_outlined,
    activeIcon: Icons.document_scanner_rounded,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body extends behind the floating pill so screens fill the full height.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: AppColors.cardBorder),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
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
                _NavCell(
                  spec: _scanSpec,
                  selected: false,
                  onTap: () => context.push('/scan'),
                ),
                _NavCell(
                  spec: _tabs[3], // Library
                  selected: navigationShell.currentIndex == 3,
                  onTap: () => _goBranch(3),
                ),
                _NavCell(
                  spec: _tabs[2], // Profile
                  selected: navigationShell.currentIndex == 2,
                  onTap: () => _goBranch(2),
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

/// A single cell in the pill bar. Icon above label, equal width regardless
/// of selection. Active state changes color only (primary green).
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
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
