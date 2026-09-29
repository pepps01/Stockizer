from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from werkzeug.security import generate_password_hash, check_password_hash
from flask_jwt_extended import create_access_token

from app.contracts.repositories import UserRepository
from app.contracts.services import IEmailService


class EmailAlreadyRegisteredError(Exception):
    pass


class InvalidCredentialsError(Exception):
    pass


class EmailNotVerifiedError(Exception):
    pass


class InvalidOrExpiredTokenError(Exception):
    pass


class AuthService:
    def __init__(
        self,
        user_repository: UserRepository,
        email_service: IEmailService,
        *,
        secret_key: str,
        salt: str,
        max_age_seconds: int,
    ):
        self._users = user_repository
        self._email = email_service
        self._serializer = URLSafeTimedSerializer(secret_key)
        self._salt = salt
        self._max_age_seconds = max_age_seconds

    def register(self, *, first_name: str, last_name: str, email: str, password: str) -> dict:
        if self._users.get_by_email(email):
            raise EmailAlreadyRegisteredError(email)

        password_hash = generate_password_hash(password)
        user = self._users.create(
            first_name=first_name, last_name=last_name, email=email, password_hash=password_hash
        )

        token = self._serializer.dumps(user.email, salt=self._salt)
        self._email.send_verification_email(to=user.email, first_name=user.first_name, token=token)

        return user.to_dict()

    def verify_email(self, token: str) -> dict:
        try:
            email = self._serializer.loads(token, salt=self._salt, max_age=self._max_age_seconds)
        except (BadSignature, SignatureExpired) as exc:
            raise InvalidOrExpiredTokenError() from exc

        user = self._users.get_by_email(email)
        if user is None:
            raise InvalidOrExpiredTokenError()

        user = self._users.mark_verified(user.id)
        return user.to_dict()

    def login(self, *, email: str, password: str) -> dict:
        user = self._users.get_by_email(email)
        if user is None or not check_password_hash(user.password_hash, password):
            raise InvalidCredentialsError()
        if not user.is_verified:
            raise EmailNotVerifiedError()

        access_token = create_access_token(identity=str(user.id))
        return {"access_token": access_token, "user": user.to_dict()}

    def get_profile(self, user_id: int) -> dict:
        user = self._users.get_by_id(user_id)
        return user.to_dict() if user else None

    def update_profile(self, user_id: int, *, first_name: str = None, last_name: str = None) -> dict:
        user = self._users.update_profile(user_id, first_name=first_name, last_name=last_name)
        return user.to_dict() if user else None
