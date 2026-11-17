from datetime import timedelta

from flask_jwt_extended import create_access_token
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from werkzeug.security import check_password_hash, generate_password_hash

from app.contracts.repositories import ICatalogRepository, IUnitOfWork, IUserRepository
from app.contracts.services import IAuthService, IEmailService
from app.domain.client import ClientInfo
from app.domain.errors import AuthenticationError, ConflictError, ForbiddenError, NotFoundError, ValidationError
from app.models.base import utcnow
from app.models.user import ALERT_CHANNELS, RISK_PROFILES


class AuthService(IAuthService):
    MIN_PASSWORD_LENGTH = 8
    # Access log: entries kept per user, and how often a saved-session launch
    # from the same IP is logged again.
    ACCESS_KEEP = 50
    RESUME_EVERY = timedelta(hours=6)

    def __init__(
        self,
        users: IUserRepository,
        catalog: ICatalogRepository,
        email: IEmailService,
        uow: IUnitOfWork,
        *,
        secret_key: str,
        salt: str,
        max_age_seconds: int,
        require_verification: bool = True,
    ):
        self._users = users
        self._catalog = catalog
        self._email = email
        self._uow = uow
        self._serializer = URLSafeTimedSerializer(secret_key)
        self._salt = salt
        self._max_age_seconds = max_age_seconds
        self._require_verification = require_verification

    def register(self, *, first_name: str, last_name: str, email: str, password: str, client: ClientInfo | None = None) -> dict:
        missing = [n for n, v in (("first_name", first_name), ("last_name", last_name), ("email", email), ("password", password)) if not v]
        if missing:
            raise ValidationError(f"Missing required field(s): {', '.join(missing)}")
        if "@" not in email:
            raise ValidationError("Enter a valid email address")
        if len(password) < self.MIN_PASSWORD_LENGTH:
            raise ValidationError(f"Password must be at least {self.MIN_PASSWORD_LENGTH} characters long")
        if self._users.get_by_email(email):
            raise ConflictError("An account with this email already exists")

        user = self._users.create(
            first_name=first_name,
            last_name=last_name,
            email=email,
            password_hash=generate_password_hash(password),
            is_verified=not self._require_verification,
        )
        self._uow.flush()
        self._record(user, "register", client)
        self._uow.commit()
        if self._require_verification:
            token = self._serializer.dumps(user.email, salt=self._salt)
            self._email.send_verification_email(to=user.email, first_name=user.first_name, token=token)
        return user.to_dict()

    def verify_email(self, token: str) -> dict:
        if not token:
            raise ValidationError("Missing token")
        try:
            email = self._serializer.loads(token, salt=self._salt, max_age=self._max_age_seconds)
        except (BadSignature, SignatureExpired):
            raise ValidationError("Invalid or expired verification token")
        user = self._users.get_by_email(email)
        if user is None:
            raise ValidationError("Invalid or expired verification token")
        self._users.update(user.id, is_verified=True)
        self._uow.commit()
        return user.to_dict()

    def login(self, *, email: str, password: str, client: ClientInfo | None = None) -> dict:
        if not email or not password:
            raise ValidationError("Email and password are required")
        user = self._users.get_by_email(email)
        if user is None or not check_password_hash(user.password_hash, password):
            raise AuthenticationError("Invalid email or password")
        if user.is_active is False:
            raise ForbiddenError("This account has been disabled. Contact support.")
        if not user.is_verified:
            raise ForbiddenError("Please verify your email before logging in")
        self._record(user, "login", client)
        self._uow.commit()
        return {"access_token": create_access_token(identity=user.id), "user": user.to_dict()}

    def get_profile(self, user_id: str, client: ClientInfo | None = None) -> dict:
        user = self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found")
        if client is not None:
            now = utcnow()
            moved = client.ip != user.last_ip
            stale = user.last_seen_at is None or now - user.last_seen_at >= self.RESUME_EVERY
            if moved or stale:
                self._record(user, "resume", client)
            else:
                user.last_seen_at = now
            self._uow.commit()
        return user.to_dict()

    def _record(self, user, event: str, client: ClientInfo | None) -> None:
        """Remembers where the account was used from: IP, platform and browser or app."""
        if client is None:
            return
        user.last_ip = client.ip
        user.last_seen_at = utcnow()
        if event == "register":
            user.signup_ip = client.ip
        self._users.add_access(
            user.id, event=event, ip=client.ip, platform=client.platform, user_agent=client.user_agent, keep=self.ACCESS_KEEP
        )

    def update_profile(self, user_id: str, data: dict) -> dict:
        fields = {name: str(data[name]).strip()[:80] for name in ("first_name", "last_name") if data.get(name)}
        if "risk_profile" in data:
            if data["risk_profile"] not in RISK_PROFILES:
                raise ValidationError(f"risk_profile must be one of {', '.join(RISK_PROFILES)}")
            fields["risk_profile"] = data["risk_profile"]
        if "alert_channels" in data:
            channels = data["alert_channels"] or []
            if not isinstance(channels, list) or any(c not in ALERT_CHANNELS for c in channels):
                raise ValidationError(f"alert_channels must be a list drawn from {', '.join(ALERT_CHANNELS)}")
            fields["alert_channels"] = sorted(set(channels))
        if "default_exchange" in data:
            code = data["default_exchange"]
            exchange = self._catalog.exchange(code) if code else None
            if code and exchange is None:
                raise ValidationError("Unknown exchange")
            fields["default_exchange_id"] = exchange.id if exchange else None

        user = self._users.update(user_id, **fields)
        if user is None:
            raise NotFoundError("User not found")
        self._uow.commit()
        return user.to_dict()
