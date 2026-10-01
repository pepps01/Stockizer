import pytest
from werkzeug.security import generate_password_hash

from app import create_app, get_container
from app.cli import CatalogSeeder
from app.extensions import db


@pytest.fixture
def app(tmp_path):
    app = create_app("testing")
    get_container(app).artifacts.root = str(tmp_path / "artifacts")
    with app.app_context():
        CatalogSeeder(get_container(app).uow).seed()
    yield app
    with app.app_context():
        db.session.remove()
        db.drop_all()


@pytest.fixture
def container(app):
    return get_container(app)


@pytest.fixture
def client(app):
    return app.test_client()


@pytest.fixture
def auth_headers(app, client, container):
    with app.app_context():
        container.users.create(
            email="trader@example.com",
            password_hash=generate_password_hash("supersecret"),
            first_name="Test",
            last_name="Trader",
            is_verified=True,
        )
        container.uow.commit()
    token = client.post("/api/auth/login", json={"email": "trader@example.com", "password": "supersecret"}).get_json()["access_token"]
    return {"Authorization": f"Bearer {token}"}
