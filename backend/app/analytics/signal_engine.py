"""The algebraic decision signal used by the Adviser and tuned by the Optimizer.

For closing prices P with daily log returns r:

    σ_t      = stdev(r, window)                               (daily volatility)
    trend_t  = (EMA_fast / EMA_slow − 1) / (σ_t · √slow)       (trend in volatility units)
    z_t      = (P_t − SMA_window) / stdev(P, window)          (stretch from the mean)
    S_t      = w · tanh(trend_t) − (1 − w) · tanh(z_t / 2)     ∈ [−1, 1]

BUY when S_t > θ, SELL when S_t < −θ, HOLD otherwise. w (trend_weight) blends
trend-following against mean reversion; θ (threshold) sets how decisive the
signal must be. The backtest is long/flat: a BUY opens a position, a SELL
closes it, HOLD keeps whatever position is open. It is purely a signal: the
engine never places orders.
"""

import numpy as np
import pandas as pd

from app.contracts.analytics import IBacktester, IReturnStatistics, ISignalEngine, ParamSpec


class SignalEngineBase(ISignalEngine):
    """Strategy-independent half of a signal engine: parameter handling, the
    BUY/SELL/HOLD classification of a score in [-1, 1], confidence, and the
    long/flat backtest. Subclasses supply `components()` (which must include
    `close` and `score` columns), `warmup_bars()`, `backtester()` and `_explain()`."""

    TRANSACTION_COST = 0.001  # 10 bps per position change
    PARAM_SPECS: tuple[ParamSpec, ...] = ()
    key = ""
    label = ""
    description = ""

    def __init__(self, statistics: IReturnStatistics):
        self._stats = statistics
        self._specs = {s.name: s for s in self.PARAM_SPECS}

    # ---- parameters ----------------------------------------------------------------------

    @property
    def param_specs(self) -> tuple[ParamSpec, ...]:
        return self.PARAM_SPECS

    def default_params(self) -> dict:
        return {s.name: s.default for s in self.PARAM_SPECS}

    def default_bounds(self) -> dict:
        return {s.name: [s.low, s.high] for s in self.PARAM_SPECS}

    def clean_params(self, params: dict) -> dict:
        out = self.default_params()
        for name, spec in self._specs.items():
            if params.get(name) is not None:
                value = min(max(float(params[name]), spec.low), spec.high)
                out[name] = int(round(value)) if spec.kind is int else value
        return self._constrain(out, {name: spec.high for name, spec in self._specs.items()})

    def enforce(self, params: dict, bounds: dict) -> dict:
        """Clamp a candidate into `bounds`, round integer parameters and apply the
        engine's own constraints (e.g. slow span > fast span)."""
        params = self.clean_params(params)
        out = {}
        for spec in self.PARAM_SPECS:
            lo, hi = bounds[spec.name]
            value = min(max(params[spec.name], lo), hi)
            out[spec.name] = int(round(value)) if spec.kind is int else round(float(value), 6)
        return self._constrain(out, {name: hi for name, (_, hi) in bounds.items()})

    def _constrain(self, params: dict, upper: dict) -> dict:
        return params

    # ---- signal --------------------------------------------------------------------------

    @staticmethod
    def classify(score: float, threshold: float) -> str:
        if score > threshold:
            return "BUY"
        if score < -threshold:
            return "SELL"
        return "HOLD"

    @staticmethod
    def confidence(score: float, threshold: float) -> float:
        s = abs(score)
        if s > threshold:
            return round(0.5 + 0.5 * min(1.0, (s - threshold) / max(1e-9, 1 - threshold)), 3)
        return round(0.5 + 0.5 * (1 - s / max(threshold, 1e-9)), 3)

    def latest_signal(self, close: pd.Series, params: dict) -> dict | None:
        p = self.clean_params(params)
        comp = self.components(close, p).dropna()
        if comp.empty:
            return None
        row = comp.iloc[-1]
        score = float(row["score"])
        signal_type = self.classify(score, p["threshold"])
        reason, components = self._explain(row, p)
        as_of = comp.index[-1]
        return {
            "signal_type": signal_type,
            "score": round(score, 6),
            "confidence": self.confidence(score, p["threshold"]),
            "price": float(row["close"]),
            "as_of": as_of.isoformat() if hasattr(as_of, "isoformat") else str(as_of),
            "reason": f"{reason} Score {score:+.2f} vs threshold ±{p['threshold']:.2f} → {signal_type}.",
            "strategy": self.key,
            "components": components,
            "parameters": p,
        }

    def components(self, close: pd.Series, params: dict) -> pd.DataFrame:
        raise NotImplementedError

    def _explain(self, row: pd.Series, p: dict) -> tuple[str, dict]:
        raise NotImplementedError

    # ---- backtesting ---------------------------------------------------------------------

    @staticmethod
    def positions(score: pd.Series, threshold: float) -> pd.Series:
        raw = pd.Series(np.where(score > threshold, 1.0, np.where(score < -threshold, 0.0, np.nan)), index=score.index)
        return raw.ffill().fillna(0.0)

    def backtest(self, close: pd.Series, params: dict, start=None, end=None) -> dict:
        """Long/flat backtest over [start, end]; indicators use prior history as warm-up."""
        p = self.clean_params(params)
        pos = self.positions(self.components(close, p)["score"].fillna(0.0), p["threshold"])
        daily = close.pct_change().fillna(0.0)
        strat = pos.shift(1).fillna(0.0) * daily - self.TRANSACTION_COST * pos.diff().abs().fillna(0.0)

        mask = pd.Series(True, index=close.index)
        if start is not None:
            mask &= close.index >= start
        if end is not None:
            mask &= close.index <= end
        strat, daily, pos = strat[mask], daily[mask], pos[mask]
        if len(strat) < 2:
            empty = self._stats.from_array(np.array([]))
            return {"stats": empty, "benchmark": empty, "trades": 0, "win_rate": None, "exposure": 0.0,
                    "equity": pd.Series(dtype=float), "benchmark_equity": pd.Series(dtype=float)}

        trade_returns = self._trade_returns(pos, daily)
        return {
            "stats": self._stats.from_series(strat),
            "benchmark": self._stats.from_series(daily),
            "trades": int((pos.diff().fillna(pos.iloc[0]) > 0).sum()),
            "win_rate": float(np.mean([r > 0 for r in trade_returns])) if trade_returns else None,
            "exposure": float(pos.mean()),
            "equity": (1 + strat).cumprod(),
            "benchmark_equity": (1 + daily).cumprod(),
        }

    @staticmethod
    def _trade_returns(pos: pd.Series, daily: pd.Series) -> list[float]:
        held = pos.shift(1).fillna(0.0)
        results, current = [], None
        for in_market, r in zip(held.values, daily.values):
            if in_market:
                current = (1 + r) * (current if current is not None else 1.0)
            elif current is not None:
                results.append(current - 1)
                current = None
        if current is not None:
            results.append(current - 1)
        return results


