import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/post.dart';
import 'skeleton.dart';
import 'tier_frame.dart';

/// A single post in the feed. Shows the author (tier-framed avatar + byline),
/// optional community chip, body text, optional image, and an optional
/// attached-plant chip. Tapping anywhere opens the post (via [onTap]).
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onTap;

  const PostCard({super.key, required this.post, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthorRow(post: post),
            if (post.body.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(post.body, style: Theme.of(context).textTheme.bodyLarge),
            ],
            if (post.hasImage) ...[
              const SizedBox(height: 12),
              _PostImage(url: post.imageUrl!),
            ],
            if (post.plant != null) ...[
              const SizedBox(height: 12),
              _PlantChip(plant: post.plant!),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final Post post;
  const _AuthorRow({required this.post});

  @override
  Widget build(BuildContext context) {
    final author = post.author;
    return Row(
      children: [
        PostAvatar(author: author, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      author.username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (post.community != null) ...[
                    const SizedBox(width: 8),
                    _CommunityChip(community: post.community!),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${author.tier} · ${timeAgo(post.createdAt)}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tier-framed circular avatar showing the author's initial. Reused by the
/// feed and post detail.
class PostAvatar extends StatelessWidget {
  final PostAuthor author;
  final double size;

  const PostAvatar({super.key, required this.author, this.size = 42});

  @override
  Widget build(BuildContext context) {
    final color = TierFrame.tierColor(author.tier);
    return TierFrame(
      tier: author.tier,
      size: size,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.18),
        ),
        alignment: Alignment.center,
        child: Text(
          author.initial,
          style: TextStyle(
            color: color,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CommunityChip extends StatelessWidget {
  final PostCommunity community;
  const _CommunityChip({required this.community});

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(community.color) ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        community.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String url;
  const _PostImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 360),
        child: CachedNetworkImage(
          imageUrl: url,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, _) =>
              const SizedBox(height: 200, child: SkeletonBox(radius: 12)),
          errorWidget: (context, _, _) => Container(
            height: 160,
            color: AppColors.surfaceLight,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _PlantChip extends StatelessWidget {
  final PostPlant plant;
  const _PlantChip({required this.plant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 36,
              height: 36,
              child: plant.photoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: plant.photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, _) =>
                          const SkeletonBox(radius: 8),
                      errorWidget: (context, _, _) =>
                          const _PlantPlaceholder(),
                    )
                  : const _PlantPlaceholder(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  plant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (plant.speciesName.isNotEmpty)
                  Text(
                    plant.speciesName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(Icons.eco_rounded, size: 16, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _PlantPlaceholder extends StatelessWidget {
  const _PlantPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      alignment: Alignment.center,
      child: const Icon(Icons.eco_outlined, size: 18, color: AppColors.textMuted),
    );
  }
}

/// Compact relative timestamp ("just now", "5m", "3h", "2d", or a date).
String timeAgo(DateTime? when) {
  if (when == null) return '';
  final diff = DateTime.now().difference(when);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  final local = when.toLocal();
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}';
}

Color? _parseHex(String hex) {
  var h = hex.trim();
  if (h.isEmpty) return null;
  if (h.startsWith('#')) h = h.substring(1);
  if (h.length == 6) h = 'FF$h';
  final value = int.tryParse(h, radix: 16);
  return value == null ? null : Color(value);
}
