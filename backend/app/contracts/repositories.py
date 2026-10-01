"""Persistence ports. Services depend only on these interfaces; the SQLAlchemy
implementations live in app/repositories/."""

from abc import ABC, abstractmethod
from datetime import date, datetime

import pandas as pd


class IUnitOfWork(ABC):
    """Transaction boundary. Repositories stage changes; services decide when
    they become durable."""

    @abstractmethod
    def commit(self) -> None: ...

    @abstractmethod
    def rollback(self) -> None: ...

    @abstractmethod
    def flush(self) -> None: ...

    @abstractmethod
    def close(self) -> None:
        """Release the current session (long-lived loops call this between cycles)."""


class ICatalogRepository(ABC):
    @abstractmethod
    def countries(self) -> list[dict]: ...

    @abstractmethod
    def exchanges(self, *, country_code: str | None = None) -> list: ...

    @abstractmethod
    def exchange(self, code: str): ...

    @abstractmethod
    def stock_counts(self) -> dict[str, int]: ...

    @abstractmethod
    def tickers(self, *, kind: str | None = None, exchange_code: str | None = None, country_code: str | None = None) -> list: ...

    @abstractmethod
    def ticker(self, symbol: str): ...

    @abstractmethod
    def tickers_by_symbols(self, symbols: list[str]) -> list: ...

    @abstractmethod
    def search(self, text: str, limit: int = 12) -> list: ...


class IBarRepository(ABC):
    @abstractmethod
    def coverage(self, ticker_ids: list[str]) -> dict[str, tuple[date, date]]: ...

    @abstractmethod
    def upsert(self, ticker_id: str, frame: pd.DataFrame, source: str) -> None: ...

    @abstractmethod
    def read(self, ticker_ids: list[str], start: date, end: date) -> dict[str, pd.DataFrame]: ...


class IUserRepository(ABC):
    @abstractmethod
    def get_by_id(self, user_id: str): ...

    @abstractmethod
    def get_by_email(self, email: str): ...

    @abstractmethod
    def create(self, *, first_name: str, last_name: str, email: str, password_hash: str, is_verified: bool = False): ...

    @abstractmethod
    def update(self, user_id: str, **fields): ...


class ISelectorRunRepository(ABC):
    @abstractmethod
    def add(self, run) -> None: ...

    @abstractmethod
    def list_for_user(self, user_id: str, limit: int = 20) -> list: ...

    @abstractmethod
    def get_for_user(self, user_id: str, run_id: str): ...


class IOptimizerRunRepository(ABC):
    @abstractmethod
    def add(self, run) -> None: ...

    @abstractmethod
    def list_for_user(self, user_id: str, *, ticker_id: str | None = None, limit: int = 30) -> list: ...

    @abstractmethod
    def get_for_user(self, user_id: str, run_id: str): ...

    @abstractmethod
    def latest_completed(self, user_id: str, ticker_id: str): ...


class IAdviserSessionRepository(ABC):
    @abstractmethod
    def add(self, session) -> None: ...

    @abstractmethod
    def get_for_user(self, user_id: str, session_id: str): ...

    @abstractmethod
    def list_open_for_user(self, user_id: str) -> list: ...

    @abstractmethod
    def count_active(self, user_id: str) -> int: ...

    @abstractmethod
    def list_active(self) -> list: ...


class ISignalRepository(ABC):
    @abstractmethod
    def add(self, signal) -> None: ...

    @abstractmethod
    def list_for_user(self, user_id: str, *, session_id: str | None = None, since: datetime | None = None, limit: int = 50) -> list: ...


class IWatchlistRepository(ABC):
    @abstractmethod
    def list_for_user(self, user_id: str) -> list: ...

    @abstractmethod
    def add(self, user_id: str, ticker_id: str) -> None: ...

    @abstractmethod
    def remove(self, user_id: str, ticker_id: str) -> None: ...


class IUserActionRepository(ABC):
    @abstractmethod
    def add(self, user_id: str, ticker_id: str, action: str): ...

    @abstractmethod
    def list_for_user(self, user_id: str, limit: int = 100) -> list: ...


class IArtifactRepository(ABC):
    @abstractmethod
    def add(self, artifact) -> None: ...

    @abstractmethod
    def get(self, artifact_id: str): ...
