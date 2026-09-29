"""Repository contracts (ports). Concrete implementations live in app/repositories/
and must depend only on these interfaces, never the other way around."""

from abc import ABC, abstractmethod
from typing import Optional


class UserRepository(ABC):
    @abstractmethod
    def get_by_id(self, user_id: int):
        ...

    @abstractmethod
    def get_by_email(self, email: str):
        ...

    @abstractmethod
    def create(self, *, first_name: str, last_name: str, email: str, password_hash: str):
        ...

    @abstractmethod
    def update_profile(self, user_id: int, *, first_name: Optional[str] = None, last_name: Optional[str] = None):
        ...

    @abstractmethod
    def mark_verified(self, user_id: int):
        ...


class ExchangeRepository(ABC):
    @abstractmethod
    def list_all(self) -> list[dict]:
        ...

    @abstractmethod
    def get_by_code(self, code: str) -> Optional[dict]:
        ...


class TickerRepository(ABC):
    @abstractmethod
    def list_by_exchange(self, exchange_code: str) -> list[dict]:
        ...

    @abstractmethod
    def get_by_symbol(self, symbol: str) -> Optional[dict]:
        ...

    @abstractmethod
    def list_all(self) -> list[dict]:
        """All lookup-able symbols, including non-tradable indices/benchmarks."""

    @abstractmethod
    def list_tradable(self) -> list[dict]:
        """Exchange-listed tickers only (excludes indices/benchmarks) — the
        universe the Selector ranks over."""


class FundamentalsRepository(ABC):
    """The real ticker universe (~6k symbols across Dow/S&P500/Nasdaq/Russell)
    the Selector ranks over, distinct from the small curated TickerRepository
    used for exchange-browsing pages."""

    @abstractmethod
    def list_all(self) -> list[dict]:
        ...

    @abstractmethod
    def get_by_symbol(self, symbol: str) -> Optional[dict]:
        ...


class UserActionRepository(ABC):
    @abstractmethod
    def add(self, *, user_id: int, symbol: str, action: str):
        ...

    @abstractmethod
    def list_for_user(self, user_id: int) -> list[dict]:
        ...
