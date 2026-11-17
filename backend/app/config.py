import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()

BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-jwt-secret-key")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=12)
    # REST calls send "Authorization: Bearer"; only the WebSocket gateway takes
    # ?token= (browsers can't set upgrade headers) and decodes it itself.
    JWT_TOKEN_LOCATION = ["headers"]

    SQLALCHEMY_DATABASE_URI = os.environ.get(
        "DATABASE_URL", "mysql+pymysql://algizer:algizer@127.0.0.1:3316/algizer?charset=utf8mb4"
    )
    SQLALCHEMY_ENGINE_OPTIONS = {"pool_pre_ping": True, "pool_recycle": 1800}
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY")
    # Firebase service-account JSON for push notifications; push is off when unset.
    FCM_SERVICE_ACCOUNT_FILE = os.environ.get("FCM_SERVICE_ACCOUNT_FILE")
    EMAIL_FROM = os.environ.get("EMAIL_FROM", "no-reply@algizer.app")
    EMAIL_VERIFICATION_SALT = "email-verification"
    EMAIL_VERIFICATION_MAX_AGE_SECONDS = 60 * 60 * 24  # 24h

    FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:3000")

    # Browser origins allowed to call the REST API and open the /ws socket.
    # Comma-separated env var overrides the default, which covers the Next.js
    # dev server and a locally-served Flutter web build (native Android/iOS/
    # desktop clients aren't browsers and send no Origin header).
    CORS_ORIGINS = os.environ.get("CORS_ORIGINS", "http://localhost:3000,http://localhost:8080").split(",")

    # "auto": Yahoo where the catalog says so, synthetic elsewhere.
    # "synthetic": every ticker simulated (offline development and tests).
    MARKET_DATA_MODE = os.environ.get("MARKET_DATA_MODE", "auto")
    ARTIFACT_DIR = os.environ.get("ARTIFACT_DIR", os.path.join(BACKEND_DIR, "instance", "artifacts"))

    RATELIMIT_DEFAULT = "600 per minute"
    RATELIMIT_STORAGE_URI = os.environ.get("RATELIMIT_STORAGE_URI", "memory://")
    RATELIMIT_HEADERS_ENABLED = True

    ADVISER_WORKER = os.environ.get("ADVISER_WORKER", "1") == "1"
    ADVISER_TICK_SECONDS = 5


class DevConfig(Config):
    DEBUG = True


class ProdConfig(Config):
    DEBUG = False


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_ENGINE_OPTIONS = {}
    MARKET_DATA_MODE = "synthetic"
    RATELIMIT_ENABLED = False
    ADVISER_WORKER = False


config_by_name = {"development": DevConfig, "production": ProdConfig, "testing": TestConfig}
