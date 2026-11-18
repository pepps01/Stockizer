import logging
import threading
import time
from datetime import date, timedelta

import pandas as pd
import yfinance as yf

from app.contracts.market_data import BAR_COLUMNS, IFundamentalsProvider, IPriceSource, TickerRef, empty_bars

logger = logging.getLogger(__name__)


class YahooPriceSource(IPriceSource):
    """Daily bars and snapshots from Yahoo Finance via yfinance."""

    name = "yahoo"
    CHUNK_SIZE = 50  # symbols per download call; bounds memory and contains failures
    DOWNLOAD_THREADS = 4

    def daily_bars(self, refs: list[TickerRef], start: date, end: date) -> dict[str, pd.DataFrame]:
        return self._download([r.symbol for r in refs], start=start.isoformat(), end=(end + timedelta(days=1)).isoformat())

    def snapshots(self, refs: list[TickerRef]) -> dict[str, dict]:
        out = {}
        for symbol, frame in self._download([r.symbol for r in refs], period="7d").items():
            if len(frame) < 2:
                continue
            last, prev = frame.iloc[-1], frame.iloc[-2]
            out[symbol] = {
                "price": float(last["close"]),
                "prev_close": float(prev["close"]),
                "open": float(last["open"]),
                "high": float(last["high"]),
                "low": float(last["low"]),
                "volume": float(last["volume"]),
                "as_of": last.name.isoformat(),
            }
        return out

    def _download(self, symbols: list[str], **kwargs) -> dict[str, pd.DataFrame]:
        out: dict[str, pd.DataFrame] = {}
        for i in range(0, len(symbols), self.CHUNK_SIZE):
            chunk = symbols[i : i + self.CHUNK_SIZE]
            try:
                raw = yf.download(chunk, interval="1d", group_by="ticker", auto_adjust=True, progress=False, threads=self.DOWNLOAD_THREADS, **kwargs)
            except Exception:
                logger.warning("yfinance download failed for %s", chunk, exc_info=True)
                continue
            for symbol in chunk:
                out[symbol] = self._normalise(raw, symbol)
        return out

    @staticmethod
    def _normalise(raw: pd.DataFrame, symbol: str) -> pd.DataFrame:
        try:
            frame = raw[symbol] if isinstance(raw.columns, pd.MultiIndex) else raw
        except KeyError:
            return empty_bars()
        frame = frame.rename(columns=str.lower)
        if "close" not in frame:
            return empty_bars()
        frame = frame.dropna(subset=["close"])
        if frame.empty:
            return empty_bars()
        frame = frame.reindex(columns=BAR_COLUMNS).fillna({"volume": 0})
        frame[["open", "high", "low"]] = frame[["open", "high", "low"]].fillna(frame["close"], axis=0)
        frame.index = [ts.date() for ts in frame.index]
        return frame.astype(float)


class YahooFundamentalsProvider(IFundamentalsProvider):
    """Company fundamentals from yfinance `.info`, cached for a few hours."""

    TTL_SECONDS = 6 * 3600
    DESCRIPTION_LIMIT = 600

    def __init__(self):
        self._cache: dict[str, tuple[float, dict]] = {}
        self._lock = threading.Lock()

    def fundamentals(self, ticker, price: float | None) -> dict:
        with self._lock:
            cached = self._cache.get(ticker.symbol)
        if cached and time.time() - cached[0] < self.TTL_SECONDS:
            return cached[1]
        data = self._fetch(ticker.symbol)
        with self._lock:
            self._cache[ticker.symbol] = (time.time(), data)
        return data

    def _fetch(self, symbol: str) -> dict:
        try:
            info = yf.Ticker(symbol).get_info()
        except Exception:
            logger.warning("yfinance info lookup failed for %s", symbol, exc_info=True)
            return {}
        description = info.get("longBusinessSummary")
        if description and len(description) > self.DESCRIPTION_LIMIT:
            description = description[: self.DESCRIPTION_LIMIT] + "…"
        return {
            "market_cap": self._float(info.get("marketCap")),
            "pe_ratio": self._float(info.get("trailingPE")),
            "forward_pe": self._float(info.get("forwardPE")),
            "eps": self._float(info.get("trailingEps")),
            "dividend_yield": self._float(info.get("dividendYield")),  # yfinance reports percent
            "beta": self._float(info.get("beta")),
            "price_to_book": self._float(info.get("priceToBook")),
            "revenue_growth": self._float(info.get("revenueGrowth")),  # fraction, year over year
            "earnings_growth": self._float(info.get("earningsGrowth")),
            "fifty_two_week_high": self._float(info.get("fiftyTwoWeekHigh")),
            "fifty_two_week_low": self._float(info.get("fiftyTwoWeekLow")),
            "employees": self._float(info.get("fullTimeEmployees")),
            "industry": info.get("industry"),
            "website": info.get("website"),
            "description": description,
        }

    @staticmethod
    def _float(value) -> float | None:
        try:
            return float(value) if value is not None else None
        except (TypeError, ValueError):
            return None
