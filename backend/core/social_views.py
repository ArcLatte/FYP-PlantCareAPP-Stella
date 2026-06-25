"""Views for the social layer (feed + posts).

Mirrors the conventions in `views.py`: function-based DRF views, token auth via
`IsAuthenticated`, manual validation, `{'error': ...}` payloads, and 404 for
resources the caller doesn't own. Kept separate so `views.py` (ML + plant care)
stays focused.

Phase 1 wires the feed + post CRUD. Likes/comments/follows/communities get
their own views in later phases against the schema already in place.
"""

import base64

from django.db.models import Q
from django.utils.dateparse import parse_datetime
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from .models import Post, Plant, Community
from .serializers import PostSerializer

# How many posts per feed page. Fetch one extra to detect "has next" without a
# COUNT(*).
FEED_PAGE_SIZE = 20


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def post_list(request):
    if request.method == 'GET':
        return _feed(request)
    return _create_post(request)


def _feed(request):
    """Global reverse-chronological feed with keyset (cursor) pagination.

    Ordered by (-created_at, -id). The cursor encodes the last seen post as
    "<created_at_iso>_<id>"; the next page is everything strictly older than
    that, which keeps paging stable even as new posts arrive at the top.
    """
    qs = (
        Post.objects
        .select_related('author', 'plant', 'plant__species', 'community')
        .order_by('-created_at', '-id')
    )

    cursor = request.query_params.get('cursor')
    if cursor:
        ts, last_id = _parse_cursor(cursor)
        if ts is not None and last_id is not None:
            qs = qs.filter(
                Q(created_at__lt=ts) | Q(created_at=ts, id__lt=last_id)
            )

    rows = list(qs[:FEED_PAGE_SIZE + 1])
    has_more = len(rows) > FEED_PAGE_SIZE
    rows = rows[:FEED_PAGE_SIZE]

    next_cursor = None
    if has_more and rows:
        next_cursor = _encode_cursor(rows[-1])

    return Response({
        'results': PostSerializer(rows, many=True).data,
        'next': next_cursor,
    })


def _encode_cursor(post):
    """Opaque, URL-safe cursor for [post]. Base64 keeps the `+`/`:` of the ISO
    timestamp from being mangled in a query string (a raw `+` decodes to a
    space), so paging is robust however the token is transported."""
    raw = f"{post.created_at.isoformat()}_{post.id}"
    return base64.urlsafe_b64encode(raw.encode()).decode()


def _parse_cursor(cursor):
    """Decode a cursor back to (datetime, int). Returns (None, None) if
    malformed — a bad cursor just yields the first page rather than erroring."""
    try:
        raw = base64.urlsafe_b64decode(cursor.encode()).decode()
        ts_raw, id_raw = raw.rsplit('_', 1)
        return parse_datetime(ts_raw), int(id_raw)
    except (ValueError, AttributeError, TypeError):
        return None, None


def _create_post(request):
    """Create a post. Requires text OR an image. Optionally attaches one of the
    author's own tracked plants and/or a community."""
    body = (request.data.get('body') or '').strip()
    image = request.FILES.get('image')
    if not body and not image:
        return Response(
            {'error': 'Add some text or a photo to post.'}, status=400,
        )

    plant = None
    plant_id = request.data.get('plant_id')
    if plant_id:
        try:
            plant = Plant.objects.get(pk=plant_id, user=request.user)
        except Plant.DoesNotExist:
            return Response({'error': 'Plant not found.'}, status=404)

    community = None
    community_id = request.data.get('community_id')
    if community_id:
        try:
            community = Community.objects.get(pk=community_id)
        except Community.DoesNotExist:
            return Response({'error': 'Community not found.'}, status=404)

    post = Post.objects.create(
        author=request.user,
        body=body,
        image=image,
        plant=plant,
        community=community,
    )
    # Re-fetch through the select_related path so the response matches the feed
    # shape (author/plant/community all populated).
    post = (
        Post.objects
        .select_related('author', 'plant', 'plant__species', 'community')
        .get(pk=post.pk)
    )
    return Response(PostSerializer(post).data, status=201)


@api_view(['GET', 'DELETE'])
@permission_classes([IsAuthenticated])
def post_detail(request, pk):
    try:
        post = (
            Post.objects
            .select_related('author', 'plant', 'plant__species', 'community')
            .get(pk=pk)
        )
    except Post.DoesNotExist:
        return Response({'error': 'Post not found.'}, status=404)

    if request.method == 'GET':
        return Response(PostSerializer(post).data)

    # DELETE — author only. 404 (not 403) for non-owners, matching the
    # isolation pattern used elsewhere in the API.
    if post.author_id != request.user.id:
        return Response({'error': 'Post not found.'}, status=404)
    post.delete()
    return Response(status=204)
