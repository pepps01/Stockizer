"""Indicator strategy: Stochastic + MACD + RSI, tuned by the Optimizer.

Each indicator casts a vote in [-1, 1] and the score is their mean:

    MACD       hist = (EMA_fast − EMA_slow) − EMA_smooth(EMA_fast − EMA_slow)
               vote = tanh(hist / stdev(hist, slow))          trend-following
    RSI        Wilder RSI over `rsi_window`                    contrarian
    Stochastic raw %K = 100 · (P − rolling low) / (rolling high − rolling low),
               with separate "roll low" and "roll high" look-backs;
               %K = SMA_fast(raw %K), %D = SMA_slow(%K); votes on %D   contrarian

    oscillator vote = clip((mid − value) / half_band, −1, 1), with
    mid = (overbought + oversold) / 2 and half_band = (overbought − oversold) / 2,
    so it is +1 at or below `oversold` and −1 at or above `overbought`.

    S = (MACD vote + RSI vote + Stochastic vote) / 3   ∈ [−1, 1]

BUY when S > θ, SELL when S < −θ, HOLD otherwise, with the same long/flat
backtest as the algebraic engine. The stochastic uses the rolling low/high of
closing prices because the engine works on a close series.
"""

import numpy as np
import pandas as pd

from app.analytics.signal_engine import LongFlatSimulator, SignalEngineBase
from app.contracts.analytics import IBacktester, IReturnStatistics, ParamSpec


def macd_vote(close: pd.Series, fast: int, slow: int, smooth: int) -> tuple[pd.Series, pd.Series]:
    """(histogram, histogram scaled to a vote in [-1, 1])."""
    macd = close.ewm(span=fast, adjust=False).mean() - close.ewm(span=slow, adjust=False).mean()
    hist = macd - macd.ewm(span=smooth, adjust=False).mean()
    scale = hist.rolling(slow, min_periods=slow).std().replace(0, np.nan)
    return hist, np.tanh(hist / scale)


def rsi(close: pd.Series, window: int) -> pd.Series:
    delta = close.diff()
    gain = delta.clip(lower=0).ewm(alpha=1 / window, adjust=False, min_periods=window).mean()
    loss = (-delta).clip(lower=0).ewm(alpha=1 / window, adjust=False, min_periods=window).mean()
    value = 100 - 100 / (1 + gain / loss.replace(0, np.nan))
    return value.where(~((loss == 0) & gain.notna()), 100.0)


def stochastic_d(close: pd.Series, roll_low: int, roll_high: int, fast: int, slow: int) -> pd.Series:
    """Slow stochastic %D. Both rolling windows include today's close, so raw %K
    stays within 0–100 even when the two look-backs differ."""
    low = close.rolling(roll_low).min()
    high = close.rolling(roll_high).max()
    raw_k = 100 * (close - low) / (high - low).replace(0, np.nan)
    k = raw_k.rolling(fast).mean()
    return k.rolling(slow).mean()


def combine(macd_v: np.ndarray, rsi_v: np.ndarray, stoch_v: np.ndarray, p: dict) -> np.ndarray:
    """The score from the three indicator arrays. Shared by `components` and the
    fast backtester so both paths agree to the last bit."""
    mid = (p["overbought"] + p["oversold"]) / 2
    half = (p["overbought"] - p["oversold"]) / 2
    with np.errstate(invalid="ignore"):
        rsi_vote = np.clip((mid - rsi_v) / half, -1.0, 1.0)
        stoch_vote = np.clip((mid - stoch_v) / half, -1.0, 1.0)
    return (macd_v + rsi_vote + stoch_vote) / 3


