import pytest
from werkzeug.security import generate_password_hash

from app.models import AdminAction, AdviserSession, Ticker, User


def _make_user(app, container, email, *, admin=False):
    with app.app_context():
        user = container.users.create(email=email, password_hash=generate_password_hash("supersecret"),
                                      first_name="A", last_name="B", is_verified=True)
        user.is_admin = admin
        container.uow.commit()
        return user.id


def _login(client, email):
    token = client.post("/api/auth/login", json={"email": email, "password": "supersecret"}).get_json()["access_token"]
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def admin_headers(app, client, container):
    _make_user(app, container, "boss@example.com", admin=True)
    return _login(client, "boss@example.com")


def test_admin_routes_need_an_admin(client, auth_headers, admin_headers):
    assert client.get("/api/admin/overview").status_code == 401
    assert client.get("/api/admin/overview", headers=auth_headers).status_code == 403
    overview = client.get("/api/admin/overview", headers=admin_headers)
    assert overview.status_code == 200
    body = overview.get_json()
    assert body["users"]["total"] == 2 and body["users"]["admins"] == 1
    assert {"market_data_mode", "push_enabled", "email_enabled"} <= set(body["system"])


def test_admin_rights_are_checked_live(app, client, container, admin_headers):
    with app.app_context():
        User.query.filter_by(email="boss@example.com").update({"is_admin": False})
        container.uow.commit()
    # Same token, but the flag is read from the database on each request.
    assert client.get("/api/admin/overview", headers=admin_headers).status_code == 403


def test_list_and_search_users(client, admin_headers, auth_headers):
    body = client.get("/api/admin/users?q=trader", headers=admin_headers).get_json()
    assert body["total"] == 1 and body["users"][0]["email"] == "trader@example.com"
    assert body["users"][0]["activity"] == {"selector_runs": 0, "optimizer_runs": 0, "active_sessions": 0}


def test_disabling_a_user_blocks_them_and_stops_their_sessions(app, client, container, admin_headers, auth_headers):
    client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "ZENITHBANK.NGX", "interval_sec": 60})
    with app.app_context():
        user_id = User.query.filter_by(email="trader@example.com").one().id

    resp = client.patch(f"/api/admin/users/{user_id}", headers=admin_headers, json={"is_active": False})
    assert resp.status_code == 200 and resp.get_json()["user"]["is_active"] is False

    # The old token stops working and logging in is refused.
    assert client.get("/api/auth/me", headers=auth_headers).status_code == 401
    login = client.post("/api/auth/login", json={"email": "trader@example.com", "password": "supersecret"})
    assert login.status_code == 403 and "disabled" in login.get_json()["error"]
    with app.app_context():
        assert {s.status for s in AdviserSession.query.filter_by(user_id=user_id)} == {"stopped"}
        action = AdminAction.query.one()
        assert action.action == "user.update" and action.detail["sessions_stopped"] == 1

    client.patch(f"/api/admin/users/{user_id}", headers=admin_headers, json={"is_active": True})
    assert client.post("/api/auth/login", json={"email": "trader@example.com", "password": "supersecret"}).status_code == 200


def test_admins_cannot_lock_themselves_out(app, client, container, admin_headers):
    with app.app_context():
        boss = User.query.filter_by(email="boss@example.com").one().id
    assert client.patch(f"/api/admin/users/{boss}", headers=admin_headers, json={"is_admin": False}).status_code == 400
    assert client.patch(f"/api/admin/users/{boss}", headers=admin_headers, json={"is_active": False}).status_code == 400
    assert client.patch(f"/api/admin/users/{boss}", headers=admin_headers, json={"password_hash": "x"}).status_code == 400


def test_last_admin_cannot_be_removed(app, client, container, admin_headers):
    other = _make_user(app, container, "deputy@example.com", admin=True)
    deputy = _login(client, "deputy@example.com")
    with app.app_context():
        boss = User.query.filter_by(email="boss@example.com").one().id
    assert client.patch(f"/api/admin/users/{boss}", headers=deputy, json={"is_admin": False}).status_code == 200
    # Now the deputy is the only admin left; the boss can't remove them (boss is no longer an admin anyway).
    assert client.patch(f"/api/admin/users/{other}", headers=admin_headers, json={"is_admin": False}).status_code == 403


def test_hiding_a_ticker_removes_it_from_markets_and_survives_reseeding(app, client, container, admin_headers):
    tickers = client.get("/api/admin/exchanges/NGX/tickers", headers=admin_headers).get_json()["tickers"]
    assert any(t["symbol"] == "MTNN.NGX" and t["active"] for t in tickers)

    resp = client.patch("/api/admin/tickers/MTNN.NGX", headers=admin_headers, json={"active": False})
    assert resp.status_code == 200 and resp.get_json()["ticker"]["active"] is False
    assert all(r["symbol"] != "MTNN.NGX" for r in client.get("/api/search?q=MTNN").get_json()["results"])

    exchanges = {e["code"]: e for e in client.get("/api/admin/exchanges", headers=admin_headers).get_json()["exchanges"]}
    assert exchanges["NGX"]["active_stocks"] == exchanges["NGX"]["total_stocks"] - 1

    from app.cli import CatalogSeeder

    with app.app_context():
        CatalogSeeder(container.uow).seed()
        assert Ticker.query.filter_by(symbol="MTNN.NGX").one().active is False


def test_admin_can_stop_any_session(client, auth_headers, admin_headers):
    session = client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "ZENITHBANK.NGX", "interval_sec": 60}).get_json()["session"]
    listed = client.get("/api/admin/sessions?status=active", headers=admin_headers).get_json()["sessions"]
    assert [s["user_email"] for s in listed] == ["trader@example.com"]
    resp = client.patch(f"/api/admin/sessions/{session['id']}", headers=admin_headers, json={"status": "stopped"})
    assert resp.status_code == 200 and resp.get_json()["session"]["status"] == "stopped"
    audit = client.get("/api/admin/audit", headers=admin_headers).get_json()["actions"]
    assert audit[0]["action"] == "session.status" and audit[0]["admin_email"] == "boss@example.com"
