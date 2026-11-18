from datetime import date, time, timedelta

import numpy as np

from app.contracts.market_data import SessionInfo, TickerRef
from app.memory import release_memory
from app.sources.synthetic import EPOCH, SyntheticMarketModel


def _ref(symbol="DANGCEM.NGX"):
    session = SessionInfo(timezone="Africa/Lagos", opens_at=time(10), closes_at=time(14, 30), trading_days=(0, 1, 2, 3, 4))
    return TickerRef(symbol=symbol, kind="stock", data_source="synthetic", exchange_code="NGX", base_price=500.0, session=session)


def test_release_memory_is_safe_everywhere():
    release_memory()


def test_keep_until_is_the_end_of_next_month():
    assert SyntheticMarketModel.keep_until(date(2026, 11, 18)) == date(2026, 12, 31)
    assert SyntheticMarketModel.keep_until(date(2026, 12, 3)) == date(2027, 1, 31)
    assert SyntheticMarketModel.keep_until(date(2027, 1, 31)) == date(2027, 2, 28)


def test_trimmed_series_keeps_the_same_prices(monkeypatch):
    model = SyntheticMarketModel()
    ref = _ref()
    kept = model.series(ref)
    full = model._generate(ref, 500.0)
    assert kept.index[0] == EPOCH and kept.index[-1] <= SyntheticMarketModel.keep_until()
    assert len(kept) < len(full)
    np.testing.assert_array_equal(kept["close"].to_numpy(), full["close"].to_numpy()[: len(kept)])
    np.testing.assert_array_equal(kept.attrs["day_sigma"], full.attrs["day_sigma"][: len(kept)])


def test_series_memo_is_bounded():
    model = SyntheticMarketModel()
    model.MAX_SERIES = 3
    for i in range(5):
        model.series(_ref(f"S{i}.NGX"))
    assert len(model._series) == 3


def test_warm_walks_the_exchanges_in_turn(app, container):
    with app.app_context():
        total = len(container.catalog.exchanges())
        nxt = container.board.warm(start=0, count=2)
        assert nxt == 2
        assert container.board.warm(start=total - 1, count=2) == 1


def test_streamed_history_matches_the_stored_bars(app, container):
    import pandas as pd

    with app.app_context():
        ticker = next(t for t in container.catalog.tickers(kind="stock") if container.market_data.source_name(t) == "synthetic")
        frame = pd.DataFrame(
            {"open": [1.0, 2.0], "high": [1.5, 2.5], "low": [0.5, 1.5], "close": [1.2, 2.2], "volume": [10.0, 20.0]},
            index=[date(2026, 1, 5), date(2026, 1, 6)],
        )
        container.market_data._bars.upsert(ticker.id, frame, "synthetic")
        read = container.market_data._bars.read([ticker.id, "missing"], date(2026, 1, 1), date(2026, 1, 31))
        assert list(read[ticker.id].index) == [date(2026, 1, 5), date(2026, 1, 6)]
        assert read[ticker.id]["close"].tolist() == [1.2, 2.2]
        assert read["missing"].empty
