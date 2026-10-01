import logging

from app.contracts.services import IEmailService

logger = logging.getLogger(__name__)


class SendGridEmailService(IEmailService):
    """Sends email via the SendGrid API. Falls back to logging the email to the
    console when no SENDGRID_API_KEY is configured, so registration and alerts
    work end-to-end in local development without an external account."""

    def __init__(self, *, api_key: str | None, email_from: str, frontend_url: str):
        self._api_key = api_key
        self._email_from = email_from
        self._frontend_url = frontend_url

    def send_verification_email(self, *, to: str, first_name: str, token: str) -> None:
        verify_url = f"{self._frontend_url}/verify-email?token={token}"
        self._send(
            to=to,
            subject="Verify your Algizer account",
            body=(
                f"Hi {first_name},\n\n"
                f"Welcome to Algizer. Please verify your email address by visiting:\n"
                f"{verify_url}\n\n"
                f"This link expires in 24 hours."
            ),
        )

    def send_signal_alert(self, *, to: str, first_name: str, signal: dict) -> None:
        self._send(
            to=to,
            subject=f"Algizer {signal['signal_type']} signal: {signal['display_symbol']}",
            body=(
                f"Hi {first_name},\n\n"
                f"The Adviser emitted a {signal['signal_type']} signal for {signal['name']} "
                f"({signal['display_symbol']}) at {signal['price']:.4g} {signal['currency']} "
                f"with {signal['confidence'] * 100:.0f}% confidence.\n\n"
                f"{signal['reason']}\n\n"
                f"Algizer emits signals only and never places trades.\n"
                f"{self._frontend_url}/adviser"
            ),
        )

    def _send(self, *, to: str, subject: str, body: str) -> None:
        if not self._api_key:
            logger.info("[dev email fallback] To: %s\nSubject: %s\n\n%s", to, subject, body)
            return

        from sendgrid import SendGridAPIClient
        from sendgrid.helpers.mail import Mail

        message = Mail(from_email=self._email_from, to_emails=to, subject=subject, plain_text_content=body)
        SendGridAPIClient(self._api_key).send(message)
