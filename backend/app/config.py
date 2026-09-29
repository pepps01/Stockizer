import os
from datetime import timedelta

from dotenv import load_dotenv

load_dotenv()


class Config:
    SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key")
    JWT_SECRET_KEY = os.environ.get("JWT_SECRET_KEY", "dev-jwt-secret-key")
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)

    SQLALCHEMY_DATABASE_URI = os.environ.get(
        "DATABASE_URL", "sqlite:///" + os.path.join(os.getcwd(), "instance", "tickizer.db")
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    SENDGRID_API_KEY = os.environ.get("SENDGRID_API_KEY")
    EMAIL_FROM = os.environ.get("EMAIL_FROM", "no-reply@tickizer.app")
    EMAIL_VERIFICATION_SALT = "email-verification"
    EMAIL_VERIFICATION_MAX_AGE_SECONDS = 60 * 60 * 24  # 24h

    FRONTEND_URL = os.environ.get("FRONTEND_URL", "http://localhost:3000")

    # Origins allowed to call the API. Comma-separated env var overrides the
    # default, which covers the Next.js dev server and a locally-served
    # Flutter web build (native Android/iOS/desktop targets aren't browsers
    # and don't go through CORS at all).
    CORS_ORIGINS = os.environ.get(
        "CORS_ORIGINS", "http://localhost:3000,http://localhost:8080"
    ).split(",")

    MARKET_DATA_PATH = os.environ.get(
        "MARKET_DATA_PATH", os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "data.json")
    )
    FUNDAMENTALS_DATA_PATH = os.environ.get(
        "FUNDAMENTALS_DATA_PATH",
        os.path.join(os.path.dirname(os.path.dirname(__file__)), "data", "fundamentals.json"),
    )


class DevConfig(Config):
    DEBUG = True


class ProdConfig(Config):
    DEBUG = False


class TestConfig(Config):
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"


config_by_name = {"development": DevConfig, "production": ProdConfig, "testing": TestConfig}
