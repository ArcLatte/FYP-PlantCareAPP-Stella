"""Social layer models — the "plant Twitter" feature.

Kept in their own module so `models.py` stays readable; they're imported back
into `core.models` (bottom of that file) so Django registers them under the
`core` app and migrations live alongside the rest. Foreign keys use string
references (`'CustomUser'`, `'Plant'`, …) so this module doesn't import from
`models.py` — avoids a circular import.

Phase 1 (MVP) only wires up Post + the feed; the rest of the schema
(Community, Follow, likes, comments) is created up front so later phases add
endpoints/UI without further migrations.
"""

from django.db import models
from django.utils import timezone


class Community(models.Model):
    """A plant-topic community users can post into and (later) join, e.g.
    "Tomatoes", "Succulents", "Disease Help". Seeded via a management command
    in the Communities phase."""

    name = models.CharField(max_length=60, unique=True)
    slug = models.SlugField(max_length=60, unique=True)
    description = models.TextField(blank=True)
    icon = models.CharField(max_length=40, blank=True)   # Material icon name
    color = models.CharField(max_length=9, blank=True)   # hex, e.g. "#4CAF7D"
    cover = models.ImageField(upload_to='communities/', null=True, blank=True)
    # Denormalized so the browse list doesn't COUNT memberships per row.
    member_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name_plural = 'Communities'
        ordering = ['name']

    def __str__(self):
        return self.name


class CommunityMembership(models.Model):
    """Join row: a user is a member of a community."""

    user = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='community_memberships',
    )
    community = models.ForeignKey(
        'Community',
        on_delete=models.CASCADE,
        related_name='memberships',
    )
    joined_at = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ('user', 'community')
        ordering = ['-joined_at']

    def __str__(self):
        return f"{self.user.username} ∈ {self.community.slug}"


class Post(models.Model):
    """A short-form, Twitter-style post. Needs text OR an image (enforced in
    the create view). May optionally belong to a Community and/or reference one
    of the author's tracked Plants."""

    author = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='posts',
    )
    body = models.TextField(blank=True)
    image = models.ImageField(upload_to='posts/', null=True, blank=True)
    community = models.ForeignKey(
        'Community',
        on_delete=models.SET_NULL,
        related_name='posts',
        null=True,
        blank=True,
    )
    # SET_NULL: deleting a tracked plant shouldn't erase the user's posts about
    # it — the post just loses its plant chip.
    plant = models.ForeignKey(
        'Plant',
        on_delete=models.SET_NULL,
        related_name='posts',
        null=True,
        blank=True,
    )
    # Denormalized engagement counters (kept in sync by the like/comment views
    # in Phase 2) so the feed query stays a single SELECT.
    like_count = models.PositiveIntegerField(default=0)
    comment_count = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        preview = self.body[:40] + ('…' if len(self.body) > 40 else '')
        return f"Post #{self.id} by {self.author_id}: {preview}"


class Follow(models.Model):
    """Directed follow edge: `follower` follows `following`. Self-follows are
    blocked in the view."""

    follower = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='following_set',
    )
    following = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='follower_set',
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ('follower', 'following')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.follower_id} → {self.following_id}"


class PostLike(models.Model):
    """One like by a user on a post. Uniqueness makes liking idempotent."""

    user = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='post_likes',
    )
    post = models.ForeignKey(
        'Post',
        on_delete=models.CASCADE,
        related_name='likes',
    )
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        unique_together = ('user', 'post')
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user_id} ♥ post #{self.post_id}"


class Comment(models.Model):
    """A reply on a post. Ordered oldest-first for thread display."""

    post = models.ForeignKey(
        'Post',
        on_delete=models.CASCADE,
        related_name='comments',
    )
    author = models.ForeignKey(
        'CustomUser',
        on_delete=models.CASCADE,
        related_name='comments',
    )
    body = models.TextField()
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"Comment by {self.author_id} on post #{self.post_id}"
