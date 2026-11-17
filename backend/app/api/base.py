"""HTTP-layer building blocks: the Controller base class, request parsing,
error mapping and the CORS policy."""

from abc import ABC, abstractmethod
from datetime import date
from functools import wraps
from typing import Callable

from flask import Blueprint, Flask, jsonify, request
from flask_cors import CORS
from flask_jwt_extended import get_current_user, get_jwt_identity, jwt_required, verify_jwt_in_request
from werkzeug.exceptions import HTTPException

from app.contracts.repositories import IUnitOfWork
from app.domain.errors import DomainError, ForbiddenError, ValidationError
from app.extensions import limiter


class RequestParser:
    """Typed accessors over the current request; invalid input raises ValidationError."""

    @staticmethod
    def json() -> dict:
        return request.get_json(silent=True) or {}

    @staticmethod
    def arg(name: str, default=None):
        return request.args.get(name, default)

    @staticmethod
    def date(value, field: str, default: date | None = None) -> date:
        if value in (None, ""):
            if default is None:
                raise ValidationError(f"{field} is required (YYYY-MM-DD)")
            return default
        try:
            return date.fromisoformat(str(value))
        except ValueError:
            raise ValidationError(f"{field} must be a date in YYYY-MM-DD format")

    @staticmethod
    def int(value, field: str, default: int | None = None, *, low: int | None = None, high: int | None = None) -> int:
        if value in (None, ""):
            if default is None:
                raise ValidationError(f"{field} is required")
            return default
        try:
            number = int(value)
        except (TypeError, ValueError):
            raise ValidationError(f"{field} must be an integer")
        if low is not None:
            number = max(number, low)
        if high is not None:
            number = min(number, high)
        return number


class Controller(ABC):
    """Base class for HTTP controllers. Subclasses declare routes in
    `register_routes` using `self.route(...)`; each route is a bound method."""

    name: str
    url_prefix: str

    def __init__(self):
        self.blueprint = Blueprint(self.name, __name__, url_prefix=self.url_prefix)
        self.params = RequestParser()
        self.register_routes()

    @abstractmethod
    def register_routes(self) -> None: ...

    def route(
        self,
        rule: str,
        view: Callable,
        *,
        methods=("GET",),
        auth: bool = False,
        admin: bool = False,
        limit: str | None = None,
        exempt: bool = False,
    ) -> None:
        func = view
        if limit:
            func = limiter.limit(limit)(func)
        if exempt:
            func = limiter.exempt(func)
        if admin:
            func = self._admin_only(func)
        if auth or admin:
            func = jwt_required()(func)
        self.blueprint.add_url_rule(rule, endpoint=view.__name__, view_func=func, methods=list(methods))

    @staticmethod
    def _admin_only(func: Callable) -> Callable:
        """Admin rights are read from the database on every request (via the JWT
        user loader), so revoking them takes effect immediately."""

        @wraps(func)
        def wrapper(*args, **kwargs):
            user = get_current_user()
            if user is None or not user.is_admin:
                raise ForbiddenError("Admins only")
            return func(*args, **kwargs)

        return wrapper

    @staticmethod
    def user_id() -> str:
        return get_jwt_identity()

    @staticmethod
    def optional_user_id() -> str | None:
        verify_jwt_in_request(optional=True)
        return get_jwt_identity()

    @staticmethod
    def ok(payload: dict | None = None, code: int = 200, **fields):
        return jsonify({**(payload or {}), **fields}), code


class ApiErrorHandler:
    """Maps domain exceptions and HTTP errors to JSON responses."""

    def __init__(self, uow: IUnitOfWork):
        self._uow = uow

    def register(self, app: Flask) -> None:
        app.register_error_handler(DomainError, self._domain_error)
        app.register_error_handler(HTTPException, self._http_error)

    def _domain_error(self, exc: DomainError):
        self._uow.rollback()
        return jsonify(error=exc.message), exc.status_code

    @staticmethod
    def _http_error(exc: HTTPException):
        message = f"Rate limit exceeded: {exc.description}" if exc.code == 429 else exc.description
        return jsonify(error=message), exc.code


class CorsPolicy:
    """Browser access policy for the REST API: an explicit origin allow-list,
    the methods and headers the frontend uses, and the rate-limit headers it may
    read. WebSockets aren't covered by CORS, so the socket gateway checks the
    same allow-list via `is_allowed_origin`."""

    METHODS = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]
    ALLOW_HEADERS = ["Authorization", "Content-Type"]
    EXPOSE_HEADERS = ["Content-Disposition", "Retry-After", "X-RateLimit-Limit", "X-RateLimit-Remaining", "X-RateLimit-Reset"]
    MAX_AGE_SECONDS = 600

    def __init__(self, origins: list[str]):
        self.origins = [o.strip().rstrip("/") for o in origins if o.strip()]

    def apply(self, app: Flask) -> None:
        CORS(
            app,
            resources={r"/api/*": {"origins": self.origins}},
            methods=self.METHODS,
            allow_headers=self.ALLOW_HEADERS,
            expose_headers=self.EXPOSE_HEADERS,
            supports_credentials=False,  # bearer tokens, not cookies
            max_age=self.MAX_AGE_SECONDS,
        )

    def is_allowed_origin(self, origin: str | None) -> bool:
        # Native clients (Flutter mobile/desktop, CLI tools) send no Origin header.
        return origin is None or origin.rstrip("/") in self.origins
