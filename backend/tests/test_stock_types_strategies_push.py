from datetime import date

import numpy as np

from app.analytics.style import ExchangeRelativeStyleClassifier
from app.contracts.services import IPushService
from app.models import DeviceToken


def _selector_run(client, headers, **overrides):
    payload = {"exchange": "NGX", "period_start": "2025-01-01", "period_end": "2025-12-31", "metric": "sharpe", "top_n": 5}
    return client.post("/api/selector/runs", headers=headers, json={**payload, **overrides})


# ---- Selector stock types ------------------------------------------------------------------


def test_style_classifier_ranks_within_the_exchange():
    fundamentals = {
        "CHEAP": {"pe_ratio": 5, "forward_pe": 5, "price_to_book": 0.6, "dividend_yield": 8, "revenue_growth": 0.01, "earnings_growth": 0.0},
        "MID": {"pe_ratio": 14, "forward_pe": 13, "price_to_book": 2, "dividend_yield": 3, "revenue_growth": 0.07, "earnings_growth": 0.06},
        "FAST": {"pe_ratio": 60, "forward_pe": 35, "price_to_book": 12, "dividend_yield": 0, "revenue_growth": 0.4, "earnings_growth": 0.5},
        "EMPTY": {},
    }
    styles = ExchangeRelativeStyleClassifier().classify(fundamentals)
    assert styles["CHEAP"]["style"] == "value"
    assert styles["MID"]["style"] == "blend"
    assert styles["FAST"]["style"] == "growth"
    assert styles["EMPTY"] == {"style": None, "style_score": None}
    assert styles["FAST"]["style_score"] > styles["MID"]["style_score"] > styles["CHEAP"]["style_score"]


def test_selector_offers_stock_types(client):
    options = client.get("/api/selector/options").get_json()
    assert [t["value"] for t in options["stock_types"]] == ["equity", "growth", "value"]


def test_selector_screens_growth_and_value(client, auth_headers):
    equity = _selector_run(client, auth_headers, top_n=50).get_json()["run"]
    growth = _selector_run(client, auth_headers, stock_type="growth", top_n=50).get_json()["run"]
    value = _selector_run(client, auth_headers, stock_type="value", top_n=50).get_json()["run"]

    assert equity["stock_type"] == "equity" and growth["stock_type"] == "growth" and value["stock_type"] == "value"
    assert 0 < growth["universe_size"] < equity["universe_size"]
    assert 0 < value["universe_size"] < equity["universe_size"]
    assert {r["metrics"]["style"] for r in growth["results"]} == {"growth"}
    assert {r["metrics"]["style"] for r in value["results"]} == {"value"}
    assert not {r["symbol"] for r in growth["results"]} & {r["symbol"] for r in value["results"]}
    # Equity keeps every style and labels each result.
    assert {r["metrics"]["style"] for r in equity["results"]} <= {"growth", "value", "blend"}


def test_selector_rejects_unknown_stock_type(client, auth_headers):
    assert _selector_run(client, auth_headers, stock_type="penny").status_code == 400


# ---- Optimizer strategies ------------------------------------------------------------------


def test_optimizer_lists_both_strategies(client):
    options = client.get("/api/optimizer/options").get_json()
    keys = [s["key"] for s in options["strategies"]]
    assert keys == ["algebraic", "indicators"] and options["default_strategy"] == "algebraic"
    indicators = next(s for s in options["strategies"] if s["key"] == "indicators")
    names = {p["name"] for p in indicators["parameters"]}
    assert {"stoch_roll_low", "stoch_roll_high", "stoch_fast", "stoch_slow",
            "macd_fast", "macd_slow", "macd_smooth", "rsi_window", "overbought", "oversold"} <= names


