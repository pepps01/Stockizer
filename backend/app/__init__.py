import logging
import os

from flask import Flask

from app.config import config_by_name
from app.container import Container, build_container
from app.extensions import db, jwt, limiter, migrate, sock


class ApplicationFactory:
    """Builds the Flask app: configuration, extensions, the dependency
    container, CORS, error handling, REST controllers and the WebSocket gateway."""

    def __init__(self, config_name: str | None = None):
        self._config_name = config_name or os.environ.get("FLASK_ENV", "development")

    def create(self) -> Flask:
        app = Flask(__name__)
        app.config.from_object(config_by_name[self._config_name])
        hops = app.config.get("TRUSTED_PROXY_HOPS", 0)
        if hops:
            from werkzeug.middleware.proxy_fix import ProxyFix

            app.wsgi_app = ProxyFix(app.wsgi_app, x_for=hops, x_proto=hops, x_host=hops)
        self._configure_logging()

        for extension in (db, jwt, limiter, sock):
            extension.init_app(app)
        migrate.init_app(app, db)

        container = build_container(app.config)
        app.extensions["container"] = container
        self._load_users_from_tokens(container)
        container.cors.apply(app)
        container.error_handler().register(app)
        for controller in container.controllers():
            app.register_blueprint(controller.blueprint)
        container.realtime_gateway().register(sock)
        self._register_root(app)
        self._release_memory_after_heavy_requests(app)

        from app.cli import register_cli

        register_cli(app, container)

        from app import models  # noqa: F401 — register models with SQLAlchemy metadata

        if app.config.get("TESTING"):
            with app.app_context():
                db.create_all()
        return app

    @staticmethod
    def _release_memory_after_heavy_requests(app: Flask) -> None:
        """Selector and Optimizer runs load years of prices; hand that memory
        back once the response is sent so the process doesn't stay inflated."""

        @app.teardown_request
        def release(_error):
            from flask import request

            if request.method == "POST" and request.path.rstrip("/").endswith("/runs"):
                from app.memory import release_memory

                release_memory()

    @staticmethod
    def _register_root(app: Flask) -> None:
        """The bare API address answers with a status line instead of a 404,
        so opening it in a browser shows the service is up."""

        @app.get("/")
        def root():
            from flask import jsonify

            return jsonify(service="Stockiser API", status="ok", health="/api/health", docs="All endpoints live under /api/")

    @staticmethod
    def _load_users_from_tokens(container: Container) -> None:
        """Every authenticated request loads its user; a deleted or disabled
        account makes the token invalid (401) even before it expires."""

        @jwt.user_lookup_loader
        def load_user(_header, payload):
            user = container.users.get_by_id(payload["sub"])
            return user if user is not None and user.is_active is not False else None

        @jwt.user_lookup_error_loader
        def user_rejected(_header, _payload):
            from flask import jsonify

            return jsonify(error="Your session has ended. Please log in again."), 401

    @staticmethod
    def _configure_logging() -> None:
        logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
        logging.getLogger("yfinance").setLevel(logging.CRITICAL)


def create_app(config_name: str | None = None) -> Flask:
    return ApplicationFactory(config_name).create()


def get_container(app: Flask) -> Container:
    return app.extensions["container"]
