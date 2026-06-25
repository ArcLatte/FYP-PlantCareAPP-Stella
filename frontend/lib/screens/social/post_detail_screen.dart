import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/post_card.dart';

/// Full view of a single post. Shows a delete action when the post belongs to
/// the logged-in user. Pops `true` after a delete so the feed refreshes.
/// (Comments arrive in Phase 2.)
class PostDetailScreen extends StatefulWidget {
  final int postId;
  const PostDetailScreen({super.key, required this.postId});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  String? _currentUsername;
  String? _error;
  bool _deleting = false;

  bool get _isMine =>
      _post != null &&
      _currentUsername != null &&
      _post!.author.username == _currentUsername;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getPost(widget.postId),
        ApiService.currentUsername(),
      ]);
      if (!mounted) return;
      setState(() {
        _post = results[0] as Post;
        _currentUsername = results[1] as String?;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete post?'),
        content: const Text('This permanently removes your post.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) _delete();
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await ApiService.deletePost(widget.postId);
      if (!mounted) return;
      AppSnackBar.success(context, 'Post deleted');
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      AppSnackBar.error(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (_isMine)
            IconButton(
              icon: _deleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.error),
                    )
                  : const Icon(Icons.delete_outline_rounded,
                      color: AppColors.error),
              onPressed: _deleting ? null : _confirmDelete,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }
    if (_post == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        PostCard(post: _post!),
      ],
    );
  }
}
