import json

import pytest
from flask_jwt_extended import create_access_token
from simple_websocket import ConnectionClosed

from app.api.base import CorsPolicy
from app.api.realtime import RealtimeGateway, RealtimeSession


class FakeSocket:
    """Scripted stand-in for a simple_websocket connection."""

    def __init__(self, incoming: list):
        self._incoming = list(incoming)
        self.sent: list[dict] = []
        self.closed_with = None

    def receive(self, timeout=None):
        if not self._incoming:
            raise ConnectionClosed()
        return self._incoming.pop(0)

    def send(self, data):
        self.sent.append(json.loads(data))

    def close(self, reason=None, message=None):
        self.closed_with = (reason, message)


def _session(ws, container, user_id=None):
    return RealtimeSession(ws, user_id, container.catalog, container.market_data, container.adviser, container.uow)


def test_subscribe_pushes_quotes_and_pong(app, container):
    ws = FakeSocket([json.dumps({"type": "subscribe", "symbols": ["dangcem.ngx", "SCOM.NSEKE"]}), json.dumps({"type": "ping"}), "not json"])
    with app.test_request_context():
        _session(ws, container).run()
    types = [m["type"] for m in ws.sent]
    assert types[0] == "welcome" and ws.sent[0]["authenticated"] is False
    quotes = next(m for m in ws.sent if m["type"] == "quotes")["quotes"]
    assert set(quotes) == {"DANGCEM.NGX", "SCOM.NSEKE"}
    assert quotes["DANGCEM.NGX"]["source"] == "synthetic"
    assert "pong" in types
    assert ws.sent[-1] == {"type": "error", "message": "Messages must be JSON"}


def test_authenticated_socket_receives_signals(app, client, auth_headers, container):
    session = client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "MTNN.NGX", "interval_sec": 60}).get_json()["session"]
    ws = FakeSocket([None])
    with app.test_request_context():
        rt = _session(ws, container, user_id=container.users.get_by_email("trader@example.com").id)
        rt._signals_since = rt._signals_since.replace(year=2000)
        rt.run()
    signals = [m["signal"] for m in ws.sent if m["type"] == "signal"]
    assert [s["session_id"] for s in signals] == [session["id"]]


@pytest.mark.parametrize(
    "origin, token, allowed",
    [("http://localhost:3000", None, True), ("https://evil.example", None, False), (None, "garbage", False)],
)
def test_gateway_checks_origin_and_token(app, container, origin, token, allowed):
    gateway = RealtimeGateway(CorsPolicy(["http://localhost:3000"]), container.catalog, container.market_data, container.adviser, container.uow)
    headers = {"Origin": origin} if origin else {}
    query = f"?token={token}" if token else ""
    ws = FakeSocket([])
    with app.test_request_context(f"/ws{query}", headers=headers):
        gateway.handle(ws)
    if allowed:
        assert ws.closed_with is None and ws.sent[0]["type"] == "welcome"
    else:
        assert ws.closed_with[0] == RealtimeGateway.POLICY_VIOLATION and not ws.sent


def test_gateway_accepts_valid_token(app, container):
    gateway = RealtimeGateway(CorsPolicy(["http://localhost:3000"]), container.catalog, container.market_data, container.adviser, container.uow)
    with app.app_context():
        token = create_access_token(identity="user-123")
    ws = FakeSocket([])
    with app.test_request_context(f"/ws?token={token}", headers={"Origin": "http://localhost:3000"}):
        gateway.handle(ws)
    assert ws.sent[0] == {"type": "welcome", "authenticated": True}


def test_cors_allows_configured_origin_only(client):
    ok = client.get("/api/countries", headers={"Origin": "http://localhost:3000"})
    assert ok.headers["Access-Control-Allow-Origin"] == "http://localhost:3000"
    assert "X-RateLimit-Remaining" in ok.headers.get("Access-Control-Expose-Headers", "")

    preflight = client.options(
        "/api/selector/runs",
        headers={"Origin": "http://localhost:3000", "Access-Control-Request-Method": "POST", "Access-Control-Request-Headers": "Authorization, Content-Type"},
    )
    assert preflight.status_code == 200
    assert "POST" in preflight.headers["Access-Control-Allow-Methods"]
    assert "authorization" in preflight.headers["Access-Control-Allow-Headers"].lower()

    blocked = client.get("/api/countries", headers={"Origin": "https://evil.example"})
    assert "Access-Control-Allow-Origin" not in blocked.headers
