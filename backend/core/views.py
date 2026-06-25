from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from django.utils import timezone
from .models import (
    CustomUser, Plant, PlantSpecies, Disease, ScanResult, Location, CareLog,
    Achievement, UserAchievement,
)
from .achievements import check_achievements, progress_snapshot, PROGRESS
from .serializers import (
    PlantSerializer, PlantSpeciesSerializer, LocationSerializer,
    DiseaseSerializer,
)
import torch
import torchvision.transforms as transforms
from torchvision import models
from PIL import Image
import json
import os


# Load model once at startup
MODEL_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'ml', 'tomato_model.pth')

CLASS_NAMES = [
    'Tomato_Bacterial_spot',
    'Tomato_Early_blight',
    'Tomato_Late_blight',
    'Tomato_Leaf_Mold',
    'Tomato_Septoria_leaf_spot',
    'Tomato_Spider_mites_Two_spotted_spider_mite',
    'Tomato__Target_Spot',
    'Tomato__Tomato_YellowLeaf__Curl_Virus',
    'Tomato__Tomato_mosaic_virus',
    'Tomato_healthy',
]

def load_model():
    model = models.efficientnet_b0(weights=None)
    model.classifier[1] = torch.nn.Linear(model.classifier[1].in_features, len(CLASS_NAMES))
    model.load_state_dict(torch.load(MODEL_PATH, map_location='cpu'))
    model.eval()
    return model

ml_model = load_model()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225])
])


# ─── Gamification helper ─────────────────────────────────────────

def _grant_xp_and_check(user, amount: int) -> dict:
    """Award XP then run achievement predicates (which may grant more XP).
    Returns a dict to spread into a JSON response so the frontend can show
    the gain / level-up / unlocked-badge toasts.
    """
    initial_level = user.level
    grant = user.award_xp(amount)
    newly = check_achievements(user)
    # If an achievement reward leveled us up, prefer the post-unlock level.
    leveled = grant['leveled_up'] or (user.level > initial_level)
    return {
        'xp_gained': grant['xp_gained'] + sum(a.xp_reward for a in newly),
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
    today = timezone.localdate()
    last_local = (
        timezone.localtime(user.last_login).date()
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
    request.user.register_care_activity()
    CareLog.objects.create(user=request.user, plant=plant, activity='water')
    xp = _grant_xp_and_check(request.user, 5)
    serializer = PlantSerializer(plant)
    return Response({**serializer.data, **xp})


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
    request.user.register_care_activity()
    CareLog.objects.create(user=request.user, plant=plant, activity='fertilize')
    xp = _grant_xp_and_check(request.user, 5)
    serializer = PlantSerializer(plant)
    return Response({**serializer.data, **xp})


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
    request.user.register_care_activity()
    CareLog.objects.create(user=request.user, plant=plant, activity='mist')
    xp = _grant_xp_and_check(request.user, 5)
    serializer = PlantSerializer(plant)
    return Response({**serializer.data, **xp})


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

    text = (request.data.get('note') or '').strip()
    photo = request.FILES.get('photo')
    if not text and not photo:
        return Response({'error': 'Add a note or a photo.'}, status=400)

    log = CareLog.objects.create(
        user=request.user, plant=plant, activity='note', note=text,
    )
    if photo:
        log.photo = photo
        log.save(update_fields=['photo'])
    return Response({
        'type': 'care',
        'activity': 'note',
        'note': log.note,
        'note_photo': log.photo.url if log.photo else None,
        'plant_id': plant.id,
        'plant_name': plant.name,
        'created_at': log.created_at,
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def streak(request):
    u = request.user
    today = timezone.localdate()
    return Response({
        'current_streak': u.effective_streak,
        'longest_streak': u.longest_streak,
        'last_care_date': u.last_care_date,
        'active_today': u.last_care_date == today,
    })


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
            item['image'] = imgs[0] if imgs else (d.image_url or None)
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

    # Run inference
    image = Image.open(image_file).convert('RGB')
    tensor = transform(image).unsqueeze(0)

    with torch.no_grad():
        outputs = ml_model(tensor)
        probabilities = torch.nn.functional.softmax(outputs[0], dim=0)

    top3 = torch.topk(probabilities, 3)
    top3_predictions = [
        {'label': CLASS_NAMES[top3.indices[i].item()], 'confidence': round(top3.values[i].item(), 4)}
        for i in range(3)
    ]

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

    try:
        disease = Disease.objects.get(label=label)
    except Disease.DoesNotExist:
        return Response({'error': 'Disease label not found.'}, status=404)

    scan_result.disease = disease
    scan_result.save()

    return Response({
        'scan_id': scan_result.id,
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

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def profile(request):
    u = request.user
    unlocked = UserAchievement.objects.filter(user=u).count()
    total = Achievement.objects.count()
    return Response({
        'username': u.username,
        'email': u.email,
        'level': u.level,
        'tier': u.tier,
        'xp': u.xp,
        'xp_into_level': u.xp_into_level,
        'xp_for_next_level': u.xp_for_next_level,
        'current_streak': u.effective_streak,
        'longest_streak': u.longest_streak,
        'achievements_unlocked': unlocked,
        'achievements_total': total,
    })


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


PIN_CAP = 3


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