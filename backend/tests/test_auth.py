import pytest
from itsdangerous import URLSafeTimedSerializer

from app import create_app
from app.extensions import db


@pytest.fixture
def app():
    app = create_app("testing")
    yield app
    with app.app_context():
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()


def _verification_token(app, email):
    serializer = URLSafeTimedSerializer(app.config["SECRET_KEY"])
    return serializer.dumps(email, salt=app.config["EMAIL_VERIFICATION_SALT"])


def test_register_verify_login_flow(app, client):
    register_resp = client.post(
        "/api/auth/register",
        json={
            "first_name": "Ada",
            "last_name": "Lovelace",
            "email": "ada@example.com",
            "password": "supersecret",
        },
    )
    assert register_resp.status_code == 201
    assert register_resp.get_json()["user"]["is_verified"] is False

    login_before_verify = client.post(
        "/api/auth/login", json={"email": "ada@example.com", "password": "supersecret"}
    )
    assert login_before_verify.status_code == 403

    token = _verification_token(app, "ada@example.com")
    verify_resp = client.get(f"/api/auth/verify-email?token={token}")
    assert verify_resp.status_code == 200
    assert verify_resp.get_json()["user"]["is_verified"] is True

    login_resp = client.post(
        "/api/auth/login", json={"email": "ada@example.com", "password": "supersecret"}
    )
    assert login_resp.status_code == 200
    body = login_resp.get_json()
    assert "access_token" in body

    me_resp = client.get("/api/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me_resp.status_code == 200
    assert me_resp.get_json()["user"]["email"] == "ada@example.com"


def test_register_duplicate_email_rejected(client):
    payload = {
        "first_name": "Grace",
        "last_name": "Hopper",
        "email": "grace@example.com",
        "password": "supersecret",
    }
    assert client.post("/api/auth/register", json=payload).status_code == 201
    assert client.post("/api/auth/register", json=payload).status_code == 409
