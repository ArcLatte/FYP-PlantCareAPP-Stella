import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/plant/add_plant_screen.dart';
import '../screens/plant/edit_plant_screen.dart';
import '../screens/plant/plant_detail_screen.dart';
import '../screens/scan/scan_screen.dart';
import '../screens/scan/result_screen.dart';
import '../screens/disease/disease_detail_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/history/history_detail_screen.dart';
import '../screens/library/library_screen.dart';
import '../screens/library/species_detail_screen.dart';
import '../screens/tasks/tasks_screen.dart';
import '../screens/tasks/task_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/achievements_screen.dart';
import '../screens/profile/settings_screen.dart';
import '../screens/profile/shop_screen.dart';
import '../widgets/app_shell.dart';
import '../core/constants.dart';
import '../core/theme.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  redirect: (BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.tokenKey);
    final isLoggedIn = token != null && token.isNotEmpty;
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!isLoggedIn && !isAuthRoute) return '/login';
    if (isLoggedIn && isAuthRoute) return '/home';
    return null;
  },
  // Graceful fallback for any unmatched location, so a bad link never leaves
  // the user stranded on go_router's bare default page with no way home.
  errorBuilder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Page not found')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              "This page couldn't be opened.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    ),
  ),
  routes: [
    // Top-level routes (no shell, no bottom nav).
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/plants/add',
      builder: (context, state) => const AddPlantScreen(),
    ),
    GoRoute(
      path: '/plants/:id',
      builder: (context, state) {
        final plantId = int.parse(state.pathParameters['id']!);
        return PlantDetailScreen(plantId: plantId);
      },
    ),
    GoRoute(
      path: '/plants/:id/edit',
      builder: (context, state) {
        final plantId = int.parse(state.pathParameters['id']!);
        return EditPlantScreen(plantId: plantId);
      },
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const ScanScreen(),
    ),
    GoRoute(
      path: '/scan/:plantId',
      builder: (context, state) {
        final plantId = int.parse(state.pathParameters['plantId']!);
        return ScanScreen(plantId: plantId);
      },
    ),
    GoRoute(
      path: '/result/:scanId',
      builder: (context, state) {
        final scanId = int.parse(state.pathParameters['scanId']!);
        return ResultScreen(scanId: scanId);
      },
    ),
    GoRoute(
      path: '/disease/:label',
      builder: (context, state) {
        final label = Uri.decodeComponent(state.pathParameters['label']!);
        // `?scanId=` puts the page in confirm mode (reached from a scan).
        final scanIdRaw = state.uri.queryParameters['scanId'];
        final scanId = scanIdRaw == null ? null : int.tryParse(scanIdRaw);
        return DiseaseDetailScreen(label: label, scanId: scanId);
      },
    ),
    // Top-level species reference page, pushable from anywhere (e.g. the plant
    // profile's "Read more"). The Library tab reaches the same screen via its
    // nested `/library/species/:id`, but that route lives inside the shell and
    // can't be pushed from outside it.
    GoRoute(
      path: '/species/:id',
      builder: (context, state) => SpeciesDetailScreen(
        speciesId: int.parse(state.pathParameters['id']!),
      ),
    ),
    // History is a "look back" view, reached from the Tasks page header rather
    // than its own nav tab — so it pushes over the shell (no bottom nav), like
    // a detail screen.
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
      routes: [
        GoRoute(
          // /history/water/2026-06-08 — per-day, per-activity timeline.
          path: ':activity/:date',
          builder: (context, state) => HistoryDetailScreen(
            activity: state.pathParameters['activity']!,
            date: DateTime.parse(state.pathParameters['date']!),
          ),
        ),
      ],
    ),
    // Persistent shell: Home / Tasks / Library / Profile each keep their
    // own Navigator + state. Bottom nav lives in AppShellScaffold.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShellScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
              routes: [
                GoRoute(
                  path: ':activity', // /tasks/water | /fertilize | /mist
                  builder: (context, state) => TaskDetailScreen(
                    activity: state.pathParameters['activity']!,
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'achievements',
                  builder: (context, state) => const AchievementsScreen(),
                ),
                GoRoute(
                  path: 'shop',
                  builder: (context, state) => const ShopScreen(),
                ),
                GoRoute(
                  path: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
        // Branch 3: Library — browse species + disease reference content.
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const LibraryScreen(),
              routes: [
                GoRoute(
                  path: 'species/:id',
                  builder: (context, state) => SpeciesDetailScreen(
                    speciesId: int.parse(state.pathParameters['id']!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
