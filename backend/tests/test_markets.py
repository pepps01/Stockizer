def test_countries_cover_global_markets(client):
    countries = {c["code"]: c for c in client.get("/api/countries").get_json()["countries"]}
    for code in ("US", "CA", "NG", "ZA", "KR", "GB", "JP", "BR"):
        assert code in countries
    assert countries["NG"]["region"] == "Middle East / Africa"


def test_exchange_listing_has_quotes_and_technicals(client):
    resp = client.get("/api/exchanges/ngx")
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["exchange"]["code"] == "NGX"
    assert "is_open" in body["exchange"]
    stock = next(s for s in body["stocks"] if s["display_symbol"] == "DANGCEM")
    assert stock["data_source"] == "synthetic"
    assert stock["quote"]["price"] > 0
    assert stock["technicals"]["label"] in ("Strong buy", "Buy", "Neutral", "Sell", "Strong sell")
    assert body["indices"][0]["display_symbol"] == "NGXASI"


def test_unknown_exchange_404(client):
    assert client.get("/api/exchanges/XXX").status_code == 404


def test_indices_filter_by_country(client):
    all_indices = client.get("/api/indices").get_json()["indices"]
    assert all_indices[0]["display_symbol"] == "SPX"  # catalog display order
    korean = client.get("/api/indices?country=KR").get_json()["indices"]
    assert [i["display_symbol"] for i in korean] == ["KOSPI"]
    assert "perf_1y" in korean[0]["performance"]


def test_movers_are_sorted(client):
    body = client.get("/api/movers?country=NG&limit=5").get_json()
    gainers = [r["quote"]["change_percent"] for r in body["gainers"]]
    losers = [r["quote"]["change_percent"] for r in body["losers"]]
    assert gainers == sorted(gainers, reverse=True) and all(g > 0 for g in gainers)
    assert losers == sorted(losers) and all(v < 0 for v in losers)
    volumes = [r["quote"]["volume"] for r in body["highest_volume"]]
    assert volumes == sorted(volumes, reverse=True)


def test_symbol_detail_history_and_signal(client):
    detail = client.get("/api/symbols/005930.KS").get_json()
    assert detail["ticker"]["name"] == "Samsung Electronics Co., Ltd."
    assert detail["exchange"]["code"] == "KRX"
    assert detail["fundamentals"]["market_cap"] > 0

    history = client.get("/api/symbols/005930.KS/history?range=6M").get_json()
    assert len(history["bars"]) > 100
    assert set(history["bars"][0]) == {"time", "open", "high", "low", "close", "volume"}
    assert client.get("/api/symbols/005930.KS/history?range=2W").status_code == 400

    signal = client.get("/api/symbols/SCOM.NSEKE/signal").get_json()["signal"]
    assert signal["signal_type"] in ("BUY", "SELL", "HOLD")
    assert 0.5 <= signal["confidence"] <= 1.0
    assert "threshold" in signal["reason"]


def test_search_matches_symbol_and_name(client):
    names = [r["name"] for r in client.get("/api/search?q=dangote").get_json()["results"]]
    assert "Dangote Cement Plc" in names
    symbols = [r["display_symbol"] for r in client.get("/api/search?q=SHOP").get_json()["results"]]
    assert "SHOP" in symbols


def test_watchlist_round_trip(client, auth_headers):
    assert client.post("/api/watchlist", headers=auth_headers, json={"symbol": "RY.TO"}).status_code == 201
    assert client.post("/api/watchlist", headers=auth_headers, json={"symbol": "RY.TO"}).status_code == 201
    items = client.get("/api/watchlist", headers=auth_headers).get_json()["items"]
    assert [i["symbol"] for i in items] == ["RY.TO"]
    assert client.delete("/api/watchlist/RY.TO", headers=auth_headers).status_code == 204
    assert client.get("/api/watchlist", headers=auth_headers).get_json()["items"] == []


def test_health_payload_field_named_status_is_not_the_http_status(client):
    resp = client.get("/api/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}
