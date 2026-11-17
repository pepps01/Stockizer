from app import create_app, get_container
from app.cli import CatalogSeeder
from app.extensions import db
from app.models import User


def test_without_email_verification_new_accounts_can_log_in_at_once(app, client, container):
    container.auth._require_verification = False
    res = client.post("/api/auth/register", json={"first_name": "N", "last_name": "U", "email": "quick@example.com", "password": "supersecret"})
    assert res.status_code == 201 and res.get_json()["user"]["is_verified"] is True
    assert client.post("/api/auth/login", json={"email": "quick@example.com", "password": "supersecret"}).status_code == 200


def test_verification_is_required_by_default(client):
    res = client.post("/api/auth/register", json={"first_name": "N", "last_name": "U", "email": "slow@example.com", "password": "supersecret"})
    assert res.get_json()["user"]["is_verified"] is False
    assert client.post("/api/auth/login", json={"email": "slow@example.com", "password": "supersecret"}).status_code == 403


def test_ensure_admin_creates_then_promotes(monkeypatch):
    app = create_app("testing")
    app.config.update(ADMIN_EMAIL="boss@example.com", ADMIN_PASSWORD="supersecret")
    with app.app_context():
        CatalogSeeder(get_container(app).uow).seed()
    runner = app.test_cli_runner()
    assert "Admin ready" in runner.invoke(args=["ensure-admin"]).output
    with app.app_context():
        user = User.query.filter_by(email="boss@example.com").one()
        assert user.is_admin and user.is_verified
        user.is_admin = False
        db.session.commit()
    runner.invoke(args=["ensure-admin"])
    with app.app_context():
        assert User.query.filter_by(email="boss@example.com").one().is_admin
        db.drop_all()
