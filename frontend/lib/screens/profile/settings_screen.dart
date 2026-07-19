import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/app_error.dart';
import '../../core/theme.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';

const double _kShellNavClearance = 112;

/// Settings, reached from the gear icon on the Profile tab. Hosts the
/// profile picture editor, editable account details (username/email), the
/// change-password flow, app info, logout, and the delete-account danger
/// zone — all kept out of the profile body so that page stays celebratory.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isUploadingAvatar = false;
  TimeOfDay _reminderTime = const TimeOfDay(
    hour: NotificationService.defaultReminderHour,
    minute: NotificationService.defaultReminderMinute,
  );

  @override
  void initState() {
    super.initState();
    _load();
    _loadReminderTime();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiService.getProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppSnackBar.error(
        context,
        e,
        fallback: 'Could not load your profile. Please try again.',
      );
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout();
    } catch (_) {
      // Even if the server call fails, local creds are cleared by logout().
    }
    if (mounted) context.go('/login');
  }

  // ─── Profile picture ───────────────────────────────────────

  Future<void> _openAvatarSheet() async {
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AvatarSheet(hasAvatar: _profile?.avatarUrl != null),
    );
    if (action == null || !mounted) return;

    if (action == _AvatarAction.remove) {
      await _saveAvatar(removeAvatar: true);
      return;
    }

    final source = action == _AvatarAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      await _saveAvatar(file: File(picked.path));
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not open that image. Please try again.',
        );
      }
    }
  }

  Future<void> _saveAvatar({File? file, bool removeAvatar = false}) async {
    setState(() => _isUploadingAvatar = true);
    try {
      final profile = await ApiService.updateProfile(
        avatar: file,
        removeAvatar: removeAvatar,
      );
      if (!mounted) return;
      setState(() => _profile = profile);
      AppSnackBar.success(
        context,
        removeAvatar ? 'Profile picture removed' : 'Profile picture updated',
      );
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
          context,
          e,
          fallback: 'Could not update your profile picture. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ─── Account fields ────────────────────────────────────────

  Future<void> _editUsername() async {
    final profile = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true, // keyboard-aware
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditFieldSheet(
        title: 'Change username',
        hint: 'Username',
        icon: Icons.person_outline_rounded,
        initialValue: _profile?.username ?? '',
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'Username can\'t be empty';
          if (t.length < 3) return 'At least 3 characters';
          if (!RegExp(r'^[\w.@+-]+$').hasMatch(t)) {
            return 'Only letters, digits and @/./+/-/_';
          }
          return null;
        },
        onSave: (v) => ApiService.updateProfile(username: v.trim()),
      ),
    );
    if (profile != null && mounted) {
      setState(() => _profile = profile);
      AppSnackBar.success(context, 'Username updated');
    }
  }

  Future<void> _editEmail() async {
    final profile = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EditFieldSheet(
        title: 'Change email',
        hint: 'Email address',
        icon: Icons.mail_outline_rounded,
        initialValue: _profile?.email ?? '',
        keyboardType: TextInputType.emailAddress,
        validator: (v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return 'Email can\'t be empty';
          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) {
            return 'Enter a valid email address';
          }
          return null;
        },
        onSave: (v) => ApiService.updateProfile(email: v.trim()),
      ),
    );
    if (profile != null && mounted) {
      setState(() => _profile = profile);
      AppSnackBar.success(context, 'Email updated');
    }
  }

  Future<void> _openChangePassword() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true, // keyboard-aware
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ChangePasswordSheet(),
    );
    if (changed == true && mounted) {
      // Backend revokes the token after a password change; route to login.
      AppSnackBar.success(context, 'Password changed — please log in again');
      context.go('/login');
    }
  }

  // ─── Notifications ─────────────────────────────────────────

  Future<void> _loadReminderTime() async {
    final (h, m) = await NotificationService.getReminderTime();
    if (!mounted) return;
    setState(() => _reminderTime = TimeOfDay(hour: h, minute: m));
  }

  /// Tap: pick the daily reminder time, persist it, and rebuild the schedule
  /// so the change takes effect immediately (not just on the next home load).
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'Daily reminder time',
    );
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    await NotificationService.setReminderTime(picked.hour, picked.minute);
    try {
      final plants = await ApiService.getPlants();
      await NotificationService.scheduleCareReminders(plants);
    } catch (_) {
      // Best-effort; the next home load reschedules at the new time anyway.
    }
    if (!mounted) return;
    AppSnackBar.success(context, 'Reminders set for ${picked.format(context)}');
  }

  /// Long-press: fire a test notification to confirm delivery works.
  Future<void> _sendTestNotification() async {
    final result = await NotificationService.sendTestNotification();
    if (!mounted) return;
    switch (result.status) {
      case NotificationTestStatus.sent:
        AppSnackBar.success(context, 'Test notification sent');
      case NotificationTestStatus.permissionDenied:
        AppSnackBar.error(
          context,
          'Notifications are blocked. Allow them for Stella in system settings.',
        );
      case NotificationTestStatus.failed:
        final detail = (result.error ?? 'unknown Android error').replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        final shortDetail = detail.length > 500
            ? '${detail.substring(0, 500)}…'
            : detail;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Notification test failed'),
            content: SelectableText(shortDetail),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close'),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _openDeleteAccount() async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _DeleteAccountSheet(),
    );
    if (deleted == true && mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding =
        MediaQuery.paddingOf(context).bottom + _kShellNavClearance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
        children: [
          if (_isLoading)
            const SkeletonBox(height: 120, radius: 16)
          else
            _AvatarHeader(
              profile: _profile,
              isUploading: _isUploadingAvatar,
              onEdit: _openAvatarSheet,
            ),
          const SizedBox(height: 24),
          Text('Account', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          if (_isLoading)
            const SkeletonBox(height: 160, radius: 16)
          else
            _SettingsCard(
              children: [
                _SettingsRow(
                  icon: Icons.person_outline_rounded,
                  iconColor: AppColors.primary,
                  label: _profile?.username ?? '—',
                  sublabel: 'Username',
                  onTap: _editUsername,
                  trailing: const _EditChevron(),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.mail_outline_rounded,
                  iconColor: AppColors.primary,
                  label: (_profile?.email ?? '').isEmpty
                      ? '—'
                      : _profile!.email,
                  sublabel: 'Email',
                  onTap: _editEmail,
                  trailing: const _EditChevron(),
                ),
                const _RowDivider(),
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: AppColors.textSecondary,
                  label: 'Change password',
                  onTap: _openChangePassword,
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 24),
          Text('Notifications', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.schedule_rounded,
                iconColor: AppColors.primary,
                label: 'Reminder time',
                sublabel: 'When daily care reminders arrive · hold to test',
                onTap: _pickReminderTime,
                onLongPress: _sendTestNotification,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _reminderTime.format(context),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('About', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              const _SettingsRow(
                icon: Icons.eco_rounded,
                iconColor: AppColors.primary,
                label: 'Stella',
                sublabel: 'Version 1.4.3',
              ),
              const _RowDivider(),
              _SettingsRow(
                icon: Icons.description_outlined,
                iconColor: AppColors.textSecondary,
                label: 'Open-source licenses',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Stella',
                  applicationVersion: '1.4.3',
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsCard(
            children: [
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.error,
                label: 'Log out',
                labelColor: AppColors.error,
                onTap: _logout,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
              const _RowDivider(),
              _SettingsRow(
                icon: Icons.delete_forever_rounded,
                iconColor: AppColors.error,
                label: 'Delete account',
                sublabel: 'Permanently erase your account and data',
                labelColor: AppColors.error,
                onTap: _openDeleteAccount,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Profile picture header ───────────────────────────────────

/// Centered avatar with a camera badge. Tapping anywhere on it opens the
/// photo sheet; a spinner overlays while an upload is in flight.
class _AvatarHeader extends StatelessWidget {
  final UserProfile? profile;
  final bool isUploading;
  final VoidCallback onEdit;

  const _AvatarHeader({
    required this.profile,
    required this.isUploading,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = profile?.avatarUrl;
    final initial = (profile?.username ?? '').isEmpty
        ? '?'
        : profile!.username[0].toUpperCase();
    return Column(
      children: [
        GestureDetector(
          onTap: isUploading ? null : onEdit,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.14),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                child: isUploading
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      )
                    : avatarUrl != null
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (_, _, _) => _initialText(initial),
                      )
                    : _initialText(initial),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          profile?.username ?? '',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Tap the photo to change it',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  static Widget _initialText(String initial) => Text(
    initial,
    style: const TextStyle(
      color: AppColors.primary,
      fontSize: 34,
      fontWeight: FontWeight.w800,
    ),
  );
}

enum _AvatarAction { camera, gallery, remove }

/// Bottom sheet: camera / gallery / remove options for the profile picture.
class _AvatarSheet extends StatelessWidget {
  final bool hasAvatar;
  const _AvatarSheet({required this.hasAvatar});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              'Profile picture',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.photo_camera_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Take photo',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(context, _AvatarAction.camera),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.primary,
              ),
              title: const Text(
                'Choose from gallery',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(context, _AvatarAction.gallery),
            ),
            if (hasAvatar)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Remove photo',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared card / row widgets ────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.divider, height: 1, indent: 56);
  }
}

/// Small pencil-style affordance for rows that open an edit sheet.
class _EditChevron extends StatelessWidget {
  const _EditChevron();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.edit_outlined,
      color: AppColors.textMuted,
      size: 18,
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sublabel;
  final Color labelColor;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel,
    this.labelColor = AppColors.textPrimary,
    this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ─── Edit-field sheet ─────────────────────────────────────────

/// Generic single-field editor for username/email. Pops the fresh
/// [UserProfile] on success so the caller can update its state.
class _EditFieldSheet extends StatefulWidget {
  final String title;
  final String hint;
  final IconData icon;
  final String initialValue;
  final TextInputType keyboardType;
  final String? Function(String?) validator;
  final Future<UserProfile> Function(String value) onSave;

  const _EditFieldSheet({
    required this.title,
    required this.hint,
    required this.icon,
    required this.initialValue,
    this.keyboardType = TextInputType.text,
    required this.validator,
    required this.onSave,
  });

  @override
  State<_EditFieldSheet> createState() => _EditFieldSheetState();
}

class _EditFieldSheetState extends State<_EditFieldSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_controller.text.trim() == widget.initialValue) {
      Navigator.pop(context); // nothing changed
      return;
    }
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final profile = await widget.onSave(_controller.text);
      if (mounted) Navigator.pop(context, profile);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = AppErrorMessages.message(
            e,
            fallback: 'Could not update your username. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: widget.keyboardType,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    prefixIcon: Icon(widget.icon),
                  ),
                  validator: widget.validator,
                  onFieldSubmitted: (_) => _isSaving ? null : _submit(),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Change-password sheet ────────────────────────────────────

/// Old/new/confirm password form. Pops `true` after a successful change so
/// the caller can route to login (the backend revokes the token).
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ApiService.changePassword(_oldController.text, _newController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = AppErrorMessages.message(
            e,
            fallback: 'Could not update your email. Please try again.',
          );
        });
      }
    }
  }

  InputDecoration _decoration(String hint, IconData icon) =>
      InputDecoration(hintText: hint, prefixIcon: Icon(icon));

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Change password',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _oldController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(
                    'Current password',
                    Icons.lock_outline_rounded,
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration('New password', Icons.lock_rounded),
                  validator: (v) => v == null || v.length < 8
                      ? 'At least 8 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(
                    'Confirm new password',
                    Icons.lock_rounded,
                  ),
                  validator: (v) => v != _newController.text
                      ? 'Passwords don\'t match'
                      : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Change password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Delete-account sheet ─────────────────────────────────────

/// Password-confirmed, irreversible account deletion. Pops `true` after the
/// backend confirms so the caller can route to login.
class _DeleteAccountSheet extends StatefulWidget {
  const _DeleteAccountSheet();

  @override
  State<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends State<_DeleteAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isDeleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isDeleting = true;
      _error = null;
    });
    try {
      await ApiService.deleteAccount(_passwordController.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _error = AppErrorMessages.message(
            e,
            fallback: 'Could not delete your account. Please try again.',
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  'Delete account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'This permanently erases your account, plants, care '
                  'history and achievements. It cannot be undone.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofocus: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Confirm with your password',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Enter your password' : null,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isDeleting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Delete my account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
