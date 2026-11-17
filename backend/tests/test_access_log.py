from werkzeug.security import generate_password_hash

from app.domain.client import ClientInfo
from app.models import User, UserAccess

BROWSER = "Mozilla/5.0 (Windows NT 10.0) Chrome/150.0"


def _user(app, container, email, *, admin=False):
    with app.app_context():
        user = container.users.create(email=email, password_hash=generate_password_hash("supersecret"),
                                      first_name="A", last_name="B", is_verified=True)
        user.is_admin = admin
        container.uow.commit()
        return user.id


def _login(client, email, ip="203.0.113.7", platform=None, agent=BROWSER):
    headers = {"User-Agent": agent}
    if platform:
        headers["X-Client-Platform"] = platform
    res = client.post("/api/auth/login", json={"email": email, "password": "supersecret"},
                      headers=headers, environ_base={"REMOTE_ADDR": ip})
    return {"Authorization": f"Bearer {res.get_json()['access_token']}"}


def test_platform_is_declared_or_guessed():
    assert ClientInfo.platform_from("android", "Dart/3.9") == "android"
    assert ClientInfo.platform_from("IOS", None) == "ios"
    assert ClientInfo.platform_from(None, BROWSER) == "web"
    assert ClientInfo.platform_from("toaster", "curl/8") == "other"


def test_register_and_login_record_ip_and_platform(app, client):
    client.post("/api/auth/register", json={"first_name": "N", "last_name": "U", "email": "new@example.com", "password": "supersecret"},
                headers={"User-Agent": BROWSER, "X-Client-Platform": "web"}, environ_base={"REMOTE_ADDR": "198.51.100.4"})
    with app.app_context():
        user = User.query.filter_by(email="new@example.com").one()
        assert (user.signup_ip, user.last_ip) == ("198.51.100.4", "198.51.100.4")
        (entry,) = UserAccess.query.filter_by(user_id=user.id).all()
        assert (entry.event, entry.platform, entry.user_agent) == ("register", "web", BROWSER)


def test_login_and_app_launch_are_logged(app, client, container):
    uid = _user(app, container, "phone@example.com")
    headers = _login(client, "phone@example.com", ip="203.0.113.7", platform="android", agent="Dart/3.9 (dart:io)")
    # Same IP, minutes later: last seen moves on, no new entry.
    client.get("/api/auth/me", headers={**headers, "X-Client-Platform": "android"}, environ_base={"REMOTE_ADDR": "203.0.113.7"})
    # A new network: logged as a resume.
    client.get("/api/auth/me", headers={**headers, "X-Client-Platform": "android"}, environ_base={"REMOTE_ADDR": "192.0.2.55"})
    with app.app_context():
        events = [(e.event, e.ip, e.platform) for e in container.users.recent_access(uid)]
        assert events == [("resume", "192.0.2.55", "android"), ("login", "203.0.113.7", "android")]
        assert db_user(uid).last_ip == "192.0.2.55"


def db_user(uid):
    from app.extensions import db

    return db.session.get(User, uid)


def test_access_log_keeps_only_the_newest_entries(app, client, container):
    uid = _user(app, container, "busy@example.com")
    with app.app_context():
        for i in range(55):
            container.users.add_access(uid, event="login", ip=f"10.0.0.{i}", platform="web", user_agent=None, keep=50)
        container.uow.commit()
        assert UserAccess.query.filter_by(user_id=uid).count() == 50


def test_admins_see_ips_and_the_access_log(app, client, container):
    _user(app, container, "boss@example.com", admin=True)
    admin = _login(client, "boss@example.com", ip="203.0.113.1")
    uid = _user(app, container, "trader@example.com")
    trader = _login(client, "trader@example.com", ip="203.0.113.9", platform="ios", agent="Dart/3.9")

    listed = client.get("/api/admin/users?q=trader", headers=admin).get_json()["users"][0]
    assert listed["access"]["last_ip"] == "203.0.113.9"
    assert "last_ip" not in listed  # IPs only in the admin payload, not the profile

    access = client.get(f"/api/admin/users/{uid}/access", headers=admin).get_json()["access"]
    assert access[0]["ip"] == "203.0.113.9" and access[0]["platform"] == "ios"

    assert client.get(f"/api/admin/users/{uid}/access", headers=trader).status_code == 403
    assert "last_ip" not in client.get("/api/auth/me", headers=trader).get_json()["user"]
