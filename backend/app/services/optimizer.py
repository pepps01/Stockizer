"""Optimizer module: tune the signal engine's parameters for a ticker over a
training period, report the tuned strategy on the unseen period after it
(out-of-sample) next to buy-and-hold, and save the optimal values to file."""

import hashlib
import json
import math
from datetime import date, timedelta
from typing import Callable

import pandas as pd

from app.contracts.analytics import IParameterSearch, ISignalEngine
from app.contracts.repositories import ICatalogRepository, IOptimizerRunRepository, IUnitOfWork
from app.contracts.services import IArtifactStore, IMarketDataService, IOptimizerService, ISelectorService
from app.domain.errors import ValidationError
from app.models import OptimalParameter, OptimizerRun
from app.models.pipeline import OPTIMIZER_OBJECTIVES


class TrainingDataError(ValidationError):
    """A single ticker can't be optimised (recorded on its run, not raised to the client)."""


class StrategyOptimisation:
    """Optimises one close series: builds the objective, runs the search and
    summarises train / out-of-sample results. One instance per ticker."""

    MIN_TRAIN_BARS = 120
    MIN_TEST_BARS = 20
    MIN_TRADES = 3
    MIN_TRADES_PER_YEAR = 2
    CURVE_POINTS = 300
    PENALTY = -100.0

    def __init__(self, engine: ISignalEngine, search: IParameterSearch, close: pd.Series, train_start: date, train_end: date, objective: str, bounds: dict):
        self._engine = engine
        self._search = search
        self._close = close.dropna()
        self._start, self._end = train_start, train_end
        self._objective = objective
        self._bounds = bounds

    def run(self, seed_key: str) -> dict:
        train_bars = int(((self._close.index >= self._start) & (self._close.index <= self._end)).sum())
        if train_bars < self.MIN_TRAIN_BARS:
            raise TrainingDataError(f"Need at least {self.MIN_TRAIN_BARS} trading days in the training period")
        min_trades = max(self.MIN_TRADES, int(round(self.MIN_TRADES_PER_YEAR * train_bars / 252)))

        seed = int.from_bytes(hashlib.sha256(f"{seed_key}|{self._start}|{self._end}|{self._objective}".encode()).digest()[:8], "little")
        _, raw_best, evaluations = self._search.search(self._objective_fn(min_trades), self._bounds, seed)
        best = self._within(raw_best)

        train = self._engine.backtest(self._close, best, self._start, self._end)
        test_start = self._end + timedelta(days=1)
        test_bars = int((self._close.index >= test_start).sum())
        test = self._engine.backtest(self._close, best, test_start, None) if test_bars >= self.MIN_TEST_BARS else None

        return {
            "best_score": self._score(train["stats"][self._objective], train["trades"], min_trades),
            "params": best,
            "metrics": {
                "evaluations": evaluations,
                "min_trades": min_trades,
                "min_trades_met": train["trades"] >= min_trades,
                "train": self._summary(train),
                "test": self._summary(test) if test else None,
                "test_period": {"start": test_start.isoformat(), "end": self._close.index[-1].isoformat(), "bars": test_bars} if test else None,
                "curves": {"train": self._curve(train), "test": self._curve(test) if test else []},
            },
        }

    def _objective_fn(self, min_trades: int) -> Callable[[dict], float]:
        tester = self._engine.backtester(self._close, self._start, self._end)

        def objective(candidate: dict) -> float:
            stats, trades = tester.run(self._within(candidate))
            return self._score(stats[self._objective], trades, min_trades)

        return objective

    def _score(self, value: float, trades: int, min_trades: int) -> float:
        if trades < min_trades:
            # Buy-once-and-hold "strategies" overfit a single drawdown; rank them
            # below every candidate that actually trades, preferring more trades.
            return self.PENALTY + trades
        return value if math.isfinite(value) else self.PENALTY

    def _within(self, params: dict) -> dict:
        params = self._engine.clean_params(params)
        out = {}
        for spec in self._engine.param_specs:
            lo, hi = self._bounds[spec.name]
            value = min(max(params[spec.name], lo), hi)
            out[spec.name] = int(round(value)) if spec.kind is int else round(float(value), 6)
        if out["slow"] <= out["fast"] + 5:
            out["slow"] = int(min(self._bounds["slow"][1], out["fast"] + 6))
        return out

    @staticmethod
    def _summary(result: dict) -> dict:
        return {
            "strategy": {k: round(v, 6) for k, v in result["stats"].items()},
            "buy_and_hold": {k: round(v, 6) for k, v in result["benchmark"].items()},
            "trades": result["trades"],
            "win_rate": result["win_rate"],
            "exposure": round(result["exposure"], 4),
        }

    def _curve(self, result: dict) -> list[dict]:
        equity, bench = result["equity"], result["benchmark_equity"]
        if equity.empty:
            return []
        step = max(1, len(equity) // self.CURVE_POINTS)
        idx = list(range(0, len(equity), step))
        if idx[-1] != len(equity) - 1:
            idx.append(len(equity) - 1)
        return [
            {"time": equity.index[i].isoformat(), "strategy": round(float(equity.iloc[i]), 6), "buy_and_hold": round(float(bench.iloc[i]), 6)}
            for i in idx
        ]


class OptimizerService(IOptimizerService):
    MAX_TICKERS_PER_REQUEST = 10

    def __init__(
        self,
        catalog: ICatalogRepository,
        market_data: IMarketDataService,
        artifacts: IArtifactStore,
        runs: IOptimizerRunRepository,
        selector: ISelectorService,
        uow: IUnitOfWork,
        engine: ISignalEngine,
        search_factory: Callable[[ISignalEngine], IParameterSearch],
    ):
        self._catalog = catalog
        self._data = market_data
        self._artifacts = artifacts
        self._runs = runs
        self._selector = selector
        self._uow = uow
        self._engine = engine
        self._search_factory = search_factory

    def options(self) -> dict:
        return {
            "objectives": list(OPTIMIZER_OBJECTIVES),
            "parameters": [
                {"name": s.name, "type": s.kind.__name__, "low": s.low, "high": s.high, "default": s.default, "description": s.description}
                for s in self._engine.param_specs
            ],
        }

    def run(self, *, user_id, symbols, selector_run_id, top_k, training_start, training_end, objective, bounds) -> list[OptimizerRun]:
        if objective not in OPTIMIZER_OBJECTIVES:
            raise ValidationError(f"objective must be one of {', '.join(OPTIMIZER_OBJECTIVES)}")
        if training_end <= training_start:
            raise ValidationError("training_end must be after training_start")
        if training_end > date.today():
            raise ValidationError("training_end cannot be in the future")
        bounds = self._validate_bounds(bounds)
        tickers = self._resolve_tickers(user_id, symbols, selector_run_id, top_k)

        warmup_days = int(bounds["slow"][1] * 3 * 1.5) + 10
        history = self._data.history(tickers, training_start - timedelta(days=warmup_days))

        runs = []
        for ticker in tickers:
            run = OptimizerRun(
                user_id=user_id,
                ticker=ticker,
                ticker_id=ticker.id,
                selector_run_id=selector_run_id,
                training_start=training_start,
                training_end=training_end,
                bounds=bounds,
                objective=objective,
            )
            self._runs.add(run)
            runs.append(run)
            optimisation = StrategyOptimisation(
                self._engine, self._search_factory(self._engine), history[ticker.symbol]["close"],
                training_start, training_end, objective, bounds,
            )
            try:
                result = optimisation.run(seed_key=ticker.symbol)
            except TrainingDataError as exc:
                run.status, run.error = "failed", exc.message
                continue
            run.best_score = max(min(result["best_score"], 9999.0), -9999.0)
            run.metrics = result["metrics"]
            run.parameters = [OptimalParameter(param_name=k, param_value=v) for k, v in result["params"].items()]
            self._uow.flush()
            run.artifact_id = self._save_params_file(user_id, ticker, run, result).id
        self._uow.commit()
        return runs

    def list_runs(self, user_id: str, *, symbol: str | None = None) -> list[OptimizerRun]:
        ticker_id = None
        if symbol:
            ticker = self._catalog.ticker(symbol)
            if ticker is None:
                return []
            ticker_id = ticker.id
        return self._runs.list_for_user(user_id, ticker_id=ticker_id)

    def get_run(self, user_id: str, run_id: str) -> OptimizerRun | None:
        return self._runs.get_for_user(user_id, run_id)

    # ---- internals -----------------------------------------------------------------------

    def _resolve_tickers(self, user_id, symbols, selector_run_id, top_k) -> list:
        tickers = []
        if selector_run_id:
            selector_run = self._selector.get_run(user_id, selector_run_id)
            if selector_run is None:
                raise ValidationError("Selector run not found")
            tickers = [r.ticker for r in selector_run.results[: top_k or len(selector_run.results)]]
        if symbols:
            found = {t.symbol.upper(): t for t in self._catalog.tickers_by_symbols(symbols)}
            unknown = [s for s in symbols if s.upper() not in found]
            if unknown:
                raise ValidationError(f"Unknown symbol(s): {', '.join(unknown)}")
            tickers += [found[s.upper()] for s in symbols if found[s.upper()] not in tickers]
        if not tickers:
            raise ValidationError("Provide symbols or a selector_run_id")
        if len(tickers) > self.MAX_TICKERS_PER_REQUEST:
            raise ValidationError(f"Optimise at most {self.MAX_TICKERS_PER_REQUEST} tickers per request")
        return tickers

    def _validate_bounds(self, bounds: dict | None) -> dict:
        out = self._engine.default_bounds()
        specs = {s.name: s for s in self._engine.param_specs}
        for name, value in (bounds or {}).items():
            spec = specs.get(name)
            if spec is None:
                raise ValidationError(f"Unknown parameter '{name}'")
            try:
                lo, hi = float(value[0]), float(value[1])
            except (TypeError, ValueError, IndexError):
                raise ValidationError(f"Bounds for '{name}' must be [low, high]")
            if lo > hi or lo < spec.low or hi > spec.high:
                raise ValidationError(f"Bounds for '{name}' must lie within [{spec.low}, {spec.high}] with low ≤ high")
            out[name] = [lo, hi]
        return out

    def _save_params_file(self, user_id: str, ticker, run: OptimizerRun, result: dict):
        payload = {
            "symbol": ticker.symbol,
            "objective": run.objective,
            "training_start": run.training_start.isoformat(),
            "training_end": run.training_end.isoformat(),
            "parameters": result["params"],
            "train": result["metrics"]["train"],
            "test": result["metrics"]["test"],
        }
        return self._artifacts.save(
            owner_id=user_id,
            kind="params_json",
            filename=f"optimizer_{ticker.display_symbol}_{run.training_start}_{run.training_end}.json",
            content=json.dumps(payload, indent=2).encode(),
            content_type="application/json",
        )
