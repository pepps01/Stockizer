import json
import threading
from typing import Optional

from app.contracts.repositories import FundamentalsRepository


class LocalFundamentalsRepository(FundamentalsRepository):
    _lock = threading.Lock()

    def __init__(self, data_path: str):
        self._path = data_path
        self._data: Optional[list[dict]] = None
        self._by_symbol: Optional[dict[str, dict]] = None

    def _load(self) -> list[dict]:
        if self._data is None:
            with self._lock:
                if self._data is None:
                    with open(self._path, "r", encoding="utf-8") as f:
                        self._data = json.load(f)
                    self._by_symbol = {record["symbol"]: record for record in self._data}
        return self._data

    def list_all(self) -> list[dict]:
        return list(self._load())

    def get_by_symbol(self, symbol: str) -> Optional[dict]:
        self._load()
        return self._by_symbol.get(symbol.upper())
