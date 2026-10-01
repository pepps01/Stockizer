"""Selector performance criteria (Strategy pattern). Each metric turns the
per-ticker statistics into a score where higher ranks higher."""

from app.contracts.analytics import IRankingMetric


class StatisticMetric(IRankingMetric):
    """Ranks directly by one statistic (higher is better)."""

    def __init__(self, key: str, label: str, statistic: str | None = None):
        self.key = key
        self.label = label
        self._statistic = statistic or key

    def score(self, metrics: dict) -> float:
        return metrics[self._statistic]


class LowVolatilityMetric(IRankingMetric):
    key = "low_volatility"
    label = "Lowest volatility"

    def score(self, metrics: dict) -> float:
        return -metrics["volatility"]


class SmallestDrawdownMetric(IRankingMetric):
    key = "max_drawdown"
    label = "Smallest drawdown"

    def score(self, metrics: dict) -> float:
        return metrics["max_drawdown"]  # drawdowns are ≤ 0, so closer to zero ranks higher


class RankingMetricRegistry:
    def __init__(self, metrics: list[IRankingMetric]):
        self._metrics = {m.key: m for m in metrics}

    @classmethod
    def default(cls) -> "RankingMetricRegistry":
        return cls(
            [
                StatisticMetric("sharpe", "Sharpe ratio"),
                StatisticMetric("total_return", "Total return"),
                StatisticMetric("sortino", "Sortino ratio"),
                StatisticMetric("momentum", "Momentum (skip last month)"),
                LowVolatilityMetric(),
                SmallestDrawdownMetric(),
                StatisticMetric("calmar", "Calmar ratio"),
            ]
        )

    def get(self, key: str) -> IRankingMetric | None:
        return self._metrics.get(key)

    def keys(self) -> list[str]:
        return list(self._metrics)

    def options(self) -> list[dict]:
        return [{"value": m.key, "label": m.label} for m in self._metrics.values()]
