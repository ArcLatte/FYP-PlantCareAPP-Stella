from django.conf import settings
from django.contrib import admin
from django.urls import path, include, re_path
from django.views.static import serve

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('core.urls')),
]

# Serve user-uploaded media in all environments. Django/WhiteNoise don't serve
# MEDIA by default when DEBUG=False, and the app returns scan-image URLs, so we
# wire an explicit route. Fine for a demo; a CDN/object store is the eventual
# production answer.
urlpatterns += [
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
]