class IndicatorSignalEngine(SignalEngineBase):
    key = "indicators"
    label = "Stochastic + MACD + RSI"
    description = "MACD follows the trend; RSI and the stochastic buy oversold and sell overbought. Equal votes."
    PARAM_SPECS = (
        ParamSpec("stoch_roll_low", int, 5, 30, 14, "Roll low (rolling-low days)"),
        ParamSpec("stoch_roll_high", int, 5, 30, 14, "Roll high (rolling-high days)"),
        ParamSpec("stoch_fast", int, 1, 10, 3, "Fast (%K smoothing days)"),
        ParamSpec("stoch_slow", int, 1, 10, 3, "Slow (%D smoothing days)"),
        ParamSpec("macd_fast", int, 5, 20, 12, "MACD fast EMA (days)"),
        ParamSpec("macd_slow", int, 20, 60, 26, "MACD slow EMA (days)"),
        ParamSpec("macd_smooth", int, 5, 15, 9, "MACD signal-line smoothing (days)"),
        ParamSpec("rsi_window", int, 7, 28, 14, "RSI period (days)"),
        ParamSpec("overbought", float, 60, 90, 70, "Overbought level for RSI and stochastic"),
        ParamSpec("oversold", float, 10, 40, 30, "Oversold level for RSI and stochastic"),
        ParamSpec("threshold", float, 0.1, 0.8, 0.3, "Signal threshold θ"),
    )

    def _constrain(self, params: dict, upper: dict) -> dict:
        if params["macd_slow"] <= params["macd_fast"] + 4:
            params["macd_slow"] = int(min(upper["macd_slow"], params["macd_fast"] + 5))
        return params

    def warmup_bars(self, params: dict) -> int:
        return int(max(params["macd_slow"] * 3 + params["macd_smooth"], params["rsi_window"] * 3,
                       max(params["stoch_roll_low"], params["stoch_roll_high"]) + params["stoch_fast"] + params["stoch_slow"], 60))

    def components(self, close: pd.Series, params: dict) -> pd.DataFrame:
        p = self.clean_params(params)
        hist, macd_v = macd_vote(close, p["macd_fast"], p["macd_slow"], p["macd_smooth"])
        rsi_value = rsi(close, p["rsi_window"])
        stoch = stochastic_d(close, p["stoch_roll_low"], p["stoch_roll_high"], p["stoch_fast"], p["stoch_slow"])
        score = combine(macd_v.to_numpy(), rsi_value.to_numpy(), stoch.to_numpy(), p)
        return pd.DataFrame(
            {"close": close, "macd_hist": hist, "rsi": rsi_value, "stoch_d": stoch, "score": score},
            index=close.index,
        )

    def _explain(self, row: pd.Series, p: dict) -> tuple[str, dict]:
        def zone(value: float) -> str:
            if value <= p["oversold"]:
                return ", oversold"
            if value >= p["overbought"]:
                return ", overbought"
            return ""

        hist = float(row["macd_hist"])
        reason = (
            f"MACD({p['macd_fast']},{p['macd_slow']},{p['macd_smooth']}) histogram {hist:+.3f} "
            f"({'bullish' if hist > 0 else 'bearish'}); "
            f"RSI({p['rsi_window']}) {row['rsi']:.0f}{zone(row['rsi'])}; "
            f"stochastic %D({p['stoch_roll_low']}/{p['stoch_roll_high']},{p['stoch_fast']},{p['stoch_slow']}) "
            f"{row['stoch_d']:.0f}{zone(row['stoch_d'])}."
        )
        return reason, {"macd_hist": hist, "rsi": float(row["rsi"]), "stoch_d": float(row["stoch_d"])}

    def backtester(self, close: pd.Series, start=None, end=None) -> IBacktester:
        return IndicatorBacktester(self, self._stats, close, start, end)


class IndicatorBacktester(IBacktester):
    """Fast path for the Optimizer: each indicator series depends only on its
    integer windows, so it is computed once per distinct window and reused."""

    def __init__(self, engine: IndicatorSignalEngine, statistics: IReturnStatistics, close: pd.Series, start=None, end=None):
        self._engine = engine
        self._close = pd.Series(close.to_numpy(dtype=float))
        self._sim = LongFlatSimulator(statistics, self._close.to_numpy(), LongFlatSimulator.window_mask(close, start, end),
                                      engine.TRANSACTION_COST)
        self._macd: dict[tuple[int, int, int], np.ndarray] = {}
        self._rsi: dict[int, np.ndarray] = {}
        self._stoch: dict[tuple[int, int, int, int], np.ndarray] = {}

    def run(self, params: dict) -> tuple[dict, int]:
        p = self._engine.clean_params(params)
        key = (p["macd_fast"], p["macd_slow"], p["macd_smooth"])
        if key not in self._macd:
            self._macd[key] = macd_vote(self._close, *key)[1].to_numpy()
        if p["rsi_window"] not in self._rsi:
            self._rsi[p["rsi_window"]] = rsi(self._close, p["rsi_window"]).to_numpy()
        skey = (p["stoch_roll_low"], p["stoch_roll_high"], p["stoch_fast"], p["stoch_slow"])
        if skey not in self._stoch:
            self._stoch[skey] = stochastic_d(self._close, *skey).to_numpy()
        score = np.nan_to_num(combine(self._macd[key], self._rsi[p["rsi_window"]], self._stoch[skey], p), nan=0.0)
        return self._sim.run(score, p["threshold"])
