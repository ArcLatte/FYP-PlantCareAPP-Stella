from io import BytesIO
from datetime import date, datetime, timezone as datetime_timezone
import re
import tempfile
from types import SimpleNamespace
from unittest.mock import Mock, patch

from django.core import mail
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, TestCase, override_settings
from PIL import Image, ImageDraw, ImageFilter
from rest_framework.authtoken.models import Token
from rest_framework.test import APIClient, APIRequestFactory, force_authenticate

from .image_quality import ImageQualityAssessor
from .models import (
    CareLog,
    CustomUser,
    PasswordResetCode,
    Plant,
    PlantSpecies,
    NoteImage,
)
from .scanning_pipeline import ScanAnalysis, ScanningPipeline, ScanStatus
from .serializers import PlantSerializer
from .views import scan, streak


class NoteImageTests(TestCase):
    def setUp(self):
        self.media_dir = tempfile.TemporaryDirectory()
        self.settings_override = override_settings(MEDIA_ROOT=self.media_dir.name)
        self.settings_override.enable()
        self.addCleanup(self.settings_override.disable)
        self.addCleanup(self.media_dir.cleanup)
        self.client = APIClient()
        self.user = CustomUser.objects.create_user(
            username='note-image-user',
            email='note-images@example.com',
            password='test-password',
        )
        self.client.force_authenticate(user=self.user)
        species = PlantSpecies.objects.create(name='Note image species')
        self.plant = Plant.objects.create(
            user=self.user,
            species=species,
            name='Journal plant',
        )

    @staticmethod
    def _image(name, color):
        image = Image.new('RGB', (80, 80), color)
        content = BytesIO()
        image.save(content, format='JPEG')
        content.seek(0)
        return SimpleUploadedFile(name, content.read(), content_type='image/jpeg')

    def test_create_note_with_multiple_images(self):
        response = self.client.post(
            f'/api/plants/{self.plant.id}/note/',
            {
                'title': 'Growth update',
                'note': '**Two** new leaves',
                'photos': [
                    self._image('first.jpg', 'green'),
                    self._image('second.jpg', 'yellow'),
                ],
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(len(response.data['note_images']), 2)
        self.assertEqual(NoteImage.objects.count(), 2)

    def test_edit_can_remove_one_image_and_append_another(self):
        log = CareLog.objects.create(
            user=self.user,
            plant=self.plant,
            activity=CareLog.Activity.NOTE,
            note='Progress',
        )
        old = NoteImage.objects.create(
            note=log,
            image=self._image('old.jpg', 'green'),
        )

        response = self.client.put(
            f'/api/plants/{self.plant.id}/note/{log.id}/',
            {
                'title': '',
                'note': '_Updated_',
                'remove_image_ids': f'[{old.id}]',
                'photos': [self._image('new.jpg', 'blue')],
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(len(response.data['note_images']), 1)
        self.assertFalse(NoteImage.objects.filter(id=old.id).exists())


@override_settings(
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    PASSWORD_RESET_CODE_MINUTES=10,
    PASSWORD_RESET_MAX_ATTEMPTS=5,
    PASSWORD_RESET_RESEND_SECONDS=60,
)
class PasswordResetTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = CustomUser.objects.create_user(
            username='reset-user',
            email='reset@example.com',
            password='Original-password-42',
        )

    def _request_code(self):
        response = self.client.post(
            '/api/auth/password-reset/request/',
            {'email': self.user.email},
            format='json',
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)
        match = re.search(r'\b(\d{6})\b', mail.outbox[0].body)
        self.assertIsNotNone(match)
        return match.group(1)

    def test_request_sends_code_without_storing_plaintext(self):
        code = self._request_code()

        reset = PasswordResetCode.objects.get(user=self.user)
        self.assertNotEqual(reset.code_hash, code)
        self.assertEqual(mail.outbox[0].to, [self.user.email])

    def test_unknown_email_gets_same_response_without_email(self):
        response = self.client.post(
            '/api/auth/password-reset/request/',
            {'email': 'unknown@example.com'},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('If an account', response.data['message'])
        self.assertEqual(len(mail.outbox), 0)

    def test_valid_code_changes_password_and_revokes_token(self):
        token = Token.objects.create(user=self.user)
        code = self._request_code()

        response = self.client.post(
            '/api/auth/password-reset/confirm/',
            {
                'email': self.user.email,
                'code': code,
                'new_password': 'New-secure-password-84',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('New-secure-password-84'))
        self.assertFalse(Token.objects.filter(key=token.key).exists())
        self.assertTrue(PasswordResetCode.objects.get(user=self.user).used)

    def test_code_is_locked_after_five_wrong_attempts(self):
        code = self._request_code()
        wrong_code = '000000' if code != '000000' else '999999'
        for _ in range(5):
            response = self.client.post(
                '/api/auth/password-reset/confirm/',
                {
                    'email': self.user.email,
                    'code': wrong_code,
                    'new_password': 'New-secure-password-84',
                },
                format='json',
            )
            self.assertEqual(response.status_code, 400)

        response = self.client.post(
            '/api/auth/password-reset/confirm/',
            {
                'email': self.user.email,
                'code': code,
                'new_password': 'New-secure-password-84',
            },
            format='json',
        )
        self.assertEqual(response.status_code, 400)


class PlantCareIntervalTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username='care-interval-user',
            password='test-password',
        )
        self.species = PlantSpecies.objects.create(
            name='Care interval species',
            default_watering_freq_days=4,
            default_fertilizer_freq_days=14,
            default_misting_freq_days=3,
        )

    def test_create_inherits_all_species_intervals(self):
        serializer = PlantSerializer(data={
            'name': 'Inherited schedule',
            'species': self.species.id,
        })
        self.assertTrue(serializer.is_valid(), serializer.errors)
        plant = serializer.save(user=self.user)

        self.assertEqual(plant.watering_freq_days, 4)
        self.assertEqual(plant.fertilizer_freq_days, 14)
        self.assertEqual(plant.misting_freq_days, 3)

    def test_create_keeps_custom_intervals(self):
        serializer = PlantSerializer(data={
            'name': 'Custom schedule',
            'species': self.species.id,
            'watering_freq_days': 2,
            'fertilizer_freq_days': 10,
            'misting_freq_days': 5,
        })
        self.assertTrue(serializer.is_valid(), serializer.errors)
        plant = serializer.save(user=self.user)

        self.assertEqual(plant.watering_freq_days, 2)
        self.assertEqual(plant.fertilizer_freq_days, 10)
        self.assertEqual(plant.misting_freq_days, 5)


class StreakTimezoneTests(TestCase):
    def setUp(self):
        self.user = CustomUser.objects.create_user(
            username='timezone-user',
            email='timezone@example.com',
            password='test-password',
            current_streak=5,
            longest_streak=5,
            last_care_date=date(2026, 7, 15),
            streak_freezes=0,
        )
        self.factory = APIRequestFactory()
        species = PlantSpecies.objects.create(name='Timezone test species')
        self.plant = Plant.objects.create(
            user=self.user,
            species=species,
            name='Timezone test plant',
        )

    @patch(
        'core.views.timezone.now',
        return_value=datetime(2026, 7, 15, 17, tzinfo=datetime_timezone.utc),
    )
    def test_streak_uses_client_location_offset(self, _now):
        request = self.factory.get(
            '/api/streak/',
            HTTP_X_TIMEZONE_OFFSET_MINUTES='480',
        )
        force_authenticate(request, user=self.user)

        response = streak(request)

        self.assertEqual(response.data['today'], '2026-07-16')
        self.assertEqual(response.data['current_streak'], 5)
        self.assertFalse(response.data['active_today'])

    def test_care_advances_again_on_the_next_client_local_day(self):
        result = self.user.register_care_activity(today=date(2026, 7, 16))

        self.user.refresh_from_db()
        self.assertEqual(self.user.current_streak, 6)
        self.assertEqual(self.user.last_care_date, date(2026, 7, 16))
        self.assertFalse(result['saved'])

    def test_clock_moving_back_does_not_increment_or_add_freezes(self):
        result = self.user.register_care_activity(today=date(2026, 7, 14))

        self.user.refresh_from_db()
        self.assertEqual(self.user.current_streak, 5)
        self.assertEqual(self.user.streak_freezes, 0)
        self.assertFalse(result['saved'])

    @patch(
        'core.views.timezone.now',
        return_value=datetime(2026, 7, 15, 17, tzinfo=datetime_timezone.utc),
    )
    def test_calendar_groups_care_logs_by_client_local_day(self, _now):
        CareLog.objects.create(
            user=self.user,
            plant=self.plant,
            activity=CareLog.Activity.WATER,
            created_at=datetime(
                2026,
                7,
                15,
                17,
                tzinfo=datetime_timezone.utc,
            ),
        )
        request = self.factory.get(
            '/api/streak/',
            HTTP_X_TIMEZONE_OFFSET_MINUTES='480',
        )
        force_authenticate(request, user=self.user)

        response = streak(request)

        self.assertIn('2026-07-16', response.data['recent_care_days'])


@override_settings(
    SCAN_MIN_IMAGE_DIMENSION=224,
    SCAN_BLUR_THRESHOLD=25,
    SCAN_DARK_MEAN_THRESHOLD=30,
    SCAN_DARK_PIXEL_RATIO=0.80,
    SCAN_BRIGHT_MEAN_THRESHOLD=225,
    SCAN_BRIGHT_PIXEL_RATIO=0.85,
)
class ImageQualityTests(SimpleTestCase):
    def setUp(self):
        self.assessor = ImageQualityAssessor()

    @staticmethod
    def _detailed_image():
        image = Image.new('RGB', (512, 512), (70, 145, 65))
        draw = ImageDraw.Draw(image)
        for position in range(0, 512, 24):
            draw.line((position, 0, 511 - position, 511), fill=(235, 235, 90), width=4)
            draw.line((0, position, 511, 511 - position), fill=(20, 65, 25), width=3)
        return image

    def test_detailed_well_exposed_image_passes(self):
        report = self.assessor.assess(self._detailed_image())

        self.assertTrue(report['passed'])
        self.assertEqual(report['issues'], [])

    def test_low_resolution_image_is_rejected(self):
        report = self.assessor.assess(
            self._detailed_image().resize((200, 300))
        )

        self.assertFalse(report['passed'])
        self.assertIn('image_too_small', [i['code'] for i in report['issues']])

    def test_blurred_image_is_rejected(self):
        blurred = self._detailed_image().filter(ImageFilter.GaussianBlur(12))
        report = self.assessor.assess(blurred)

        self.assertFalse(report['passed'])
        self.assertIn('image_too_blurry', [i['code'] for i in report['issues']])

    def test_dark_image_is_rejected_without_duplicate_blur_issue(self):
        report = self.assessor.assess(
            Image.new('RGB', (512, 512), (5, 5, 5))
        )
        issue_codes = [i['code'] for i in report['issues']]

        self.assertIn('image_too_dark', issue_codes)
        self.assertNotIn('image_too_blurry', issue_codes)

    def test_overexposed_image_is_rejected(self):
        report = self.assessor.assess(
            Image.new('RGB', (512, 512), (255, 255, 255))
        )

        self.assertIn(
            'image_overexposed',
            [i['code'] for i in report['issues']],
        )


class ScanQualityGateTests(SimpleTestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.user = SimpleNamespace(is_authenticated=True)
        self.plant = SimpleNamespace(species=SimpleNamespace(name='Tomato'))

    @staticmethod
    def _upload(image, name='scan.jpg'):
        data = BytesIO()
        image.save(data, format='JPEG')
        return SimpleUploadedFile(name, data.getvalue(), content_type='image/jpeg')

    @patch('core.views.default_scanning_pipeline.analyze')
    @patch('core.views.Plant.objects.get')
    def test_quality_failure_stops_before_persistence(self, get_plant, analyze):
        get_plant.return_value = self.plant
        analyze.return_value = ScanAnalysis(
            status=ScanStatus.QUALITY_REJECTED,
            quality={
                'passed': False,
                'issues': [{
                    'code': 'image_too_dark',
                    'message': 'Photo is too dark.',
                }],
                'metrics': {},
            },
        )
        request = self.factory.post('/api/scans/', {
            'plant_id': '1',
            'image': self._upload(Image.new('RGB', (512, 512), (2, 2, 2))),
        }, format='multipart')
        force_authenticate(request, user=self.user)

        response = scan(request)

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.data['code'], 'image_too_dark')
        self.assertEqual(response.data['action'], 'retake')
        analyze.assert_called_once()

    @patch('core.views.Plant.objects.get')
    def test_invalid_image_returns_actionable_error(self, get_plant):
        get_plant.return_value = self.plant
        upload = SimpleUploadedFile(
            'scan.jpg', b'not an image', content_type='image/jpeg'
        )
        request = self.factory.post('/api/scans/', {
            'plant_id': '1',
            'image': upload,
        }, format='multipart')
        force_authenticate(request, user=self.user)

        response = scan(request)

        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['code'], 'invalid_image')


class ScanLeafGateTests(SimpleTestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.user = SimpleNamespace(is_authenticated=True)
        self.plant = SimpleNamespace(species=SimpleNamespace(name='Tomato'))

    @staticmethod
    def _upload():
        image = ImageQualityTests._detailed_image()
        data = BytesIO()
        image.save(data, format='JPEG')
        return SimpleUploadedFile(
            'scan.jpg', data.getvalue(), content_type='image/jpeg'
        )

    @patch('core.views._grant_xp_and_check')
    @patch('core.views.ScanResult.objects.create')
    @patch('core.views.default_scanning_pipeline.analyze')
    @patch('core.views.Plant.objects.get')
    def test_non_leaf_stops_before_disease_inference_and_persistence(
        self, get_plant, analyze, create_scan, grant_xp,
    ):
        get_plant.return_value = self.plant
        analyze.return_value = ScanAnalysis(
            status=ScanStatus.NO_LEAF,
            leaf_gate={
                'passed': False,
                'leaf_confidence': 0.013,
                'threshold': 0.99,
            },
        )
        request = self.factory.post('/api/scans/', {
            'plant_id': '1',
            'image': self._upload(),
        }, format='multipart')
        force_authenticate(request, user=self.user)

        response = scan(request)

        self.assertEqual(response.status_code, 422)
        self.assertEqual(response.data['code'], 'no_leaf_detected')
        self.assertEqual(response.data['action'], 'retake')
        self.assertEqual(response.data['leaf_gate']['leaf_confidence'], 0.013)
        create_scan.assert_not_called()
        grant_xp.assert_not_called()

    @patch('core.views.default_scanning_pipeline.analyze')
    @patch('core.views.Plant.objects.get')
    def test_leaf_passes_to_selected_species_classifier(
        self, get_plant, analyze,
    ):
        get_plant.return_value = self.plant
        analyze.return_value = ScanAnalysis(
            status=ScanStatus.UNSUPPORTED_SPECIES,
            leaf_gate={
                'passed': True,
                'leaf_confidence': 0.9998,
                'threshold': 0.99,
            },
        )
        request = self.factory.post('/api/scans/', {
            'plant_id': '1',
            'image': self._upload(),
        }, format='multipart')
        force_authenticate(request, user=self.user)

        response = scan(request)

        self.assertEqual(response.status_code, 400)
        analyze.assert_called_once()
        self.assertEqual(analyze.call_args.args[1], 'Tomato')


class ScanningPipelineTests(SimpleTestCase):
    def setUp(self):
        self.quality = Mock()
        self.leaf = Mock()
        self.disease = Mock()
        self.pipeline = ScanningPipeline(self.quality, self.leaf, self.disease)
        self.image = Image.new('RGB', (224, 224))

    def test_quality_rejection_short_circuits_model_inference(self):
        self.quality.assess.return_value = {
            'passed': False,
            'issues': [{'code': 'image_too_blurry', 'message': 'Retake.'}],
        }

        result = self.pipeline.analyze(self.image, 'Tomato')

        self.assertEqual(result.status, ScanStatus.QUALITY_REJECTED)
        self.leaf.classify.assert_not_called()
        self.disease.classify.assert_not_called()

    def test_non_leaf_short_circuits_disease_classifier(self):
        self.quality.assess.return_value = {'passed': True, 'issues': []}
        self.leaf.classify.return_value = {
            'passed': False,
            'leaf_confidence': 0.1,
            'threshold': 0.99,
        }

        result = self.pipeline.analyze(self.image, 'Tomato')

        self.assertEqual(result.status, ScanStatus.NO_LEAF)
        self.disease.classify.assert_not_called()

    def test_accepted_leaf_uses_species_classifier(self):
        predictions = [{'label': 'Tomato_healthy', 'confidence': 0.95}]
        self.quality.assess.return_value = {'passed': True, 'issues': []}
        self.leaf.classify.return_value = {
            'passed': True,
            'leaf_confidence': 0.999,
            'threshold': 0.99,
        }
        self.disease.classify.return_value = predictions

        result = self.pipeline.analyze(self.image, 'Tomato')

        self.assertTrue(result.accepted)
        self.assertEqual(result.predictions, predictions)
        self.disease.classify.assert_called_once_with('Tomato', self.image)
