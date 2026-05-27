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
      routerConfig: appRouter,
    );
      }
}