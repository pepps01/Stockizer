from itsdangerous import URLSafeTimedSerializer


def _verification_token(app, email):
    serializer = URLSafeTimedSerializer(app.config["SECRET_KEY"])
    return serializer.dumps(email, salt=app.config["EMAIL_VERIFICATION_SALT"])


def test_register_verify_login_flow(app, client):
    register_resp = client.post(
        "/api/auth/register",
        json={"first_name": "Ada", "last_name": "Lovelace", "email": "ada@example.com", "password": "supersecret"},
    )
    assert register_resp.status_code == 201
    assert register_resp.get_json()["user"]["is_verified"] is False

    login_before_verify = client.post("/api/auth/login", json={"email": "ada@example.com", "password": "supersecret"})
    assert login_before_verify.status_code == 403

    token = _verification_token(app, "ada@example.com")
    verify_resp = client.get(f"/api/auth/verify-email?token={token}")
    assert verify_resp.status_code == 200
    assert verify_resp.get_json()["user"]["is_verified"] is True

    login_resp = client.post("/api/auth/login", json={"email": "ada@example.com", "password": "supersecret"})
    assert login_resp.status_code == 200
    body = login_resp.get_json()

    me_resp = client.get("/api/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"})
    assert me_resp.status_code == 200
    me = me_resp.get_json()["user"]
    assert me["email"] == "ada@example.com"
    assert len(me["id"]) == 36  # UUID primary key


def test_register_duplicate_email_rejected(client):
    payload = {"first_name": "Grace", "last_name": "Hopper", "email": "grace@example.com", "password": "supersecret"}
    assert client.post("/api/auth/register", json=payload).status_code == 201
    assert client.post("/api/auth/register", json=payload).status_code == 409


def test_profile_update_validates_fields(client, auth_headers):
    ok = client.put(
        "/api/auth/me",
        headers=auth_headers,
        json={"risk_profile": "aggressive", "alert_channels": ["email", "in_app"], "default_exchange": "NGX"},
    )
    assert ok.status_code == 200
    user = ok.get_json()["user"]
    assert user["risk_profile"] == "aggressive"
    assert user["alert_channels"] == ["email", "in_app"]
    assert user["default_exchange"] == "NGX"

    assert client.put("/api/auth/me", headers=auth_headers, json={"risk_profile": "yolo"}).status_code == 400
    assert client.put("/api/auth/me", headers=auth_headers, json={"alert_channels": ["pager"]}).status_code == 400
    assert client.put("/api/auth/me", headers=auth_headers, json={"default_exchange": "NOPE"}).status_code == 400
