"""Market data facade: routes each ticker to its price source, caches Yahoo bars
through the bar repository, and keeps short-lived in-memory quote snapshots."""

import logging
import threading
import time
from datetime import date, datetime, timedelta, timezone

import pandas as pd

from app.contracts.market_data import IFundamentalsProvider, IPriceSource, empty_bars
from app.contracts.repositories import IBarRepository
from app.contracts.services import IMarketDataService
from app.repositories.catalog_repository import TickerRefMapper

logger = logging.getLogger(__name__)


class QuoteCache:
    """Thread-safe symbol → (fetched_at, quote) map with in-flight tracking, so
    expired entries are refreshed by exactly one background thread."""

    def __init__(self):
        self._entries: dict[str, tuple[float, dict]] = {}
        self._refreshing: set[str] = set()
        self._lock = threading.Lock()

    def partition(self, symbols_with_ttl: list[tuple[str, int]]) -> tuple[list[str], list[str]]:
        """Split into (missing, stale-and-claimed-for-refresh)."""
        now = time.time()
        missing, stale = [], []
        with self._lock:
            for symbol, ttl in symbols_with_ttl:
                entry = self._entries.get(symbol)
                if entry is None:
                    missing.append(symbol)
                elif now - entry[0] > ttl and symbol not in self._refreshing:
                    stale.append(symbol)
                    self._refreshing.add(symbol)
        return missing, stale

    def put(self, symbol: str, quote: dict) -> None:
        with self._lock:
            self._entries[symbol] = (time.time(), quote)

    def release(self, symbols: list[str]) -> None:
        with self._lock:
            self._refreshing.difference_update(symbols)

    def get_many(self, symbols: list[str]) -> dict[str, dict]:
        with self._lock:
            return {s: self._entries[s][1] for s in symbols if s in self._entries}


