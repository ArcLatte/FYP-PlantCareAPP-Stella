from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django.contrib.auth.validators import UnicodeUsernameValidator
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.validators import validate_email
from django.utils import timezone
from datetime import datetime, time, timedelta, timezone as datetime_timezone
from .models import (
    CustomUser, Plant, PlantSpecies, Disease, ScanResult, Location, CareLog,
    Achievement, UserAchievement, Cosmetic, UserCosmetic,
)
from .achievements import check_achievements, progress_snapshot, PROGRESS
from .weekly import challenge_state, check_weekly_challenge
from .serializers import (
    PlantSerializer, PlantSpeciesSerializer, LocationSerializer,
    DiseaseSerializer, image_ref_to_url,
)
from PIL import Image, ImageOps, UnidentifiedImageError
import json

from .scanning_pipeline import default_scanning_pipeline, ScanStatus


# Above this top-1 confidence the model is treated as sure: the scan response
# flags the lower-ranked candidates as locked and scan_confirm rejects them.
CONFIRM_LOCK_THRESHOLD = 0.70


def _client_timezone(request):
    """Fixed UTC offset supplied by the app's current GPS/device timezone.

    Timestamps remain UTC; this is used only to decide which local calendar
    day an action belongs to. Invalid or absent values safely fall back to UTC.
    """
    raw = request.headers.get('X-Timezone-Offset-Minutes')
    if raw is None:
        raw = request.data.get('timezone_offset_minutes')
    try:
        minutes = int(raw)
    except (TypeError, ValueError):
        minutes = 0
    if minutes < -12 * 60 or minutes > 14 * 60:
        minutes = 0
    return datetime_timezone(timedelta(minutes=minutes))


def _client_local_date(request):
    return timezone.now().astimezone(_client_timezone(request)).date()


def _utc_day_bounds(start_date, end_date, client_timezone):
    """UTC half-open bounds covering inclusive client-local calendar dates."""
    start = datetime.combine(start_date, time.min, client_timezone)
    end = datetime.combine(end_date + timedelta(days=1), time.min, client_timezone)
    return start.astimezone(datetime_timezone.utc), end.astimezone(datetime_timezone.utc)


def _alternatives_locked(preds):
    """True when the top prediction is confident enough that only it may be
    confirmed. `preds` is a top3_predictions list ([{label, confidence}, ...])."""
    if not preds:
        return False
    try:
        return float(preds[0].get('confidence', 0)) >= CONFIRM_LOCK_THRESHOLD
    except (TypeError, AttributeError):
        return False

# ─── Gamification helper ─────────────────────────────────────────

