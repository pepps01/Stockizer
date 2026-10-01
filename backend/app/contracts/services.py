"""Application-service ports. HTTP controllers and workers depend on these
interfaces only; implementations live in app/services/."""

from abc import ABC, abstractmethod
from datetime import date, datetime

import pandas as pd


class IEmailService(ABC):
    @abstractmethod
    def send_verification_email(self, *, to: str, first_name: str, token: str) -> None: ...

    @abstractmethod
    def send_signal_alert(self, *, to: str, first_name: str, signal: dict) -> None: ...


class IArtifactStore(ABC):
    @abstractmethod
    def save(self, *, owner_id: str, kind: str, filename: str, content: bytes, content_type: str): ...

    @abstractmethod
    def path(self, artifact) -> str: ...

    @abstractmethod
    def get_owned(self, artifact_id: str, owner_id: str): ...


class IMarketDataService(ABC):
    @abstractmethod
    def source_name(self, ticker) -> str: ...

    @abstractmethod
    def history(self, tickers: list, start: date, end: date | None = None) -> dict[str, pd.DataFrame]: ...

    @abstractmethod
    def history_one(self, ticker, start: date, end: date | None = None) -> pd.DataFrame: ...

    @abstractmethod
    def quotes(self, tickers: list) -> dict[str, dict]: ...

    @abstractmethod
    def fundamentals(self, ticker, price: float | None) -> dict: ...

    @abstractmethod
    def market_status(self, exchange) -> dict: ...


class IMarketBoard(ABC):
    @abstractmethod
    def indices(self, *, country_code: str | None = None) -> list[dict]: ...

    @abstractmethod
    def exchange_listing(self, code: str) -> dict: ...

    @abstractmethod
    def movers(self, *, country_code: str | None = None, exchange_code: str | None = None, limit: int = 6) -> dict: ...

    @abstractmethod
    def symbol_detail(self, symbol: str) -> dict: ...

    @abstractmethod
    def history(self, symbol: str, range_key: str) -> dict: ...

    @abstractmethod
    def warm(self) -> None: ...


class IAuthService(ABC):
    @abstractmethod
    def register(self, *, first_name: str, last_name: str, email: str, password: str) -> dict: ...

    @abstractmethod
    def verify_email(self, token: str) -> dict: ...

    @abstractmethod
    def login(self, *, email: str, password: str) -> dict: ...

    @abstractmethod
    def get_profile(self, user_id: str) -> dict: ...

    @abstractmethod
    def update_profile(self, user_id: str, data: dict) -> dict: ...


class ISelectorService(ABC):
    @abstractmethod
    def default_period(self) -> tuple[date, date]: ...

    @abstractmethod
    def options(self) -> dict: ...

    @abstractmethod
    def run(self, *, user_id: str, exchange_code: str, period_start: date, period_end: date, metric: str, top_n: int): ...

    @abstractmethod
    def list_runs(self, user_id: str) -> list: ...

    @abstractmethod
    def get_run(self, user_id: str, run_id: str): ...


class IOptimizerService(ABC):
    @abstractmethod
    def options(self) -> dict: ...

    @abstractmethod
    def run(
        self,
        *,
        user_id: str,
        symbols: list[str] | None,
        selector_run_id: str | None,
        top_k: int | None,
        training_start: date,
        training_end: date,
        objective: str,
        bounds: dict | None,
    ) -> list: ...

    @abstractmethod
    def list_runs(self, user_id: str, *, symbol: str | None = None) -> list: ...

    @abstractmethod
    def get_run(self, user_id: str, run_id: str): ...


class IAdviserService(ABC):
    @abstractmethod
    def signal_for(self, symbol: str, *, user_id: str | None, optimizer_run_id: str | None) -> dict: ...

    @abstractmethod
    def create_session(self, *, user_id: str, symbol: str, interval_sec: int, optimizer_run_id: str | None): ...

    @abstractmethod
    def list_sessions(self, user_id: str) -> list: ...

    @abstractmethod
    def get_session(self, user_id: str, session_id: str): ...

    @abstractmethod
    def set_status(self, session, status: str): ...

    @abstractmethod
    def evaluate_session(self, session): ...

    @abstractmethod
    def signals(self, user_id: str, *, session_id: str | None = None, since: datetime | None = None, limit: int = 50) -> list: ...

    @abstractmethod
    def run_due(self) -> int: ...


class IAccountService(ABC):
    @abstractmethod
    def watchlist(self, user_id: str) -> list[dict]: ...

    @abstractmethod
    def add_to_watchlist(self, user_id: str, symbol: str) -> str: ...

    @abstractmethod
    def remove_from_watchlist(self, user_id: str, symbol: str) -> None: ...

    @abstractmethod
    def record_action(self, user_id: str, symbol: str, action: str) -> dict: ...

    @abstractmethod
    def actions(self, user_id: str) -> list[dict]: ...
