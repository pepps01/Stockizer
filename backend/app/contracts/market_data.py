"""Market-data value objects and source ports. A price source turns TickerRefs
into daily OHLCV DataFrames (index: datetime.date, columns: BAR_COLUMNS)."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from datetime import date, datetime, time
from zoneinfo import ZoneInfo

import pandas as pd

BAR_COLUMNS = ["open", "high", "low", "close", "volume"]


def empty_bars() -> pd.DataFrame:
    return pd.DataFrame(columns=BAR_COLUMNS, dtype=float)


@dataclass(frozen=True)
class SessionInfo:
    """An exchange's trading session in its local timezone."""

    timezone: str
    opens_at: time
    closes_at: time
    trading_days: tuple[int, ...]  # Monday = 0

    def now_local(self) -> datetime:
        return datetime.now(ZoneInfo(self.timezone))

    def is_open(self, now: datetime | None = None) -> bool:
        now = now or self.now_local()
        if now.weekday() not in self.trading_days:
            return False
        return self.opens_at <= now.time().replace(tzinfo=None) < self.closes_at


@dataclass(frozen=True)
class TickerRef:
    """What a price source needs to know about a ticker, decoupled from the ORM."""

    symbol: str
    kind: str
    data_source: str
    exchange_code: str
    base_price: float | None
    session: SessionInfo


class IPriceSource(ABC):
    name: str

    @abstractmethod
    def daily_bars(self, refs: list[TickerRef], start: date, end: date) -> dict[str, pd.DataFrame]:
        """Bars in [start, end]. A bar for today may be partial (session in progress)."""

    @abstractmethod
    def snapshots(self, refs: list[TickerRef]) -> dict[str, dict]:
        """Latest bar plus previous close: {symbol: {price, prev_close, open, high, low, volume, as_of}}."""


class IFundamentalsProvider(ABC):
    @abstractmethod
    def fundamentals(self, ticker, price: float | None) -> dict:
        """Market cap, valuation ratios and profile text for a stock."""
