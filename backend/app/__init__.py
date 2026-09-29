import os

from flask import Flask
from flask_cors import CORS

from app.config import config_by_name
from app.container import build_container
from app.extensions import db, jwt, migrate


def create_app(config_name: str | None = None) -> Flask:
    config_name = config_name or os.environ.get("FLASK_ENV", "development")
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])

    if app.config["SQLALCHEMY_DATABASE_URI"].startswith("sqlite:///") and "instance" in app.config["SQLALCHEMY_DATABASE_URI"]:
        os.makedirs(os.path.join(os.getcwd(), "instance"), exist_ok=True)

    CORS(app, resources={r"/api/*": {"origins": app.config["CORS_ORIGINS"]}})
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)

    app.extensions["container"] = build_container(app.config)

    from app.api.adviser import bp as adviser_bp
    from app.api.auth import bp as auth_bp
    from app.api.markets import bp as markets_bp
    from app.api.optimizer import bp as optimizer_bp
    from app.api.selector import bp as selector_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(markets_bp)
    app.register_blueprint(selector_bp)
    app.register_blueprint(optimizer_bp)
    app.register_blueprint(adviser_bp)

    @app.get("/api/health")
    def health():
        return {"status": "ok"}

    with app.app_context():
        from app import models  # noqa: F401 — ensure models are registered before create_all

        db.create_all()

    return app
