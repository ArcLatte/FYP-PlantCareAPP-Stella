import 'package:flutter/material.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  runApp(const StellaApp());
}

class StellaApp extends StatelessWidget {
  const StellaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Stella',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: appRouter,
    );
  }
}

/// iOS-style bouncing overscroll across the whole app. Replaces the default
/// Android glow/stretch with a spring effect that leaves empty space at the
/// edges when the user drags past the end of the content.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );

  // Suppress the glow overlay so we don't double-render anything on Android.
  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}