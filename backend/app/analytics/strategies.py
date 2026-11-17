from app.contracts.analytics import ISignalEngine, IStrategyRegistry


class StrategyRegistry(IStrategyRegistry):
    """Signal engines by key. The first one is the default: the Adviser uses it
    for symbols the user hasn't optimised, and old runs without a strategy map to it."""

    def __init__(self, engines: list[ISignalEngine]):
        if not engines:
            raise ValueError("At least one signal engine is required")
        self._engines = {e.key: e for e in engines}
        self._default = engines[0]

    @property
    def default(self) -> ISignalEngine:
        return self._default

    def get(self, key: str | None) -> ISignalEngine | None:
        return self._engines.get(key or self._default.key)

    def all(self) -> list[ISignalEngine]:
        return list(self._engines.values())
