"""Deterministic simulated prices for markets Yahoo Finance doesn't cover.

SyntheticMarketModel: each exchange has a market factor with stochastic
(clustered) volatility; each stock loads on it with its own beta,
idiosyncratic volatility, drift and rare jumps. All randomness is seeded from
the exchange code / symbol, so a symbol has the same history on every machine
and after every restart. Each series is anchored so the close on ANCHOR_DATE
equals the ticker's catalog base_price.

While a session is open, today's bar follows a minute-resolution Brownian
bridge that ends exactly at the day's close, so the live price moves through
the day and settles on the final daily bar.
"""

import hashlib
import threading
from datetime import date, datetime, timedelta

import numpy as np
import pandas as pd

from app.contracts.market_data import BAR_COLUMNS, IFundamentalsProvider, IPriceSource, SessionInfo, TickerRef, empty_bars

EPOCH = date(2012, 1, 2)
HORIZON = date(2036, 12, 31)
ANCHOR_DATE = date(2026, 1, 2)
TRADING_DAYS_PER_YEAR = 252
WEEKDAY_NAMES = ("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")


class SyntheticMarketModel:
    """Generates and memoises full daily series (EPOCH → HORIZON) per symbol."""

    @staticmethod
    def seed(*parts: str) -> int:
        """Stable 64-bit seed from string parts (same on every machine and run)."""
        digest = hashlib.sha256("|".join(parts).encode()).digest()
        return int.from_bytes(digest[:8], "little")

    def __init__(self):
        self._calendars: dict[tuple, pd.DatetimeIndex] = {}
        self._factors: dict[tuple, np.ndarray] = {}
        self._series: dict[tuple, pd.DataFrame] = {}
        self._lock = threading.Lock()

    def calendar(self, trading_days: tuple[int, ...]) -> pd.DatetimeIndex:
        if trading_days not in self._calendars:
            weekmask = " ".join(WEEKDAY_NAMES[d] for d in sorted(trading_days))
            self._calendars[trading_days] = pd.bdate_range(EPOCH, HORIZON, freq="C", weekmask=weekmask)
        return self._calendars[trading_days]

    def market_factor(self, exchange_code: str, trading_days: tuple[int, ...]) -> np.ndarray:
        key = (exchange_code, trading_days)
        if key not in self._factors:
            n = len(self.calendar(trading_days))
            rng = np.random.default_rng(SyntheticMarketModel.seed("market", exchange_code))
            base_vol = rng.uniform(0.009, 0.014)
            sigma = base_vol * self._clustered_vol(rng, n, persistence=0.97, shock=0.16)
            drift = rng.uniform(0.02, 0.10) / TRADING_DAYS_PER_YEAR
            self._factors[key] = drift + sigma * rng.standard_normal(n)
        return self._factors[key]

    def series(self, ref: TickerRef) -> pd.DataFrame:
        base = ref.base_price or self.default_base_price(ref.symbol)
        key = (ref.symbol, ref.kind, ref.exchange_code, ref.session.trading_days, float(base))
        with self._lock:
            if key not in self._series:
                self._series[key] = self._generate(ref, float(base))
            return self._series[key]

    @staticmethod
    def default_base_price(symbol: str) -> float:
        rng = np.random.default_rng(SyntheticMarketModel.seed("base", symbol))
        return float(10 ** rng.uniform(1.0, 3.0))

    @staticmethod
    def _clustered_vol(rng: np.random.Generator, n: int, *, persistence: float, shock: float) -> np.ndarray:
        """AR(1) log-volatility: realistic calm and turbulent regimes."""
        h = np.zeros(n)
        shocks = rng.standard_normal(n)
        for i in range(1, n):
            h[i] = persistence * h[i - 1] + shock * shocks[i]
        return np.exp(h - 0.5 * np.var(h))

    def _generate(self, ref: TickerRef, base_price: float) -> pd.DataFrame:
        days = ref.session.trading_days
        calendar = self.calendar(days)
        n = len(calendar)
        market = self.market_factor(ref.exchange_code, days)
        rng = np.random.default_rng(SyntheticMarketModel.seed("ticker", ref.symbol))

        if ref.kind == "index":
            idio_sigma = np.full(n, 0.0015)
            beta, drift, jumps = 1.0, 0.0, np.zeros(n)
        else:
            beta = rng.uniform(0.6, 1.4)
            drift = rng.uniform(-0.03, 0.14) / TRADING_DAYS_PER_YEAR
            idio_sigma = rng.uniform(0.011, 0.024) * self._clustered_vol(rng, n, persistence=0.95, shock=0.2)
            jumps = np.where(rng.random(n) < 0.004, rng.normal(0.0, 0.07, n), 0.0)

        log_returns = drift + beta * market + idio_sigma * rng.standard_normal(n) + jumps
        log_path = np.cumsum(log_returns)
        anchor_idx = int(np.searchsorted(calendar.values, np.datetime64(ANCHOR_DATE)))
        close = base_price * np.exp(log_path - log_path[anchor_idx])

        day_sigma = np.sqrt((beta * 0.011) ** 2 + idio_sigma**2)
        prev_close = np.concatenate([[close[0]], close[:-1]])
        open_ = prev_close * np.exp(rng.normal(0.0, 0.3, n) * day_sigma)
        high = np.maximum(open_, close) * np.exp(np.abs(rng.normal(0.0, 0.5, n)) * day_sigma)
        low = np.minimum(open_, close) * np.exp(-np.abs(rng.normal(0.0, 0.5, n)) * day_sigma)

        if ref.kind == "index":
            volume = np.zeros(n)
        else:
            base_volume = 10 ** rng.uniform(5.0, 7.3)
            surprise = np.abs(log_returns - drift) / day_sigma
            volume = np.round(base_volume * np.exp(0.35 * rng.standard_normal(n)) * (1 + 0.6 * surprise))

        frame = pd.DataFrame(
            {"open": open_, "high": high, "low": low, "close": close, "volume": volume},
            index=[d.date() for d in calendar],
        )
        frame.attrs["day_sigma"] = day_sigma
        return frame


