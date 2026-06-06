import 'package:flutter/material.dart';
import '../core/theme.dart';

/// App-styled toast/snackbar helpers so feedback matches the rest of the
/// light theme: floating, rounded, icon + message, themed colors.
class AppSnackBar {
  AppSnackBar._();

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      background: AppColors.primary,
    );
  }

  static void error(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_rounded,
      background: AppColors.error,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color background,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars(); // avoid stacking when tapped repeatedly
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
