"""Transactional email delivery for Stella."""

from email.utils import parseaddr
import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.mail import send_mail


class EmailDeliveryError(RuntimeError):
    """Raised when a transactional email provider rejects a message."""


def _send_with_brevo(*, subject, text_content, recipient_email):
    sender_name, parsed_sender_email = parseaddr(settings.DEFAULT_FROM_EMAIL)
    sender_email = settings.BREVO_SENDER_EMAIL or parsed_sender_email
    sender_name = settings.BREVO_SENDER_NAME or sender_name or 'Stella Plant Care'
    if not sender_email:
        raise EmailDeliveryError('BREVO_SENDER_EMAIL is not configured.')

    payload = json.dumps({
        'sender': {'name': sender_name, 'email': sender_email},
        'to': [{'email': recipient_email}],
        'subject': subject,
        'textContent': text_content,
    }).encode('utf-8')
    request = Request(
        settings.BREVO_API_URL,
        data=payload,
        headers={
            'accept': 'application/json',
            'api-key': settings.BREVO_API_KEY,
            'content-type': 'application/json',
        },
        method='POST',
    )
    try:
        with urlopen(request, timeout=settings.BREVO_TIMEOUT_SECONDS) as response:
            if response.status != 201:
                raise EmailDeliveryError(
                    f'Brevo returned unexpected status {response.status}.'
                )
    except HTTPError as exc:
        # Do not include the response body: providers can echo message data.
        raise EmailDeliveryError(
            f'Brevo rejected the email with status {exc.code}.'
        ) from exc
    except (URLError, TimeoutError) as exc:
        raise EmailDeliveryError('Could not connect to the Brevo API.') from exc


def send_transactional_email(*, subject, text_content, recipient_email):
    """Send through Brevo when configured, otherwise Django's email backend.

    The fallback keeps local console/locmem development and tests convenient.
    Production should always provide BREVO_API_KEY.
    """
    if settings.BREVO_API_KEY:
        _send_with_brevo(
            subject=subject,
            text_content=text_content,
            recipient_email=recipient_email,
        )
        return

    if settings.EMAIL_BACKEND.endswith('smtp.EmailBackend'):
        raise EmailDeliveryError(
            'BREVO_API_KEY is required; SMTP delivery is disabled for Stella.'
        )

    send_mail(
        subject=subject,
        message=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[recipient_email],
        fail_silently=False,
    )
