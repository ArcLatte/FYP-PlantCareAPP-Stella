import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/achievement.dart';
import '../../models/user_profile.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/tier_frame.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  List<Achievement> _pinned = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Load both endpoints independently so one failure can't hide the other.
    UserProfile? profile;
    List<Achievement> pinned = const [];
    String? error;
    try {
      profile = await ApiService.getProfile();
    } catch (e) {
      error = 'profile: $e';
    }
    try {
      final all = await ApiService.getAchievements();
      pinned = all.where((a) => a.isPinned).toList();
    } catch (e) {
      error = error == null ? 'achievements: $e' : '$error; achievements: $e';
    }
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _pinned = pinned;
      _isLoading = false;
    });
    if (error != null) {
      AppSnackBar.error(context, 'Profile load failed — $error');
    }
  }

  Future<void> _logout() async {
    try {
      await ApiService.logout();
    } catch (_) {
      // Even if the server call fails, clear local creds below.
    }
    if (mounted) context.go('/login');
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

  Future<void> _openAchievements() async {
    await context.push('/profile/achievements');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const _ProfileSkeleton()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_profile != null) ...[
                    _HeroCard(profile: _profile!),
                    const SizedBox(height: 16),
                    _StatsGrid(profile: _profile!),
                    const SizedBox(height: 24),
                  ],
                  _SectionHeader(
                    title: 'Medal showcase',
                    actionLabel: 'Medal book',
                    onAction: _openAchievements,
                  ),
                  const SizedBox(height: 12),
                  _ShowcaseRow(
                    pinned: _pinned,
                    onTapSlot: _openAchievements,
                  ),
                  const SizedBox(height: 24),
                  Text('Account', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _AccountCard(
                    email: _profile?.email ?? '',
                    onChangePassword: _openChangePassword,
                    onLogout: _logout,
                  ),
                ],
              ),
            ),
    );
  }
}

/// Gradient identity card: framed avatar, name, tier pill, XP ring of
/// progress toward the next level.
class _HeroCard extends StatelessWidget {
  final UserProfile profile;
  const _HeroCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final tierColor = TierFrame.tierColor(profile.tier);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TierFrame(
                tier: profile.tier,
                size: 84,
                child: Container(
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    profile.username.isEmpty
                        ? '?'
                        : profile.username[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Tier pill — dot tinted with the tier's frame color so
                    // the label visually links to the avatar frame.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: tierColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${profile.tier} · Lv. ${profile.level}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: profile.progressFraction,
              minHeight: 10,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${profile.xpIntoLevel} / ${profile.xpForNextLevel} XP to Lv. ${profile.level + 1}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 2×2 grid of soft stat tiles — same tinted-icon language as the plant
/// detail status card and the Tasks screen.
class _StatsGrid extends StatelessWidget {
  final UserProfile profile;
  const _StatsGrid({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.local_fire_department_rounded,
                color: AppColors.amber,
                label: 'CURRENT STREAK',
                value: '${profile.currentStreak} days',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.bolt_rounded,
                color: const Color(0xFF4F9FD9),
                label: 'LONGEST STREAK',
                value: '${profile.longestStreak} days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                icon: Icons.emoji_events_rounded,
                color: const Color(0xFFE5A722),
                label: 'MEDALS',
                value:
                    '${profile.achievementsUnlocked} / ${profile.achievementsTotal}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatTile(
                icon: Icons.auto_awesome_rounded,
                color: AppColors.primary,
                label: 'TOTAL XP',
                value: '${profile.xp}',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        GestureDetector(
          onTap: onAction,
          child: Row(
            children: [
              Text(
                actionLabel,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The three pinned medals as gacha medallions on one soft shelf card —
/// matching the medal book's gradient-and-glow style.
class _ShowcaseRow extends StatelessWidget {
  static const int slotCount = 3;
  final List<Achievement> pinned;
  final VoidCallback onTapSlot;

  const _ShowcaseRow({required this.pinned, required this.onTapSlot});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
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
      child: Column(
        children: [
          Row(
            children: [
              for (int i = 0; i < slotCount; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: i < pinned.length
                      ? _Medallion(
                          achievement: pinned[i], onTap: onTapSlot)
                      : _EmptyMedalSlot(onTap: onTapSlot),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Shelf line under the medals, echoing the medal book pages.
          Container(
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _Medallion extends StatelessWidget {
  final Achievement achievement;
  final VoidCallback onTap;
  const _Medallion({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = achievement.rarityColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color.withValues(alpha: 0.85), color],
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7),
                width: 2.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child:
                Icon(achievement.iconData, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < achievement.rarityStars; i++)
                Icon(Icons.star_rounded, size: 11, color: color),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            achievement.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMedalSlot extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyMedalSlot({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: AppColors.cardBorder, width: 1.6),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: AppColors.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Pin a medal',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft account card: email, change password, and logout rows, replacing
/// the loud full-width red button.
class _AccountCard extends StatelessWidget {
  final String email;
  final VoidCallback onChangePassword;
  final VoidCallback onLogout;
  const _AccountCard({
    required this.email,
    required this.onChangePassword,
    required this.onLogout,
  });

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
      child: Column(
        children: [
          if (email.isNotEmpty) ...[
            _AccountRow(
              icon: Icons.mail_outline_rounded,
              iconColor: AppColors.primary,
              label: email,
              labelColor: AppColors.textPrimary,
            ),
            const Divider(
                color: AppColors.divider, height: 1, indent: 56),
          ],
          _AccountRow(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.textSecondary,
            label: 'Change password',
            labelColor: AppColors.textPrimary,
            onTap: onChangePassword,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
          const Divider(color: AppColors.divider, height: 1, indent: 56),
          _AccountRow(
            icon: Icons.logout_rounded,
            iconColor: AppColors.error,
            label: 'Log out',
            labelColor: AppColors.error,
            onTap: onLogout,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}

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
      await ApiService.changePassword(
        _oldController.text,
        _newController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString().replaceAll('Exception: ', '');
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
                Text('Change password',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_error != null) ...[
                  Text(
                    _error!,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _oldController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(
                      'Current password', Icons.lock_outline_rounded),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your current password'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newController,
                  obscureText: true,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: _decoration(
                      'New password', Icons.lock_rounded),
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
                      'Confirm new password', Icons.lock_rounded),
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

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _AccountRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: const [
        SkeletonBox(height: 170, radius: 20),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
            SizedBox(width: 12),
            Expanded(child: SkeletonBox(height: 68, radius: 16)),
          ],
        ),
        SizedBox(height: 24),
        SkeletonBox(width: 180, height: 22, radius: 8),
        SizedBox(height: 12),
        SkeletonBox(height: 130, radius: 16),
        SizedBox(height: 24),
        SkeletonBox(width: 120, height: 22, radius: 8),
        SizedBox(height: 12),
        SkeletonBox(height: 110, radius: 16),
      ],
    );
  }
}
