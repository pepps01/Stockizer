"""Push notifications through Firebase Cloud Messaging (HTTP v1 API).

Configure with FCM_SERVICE_ACCOUNT_FILE: the JSON key of a Firebase service
account (Firebase console → Project settings → Service accounts → Generate new
private key). Without it the app runs with DisabledPushService and signals are
still delivered in-app and by email.
"""

import json
import logging
import threading

import requests

from app.contracts.services import IPushService

logger = logging.getLogger(__name__)


class DisabledPushService(IPushService):
    @property
    def enabled(self) -> bool:
        return False

    def send(self, tokens: list[str], *, title: str, body: str, data: dict[str, str]) -> list[str]:
        return []


class FcmPushService(IPushService):
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
    ENDPOINT = "https://fcm.googleapis.com/v1/projects/{project}/messages:send"
    TIMEOUT_SECONDS = 10
    # Error codes meaning the token will never work again.
    DEAD_TOKEN_CODES = {"UNREGISTERED", "INVALID_ARGUMENT", "SENDER_ID_MISMATCH"}

    def __init__(self, service_account_file: str):
        # Imported here so the dependency is only needed when push is configured.
        from google.oauth2 import service_account

        with open(service_account_file, encoding="utf-8") as fh:
            self._project = json.load(fh)["project_id"]
        self._credentials = service_account.Credentials.from_service_account_file(service_account_file, scopes=[self.SCOPE])
        self._lock = threading.Lock()

    @property
    def enabled(self) -> bool:
        return True

    def send(self, tokens: list[str], *, title: str, body: str, data: dict[str, str]) -> list[str]:
        headers = {"Authorization": f"Bearer {self._access_token()}", "Content-Type": "application/json"}
        url = self.ENDPOINT.format(project=self._project)
        invalid = []
        for token in tokens:
            message = {
                "message": {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "data": {k: str(v) for k, v in data.items()},
                    "android": {"priority": "high", "notification": {"channel_id": "signals"}},
                    "apns": {"payload": {"aps": {"sound": "default"}}},
                }
            }
            response = requests.post(url, headers=headers, json=message, timeout=self.TIMEOUT_SECONDS)
            if response.ok:
                continue
            if self._is_dead_token(response):
                invalid.append(token)
            else:
                logger.warning("FCM send failed (%s): %s", response.status_code, response.text[:300])
        return invalid

    def _access_token(self) -> str:
        from google.auth.transport.requests import Request

        with self._lock:
            if not self._credentials.valid:
                self._credentials.refresh(Request())
            return self._credentials.token

    def _is_dead_token(self, response: requests.Response) -> bool:
        if response.status_code == 404:
            return True
        try:
            details = response.json().get("error", {}).get("details", [])
        except ValueError:
            return False
        return any(d.get("errorCode") in self.DEAD_TOKEN_CODES for d in details)
