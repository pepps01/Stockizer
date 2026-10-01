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
        self._configure_logging()

        for extension in (db, jwt, limiter, sock):
            extension.init_app(app)
        migrate.init_app(app, db)

        container = build_container(app.config)
        app.extensions["container"] = container
        container.cors.apply(app)
        container.error_handler().register(app)
        for controller in container.controllers():
            app.register_blueprint(controller.blueprint)
        container.realtime_gateway().register(sock)

        from app.cli import register_cli

        register_cli(app, container)

        from app import models  # noqa: F401 — register models with SQLAlchemy metadata

        if app.config.get("TESTING"):
            with app.app_context():
                db.create_all()
        return app

    @staticmethod
    def _configure_logging() -> None:
        logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
        logging.getLogger("yfinance").setLevel(logging.CRITICAL)


def create_app(config_name: str | None = None) -> Flask:
    return ApplicationFactory(config_name).create()


def get_container(app: Flask) -> Container:
    return app.extensions["container"]
