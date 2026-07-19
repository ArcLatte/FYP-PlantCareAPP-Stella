import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../services/app_badge_controller.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

/// Scaffold wrapper rendered by `StatefulShellRoute.indexedStack` in
/// `core/router.dart`. Hosts the persistent **floating pill bar** for the
/// main tabs (Home, Tasks, Library, Profile) plus a Scan cell that
/// pushes a modal route over the shell. (History isn't a tab — it's reached
/// from the Tasks page header and pushed over the shell.)
///
/// Visual: a rounded surface bar floats above the bottom safe-area with
/// horizontal margin. Each cell shows icon-above-label; the active cell
/// just changes color (primary green) — no expansion.
class AppShellScaffold extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShellScaffold({super.key, required this.navigationShell});

  @override
  State<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends State<AppShellScaffold>
    with WidgetsBindingObserver {
  final _badges = AppBadgeController.instance;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _badges.addListener(_onBadgesChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDeviceFeatures();
    });
  }

  /// Android presents one permission activity at a time. Request the two app
  /// permissions sequentially, then build badges and reminder schedules.
  Future<void> _startDeviceFeatures() async {
    try {
      await LocationService.ensurePermission();
    } catch (_) {
      // The weather card can remain empty if location is unavailable.
    }
    try {
      await NotificationService.requestNotificationPermission();
    } catch (_) {
      // Badges still need to start if notification setup is unavailable.
    }
    if (!mounted) return;
    await _badges.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _badges.removeListener(_onBadgesChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _badges.refresh();
  }

  void _onBadgesChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Body extends behind the floating pill so screens fill the full height.
      extendBody: true,
      body: widget.navigationShell,
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
                  selected: widget.navigationShell.currentIndex == 0,
                  onTap: () => _goBranch(0),
                ),
                _NavCell(
                  spec: _tabs[1],
                  selected: widget.navigationShell.currentIndex == 1,
                  showAttentionDot: _badges.dueCareActions > 0,
                  onTap: () => _goBranch(1),
                ),
                _NavCell(
                  spec: _scanSpec,
                  selected: false,
                  onTap: () => context.push('/scan'),
                ),
                _NavCell(
                  spec: _tabs[3], // Library
                  selected: widget.navigationShell.currentIndex == 3,
                  onTap: () => _goBranch(3),
                ),
                _NavCell(
                  spec: _tabs[2], // Profile
                  selected: widget.navigationShell.currentIndex == 2,
                  showNewDot: _badges.hasNewProfileUnlock,
                  onTap: () {
                    _badges.clearProfileUnlock();
                    _goBranch(2);
                  },
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
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
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
  final bool showAttentionDot;
  final bool showNewDot;

  const _NavCell({
    required this.spec,
    required this.selected,
    required this.onTap,
    this.showAttentionDot = false,
    this.showNewDot = false,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 22),
                if (showAttentionDot)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE76F51),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  )
                else if (showNewDot)
                  Positioned(
                    right: -5,
                    top: -4,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              spec.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