class AlgebraicSignalEngine(SignalEngineBase):
    key = "algebraic"
    label = "Algebraic trend + mean reversion"
    description = "Blends an EMA trend, measured in volatility units, with the stretch from a moving average."
    PARAM_SPECS = (
        ParamSpec("fast", int, 5, 30, 12, "Fast EMA span (days)"),
        ParamSpec("slow", int, 30, 150, 50, "Slow EMA span (days)"),
        ParamSpec("window", int, 10, 60, 20, "Volatility / mean-reversion window (days)"),
        ParamSpec("trend_weight", float, 0.0, 1.0, 0.6, "Weight on trend vs. mean reversion"),
        ParamSpec("threshold", float, 0.1, 0.8, 0.3, "Signal threshold θ"),
    )

    def _constrain(self, params: dict, upper: dict) -> dict:
        if params["slow"] <= params["fast"] + 5:
            params["slow"] = int(min(upper["slow"], params["fast"] + 6))
        return params

    def warmup_bars(self, params: dict) -> int:
        return int(max(params["slow"] * 3, params["window"] * 2, 60))

    # ---- signal --------------------------------------------------------------------------

    def components(self, close: pd.Series, params: dict) -> pd.DataFrame:
        p = self.clean_params(params)
        log_ret = np.log(close).diff()
        sigma = log_ret.rolling(p["window"], min_periods=p["window"]).std()
        ema_fast = close.ewm(span=p["fast"], adjust=False).mean()
        ema_slow = close.ewm(span=p["slow"], adjust=False).mean()
        trend = (ema_fast / ema_slow - 1) / (sigma * np.sqrt(p["slow"]))
        mean = close.rolling(p["window"]).mean()
        z = (close - mean) / close.rolling(p["window"]).std().replace(0, np.nan)
        w = p["trend_weight"]
        score = w * np.tanh(trend) - (1 - w) * np.tanh(z / 2)
        return pd.DataFrame({"close": close, "trend": trend, "z": z, "score": score, "ema_fast": ema_fast, "ema_slow": ema_slow})

    def _explain(self, row: pd.Series, p: dict) -> tuple[str, dict]:
        trend_dir = "above" if row["ema_fast"] >= row["ema_slow"] else "below"
        stretch = "above" if row["z"] >= 0 else "below"
        reason = (
            f"EMA{p['fast']} is {trend_dir} EMA{p['slow']} (trend {row['trend']:+.2f}σ); "
            f"price is {abs(row['z']):.1f}σ {stretch} its {p['window']}-day mean."
        )
        return reason, {"trend": float(row["trend"]), "z": float(row["z"])}

    # ---- backtesting ---------------------------------------------------------------------

    def backtester(self, close: pd.Series, start=None, end=None) -> IBacktester:
        return FastBacktester(self, self._stats, close, start, end)


