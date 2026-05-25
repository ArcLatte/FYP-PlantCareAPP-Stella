from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate
from .models import CustomUser
from .models import CustomUser, Plant, PlantSpecies, Disease, ScanResult
from .serializers import PlantSerializer, PlantSpeciesSerializer
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

    return Response({'token': token.key, 'username': user.username})


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
            return Response(serializer.data, status=201)
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
        return Response({'message': 'Plant deleted.'}, status=204)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def species_list(request):
    species = PlantSpecies.objects.all()
    serializer = PlantSpeciesSerializer(species, many=True)
    return Response(serializer.data)


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

    return Response({
        'scan_id': scan_result.id,
        'top3': top3_predictions,
        'predicted_label': top_label,
        'confidence': top_confidence,
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
        'confirmed_label': disease.label,
        'treatment': disease.treatment,
        'care_tips': disease.care_tips,
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
            'top3': scan.top3_predictions,
            'predicted_label': scan.top3_predictions[0]['label'] if scan.top3_predictions else None,
            'confidence': scan.confidence_score,
            'disease': scan.disease.label if scan.disease else None,
            'treatment': scan.disease.treatment if scan.disease else None,
            'care_tips': scan.disease.care_tips if scan.disease else None,
            'created_at': scan.created_at,
        })

    elif request.method == 'DELETE':
        scan.delete()
        return Response({'message': 'Scan deleted.'}, status=204)


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