def _grant_xp_and_check(user, amount: int) -> dict:
    """Award XP then run achievement + weekly-challenge checks (which may
    grant more XP / streak saves). Returns a dict to spread into a JSON
    response so the frontend can show the gain / level-up / unlocked-badge /
    challenge-complete toasts.
    """
    initial_level = user.level
    initial_seeds = user.seeds
    grant = user.award_xp(amount)
    newly = check_achievements(user)
    weekly = check_weekly_challenge(user)
    # If an achievement/challenge reward leveled us up, prefer the final level.
    leveled = grant['leveled_up'] or (user.level > initial_level)
    return {
        'xp_gained': (
            grant['xp_gained']
            + sum(a.xp_reward for a in newly)
            + (weekly['xp_reward'] if weekly else 0)
        ),
        # Snapshot delta: catches every payout source (level-ups, achievement
        # tiers, weekly bounty) no matter which check granted it.
        'seeds_gained': user.seeds - initial_seeds,
        'leveled_up_to': user.level if leveled else None,
        'unlocked': [
            {
                'code': a.code,
                'name': a.name,
                'icon': a.icon,
                'tier': a.tier,
                'xp_reward': a.xp_reward,
            }
            for a in newly
        ],
        'weekly_completed': weekly,
    }


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    username = request.data.get('username')
    email = request.data.get('email')
    password = request.data.get('password')

    if not username or not email or not password:
        return Response({'error': 'Username, email and password are required.'}, status=400)

    if CustomUser.objects.filter(username=username).exists():
        return Response({'error': 'Username already taken.'}, status=400)

    if CustomUser.objects.filter(email=email).exists():
        return Response({'error': 'Email already registered.'}, status=400)

    user = CustomUser.objects.create_user(username=username, email=email, password=password)
    token, _ = Token.objects.get_or_create(user=user)

    return Response({'token': token.key, 'username': user.username}, status=201)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    username = request.data.get('username')
    password = request.data.get('password')

    user = authenticate(username=username, password=password)

    if not user:
        return Response({'error': 'Invalid credentials.'}, status=400)

    token, _ = Token.objects.get_or_create(user=user)

    # Daily login bonus: only on the first login of the calendar day.
    client_timezone = _client_timezone(request)
    today = timezone.now().astimezone(client_timezone).date()
    last_local = (
        user.last_login.astimezone(client_timezone).date()
        if user.last_login else None
    )
    xp_result = {'xp_gained': 0, 'leveled_up_to': None, 'unlocked': []}
    if last_local != today:
        xp_result = _grant_xp_and_check(user, 10)
    user.last_login = timezone.now()
    user.save(update_fields=['last_login'])

    return Response({
        'token': token.key,
        'username': user.username,
        **xp_result,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    request.user.auth_token.delete()
    return Response({'message': 'Logged out.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    user = request.user
    old_password = request.data.get('old_password')
    new_password = request.data.get('new_password')

    if not user.check_password(old_password):
        return Response({'error': 'Old password is incorrect.'}, status=400)

    user.set_password(new_password)
    user.save()
    user.auth_token.delete()

    return Response({'message': 'Password changed. Please log in again.'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    """Permanently delete the account and everything cascaded from it
    (plants, logs, scans, and profile data). Requires the current password as confirmation."""
    password = request.data.get('password') or ''
    if not request.user.check_password(password):
        return Response({'error': 'Password is incorrect.'}, status=400)
    request.user.delete()
    return Response({'message': 'Account deleted.'})


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def plant_list(request):
    if request.method == 'GET':
        plants = Plant.objects.filter(user=request.user)
        serializer = PlantSerializer(plants, many=True)
        return Response(serializer.data)

    elif request.method == 'POST':
        serializer = PlantSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user=request.user)
            xp = _grant_xp_and_check(request.user, 20)
            return Response({**serializer.data, **xp}, status=201)
        return Response(serializer.errors, status=400)


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsAuthenticated])
def plant_detail(request, pk):
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    if request.method == 'GET':
        serializer = PlantSerializer(plant)
        return Response(serializer.data)

    elif request.method == 'PUT':
        serializer = PlantSerializer(plant, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=400)

    elif request.method == 'DELETE':
        plant.delete()
        return Response(status=204)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def water_plant(request, pk):
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    plant.last_watered = timezone.now()
    plant.save(update_fields=['last_watered'])
    care = request.user.register_care_activity(today=_client_local_date(request))
    CareLog.objects.create(user=request.user, plant=plant, activity='water')
    xp = _grant_xp_and_check(request.user, 5)
    serializer = PlantSerializer(plant)
    return Response({
        **serializer.data,
        **xp,
        'streak_saved': care['saved'],
        'freezes_left': care['freezes_left'],
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def fertilize_plant(request, pk):
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    if plant.species.default_fertilizer_freq_days is None:
        return Response(
            {'error': f'{plant.species.name} has no fertilizer schedule.'},
            status=400,
        )

    plant.last_fertilized = timezone.now()
    plant.save(update_fields=['last_fertilized'])
    care = request.user.register_care_activity(today=_client_local_date(request))
    CareLog.objects.create(user=request.user, plant=plant, activity='fertilize')
    xp = _grant_xp_and_check(request.user, 5)
    serializer = PlantSerializer(plant)
    return Response({
        **serializer.data,
        **xp,
        'streak_saved': care['saved'],
        'freezes_left': care['freezes_left'],
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mist_plant(request, pk):
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    if plant.species.default_misting_freq_days is None:
        return Response(
            {'error': f'{plant.species.name} does not need misting.'},
            status=400,
        )

    plant.last_misted = timezone.now()
    plant.save(update_fields=['last_misted'])
    care = request.user.register_care_activity(today=_client_local_date(request))
    CareLog.objects.create(user=request.user, plant=plant, activity='mist')
    xp = _grant_xp_and_check(request.user, 5)
    serializer = PlantSerializer(plant)
    return Response({
        **serializer.data,
        **xp,
        'streak_saved': care['saved'],
        'freezes_left': care['freezes_left'],
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_note(request, pk):
    """Append a free-text journal note to a plant. Unlike water/fertilize/mist
    this records only a timestamped note: it does not touch Plant.last_*, does
    not advance the care streak, and grants no XP (notes are unlimited free
    text). The note rides the same CareLog table so it merges into the History
    timeline. Returns the new entry in the activity-event shape so the client
    can prepend it without a full refresh."""
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    title = (request.data.get('title') or '').strip()[:120]
    text = (request.data.get('note') or '').strip()
    photo = request.FILES.get('photo')
    if not text and not photo and not title:
        return Response({'error': 'Add a note or a photo.'}, status=400)

    log = CareLog.objects.create(
        user=request.user, plant=plant, activity='note', note=text, title=title,
    )
    if photo:
        log.photo = photo
        log.save(update_fields=['photo'])
    # Notes grant no XP, but they count toward the weekly challenge (e.g.
    # "Journalist") — completing it here still pays its rewards immediately.
    weekly = check_weekly_challenge(request.user)
    extra = {}
    if weekly:
        extra = {
            'weekly_completed': weekly,
            'xp_gained': weekly['xp_reward'],
            'seeds_gained': weekly['seeds_reward'],
        }
    return Response({**_note_event(log, plant), **extra}, status=201)


def _note_event(log, plant):
    """Activity-event payload for a single journal note (shared by add/edit)."""
    return {
        'type': 'care',
        'activity': 'note',
        'id': log.id,
        'title': log.title,
        'note': log.note,
        'note_photo': log.photo.url if log.photo else None,
        'plant_id': plant.id,
        'plant_name': plant.name,
        'created_at': log.created_at,
    }


@api_view(['PUT', 'PATCH', 'DELETE'])
@permission_classes([IsAuthenticated])
def note_detail(request, pk, log_id):
    """Edit (PUT/PATCH) or delete (DELETE) a single journal note. Editing
    updates the text and, optionally, the photo: send a new `photo` file to
    replace it, or `remove_photo=true` to clear it."""
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)
    try:
        log = CareLog.objects.get(
            pk=log_id, plant=plant, user=request.user, activity='note')
    except CareLog.DoesNotExist:
        return Response({'error': 'Note not found.'}, status=404)

    if request.method == 'DELETE':
        log.delete()
        return Response(status=204)

    title = (request.data.get('title') or '').strip()[:120]
    text = (request.data.get('note') or '').strip()
    photo = request.FILES.get('photo')
    remove_photo = str(request.data.get('remove_photo', '')).lower() in (
        '1', 'true', 'yes')

    will_have_photo = bool(photo) or (bool(log.photo) and not remove_photo)
    if not text and not will_have_photo and not title:
        return Response({'error': 'Add a note or a photo.'}, status=400)

    log.title = title
    log.note = text
    if photo:
        log.photo = photo
    elif remove_photo:
        log.photo = None
    log.save()
    return Response(_note_event(log, plant), status=200)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def streak(request):
    u = request.user
    client_timezone = _client_timezone(request)
    today = timezone.now().astimezone(client_timezone).date()
    # Equipped companion pot style. Creature skin tints are no longer shown or
    # applied, but the response keeps `equipped_skin: null` for old clients.
    pot = (
        UserCosmetic.objects
        .filter(
            user=u,
            equipped=True,
            cosmetic__kind=Cosmetic.Kind.POT_STYLE,
        )
        .select_related('cosmetic')
        .first()
    )
    # Actual care days of the last week, so the day strip lights the days
    # that were really cared for. Deriving them client-side from the streak
    # count goes wrong once a save bridges a missed day (the count is
    # smaller than the calendar span, so the chain shifts). The strip shows
    # a rolling window centered on today (3 days back), so 7 days of
    # history is plenty.
    window_start = today - timedelta(days=6)
    utc_start, utc_end = _utc_day_bounds(window_start, today, client_timezone)
    week_days = (
        CareLog.objects
        .filter(
            user=u,
            created_at__gte=utc_start,
            created_at__lt=utc_end,
        )
        .exclude(activity=CareLog.Activity.NOTE)
        .datetimes('created_at', 'day', tzinfo=client_timezone)
    )
    return Response({
        'current_streak': u.effective_streak_for(today),
        'longest_streak': u.longest_streak,
        'last_care_date': u.last_care_date,
        'active_today': u.last_care_date == today,
        # Server's "today". Care days are dated on the server clock, so the
        # strip must build its window around the server's today too —
        # otherwise a device clock a day off pushes a just-logged care day
        # into a "future" cell and it never lights.
        'today': today.isoformat(),
        'freezes': u.streak_freezes,
        'freeze_active': u.freeze_active_for(today),
        'recent_care_days': [d.date().isoformat() for d in week_days],
        # Kept for old clients; tint skins are no longer applied.
        # or null — the Tasks scene applies it to the companion.
        'equipped_skin': None,
        # Equipped pot-style payload ({'body': '#hex', 'rim': '#hex', ...})
        # or null — the client falls back to the default terracotta pot.
        'equipped_pot': pot.cosmetic.payload if pot else None,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def streak_calendar(request):
    """Full care-day history for the streak calendar: every calendar day with
    at least one water/fertilize/mist action (notes don't count — they don't
    advance the streak either), oldest first, plus the streak summary."""
    u = request.user
    client_timezone = _client_timezone(request)
    today = timezone.now().astimezone(client_timezone).date()
    days = (
        CareLog.objects
        .filter(user=u)
        .exclude(activity=CareLog.Activity.NOTE)
        .datetimes('created_at', 'day', tzinfo=client_timezone)
    )
    return Response({
        'care_dates': [d.date().isoformat() for d in days],
        'current_streak': u.effective_streak_for(today),
        'longest_streak': u.longest_streak,
        'last_care_date': u.last_care_date,
        'active_today': u.last_care_date == today,
        'today': today.isoformat(),  # server date, so the calendar's "today"
        'freeze_active': u.freeze_active_for(today),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def weekly_challenge(request):
    """The current week's challenge with the user's live progress."""
    return Response(challenge_state(request.user))


def _scan_label_health(scan):
    """Return (label, health) for a scan: confirmed disease if present,
    else the top model prediction. health is 'healthy'/'diseased'/None."""
    label = None
    if scan.disease_id:
        label = scan.disease.label
    elif scan.top3_predictions:
        top = scan.top3_predictions[0]
        if isinstance(top, dict):
            label = top.get('label')
    if not label:
        return None, None
    health = 'healthy' if 'healthy' in label.lower() else 'diseased'
    return label, health


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def activity(request):
    """Unified, reverse-chronological feed of the user's plant activity:
    care actions (water/fertilize/mist) merged with disease scans."""
    events = []

    care_logs = (
        CareLog.objects
        .filter(user=request.user)
        .select_related('plant')[:100]
    )
    for log in care_logs:
        events.append({
            'type': 'care',
            'activity': log.activity,
            'id': log.id,
            'title': log.title,
            'note': log.note,
            'note_photo': log.photo.url if log.photo else None,
            'plant_id': log.plant_id,
            'plant_name': log.plant.name,
            'created_at': log.created_at,
        })

    scans = (
        ScanResult.objects
        .filter(plant__user=request.user)
        .select_related('plant', 'disease')
        .order_by('-created_at')[:100]
    )
    for s in scans:
        label, health = _scan_label_health(s)
        events.append({
            'type': 'scan',
            'scan_id': s.id,
            'plant_id': s.plant_id,
            'plant_name': s.plant.name,
            'label': label,
            'health': health,
            'created_at': s.created_at,
        })

    events.sort(key=lambda e: e['created_at'], reverse=True)
    return Response(events[:100])


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def location_list(request):
    if request.method == 'GET':
        locations = Location.objects.filter(user=request.user)
        serializer = LocationSerializer(locations, many=True)
        return Response(serializer.data)

    # POST
    name = (request.data.get('name') or '').strip()
    if not name:
        return Response({'error': 'Name is required.'}, status=400)

    # Idempotent: return existing entry if user already saved this name
    location, _created = Location.objects.get_or_create(
        user=request.user,
        name=name,
    )
    serializer = LocationSerializer(location)
    return Response(serializer.data, status=201)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def location_detail(request, pk):
    try:
        location = Location.objects.get(pk=pk, user=request.user)
    except Location.DoesNotExist:
        return Response({'error': 'Location not found.'}, status=404)
    location.delete()
    return Response(status=204)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def species_list(request):
    species = PlantSpecies.objects.all()
    serializer = PlantSpeciesSerializer(species, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def species_detail(request, pk):
    """Full reference entry for one species. Powers the Library species page."""
    try:
        species = PlantSpecies.objects.get(pk=pk)
    except PlantSpecies.DoesNotExist:
        return Response({'error': 'Species not found.'}, status=404)
    return Response(PlantSpeciesSerializer(species).data)


def _enrich_predictions(preds):
    """Attach the disease display `name` + first reference `image` to each
    top-N prediction so the scan result cards can show an example photo and a
    friendly name without extra requests. Unknown labels are passed through."""
    if not preds:
        return preds
    labels = [p.get('label') for p in preds if isinstance(p, dict)]
    by_label = {d.label: d for d in Disease.objects.filter(label__in=labels)}
    enriched = []
    for p in preds:
        if not isinstance(p, dict):
            enriched.append(p)
            continue
        item = dict(p)
        d = by_label.get(p.get('label'))
        if d:
            item['name'] = d.name
            imgs = d.image_urls or []
            item['image'] = image_ref_to_url(
                imgs[0] if imgs else (d.image_url or None)
            )
        enriched.append(item)
    return enriched


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def scan(request):
    image_file = request.FILES.get('image')
    plant_id = request.data.get('plant_id')

    if not image_file or not plant_id:
        return Response({'error': 'Image and plant_id are required.'}, status=400)

    try:
        plant = Plant.objects.get(pk=plant_id, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    try:
        # Apply camera orientation before quality checks and inference so width,
        # height and model input all describe the same visible image.
        image = ImageOps.exif_transpose(Image.open(image_file)).convert('RGB')
    except (UnidentifiedImageError, OSError, ValueError):
        return Response({
            'error': 'The uploaded file is not a valid image. Please choose a '
                     'JPEG or PNG photo and try again.',
            'code': 'invalid_image',
            'action': 'retake',
        }, status=status.HTTP_400_BAD_REQUEST)

    analysis = default_scanning_pipeline.analyze(image, plant.species.name)
    if analysis.status is ScanStatus.QUALITY_REJECTED:
        primary_issue = analysis.quality['issues'][0]
        return Response({
            'error': primary_issue['message'],
            'code': primary_issue['code'],
            'action': 'retake',
            'quality': analysis.quality,
        }, status=status.HTTP_422_UNPROCESSABLE_ENTITY)

    if analysis.status is ScanStatus.NO_LEAF:
        return Response({
            'error': 'No leaf was detected. Move closer and center one plant '
                     'leaf in the frame, then retake the photo.',
            'code': 'no_leaf_detected',
            'action': 'retake',
            'leaf_gate': analysis.leaf_gate,
        }, status=status.HTTP_422_UNPROCESSABLE_ENTITY)

    if analysis.status is ScanStatus.UNSUPPORTED_SPECIES:
        return Response(
            {'error': f'Disease detection is not available for '
                      f'{plant.species.name} yet.'},
            status=400,
        )

    # Pillow reads from the upload before Django persists it below.
    image_file.seek(0)

    top3_predictions = analysis.predictions

    top_label = top3_predictions[0]['label']
    top_confidence = top3_predictions[0]['confidence']

    # Save scan result
    scan_result = ScanResult.objects.create(
        plant=plant,
        image=image_file,
        confidence_score=top_confidence,
        top3_predictions=top3_predictions,
    )

    xp = _grant_xp_and_check(request.user, 5)

    return Response({
        'scan_id': scan_result.id,
        'image': request.build_absolute_uri(scan_result.image.url) if scan_result.image else None,
        'top3': _enrich_predictions(top3_predictions),
        'predicted_label': top_label,
        'confidence': top_confidence,
        'alternatives_locked': _alternatives_locked(top3_predictions),
        **xp,
    }, status=201)
    
    
@api_view(['PUT'])
@permission_classes([IsAuthenticated])
def scan_confirm(request, pk):
    try:
        scan_result = ScanResult.objects.get(pk=pk, plant__user=request.user)
    except ScanResult.DoesNotExist:
        return Response({'error': 'Scan not found.'}, status=404)

    label = request.data.get('label')

    # High-confidence scans may only be confirmed as the top prediction — the
    # same rule the result screen enforces by locking the alternative cards.
    preds = scan_result.top3_predictions or []
    if _alternatives_locked(preds) and label != preds[0].get('label'):
        return Response(
            {'error': 'High-confidence result — only the top prediction can be confirmed.'},
            status=400,
        )

    try:
        disease = Disease.objects.get(label=label)
    except Disease.DoesNotExist:
        return Response({'error': 'Disease label not found.'}, status=404)

    scan_result.disease = disease
    scan_result.save()

    return Response({
        'scan_id': scan_result.id,
        'plant_id': scan_result.plant_id,
        'image': request.build_absolute_uri(scan_result.image.url) if scan_result.image else None,
        'top3': scan_result.top3_predictions,
        'disease': disease.label,
        'disease_name': disease.name,
        'confirmed_label': disease.label,
        'treatment': disease.treatment,
        'care_tips': disease.care_tips,
        'created_at': scan_result.created_at,
    })
    
    
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def plant_scan_history(request, pk):
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    scans = ScanResult.objects.filter(plant=plant).order_by('-created_at')
    data = [
        {
            'scan_id': s.id,
            'predicted_label': s.top3_predictions[0]['label'] if s.top3_predictions else None,
            'confidence': s.confidence_score,
            'created_at': s.created_at,
        }
        for s in scans
    ]
    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def plant_activity(request, pk):
    """Per-plant version of `activity`: a reverse-chronological feed of one
    plant's care actions (water/fertilize/mist) merged with its disease scans.
    Powers the History timeline on the plant profile. Same shape as `/activity/`."""
    try:
        plant = Plant.objects.get(pk=pk, user=request.user)
    except Plant.DoesNotExist:
        return Response({'error': 'Plant not found.'}, status=404)

    events = []

    care_logs = CareLog.objects.filter(plant=plant)[:100]
    for log in care_logs:
        events.append({
            'type': 'care',
            'activity': log.activity,
            'id': log.id,
            'title': log.title,
            'note': log.note,
            'note_photo': log.photo.url if log.photo else None,
            'plant_id': plant.id,
            'plant_name': plant.name,
            'created_at': log.created_at,
        })

    scans = (
        ScanResult.objects
        .filter(plant=plant)
        .select_related('disease')
        .order_by('-created_at')[:100]
    )
    for s in scans:
        label, health = _scan_label_health(s)
        events.append({
            'type': 'scan',
            'scan_id': s.id,
            'plant_id': plant.id,
            'plant_name': plant.name,
            'label': label,
            'health': health,
            'created_at': s.created_at,
        })

    events.sort(key=lambda e: e['created_at'], reverse=True)
    return Response(events[:100])


@api_view(['GET', 'DELETE'])
@permission_classes([IsAuthenticated])
def scan_detail(request, pk):
    try:
        scan = ScanResult.objects.get(pk=pk, plant__user=request.user)
    except ScanResult.DoesNotExist:
        return Response({'error': 'Scan not found.'}, status=404)

    if request.method == 'GET':
        return Response({
            'scan_id': scan.id,
            'plant': scan.plant.name,
            'plant_id': scan.plant_id,
            'image': request.build_absolute_uri(scan.image.url) if scan.image else None,
            'top3': _enrich_predictions(scan.top3_predictions),
            'predicted_label': scan.top3_predictions[0]['label'] if scan.top3_predictions else None,
            'confidence': scan.confidence_score,
            'alternatives_locked': _alternatives_locked(scan.top3_predictions),
            'disease': scan.disease.label if scan.disease else None,
            'disease_name': scan.disease.name if scan.disease else None,
            'treatment': scan.disease.treatment if scan.disease else None,
            'care_tips': scan.disease.care_tips if scan.disease else None,
            'created_at': scan.created_at,
        })

    elif request.method == 'DELETE':
        scan.delete()
        return Response(status=204)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def all_scans(request):
    scans = ScanResult.objects.filter(plant__user=request.user).order_by('-created_at')
    data = [
        {
            'scan_id': s.id,
            'plant': s.plant.name,
            'predicted_label': s.top3_predictions[0]['label'] if s.top3_predictions else None,
            'confidence': s.confidence_score,
            'created_at': s.created_at,
        }
        for s in scans
    ]
    return Response(data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def diseases_list(request):
    """All diseases for the Library, excluding the "Healthy" pseudo-entries
    (they describe a healthy plant, not a disease to read about)."""
    diseases = (
        Disease.objects
        .exclude(label__icontains='healthy')
        .select_related('species')
        .order_by('name')
    )
    return Response(DiseaseSerializer(diseases, many=True).data)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def disease_detail(request, label):
    """Full knowledge-base entry for a disease, keyed by its model label.

    Powers the in-app disease detail ("read more") page.
    """
    try:
        disease = Disease.objects.get(label=label)
    except Disease.DoesNotExist:
        return Response({'error': 'Disease not found.'}, status=404)
    return Response(DiseaseSerializer(disease).data)


# ─── Gamification: profile + achievements ───────────────────────

def _profile_payload(u, today):
    unlocked = UserAchievement.objects.filter(user=u).count()
    total = Achievement.objects.count()
    return {
        'username': u.username,
        'email': u.email,
        # Relative /media/ URL — the Flutter side absolutizes it (same
        # convention as uploaded plant photos).
        'avatar': u.avatar.url if u.avatar else None,
        'level': u.level,
        'tier': u.tier,
        'xp': u.xp,
        'xp_into_level': u.xp_into_level,
        'xp_for_next_level': u.xp_for_next_level,
        'current_streak': u.effective_streak_for(today),
        'longest_streak': u.longest_streak,
        'freezes': u.streak_freezes,
        'seeds': u.seeds,
        'achievements_unlocked': unlocked,
        'achievements_total': total,
    }


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated])
def profile(request):
    """GET the profile summary, or PATCH account fields from Settings.

    PATCH accepts any subset of `username`, `email`, `avatar` (multipart
    file) and `remove_avatar`, and returns the fresh profile payload."""
    u = request.user

    if request.method == 'PATCH':
        username = request.data.get('username')
        if username is not None:
            username = username.strip()
            try:
                UnicodeUsernameValidator()(username)
            except DjangoValidationError:
                return Response(
                    {'error': 'Username may only contain letters, digits '
                              'and @/./+/-/_.'},
                    status=400,
                )
            if len(username) > 150:
                return Response({'error': 'Username is too long.'}, status=400)
            if (CustomUser.objects.exclude(pk=u.pk)
                    .filter(username=username).exists()):
                return Response({'error': 'Username already taken.'}, status=400)
            u.username = username

        email = request.data.get('email')
        if email is not None:
            email = email.strip()
            try:
                validate_email(email)
            except DjangoValidationError:
                return Response({'error': 'Enter a valid email address.'}, status=400)
            if (CustomUser.objects.exclude(pk=u.pk)
                    .filter(email=email).exists()):
                return Response({'error': 'Email already registered.'}, status=400)
            u.email = email

        if 'avatar' in request.FILES:
            if u.avatar:
                u.avatar.delete(save=False)  # drop the old file from storage
            u.avatar = request.FILES['avatar']
        elif request.data.get('remove_avatar') in (True, 'true', 'True', '1', 1):
            if u.avatar:
                u.avatar.delete(save=False)
            u.avatar = None

        u.save()

    return Response(_profile_payload(u, _client_local_date(request)))


def _serialize_achievement(ach, user_view, snapshot=None):
    data = {
        'code': ach.code,
        'name': ach.name,
        'description': ach.description,
        'icon': ach.icon,
        'tier': ach.tier,
        'xp_reward': ach.xp_reward,
        'unlocked': user_view is not None,
        'unlocked_at': user_view.unlocked_at if user_view else None,
        'is_pinned': bool(user_view and user_view.is_pinned),
    }
    # Progress toward locked achievements ("12/50"), when a snapshot of the
    # user's counters is supplied and the code has a registered metric.
    if snapshot is not None and user_view is None:
        metric = PROGRESS.get(ach.code)
        if metric is not None:
            key, target = metric
            data['progress_current'] = min(snapshot.get(key, 0), target)
            data['progress_target'] = target
    return data


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def achievements_list(request):
    own = {
        ua.achievement_id: ua
        for ua in UserAchievement.objects.filter(user=request.user)
    }
    snapshot = progress_snapshot(request.user)
    data = [
        _serialize_achievement(a, own.get(a.id), snapshot)
        for a in Achievement.objects.all()
    ]
    return Response(data)


# One pin per slot in the profile's honeycomb medal case (4 + 5 + 4 hive rows).
PIN_CAP = 13


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def pin_achievement(request, code):
    try:
        ua = UserAchievement.objects.select_related('achievement').get(
            user=request.user,
            achievement__code=code,
        )
    except UserAchievement.DoesNotExist:
        return Response({'error': 'Achievement not unlocked.'}, status=404)

    if not ua.is_pinned:
        pinned = UserAchievement.objects.filter(
            user=request.user, is_pinned=True,
        ).count()
        if pinned >= PIN_CAP:
            return Response(
                {'error': f'Pin cap reached ({PIN_CAP}). Unpin one first.'},
                status=400,
            )
        ua.is_pinned = True
        ua.save(update_fields=['is_pinned'])
    return Response(_serialize_achievement(ua.achievement, ua))


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unpin_achievement(request, code):
    try:
        ua = UserAchievement.objects.select_related('achievement').get(
            user=request.user,
            achievement__code=code,
        )
    except UserAchievement.DoesNotExist:
        return Response({'error': 'Achievement not unlocked.'}, status=404)

    if ua.is_pinned:
        ua.is_pinned = False
        ua.save(update_fields=['is_pinned'])
    return Response(_serialize_achievement(ua.achievement, ua))


# ─── Gamification: seed shop ─────────────────────────────────────

def _serialize_cosmetic(c, owned_row):
    return {
        'code': c.code,
        'name': c.name,
        'description': c.description,
        'kind': c.kind,
        'rarity': c.rarity,
        'cost_seeds': c.cost_seeds,
        'payload': c.payload,
        'owned': owned_row is not None,
        'equipped': bool(owned_row and owned_row.equipped),
    }


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def shop(request):
    """The full cosmetic catalog with the user's balance/ownership state."""
    owned = {
        uc.cosmetic_id: uc
        for uc in UserCosmetic.objects.filter(user=request.user)
    }
    return Response({
        'seeds': request.user.seeds,
        'items': [
            _serialize_cosmetic(c, owned.get(c.id))
            for c in Cosmetic.objects.exclude(kind=Cosmetic.Kind.CREATURE_SKIN)
        ],
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def shop_buy(request, code):
    try:
        cosmetic = Cosmetic.objects.get(code=code)
    except Cosmetic.DoesNotExist:
        return Response({'error': 'Item not found.'}, status=404)

    u = request.user
    if UserCosmetic.objects.filter(user=u, cosmetic=cosmetic).exists():
        return Response({'error': 'Already owned.'}, status=400)
    if u.seeds < cosmetic.cost_seeds:
        return Response(
            {'error': f'Not enough seeds ({u.seeds}/{cosmetic.cost_seeds}).'},
            status=400,
        )

    u.seeds -= cosmetic.cost_seeds
    u.save(update_fields=['seeds'])
    row = UserCosmetic.objects.create(user=u, cosmetic=cosmetic)
    return Response({
        'seeds': u.seeds,
        'item': _serialize_cosmetic(cosmetic, row),
    }, status=201)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def shop_equip(request, code):
    """Equip an owned cosmetic (unequips any other of the same kind), or
    unequip it if it's the one currently equipped — a simple toggle."""
    try:
        row = UserCosmetic.objects.select_related('cosmetic').get(
            user=request.user, cosmetic__code=code,
        )
    except UserCosmetic.DoesNotExist:
        return Response({'error': 'Item not owned.'}, status=404)

    if row.equipped:
        row.equipped = False
        row.save(update_fields=['equipped'])
    else:
        UserCosmetic.objects.filter(
            user=request.user,
            cosmetic__kind=row.cosmetic.kind,
            equipped=True,
        ).update(equipped=False)
        row.equipped = True
        row.save(update_fields=['equipped'])
    return Response({
        'seeds': request.user.seeds,
        'item': _serialize_cosmetic(row.cosmetic, row),
    })
