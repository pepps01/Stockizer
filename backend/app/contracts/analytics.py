"""Analytics ports: statistics, technical analysis, the decision-signal engine,
Selector ranking metrics and the Optimizer's parameter search."""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Callable

import numpy as np
import pandas as pd


@dataclass(frozen=True)
class ParamSpec:
    name: str
    kind: type
    low: float
    high: float
    default: float
    description: str


class IReturnStatistics(ABC):
    @abstractmethod
    def from_array(self, returns: np.ndarray) -> dict:
        """total_return, cagr, volatility, sharpe, sortino, max_drawdown, calmar (fractions)."""

    @abstractmethod
    def from_series(self, returns: pd.Series) -> dict: ...


class ITechnicalAnalyzer(ABC):
    @abstractmethod
    def rating(self, bars: pd.DataFrame | None) -> dict:
        """Summary / moving-average / oscillator ratings in [-1, 1] with labels."""

    @abstractmethod
    def performance(self, bars: pd.DataFrame | None) -> dict:
        """Trailing returns (1W … 1Y, YTD) and 1-month volatility, in percent."""


class IBacktester(ABC):
    @abstractmethod
    def run(self, params: dict) -> tuple[dict, int]:
        """(return statistics, number of entries) for a parameter set."""


class ISignalEngine(ABC):
    @property
    @abstractmethod
    def param_specs(self) -> tuple[ParamSpec, ...]: ...

    @abstractmethod
    def default_params(self) -> dict: ...

    @abstractmethod
    def default_bounds(self) -> dict: ...

    @abstractmethod
    def clean_params(self, params: dict) -> dict: ...

    @abstractmethod
    def warmup_bars(self, params: dict) -> int: ...

    @abstractmethod
    def latest_signal(self, close: pd.Series, params: dict) -> dict | None: ...

    @abstractmethod
    def backtest(self, close: pd.Series, params: dict, start=None, end=None) -> dict: ...

    @abstractmethod
    def backtester(self, close: pd.Series, start=None, end=None) -> IBacktester: ...


class IRankingMetric(ABC):
    """A Selector performance criterion. Higher score ranks higher."""

    key: str
    label: str

    @abstractmethod
    def score(self, metrics: dict) -> float: ...


class IParameterSearch(ABC):
    @abstractmethod
    def search(self, objective: Callable[[dict], float], bounds: dict, seed: int) -> tuple[float, dict, int]:
        """Maximise `objective` inside `bounds`; returns (best score, best params, evaluations)."""
