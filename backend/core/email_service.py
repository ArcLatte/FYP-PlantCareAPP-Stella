"""Transactional email delivery for Stella."""

import base64
from email.message import EmailMessage
from email.utils import parseaddr
import json
from threading import Lock
from time import monotonic
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from django.conf import settings
from django.core.mail import send_mail


class EmailDeliveryError(RuntimeError):
    """Raised when a transactional email provider rejects a message."""


_token_lock = Lock()
_gmail_access_token = None
_gmail_access_token_expires_at = 0.0


def _request_gmail_access_token():
    global _gmail_access_token, _gmail_access_token_expires_at

    with _token_lock:
        if (
            _gmail_access_token
            and monotonic() < _gmail_access_token_expires_at
        ):
            return _gmail_access_token

        body = urlencode({
            'client_id': settings.GMAIL_CLIENT_ID,
            'client_secret': settings.GMAIL_CLIENT_SECRET,
            'refresh_token': settings.GMAIL_REFRESH_TOKEN,
            'grant_type': 'refresh_token',
        }).encode('utf-8')
        request = Request(
            settings.GMAIL_TOKEN_URL,
            data=body,
            headers={'content-type': 'application/x-www-form-urlencoded'},
            method='POST',
        )
        try:
            with urlopen(
                request,
                timeout=settings.GMAIL_API_TIMEOUT_SECONDS,
            ) as response:
                result = json.loads(response.read().decode('utf-8'))
        except HTTPError as exc:
            raise EmailDeliveryError(
                f'Google OAuth rejected the token request with status '
                f'{exc.code}.'
            ) from exc
        except (URLError, TimeoutError, ValueError) as exc:
            raise EmailDeliveryError(
                'Could not obtain a Gmail API access token.'
            ) from exc

        token = result.get('access_token')
        if not token:
            raise EmailDeliveryError(
                'Google OAuth did not return an access token.'
            )
        expires_in = max(int(result.get('expires_in', 3600)), 120)
        _gmail_access_token = token
        _gmail_access_token_expires_at = monotonic() + expires_in - 60
        return token


def _send_with_gmail_api(
    *, subject, text_content, recipient_email, html_content=None
):
    access_token = _request_gmail_access_token()
    sender_name, default_sender = parseaddr(settings.DEFAULT_FROM_EMAIL)
    sender_email = settings.GMAIL_SENDER_EMAIL or default_sender
    if not sender_email:
        raise EmailDeliveryError('GMAIL_SENDER_EMAIL is not configured.')

    message = EmailMessage()
    message['To'] = recipient_email
    message['From'] = (
        f'{sender_name} <{sender_email}>' if sender_name else sender_email
    )
    message['Subject'] = subject
    message.set_content(text_content)
    if html_content:
        message.add_alternative(html_content, subtype='html')
    raw_message = base64.urlsafe_b64encode(message.as_bytes()).decode('ascii')

    request = Request(
        settings.GMAIL_API_URL,
        data=json.dumps({'raw': raw_message}).encode('utf-8'),
        headers={
            'authorization': f'Bearer {access_token}',
            'content-type': 'application/json',
        },
        method='POST',
    )
    try:
        with urlopen(
            request,
            timeout=settings.GMAIL_API_TIMEOUT_SECONDS,
        ) as response:
            if response.status != 200:
                raise EmailDeliveryError(
                    f'Gmail API returned unexpected status {response.status}.'
                )
    except HTTPError as exc:
        raise EmailDeliveryError(
            f'Gmail API rejected the email with status {exc.code}.'
        ) from exc
    except (URLError, TimeoutError) as exc:
        raise EmailDeliveryError('Could not connect to the Gmail API.') from exc


def send_transactional_email(
    *, subject, text_content, recipient_email, html_content=None
):
    """Send through Gmail API, or use a local non-SMTP Django backend."""
    gmail_settings = (
        settings.GMAIL_CLIENT_ID,
        settings.GMAIL_CLIENT_SECRET,
        settings.GMAIL_REFRESH_TOKEN,
    )
    if all(gmail_settings):
        _send_with_gmail_api(
            subject=subject,
            text_content=text_content,
            recipient_email=recipient_email,
            html_content=html_content,
        )
        return

    if any(gmail_settings):
        raise EmailDeliveryError('Gmail API credentials are incomplete.')
    if settings.EMAIL_BACKEND.endswith('smtp.EmailBackend'):
        raise EmailDeliveryError(
            'Gmail API credentials are required; SMTP delivery is disabled.'
        )

    send_mail(
        subject=subject,
        message=text_content,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[recipient_email],
        fail_silently=False,
        html_message=html_content,
    )