class SyntheticSession:
    """Session-clock helpers for the simulated live bar."""

    def __init__(self, session: SessionInfo):
        self._session = session

    def last_complete_day(self) -> date:
        """Most recent trading day whose session has closed (exchange-local)."""
        now = self._session.now_local()
        day = now.date()
        closed_today = now.weekday() in self._session.trading_days and now.time().replace(tzinfo=None) >= self._session.closes_at
        if not closed_today:
            day -= timedelta(days=1)
        while day.weekday() not in self._session.trading_days:
            day -= timedelta(days=1)
        return day

    def elapsed_minutes(self) -> tuple[int, int] | None:
        """(elapsed, session length) in minutes while open, else None."""
        now = self._session.now_local()
        if not self._session.is_open(now):
            return None
        length = self._minutes(self._session.opens_at, self._session.closes_at)
        elapsed = self._minutes(self._session.opens_at, now.time().replace(tzinfo=None))
        return max(1, min(elapsed, length)), length

    @staticmethod
    def _minutes(a, b) -> int:
        return int((datetime.combine(date.min, b) - datetime.combine(date.min, a)).total_seconds() // 60)


class SyntheticPriceSource(IPriceSource):
    name = "synthetic"

    def __init__(self, model: SyntheticMarketModel | None = None):
        self._model = model or SyntheticMarketModel()

    def daily_bars(self, refs: list[TickerRef], start: date, end: date) -> dict[str, pd.DataFrame]:
        out = {}
        for ref in refs:
            frame = self._model.series(ref)
            last_complete = SyntheticSession(ref.session).last_complete_day()
            window = frame.loc[(frame.index >= start) & (frame.index <= min(end, last_complete))]
            live = self._live_bar(ref, frame)
            if live is not None and start <= live.name <= end:
                window = pd.concat([window, live.to_frame().T])
            out[ref.symbol] = window[BAR_COLUMNS].astype(float) if len(window) else empty_bars()
        return out

    def snapshots(self, refs: list[TickerRef]) -> dict[str, dict]:
        out = {}
        for ref in refs:
            frame = self._model.series(ref)
            history = frame.loc[frame.index <= SyntheticSession(ref.session).last_complete_day()]
            live = self._live_bar(ref, frame)
            if live is not None:
                bar, prev_close = live, float(history["close"].iloc[-1])
            else:
                bar, prev_close = history.iloc[-1], float(history["close"].iloc[-2])
            out[ref.symbol] = {
                "price": float(bar["close"]),
                "prev_close": prev_close,
                "open": float(bar["open"]),
                "high": float(bar["high"]),
                "low": float(bar["low"]),
                "volume": float(bar["volume"]),
                "as_of": bar.name.isoformat(),
            }
        return out

    def _live_bar(self, ref: TickerRef, frame: pd.DataFrame) -> pd.Series | None:
        clock = SyntheticSession(ref.session).elapsed_minutes()
        today = ref.session.now_local().date()
        if clock is None or today not in frame.index:
            return None
        elapsed, length = clock
        full_day = frame.loc[today]

        rng = np.random.default_rng(SyntheticMarketModel.seed("intraday", ref.symbol, today.isoformat()))
        walk = np.concatenate([[0.0], np.cumsum(rng.standard_normal(length) / np.sqrt(length))])
        t = np.linspace(0.0, 1.0, length + 1)
        target = np.log(full_day["close"] / full_day["open"])
        day_sigma = float(frame.attrs["day_sigma"][frame.index.get_loc(today)])
        bridge = (walk - t * walk[-1]) * day_sigma * 0.8 + t * target
        path = full_day["open"] * np.exp(bridge[: elapsed + 1])

        return pd.Series(
            {
                "open": float(full_day["open"]),
                "high": float(path.max()),
                "low": float(path.min()),
                "close": float(path[-1]),
                "volume": float(round(full_day["volume"] * elapsed / length)),
            },
            name=today,
        )


class SyntheticFundamentalsProvider(IFundamentalsProvider):
    """Plausible, deterministic fundamentals for simulated listings."""

    def fundamentals(self, ticker, price: float | None) -> dict:
        rng = np.random.default_rng(SyntheticMarketModel.seed("fund", ticker.symbol))
        shares = 10 ** rng.uniform(8.3, 10.3)
        pe = rng.uniform(4.5, 28.0)
        price = price or float(ticker.base_price or 0)
        # Growthier firms (higher P/E) grow faster, trade at more times book and
        # pay less out, so growth / value screens behave plausibly on simulated markets.
        tilt = (pe - 4.5) / 23.5
        style_rng = np.random.default_rng(SyntheticMarketModel.seed("style", ticker.symbol))
        dividend_yield = float(max(0.0, 7.5 * (1 - tilt) + style_rng.normal(0, 1.2)))
        price_to_book = float(max(0.3, 0.6 + 5.5 * tilt + style_rng.normal(0, 0.5)))
        revenue_growth = float(-0.03 + 0.30 * tilt + style_rng.normal(0, 0.05))
        earnings_growth = float(-0.05 + 0.40 * tilt + style_rng.normal(0, 0.08))
        return {
            "market_cap": price * shares if price else None,
            "pe_ratio": pe,
            "forward_pe": pe * rng.uniform(0.75, 1.05),
            "eps": price / pe if price else None,
            "dividend_yield": dividend_yield,  # percent, like yfinance
            "beta": rng.uniform(0.6, 1.4),
            "price_to_book": price_to_book,
            "revenue_growth": revenue_growth,
            "earnings_growth": earnings_growth,
            "fifty_two_week_high": None,
            "fifty_two_week_low": None,
            "employees": float(round(10 ** rng.uniform(2.7, 4.8))),
            "industry": ticker.sector,
            "website": None,
            "description": (
                f"{ticker.company_name} is listed on the {ticker.exchange.name} "
                f"({ticker.exchange.country.name}) in the {ticker.sector or 'general'} sector. "
                "Prices and fundamentals for this market are simulated because no free live feed covers it."
            ),
            "simulated": True,
        }
