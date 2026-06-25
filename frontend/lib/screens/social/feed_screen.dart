import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/post.dart';
import '../../services/api_service.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/post_card.dart';
import '../../widgets/skeleton.dart';

/// The Community tab: a global, reverse-chronological feed of posts with
/// pull-to-refresh and cursor-based infinite scroll. Compose lives behind the
/// lifted FAB; tapping a card opens its detail.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<Post> _posts = [];
  final ScrollController _scroll = ScrollController();

  String? _nextCursor;
  bool _isLoading = true; // first page
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await ApiService.getFeed();
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(page.posts);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  /// Pull-to-refresh: reload the first page without the full-screen skeleton.
  Future<void> _refresh() async {
    try {
      final page = await ApiService.getFeed();
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(page.posts);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _error = null;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.error(
            context, e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _nextCursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final page = await ApiService.getFeed(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(page.posts);
        _nextCursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openCompose() async {
    final created = await context.push<bool>('/feed/compose');
    if (created == true) _loadFirstPage();
  }

  Future<void> _openPost(Post post) async {
    // Detail returns true when the post was deleted there, so we refresh.
    final changed = await context.push<bool>('/posts/${post.id}');
    if (changed == true) _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      floatingActionButton: Padding(
        // Lift above the floating pill nav bar (64h + 12 margin).
        padding: const EdgeInsets.only(bottom: 76),
        child: FloatingActionButton(
          onPressed: _openCompose,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.edit_outlined),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _FeedSkeleton();
    if (_error != null) return _FeedError(message: _error!, onRetry: _loadFirstPage);
    if (_posts.isEmpty) return const _FeedEmpty();

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _posts.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= _posts.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        }
        final post = _posts[index];
        return PostCard(post: post, onTap: () => _openPost(post));
      },
    );
  }
}

class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                SkeletonBox(width: 42, height: 42, radius: 21),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(width: 110, height: 13, radius: 6),
                    SizedBox(height: 6),
                    SkeletonBox(width: 70, height: 10, radius: 6),
                  ],
                ),
              ],
            ),
            SizedBox(height: 14),
            SkeletonBox(width: double.infinity, height: 12, radius: 6),
            SizedBox(height: 8),
            SkeletonBox(width: 220, height: 12, radius: 6),
          ],
        ),
      ),
    );
  }
}

class _FeedEmpty extends StatelessWidget {
  const _FeedEmpty();

  @override
  Widget build(BuildContext context) {
    // Wrapped in a scroll view so pull-to-refresh still works when empty.
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
      children: [
        Icon(Icons.forum_outlined,
            size: 64, color: AppColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
        const Text(
          'No posts yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Be the first to share a plant or ask the community a question.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }
}

class _FeedError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FeedError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 120, 24, 100),
      children: [
        const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: 160,
            child: ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ),
        ),
      ],
    );
  }
}
