import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import 'app_snackbar.dart';

/// Result of [showPhotoPickerSheet]. Distinguishes "user picked a new file"
/// from "user asked to clear the pending photo" from "user dismissed".
class PhotoPickResult {
  final File? file;
  final bool cleared;
  const PhotoPickResult.picked(this.file) : cleared = false;
  const PhotoPickResult.clear()
      : file = null,
        cleared = true;
}

/// Shared camera / gallery / clear bottom sheet used by the add-plant wizard
/// and the edit-plant screen. Returns null when dismissed without action.
///
/// [showClear] adds a "Remove selected photo" row — pass true only when the
/// caller has a pending photo that can be discarded.
Future<PhotoPickResult?> showPhotoPickerSheet(
  BuildContext context, {
  bool showClear = false,
}) async {
  final picker = ImagePicker();

  Future<void> pick(BuildContext sheetContext, ImageSource source) async {
    try {
      final picked = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (!sheetContext.mounted) return;
      Navigator.pop(
        sheetContext,
        picked == null ? null : PhotoPickResult.picked(File(picked.path)),
      );
    } catch (e) {
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
        AppSnackBar.error(
          sheetContext,
          e,
          fallback: 'Could not open that image. Please try again.',
        );
      }
    }
  }

  return showModalBottomSheet<PhotoPickResult>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Take photo',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => pick(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () => pick(sheetContext, ImageSource.gallery),
            ),
            if (showClear)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Remove selected photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, const PhotoPickResult.clear()),
              ),
          ],
        ),
      ),
    ),
  );
}
