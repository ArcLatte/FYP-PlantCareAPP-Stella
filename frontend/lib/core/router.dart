import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/plant/add_plant_screen.dart';
import '../screens/plant/plant_detail_screen.dart';
import '../screens/scan/scan_screen.dart';
import '../screens/scan/result_screen.dart';
import '../screens/history/history_screen.dart';
import '../core/constants.dart';

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
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
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
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
  ],
);