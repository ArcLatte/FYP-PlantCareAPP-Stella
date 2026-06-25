import '../core/constants.dart';

/// A social post in the feed. Twitter-style: has [body] text and/or an
/// [imageUrl], an [author], and optional attached [plant] / [community].
class Post {
  final int id;
  final String body;
  final String? imageUrl;
  final PostAuthor author;
  final PostPlant? plant;
  final PostCommunity? community;
  final int likeCount;
  final int commentCount;
  final DateTime? createdAt;

  Post({
    required this.id,
    required this.body,
    this.imageUrl,
    required this.author,
    this.plant,
    this.community,
    this.likeCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: (json['id'] as num).toInt(),
      body: json['body']?.toString() ?? '',
      imageUrl: _absoluteUrl(json['image']),
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>),
      plant: json['plant'] is Map<String, dynamic>
          ? PostPlant.fromJson(json['plant'])
          : null,
      community: json['community'] is Map<String, dynamic>
          ? PostCommunity.fromJson(json['community'])
          : null,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      createdAt: _parseDate(json['created_at']),
    );
  }
}

/// One page of the feed: the posts plus the cursor for the next page (null
/// when there are no more).
class FeedPage {
  final List<Post> posts;
  final String? nextCursor;

  FeedPage({required this.posts, this.nextCursor});

  factory FeedPage.fromJson(Map<String, dynamic> json) {
    final results = (json['results'] as List? ?? const [])
        .map((p) => Post.fromJson(p as Map<String, dynamic>))
        .toList();
    return FeedPage(posts: results, nextCursor: json['next']?.toString());
  }
}

/// Minimal author identity embedded in a post (byline + tier-framed avatar).
class PostAuthor {
  final String username;
  final int level;
  final String tier;

  PostAuthor({
    required this.username,
    this.level = 1,
    this.tier = 'Seedling',
  });

  /// First letter of the username, for the placeholder avatar.
  String get initial =>
      username.isEmpty ? '?' : username[0].toUpperCase();

  factory PostAuthor.fromJson(Map<String, dynamic> json) {
    return PostAuthor(
      username: json['username']?.toString() ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      tier: json['tier']?.toString() ?? 'Seedling',
    );
  }
}

/// Summary of a tracked plant attached to a post (the chip on the card).
class PostPlant {
  final int id;
  final String name;
  final String speciesName;
  final String? photoUrl;

  PostPlant({
    required this.id,
    required this.name,
    this.speciesName = '',
    this.photoUrl,
  });

  factory PostPlant.fromJson(Map<String, dynamic> json) {
    return PostPlant(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      speciesName: json['species_name']?.toString() ?? '',
      photoUrl: _absoluteUrl(json['photo']),
    );
  }
}

/// Summary of a community a post belongs to.
class PostCommunity {
  final int id;
  final String name;
  final String slug;
  final String icon;
  final String color;

  PostCommunity({
    required this.id,
    required this.name,
    this.slug = '',
    this.icon = '',
    this.color = '',
  });

  factory PostCommunity.fromJson(Map<String, dynamic> json) {
    return PostCommunity(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      color: json['color']?.toString() ?? '',
    );
  }
}

/// Absolutize a relative `/media/...` URL returned by Django (same convention
/// as plant.dart).
String? _absoluteUrl(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  if (s.startsWith('http://') || s.startsWith('https://')) return s;
  if (s.startsWith('/')) return '${AppConstants.mediaHost}$s';
  return '${AppConstants.mediaHost}/$s';
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}