class LongFlatSimulator:
    """The numpy half of every fast backtester: turn a score array into
    long/flat positions and return statistics over the evaluation window,
    exactly as `SignalEngineBase.backtest` does with pandas."""

    def __init__(self, statistics: IReturnStatistics, close: np.ndarray, mask: np.ndarray, cost: float):
        self._stats = statistics
        self._mask = mask
        self._cost = cost
        self._daily = np.concatenate([[0.0], close[1:] / close[:-1] - 1])

    @staticmethod
    def window_mask(close: pd.Series, start=None, end=None) -> np.ndarray:
        mask = np.ones(len(close), dtype=bool)
        if start is not None:
            mask &= np.array([d >= start for d in close.index])
        if end is not None:
            mask &= np.array([d <= end for d in close.index])
        return mask

    def run(self, score: np.ndarray, threshold: float) -> tuple[dict, int]:
        raw = np.where(score > threshold, 1.0, np.where(score < -threshold, 0.0, np.nan))
        filled_at = np.where(~np.isnan(raw), np.arange(raw.size), 0)
        np.maximum.accumulate(filled_at, out=filled_at)
        pos = np.nan_to_num(raw[filled_at], nan=0.0)

        held = np.concatenate([[0.0], pos[:-1]])
        strat = held * self._daily - self._cost * np.abs(np.diff(pos, prepend=pos[0]))

        m = self._mask
        if m.sum() < 2:
            return self._stats.from_array(np.array([])), 0
        window_pos = pos[m]
        # Same entry count as `backtest`: position increases inside the window,
        # plus an already-open position at its first bar.
        entries = int((np.diff(window_pos, prepend=window_pos[0]) > 0).sum() + (window_pos[0] > 0))
        return self._stats.from_array(strat[m]), entries


class FastBacktester(IBacktester):
    """Numpy re-implementation of AlgebraicSignalEngine.backtest for the
    optimiser's inner loop. Indicator series depend only on the integer
    spans/windows, so each is computed once per distinct value and reused across
    the ~200 candidate parameter sets. Results match `backtest` exactly."""

    def __init__(self, engine: SignalEngineBase, statistics: IReturnStatistics, close: pd.Series, start=None, end=None):
        self._engine = engine
        self._stats = statistics
        self._c = close.to_numpy(dtype=float)
        mask = LongFlatSimulator.window_mask(close, start, end)
        self._sim = LongFlatSimulator(statistics, self._c, mask, engine.TRANSACTION_COST)
        self._log_ret = pd.Series(np.concatenate([[np.nan], np.diff(np.log(self._c))]))
        self._ema: dict[int, np.ndarray] = {}
        self._rolling: dict[int, tuple[np.ndarray, np.ndarray, np.ndarray]] = {}

    def run(self, params: dict) -> tuple[dict, int]:
        p = self._engine.clean_params(params)
        sigma, mean, std = self._rolling_of(p["window"])
        with np.errstate(divide="ignore", invalid="ignore"):
            trend = (self._ema_of(p["fast"]) / self._ema_of(p["slow"]) - 1) / (sigma * np.sqrt(p["slow"]))
            z = (self._c - mean) / np.where(std == 0, np.nan, std)
        w, th = p["trend_weight"], p["threshold"]
        score = np.nan_to_num(w * np.tanh(trend) - (1 - w) * np.tanh(z / 2), nan=0.0)

        return self._sim.run(score, th)

    def _ema_of(self, span: int) -> np.ndarray:
        if span not in self._ema:
            self._ema[span] = pd.Series(self._c).ewm(span=span, adjust=False).mean().to_numpy()
        return self._ema[span]

    def _rolling_of(self, window: int):
        if window not in self._rolling:
            price = pd.Series(self._c)
            self._rolling[window] = (
                self._log_ret.rolling(window, min_periods=window).std().to_numpy(),
                price.rolling(window).mean().to_numpy(),
                price.rolling(window).std().to_numpy(),
            )
        return self._rolling[window]
