"""Read models for the TradingView-style market pages: index board, movers,
exchange listings, the symbol page and chart history."""

import threading
import time
from datetime import date, timedelta

from app.contracts.analytics import ITechnicalAnalyzer
from app.contracts.repositories import ICatalogRepository
from app.contracts.services import IMarketBoard, IMarketDataService
from app.domain.errors import NotFoundError, ValidationError


class MarketBoard(IMarketBoard):
    TECHNICALS_LOOKBACK_DAYS = 430
    ANALYTICS_TTL_SECONDS = 120
    HISTORY_RANGES = {"1M": 31, "3M": 92, "6M": 183, "1Y": 366, "5Y": 5 * 366, "10Y": 10 * 366}

    def __init__(self, catalog: ICatalogRepository, market_data: IMarketDataService, analyzer: ITechnicalAnalyzer):
        self._catalog = catalog
        self._data = market_data
        self._analyzer = analyzer
        self._analytics: dict[str, tuple[float, dict]] = {}
        self._lock = threading.Lock()

    # ---- boards --------------------------------------------------------------------------

    def indices(self, *, country_code: str | None = None) -> list[dict]:
        return self._rows(self._catalog.tickers(kind="index", country_code=country_code), analytics=True)

    def exchange_listing(self, code: str) -> dict:
        exchange = self._catalog.exchange(code)
        if exchange is None:
            raise NotFoundError("Exchange not found")
        return {
            "exchange": {**exchange.to_dict(), **self._data.market_status(exchange)},
            "indices": self._rows(self._catalog.tickers(kind="index", exchange_code=exchange.code), analytics=False),
            "stocks": self._rows(self._catalog.tickers(kind="stock", exchange_code=exchange.code), analytics=True),
        }

    def movers(self, *, country_code: str | None = None, exchange_code: str | None = None, limit: int = 6) -> dict:
        tickers = self._catalog.tickers(kind="stock", country_code=country_code, exchange_code=exchange_code)
        quotes = self._data.quotes(tickers)
        rows = []
        for t in tickers:
            q = quotes.get(t.symbol)
            if not q or q.get("change_percent") is None:
                continue
            day_range = (q["high"] - q["low"]) / q["low"] * 100 if q.get("low") else 0.0
            rows.append({**t.to_dict(), "quote": q, "range_percent": day_range})

        def top(key, *, reverse=True, keep=lambda r: True):
            return sorted((r for r in rows if keep(r)), key=key, reverse=reverse)[:limit]

        change = lambda r: r["quote"]["change_percent"]  # noqa: E731
        return {
            "highest_volume": top(lambda r: r["quote"]["volume"] or 0),
            "most_volatile": top(lambda r: max(r["range_percent"], abs(change(r)))),
            "gainers": top(change, keep=lambda r: change(r) > 0),
            "losers": top(change, reverse=False, keep=lambda r: change(r) < 0),
            "universe_size": len(rows),
        }

    def symbol_detail(self, symbol: str) -> dict:
        ticker = self._require_ticker(symbol)
        quote = self._data.quotes([ticker]).get(ticker.symbol)
        bars = self._data.history_one(ticker, date.today() - timedelta(days=self.TECHNICALS_LOOKBACK_DAYS))
        fundamentals = self._data.fundamentals(ticker, quote["price"] if quote else None)
        if len(bars):
            year = bars.tail(252)
            fundamentals = {
                **fundamentals,
                "fifty_two_week_high": fundamentals.get("fifty_two_week_high") or float(year["high"].max()),
                "fifty_two_week_low": fundamentals.get("fifty_two_week_low") or float(year["low"].min()),
                "avg_volume_30d": float(bars["volume"].tail(30).mean()),
            }
        return {
            "ticker": ticker.to_dict(),
            "exchange": {**ticker.exchange.to_dict(), **self._data.market_status(ticker.exchange)},
            "quote": quote,
            "fundamentals": fundamentals,
            "technicals": self._analyzer.rating(bars),
            "performance": self._analyzer.performance(bars),
        }

    def history(self, symbol: str, range_key: str) -> dict:
        ticker = self._require_ticker(symbol)
        range_key = (range_key or "1Y").upper()
        today = date.today()
        if range_key == "YTD":
            start = date(today.year, 1, 1)
        elif range_key in self.HISTORY_RANGES:
            start = today - timedelta(days=self.HISTORY_RANGES[range_key])
        else:
            raise ValidationError(f"range must be one of {', '.join([*self.HISTORY_RANGES, 'YTD'])}")
        bars = self._data.history_one(ticker, start)
        return {
            "symbol": ticker.symbol,
            "range": range_key,
            "data_source": self._data.source_name(ticker),
            "bars": [
                {"time": ts.isoformat(), "open": r.open, "high": r.high, "low": r.low, "close": r.close, "volume": r.volume}
                for ts, r in bars.iterrows()
            ],
        }

    def warm(self) -> None:
        """Pre-load remote history and quotes so no visitor pays for the first download."""
        self.indices()
        self.movers()
        for exchange in self._catalog.exchanges():
            self.exchange_listing(exchange.code)

    # ---- internals -----------------------------------------------------------------------

    def _require_ticker(self, symbol: str):
        ticker = self._catalog.ticker(symbol)
        if ticker is None:
            raise NotFoundError("Symbol not found")
        return ticker

    def _rows(self, tickers: list, *, analytics: bool) -> list[dict]:
        quotes = self._data.quotes(tickers)
        computed = self._analytics_for(tickers) if analytics else {}
        return [{**t.to_dict(), "quote": quotes.get(t.symbol), **computed.get(t.symbol, {})} for t in tickers]

    def _analytics_for(self, tickers: list) -> dict[str, dict]:
        """Technical rating + trailing performance per symbol, memoised briefly —
        they only move with the daily bars, which refresh every few minutes."""
        now = time.time()
        with self._lock:
            stale = [t for t in tickers if now - self._analytics.get(t.symbol, (0.0, None))[0] > self.ANALYTICS_TTL_SECONDS]
        if stale:
            history = self._data.history(stale, date.today() - timedelta(days=self.TECHNICALS_LOOKBACK_DAYS))
            fresh = {}
            for t in stale:
                bars = history.get(t.symbol)
                rating = self._analyzer.rating(bars)
                fresh[t.symbol] = (
                    now,
                    {
                        "technicals": {k: rating.get(k) for k in ("summary", "label", "moving_averages", "ma_label", "oscillators", "osc_label")},
                        "performance": self._analyzer.performance(bars),
                    },
                )
            with self._lock:
                self._analytics.update(fresh)
        with self._lock:
            return {t.symbol: self._analytics[t.symbol][1] for t in tickers}