class MarketDataService(IMarketDataService):
    QUOTE_TTL = {"yahoo": 90, "synthetic": 10}
    HISTORY_REFRESH_SECONDS = 900

    def __init__(
        self,
        *,
        bars: IBarRepository,
        sources: dict[str, IPriceSource],
        fundamentals: dict[str, IFundamentalsProvider],
        mapper: TickerRefMapper,
    ):
        self._bars = bars
        self._sources = sources
        self._fundamentals = fundamentals
        self._mapper = mapper
        self._quotes = QuoteCache()
        self._fetched_from: dict[str, date] = {}
        self._refreshed_at: dict[str, float] = {}

    # ---- routing -------------------------------------------------------------------------

    def source_name(self, ticker) -> str:
        return self._mapper.source_of(ticker)

    def _is_cached_source(self, ticker) -> bool:
        """Remote sources are cached in MySQL; the synthetic model is regenerated on demand."""
        return self.source_name(ticker) != "synthetic"

    # ---- history -------------------------------------------------------------------------

    def history(self, tickers: list, start: date, end: date | None = None) -> dict[str, pd.DataFrame]:
        end = end or date.today() + timedelta(days=1)
        out: dict[str, pd.DataFrame] = {}
        generated = [t for t in tickers if not self._is_cached_source(t)]
        cached = [t for t in tickers if self._is_cached_source(t)]

        if generated:
            data = self._sources["synthetic"].daily_bars([self._mapper.ref(t) for t in generated], start, end)
            out.update({t.symbol: data.get(t.symbol, empty_bars()) for t in generated})
        if cached:
            self._ensure_cached(cached, start)
            rows = self._bars.read([t.id for t in cached], start, end)
            out.update({t.symbol: rows.get(t.id, empty_bars()) for t in cached})
        return out

    def history_one(self, ticker, start: date, end: date | None = None) -> pd.DataFrame:
        return self.history([ticker], start, end)[ticker.symbol]

    def _ensure_cached(self, tickers: list, start: date) -> None:
        coverage = self._bars.coverage([t.id for t in tickers])
        now = time.time()
        full, recent = [], []
        for t in tickers:
            cov = coverage.get(t.id)
            fetched_from = self._fetched_from.get(t.id)
            missing_early = cov is not None and start < cov[0] - timedelta(days=6)
            if cov is None or (missing_early and (fetched_from is None or start < fetched_from)):
                full.append(t)
            elif now - self._refreshed_at.get(t.id, 0) > self.HISTORY_REFRESH_SECONDS:
                recent.append((t, cov[1]))

        today = date.today()
        if full:
            self._fetch_and_store(full, start, today)
            for t in full:
                self._fetched_from[t.id] = start
        if recent:
            since = min(hi for _, hi in recent) - timedelta(days=7)
            self._fetch_and_store([t for t, _ in recent], since, today)

    def _fetch_and_store(self, tickers: list, start: date, end: date) -> None:
        by_source: dict[str, list] = {}
        for t in tickers:
            by_source.setdefault(self.source_name(t), []).append(t)
        for source_name, group in by_source.items():
            data = self._sources[source_name].daily_bars([self._mapper.ref(t) for t in group], start, end)
            now = time.time()
            for t in group:
                frame = data.get(t.symbol)
                if frame is not None and not frame.empty:
                    self._bars.upsert(t.id, frame, source_name)
                self._refreshed_at[t.id] = now

    # ---- quotes --------------------------------------------------------------------------

    def quotes(self, tickers: list) -> dict[str, dict]:
        """Latest snapshot per symbol. Expired entries are served stale while a
        background refresh runs; only never-seen symbols block the request."""
        by_symbol = {t.symbol: t for t in tickers}
        missing, stale = self._quotes.partition([(t.symbol, self.QUOTE_TTL[self.source_name(t)]) for t in tickers])
        if missing:
            self._refresh(self._jobs([by_symbol[s] for s in missing]))
        if stale:
            threading.Thread(target=self._refresh, args=(self._jobs([by_symbol[s] for s in stale]),), daemon=True).start()
        return self._quotes.get_many(list(by_symbol))

    def _jobs(self, tickers: list) -> list[tuple]:
        # Built in the request thread: background refreshes must not touch the ORM.
        return [(t.symbol, self.source_name(t), self._mapper.ref(t), t.currency) for t in tickers]

    def _refresh(self, jobs: list[tuple]) -> None:
        try:
            by_source: dict[str, list] = {}
            for job in jobs:
                by_source.setdefault(job[1], []).append(job)
            for source_name, group in by_source.items():
                snaps = self._sources[source_name].snapshots([ref for _, _, ref, _ in group])
                for symbol, _, ref, currency in group:
                    if symbol in snaps:
                        self._quotes.put(symbol, self._quote(symbol, snaps[symbol], currency, source_name, ref.session.is_open()))
        except Exception:
            logger.warning("quote refresh failed", exc_info=True)
        finally:
            self._quotes.release([job[0] for job in jobs])

    @staticmethod
    def _quote(symbol: str, snap: dict, currency: str, source: str, is_open: bool) -> dict:
        price, prev = snap["price"], snap["prev_close"]
        change = price - prev if prev else None
        return {
            "symbol": symbol,
            "price": price,
            "prev_close": prev,
            "change": change,
            "change_percent": (change / prev * 100) if prev else None,
            "open": snap["open"],
            "high": snap["high"],
            "low": snap["low"],
            "volume": snap["volume"],
            "as_of": snap["as_of"],
            "currency": currency,
            "source": source,
            "market_open": is_open,
            "updated_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        }

    # ---- fundamentals & status -----------------------------------------------------------

    def fundamentals(self, ticker, price: float | None) -> dict:
        if ticker.kind == "index":
            return {}
        return self._fundamentals[self.source_name(ticker)].fundamentals(ticker, price)

    def market_status(self, exchange) -> dict:
        session = self._mapper.session(exchange)
        now = session.now_local()
        return {"is_open": session.is_open(now), "local_time": now.strftime("%Y-%m-%d %H:%M")}