def test_indicator_fast_backtester_matches_reference(app, container):
    engine = container.strategies.get("indicators")
    with app.app_context():
        ticker = container.catalog.ticker("MTNN.NGX")
        close = container.market_data.history_one(ticker, date(2022, 1, 1))["close"]
    start, end = date(2023, 1, 1), date(2025, 12, 31)
    fast = engine.backtester(close, start, end)
    rng = np.random.default_rng(11)
    for _ in range(25):
        params = {s.name: rng.uniform(s.low, s.high) for s in engine.param_specs}
        reference = engine.backtest(close, params, start, end)
        stats, trades = fast.run(params)
        assert trades == reference["trades"]
        for key, value in stats.items():
            assert abs(value - reference["stats"][key]) < 1e-9


def test_indicator_strategy_is_tuned_and_used_by_the_adviser(client, auth_headers):
    resp = client.post(
        "/api/optimizer/runs",
        headers=auth_headers,
        json={"symbols": ["GTCO.NGX"], "strategy": "indicators", "training_start": "2023-01-01", "training_end": "2025-06-30"},
    )
    assert resp.status_code == 201
    run = resp.get_json()["runs"][0]
    assert run["status"] == "completed" and run["strategy"] == "indicators"
    assert run["parameters"]["macd_slow"] >= run["parameters"]["macd_fast"] + 5
    assert run["metrics"]["test"] is not None

    signal = client.get("/api/symbols/GTCO.NGX/signal", headers=auth_headers).get_json()["signal"]
    assert signal["strategy"] == "indicators"
    assert set(signal["components"]) == {"macd_hist", "rsi", "stoch_d"}
    assert "MACD" in signal["reason"] and "RSI" in signal["reason"]


def test_optimizer_rejects_unknown_strategy(client, auth_headers):
    body = {"symbols": ["GTCO.NGX"], "strategy": "astrology", "training_start": "2023-01-01", "training_end": "2025-06-30"}
    assert client.post("/api/optimizer/runs", headers=auth_headers, json=body).status_code == 400


# ---- Push notifications --------------------------------------------------------------------


class RecordingPush(IPushService):
    def __init__(self, dead=()):
        self.sent = []
        self._dead = set(dead)

    @property
    def enabled(self) -> bool:
        return True

    def send(self, tokens, *, title, body, data):
        self.sent.append((list(tokens), title, body, data))
        return [t for t in tokens if t in self._dead]


def test_device_registration(client, auth_headers, app):
    assert client.post("/api/devices", headers=auth_headers, json={"token": "tok-1", "platform": "android"}).status_code == 204
    assert client.post("/api/devices", headers=auth_headers, json={"token": "tok-1", "platform": "android"}).status_code == 204
    assert client.post("/api/devices", headers=auth_headers, json={"token": "tok-2", "platform": "fax"}).status_code == 400
    assert client.post("/api/devices", json={"token": "tok-3"}).status_code == 401
    with app.app_context():
        assert DeviceToken.query.count() == 1
    assert client.delete("/api/devices", headers=auth_headers, json={"token": "tok-1"}).status_code == 204
    with app.app_context():
        assert DeviceToken.query.count() == 0


def test_signal_is_pushed_and_dead_tokens_are_dropped(client, auth_headers, app, container):
    push = RecordingPush(dead={"dead-token"})
    container.adviser._push = push
    client.put("/api/auth/me", headers=auth_headers, json={"alert_channels": ["in_app", "push"]})
    for token in ("live-token", "dead-token"):
        client.post("/api/devices", headers=auth_headers, json={"token": token, "platform": "android"})

    created = client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "ZENITHBANK.NGX", "interval_sec": 60})
    assert created.status_code == 201

    assert len(push.sent) == 1
    tokens, title, body, data = push.sent[0]
    assert sorted(tokens) == ["dead-token", "live-token"]
    assert "ZENITHBANK" in title and data["symbol"] == "ZENITHBANK.NGX" and data["type"] == "signal"
    with app.app_context():
        assert [d.token for d in DeviceToken.query.all()] == ["live-token"]


def test_no_push_without_the_push_channel(client, auth_headers, container):
    push = RecordingPush()
    container.adviser._push = push
    client.post("/api/devices", headers=auth_headers, json={"token": "live-token", "platform": "android"})
    client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "ZENITHBANK.NGX", "interval_sec": 60})
    assert push.sent == []
