from datetime import date

import numpy as np

from app.contracts.market_data import SessionInfo, TickerRef
from app.models import Signal
from app.sources.synthetic import ANCHOR_DATE, SyntheticPriceSource


def _selector_run(client, headers, **overrides):
    payload = {"exchange": "NGX", "period_start": "2025-01-01", "period_end": "2025-12-31", "metric": "sharpe", "top_n": 5}
    return client.post("/api/selector/runs", headers=headers, json={**payload, **overrides})


def test_synthetic_source_is_deterministic_and_anchored():
    from datetime import time

    session = SessionInfo("Africa/Lagos", time(10), time(14, 30), (0, 1, 2, 3, 4))
    ref = TickerRef("TEST.NGX", "stock", "synthetic", "NGX", 480.0, session)
    first = SyntheticPriceSource().daily_bars([ref], date(2025, 1, 1), date(2026, 3, 1))["TEST.NGX"]
    second = SyntheticPriceSource().daily_bars([ref], date(2025, 1, 1), date(2026, 3, 1))["TEST.NGX"]
    assert first.equals(second)
    assert first.loc[ANCHOR_DATE, "close"] == 480.0
    assert (first["high"] >= first[["open", "close"]].max(axis=1)).all()
    assert (first["low"] <= first[["open", "close"]].min(axis=1)).all()


def test_selector_ranks_and_writes_ticker_file(client, auth_headers):
    resp = _selector_run(client, auth_headers)
    assert resp.status_code == 201
    run = resp.get_json()["run"]
    assert run["universe_size"] == 15
    scores = [r["score"] for r in run["results"]]
    assert len(scores) == 5 and scores == sorted(scores, reverse=True)
    assert [r["rank"] for r in run["results"]] == [1, 2, 3, 4, 5]

    download = client.get(f"/api/artifacts/{run['artifact_id']}/download", headers=auth_headers)
    assert download.status_code == 200
    lines = download.data.decode().strip().splitlines()
    assert lines[0].startswith("rank,symbol")
    assert len(lines) == 6


def test_selector_validation(client, auth_headers):
    assert _selector_run(client, auth_headers, metric="vibes").status_code == 400
    assert _selector_run(client, auth_headers, period_end="2024-01-01").status_code == 400
    assert _selector_run(client, auth_headers, exchange="NOPE").status_code == 400
    assert client.post("/api/selector/runs", json={}).status_code == 401


def test_artifacts_are_private(client, auth_headers, app):
    artifact_id = _selector_run(client, auth_headers).get_json()["run"]["artifact_id"]
    client.post("/api/auth/register", json={"first_name": "E", "last_name": "V", "email": "eve@example.com", "password": "supersecret"})
    with app.app_context():
        from app.extensions import db
        from app.models import User

        User.query.filter_by(email="eve@example.com").update({"is_verified": True})
        db.session.commit()
    eve = client.post("/api/auth/login", json={"email": "eve@example.com", "password": "supersecret"}).get_json()
    other = {"Authorization": f"Bearer {eve['access_token']}"}
    assert client.get(f"/api/artifacts/{artifact_id}/download", headers=other).status_code == 404


def test_optimizer_from_selector_run(client, auth_headers):
    run_id = _selector_run(client, auth_headers).get_json()["run"]["id"]
    resp = client.post(
        "/api/optimizer/runs",
        headers=auth_headers,
        json={"selector_run_id": run_id, "top_k": 2, "training_start": "2023-01-01", "training_end": "2025-06-30", "objective": "sharpe"},
    )
    assert resp.status_code == 201
    runs = resp.get_json()["runs"]
    assert len(runs) == 2
    for run in runs:
        assert run["status"] == "completed"
        params = run["parameters"]
        assert set(params) == {"fast", "slow", "window", "trend_weight", "threshold"}
        assert params["slow"] > params["fast"] + 5
        assert run["metrics"]["test"] is not None  # out-of-sample period after training_end
        assert run["metrics"]["min_trades_met"] is True

    detail = client.get(f"/api/optimizer/runs/{runs[0]['id']}", headers=auth_headers).get_json()["run"]
    assert detail["metrics"]["curves"]["train"]


def test_optimizer_validation(client, auth_headers):
    base = {"symbols": ["DANGCEM.NGX"], "training_start": "2023-01-01", "training_end": "2025-06-30"}
    assert client.post("/api/optimizer/runs", headers=auth_headers, json={**base, "objective": "luck"}).status_code == 400
    assert client.post("/api/optimizer/runs", headers=auth_headers, json={**base, "bounds": {"fast": [1, 500]}}).status_code == 400
    assert client.post("/api/optimizer/runs", headers=auth_headers, json={**base, "symbols": ["NOPE"]}).status_code == 400
    short = {**base, "training_start": "2025-05-01"}
    run = client.post("/api/optimizer/runs", headers=auth_headers, json=short).get_json()["runs"][0]
    assert run["status"] == "failed" and "training period" in run["error"]


def test_fast_backtester_matches_reference(app, container):
    engine = container.engine
    with app.app_context():
        ticker = container.catalog.ticker("MTNN.NGX")
        close = container.market_data.history_one(ticker, date(2022, 1, 1))["close"]
    start, end = date(2023, 1, 1), date(2025, 12, 31)
    fast = engine.backtester(close, start, end)
    rng = np.random.default_rng(7)
    for _ in range(25):
        params = {s.name: rng.uniform(s.low, s.high) for s in engine.param_specs}
        reference = engine.backtest(close, params, start, end)
        stats, trades = fast.run(params)
        assert trades == reference["trades"]
        for key, value in stats.items():
            assert abs(value - reference["stats"][key]) < 1e-9


def test_adviser_session_emits_signal_on_change(client, auth_headers, app):
    created = client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "ZENITHBANK.NGX", "interval_sec": 60})
    assert created.status_code == 201
    session = created.get_json()["session"]
    assert session["last_signal_type"] in ("BUY", "SELL", "HOLD")

    signals = client.get("/api/adviser/signals", headers=auth_headers).get_json()["signals"]
    assert len(signals) == 1 and signals[0]["symbol"] == "ZENITHBANK.NGX"

    # Re-evaluating with an unchanged recommendation doesn't emit a duplicate signal.
    client.post(f"/api/adviser/sessions/{session['id']}/evaluate", headers=auth_headers)
    with app.app_context():
        assert Signal.query.count() == 1

    paused = client.patch(f"/api/adviser/sessions/{session['id']}", headers=auth_headers, json={"status": "paused"})
    assert paused.get_json()["session"]["status"] == "paused"
    assert client.post("/api/adviser/sessions", headers=auth_headers, json={"symbol": "ZENITHBANK.NGX", "interval_sec": 5}).status_code == 400


def test_adviser_uses_latest_optimised_parameters(client, auth_headers):
    runs = client.post(
        "/api/optimizer/runs",
        headers=auth_headers,
        json={"symbols": ["GTCO.NGX"], "training_start": "2023-01-01", "training_end": "2025-06-30"},
    ).get_json()["runs"]
    signal = client.get("/api/symbols/GTCO.NGX/signal", headers=auth_headers).get_json()
    assert signal["optimizer_run_id"] == runs[0]["id"]
    assert signal["signal"]["parameters"]["fast"] == runs[0]["parameters"]["fast"]
