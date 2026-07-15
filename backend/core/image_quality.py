"""Model-free quality assessment for uploaded scan images."""

from dataclasses import dataclass

from django.conf import settings
from PIL import Image, ImageFilter, ImageOps, ImageStat


@dataclass(frozen=True)
class ImageQualityIssue:
    code: str
    message: str


class ImageQualityAssessor:
    """Encapsulates capture-quality rules and their configurable thresholds."""

    @staticmethod
    def _setting(name, default):
        return getattr(settings, name, default)

    def assess(self, image: Image.Image) -> dict:
        """Return quality metrics and actionable issues for a decoded image."""
        width, height = image.size
        issues = []

        min_dimension = int(self._setting('SCAN_MIN_IMAGE_DIMENSION', 224))
        if width < min_dimension or height < min_dimension:
            issues.append(ImageQualityIssue(
                'image_too_small',
                f'Photo resolution is too low. Use an image of at least '
                f'{min_dimension} x {min_dimension} pixels.',
            ))

        # Bound analysis cost for large phone photos.
        analysis = ImageOps.grayscale(image)
        analysis.thumbnail((512, 512), Image.Resampling.LANCZOS)
        stats = ImageStat.Stat(analysis)
        brightness = stats.mean[0]
        histogram = analysis.histogram()
        pixel_count = max(1, analysis.width * analysis.height)
        dark_ratio = sum(histogram[:16]) / pixel_count
        bright_ratio = sum(histogram[240:]) / pixel_count

        dark_mean = float(self._setting('SCAN_DARK_MEAN_THRESHOLD', 30.0))
        dark_pixel_ratio = float(self._setting('SCAN_DARK_PIXEL_RATIO', 0.80))
        bright_mean = float(self._setting('SCAN_BRIGHT_MEAN_THRESHOLD', 225.0))
        bright_pixel_ratio = float(self._setting('SCAN_BRIGHT_PIXEL_RATIO', 0.85))

        if brightness < dark_mean and dark_ratio >= dark_pixel_ratio:
            issues.append(ImageQualityIssue(
                'image_too_dark',
                'Photo is too dark. Add more light and retake the photo.',
            ))
        elif brightness > bright_mean and bright_ratio >= bright_pixel_ratio:
            issues.append(ImageQualityIssue(
                'image_overexposed',
                'Photo is overexposed. Reduce glare or direct light and retake it.',
            ))

        # FIND_EDGES gives a cheap focus measure. Cropping removes the filter's
        # artificial high-contrast border.
        edges = analysis.filter(ImageFilter.FIND_EDGES)
        if edges.width > 2 and edges.height > 2:
            edges = edges.crop((1, 1, edges.width - 1, edges.height - 1))
        sharpness = ImageStat.Stat(edges).var[0]
        blur_threshold = float(self._setting('SCAN_BLUR_THRESHOLD', 25.0))

        exposure_codes = {'image_too_dark', 'image_overexposed'}
        if not any(issue.code in exposure_codes for issue in issues):
            if sharpness < blur_threshold:
                issues.append(ImageQualityIssue(
                    'image_too_blurry',
                    'Photo is too blurry. Hold the camera steady, focus on the '
                    'leaf, and retake it.',
                ))

        return {
            'passed': not issues,
            'issues': [
                {'code': issue.code, 'message': issue.message}
                for issue in issues
            ],
            'metrics': {
                'width': width,
                'height': height,
                'brightness': round(brightness, 2),
                'dark_pixel_ratio': round(dark_ratio, 4),
                'bright_pixel_ratio': round(bright_ratio, 4),
                'sharpness': round(sharpness, 2),
            },
        }
