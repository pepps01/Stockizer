import json
import threading
from typing import Optional

from app.contracts.repositories import ExchangeRepository, TickerRepository


class _MarketDataStore:
    """Loads and caches data.json once per process. Both repositories below share
    this loader instead of re-reading the file on every request."""

    _lock = threading.Lock()

    def __init__(self, path: str):
        self._path = path
        self._data: Optional[dict] = None

    def load(self) -> dict:
        if self._data is None:
            with self._lock:
                if self._data is None:
                    with open(self._path, "r", encoding="utf-8") as f:
                        self._data = json.load(f)
        return self._data


class LocalExchangeRepository(ExchangeRepository):
    def __init__(self, data_path: str):
        self._store = _MarketDataStore(data_path)

    def list_all(self) -> list[dict]:
        return list(self._store.load()["exchanges"])

    def get_by_code(self, code: str) -> Optional[dict]:
        code = code.upper()
        for exchange in self._store.load()["exchanges"]:
            if exchange["code"] == code:
                return exchange
        return None


class LocalTickerRepository(TickerRepository):
    """Backs onto data.json's "tickers" (exchange-listed) plus "indices"
    (benchmarks like the S&P 500 used on the dashboard, not tied to a single
    tradable exchange). list_by_exchange only ever returns tickers."""

    def __init__(self, data_path: str):
        self._store = _MarketDataStore(data_path)

    def _all_symbols(self) -> list[dict]:
        data = self._store.load()
        return [*data["tickers"], *data.get("indices", [])]

    def list_all(self) -> list[dict]:
        return self._all_symbols()

    def list_tradable(self) -> list[dict]:
        return list(self._store.load()["tickers"])

    def list_by_exchange(self, exchange_code: str) -> list[dict]:
        exchange_code = exchange_code.upper()
        return [t for t in self._store.load()["tickers"] if t["exchange"] == exchange_code]

    def get_by_symbol(self, symbol: str) -> Optional[dict]:
        symbol = symbol.upper()
        for ticker in self._all_symbols():
            if ticker["symbol"] == symbol:
                return ticker
        return None
