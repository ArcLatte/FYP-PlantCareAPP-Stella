from django.urls import path
from . import views

urlpatterns = [
    path('auth/register/', views.register),
    path('auth/login/', views.login),
    path('auth/logout/', views.logout),
    path('auth/change-password/', views.change_password),

    path('plants/', views.plant_list),
    path('plants/<int:pk>/', views.plant_detail),
    path('plants/<int:pk>/water/', views.water_plant),
    path('plants/<int:pk>/fertilize/', views.fertilize_plant),
    path('plants/<int:pk>/mist/', views.mist_plant),
    path('species/', views.species_list),
    path('locations/', views.location_list),
    path('locations/<int:pk>/', views.location_detail),
    path('scans/', views.scan),
    path('scans/<int:pk>/confirm/', views.scan_confirm),
    path('plants/<int:pk>/scans/', views.plant_scan_history),
    path('scans/<int:pk>/', views.scan_detail),
    path('scans/history/', views.all_scans),
]