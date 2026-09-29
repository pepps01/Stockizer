"""Service contracts (ports) for cross-cutting concerns and the Selector/Optimizer/
Adviser algorithmic pipeline described in the product spec. Concrete implementations
live in app/services/."""

from abc import ABC, abstractmethod
from typing import Optional


class IEmailService(ABC):
    @abstractmethod
    def send_verification_email(self, *, to: str, first_name: str, token: str) -> None:
        ...


class IMarketDataProvider(ABC):
    @abstractmethod
    def get_quote(self, symbol: str) -> dict:
        """Live-ish snapshot: price, change, change_percent, market_state."""

    @abstractmethod
    def get_quotes(self, symbols: list[str]) -> dict[str, dict]:
        ...

    @abstractmethod
    def get_financials(self, symbol: str) -> dict:
        """P/E ratio, market cap, EPS, and other fundamentals."""

    @abstractmethod
    def get_financials_batch(self, symbols: list[str]) -> dict[str, dict]:
        ...

    @abstractmethod
    def get_history(self, symbol: str, *, period: str = "1mo", interval: str = "1d") -> list[dict]:
        """Chronological [{time, value}] closing-price series for charting."""

    @abstractmethod
    def get_company_profile(self, symbol: str) -> dict:
        """Descriptive metadata (name, sector, country, description) for tickers
        that aren't in the curated local directory (e.g. the fundamentals
        universe), fetched live since it isn't in that data."""

    @abstractmethod
    def get_company_profiles_batch(self, symbols: list[str]) -> dict[str, dict]:
        ...

    @abstractmethod
    def is_market_open(self, exchange: dict) -> bool:
        ...


class IStockSelector(ABC):
    """Selector module: ranks tickers by stock type (Growth/Value/Equity)."""

    @abstractmethod
    def select(self, *, stock_type: str, top_n: int = 10) -> list[dict]:
        ...


class IOptimizer(ABC):
    """Optimizer module: tunes adviser parameters for a given ticker. Stub for now —
    real parameter-estimation algorithm to be plugged in later."""

    @abstractmethod
    def optimize(self, *, symbol: str, historical_period: str, param_bounds: Optional[dict] = None) -> dict:
        ...


class IAdviser(ABC):
    """Adviser module: produces a buy/sell/hold decision signal. Stub for now — real
    algebraic decision-signal algorithm to be plugged in later."""

    @abstractmethod
    def get_signal(self, *, symbol: str) -> dict:
        ...
