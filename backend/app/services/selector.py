"""Selector module: screen an exchange's stocks by type (equity = all, growth or
value), rank them by a performance criterion over a historical period, keep the
top N, and save them to a ticker file."""

import csv
import io
from datetime import date, timedelta

import numpy as np
import pandas as pd

from app.contracts.analytics import IReturnStatistics, IStyleClassifier
from app.contracts.repositories import ICatalogRepository, ISelectorRunRepository, IUnitOfWork
from app.contracts.services import IArtifactStore, IMarketDataService, ISelectorService
from app.analytics.ranking import RankingMetricRegistry
from app.analytics.style import STOCK_TYPES as STYLE_INFO
from app.domain.errors import ValidationError
from app.models import SelectorResult, SelectorRun
from app.models.pipeline import STOCK_TYPES


# Short descriptions for the Selector's picker; the full ones live in analytics/style.py.
STOCK_TYPE_INFO = {
    "equity": (STYLE_INFO["equity"]["label"], "Every listed stock on the exchange: a share of ownership in the company."),
    "growth": (STYLE_INFO["growth"]["label"], "Expected to grow faster than the market. They reinvest profits, pay little or no dividend and trade on high P/E."),
    "value": (STYLE_INFO["value"]["label"], "Trading below what their fundamentals suggest. Often mature, steady companies with low P/E that pay dividends."),
}


class SelectorService(ISelectorService):
    MIN_BARS = 20
    MIN_PERIOD_DAYS = 30
    MAX_TOP_N = 50
    MOMENTUM_SKIP_DAYS = 21  # classic 12-1 momentum skips the most recent month

    def __init__(
        self,
        catalog: ICatalogRepository,
        market_data: IMarketDataService,
        artifacts: IArtifactStore,
        runs: ISelectorRunRepository,
        uow: IUnitOfWork,
        statistics: IReturnStatistics,
        metrics: RankingMetricRegistry,
        styles: IStyleClassifier,
    ):
        self._catalog = catalog
        self._data = market_data
        self._artifacts = artifacts
        self._runs = runs
        self._uow = uow
        self._stats = statistics
        self._metrics = metrics
        self._styles = styles

    @staticmethod
    def default_period() -> tuple[date, date]:
        end = date.today()
        return end - timedelta(days=365), end

    def options(self) -> dict:
        start, end = self.default_period()
        return {
            "metrics": self._metrics.options(),
            "stock_types": [{"value": key, "label": label, "description": text} for key, (label, text) in STOCK_TYPE_INFO.items()],
            "default_period": {"start": start.isoformat(), "end": end.isoformat()},
        }

    def run(self, *, user_id: str, exchange_code: str, period_start: date, period_end: date, metric: str, top_n: int,
            stock_type: str = "equity") -> SelectorRun:
        ranking = self._metrics.get(metric)
        if ranking is None:
            raise ValidationError(f"metric must be one of {', '.join(self._metrics.keys())}")
        if period_end <= period_start:
            raise ValidationError("period_end must be after period_start")
        if (period_end - period_start).days < self.MIN_PERIOD_DAYS:
            raise ValidationError(f"Choose a historical period of at least {self.MIN_PERIOD_DAYS} days")
        if stock_type not in STOCK_TYPES:
            raise ValidationError(f"stock_type must be one of {', '.join(STOCK_TYPES)}")
        if not 1 <= top_n <= self.MAX_TOP_N:
            raise ValidationError(f"top_n must be between 1 and {self.MAX_TOP_N}")
        exchange = self._catalog.exchange(exchange_code or "")
        if exchange is None:
            raise ValidationError("Unknown exchange")

        stocks = self._catalog.tickers(kind="stock", exchange_code=exchange.code)
        styles = self._styles.classify(self._data.fundamentals_many(stocks))
        if stock_type != "equity":
            stocks = [t for t in stocks if styles.get(t.symbol, {}).get("style") == stock_type]
            if not stocks:
                raise ValidationError(f"No {stock_type} stocks could be identified on {exchange.name}: fundamentals are missing")
        history = self._data.history(stocks, period_start, period_end)
        scored = []
        for ticker in stocks:
            bars = history.get(ticker.symbol)
            if bars is None or len(bars) < self.MIN_BARS:
                continue
            metrics = {**self._ticker_metrics(bars["close"]), **styles.get(ticker.symbol, {"style": None, "style_score": None})}
            scored.append((ticker, ranking.score(metrics), metrics))
        if not scored:
            raise ValidationError("No price history available for this exchange and period")
        scored.sort(key=lambda item: item[1], reverse=True)

        run = SelectorRun(
            user_id=user_id,
            exchange_id=exchange.id,
            period_start=period_start,
            period_end=period_end,
            metric=metric,
            top_n=top_n,
            stock_type=stock_type,
            universe_size=len(scored),
        )
        self._runs.add(run)
        for rank, (ticker, score, metrics) in enumerate(scored[:top_n], start=1):
            run.results.append(SelectorResult(ticker=ticker, ticker_id=ticker.id, rank=rank, score=round(score, 6), metrics=metrics))
        self._uow.flush()
        run.artifact_id = self._artifacts.save(
            owner_id=user_id,
            kind="ticker_file",
            filename=f"selector_{exchange.code}_{stock_type}_{metric}_{period_start}_{period_end}.csv",
            content=self._ticker_file(run, exchange.code),
            content_type="text/csv",
        ).id
        self._uow.commit()
        return run

    def list_runs(self, user_id: str) -> list[SelectorRun]:
        return self._runs.list_for_user(user_id)

    def get_run(self, user_id: str, run_id: str) -> SelectorRun | None:
        return self._runs.get_for_user(user_id, run_id)

    def _ticker_metrics(self, close: pd.Series) -> dict:
        stats = self._stats.from_series(close.pct_change().dropna())
        momentum_close = close.iloc[: -self.MOMENTUM_SKIP_DAYS] if len(close) > self.MOMENTUM_SKIP_DAYS + 5 else close
        stats["momentum"] = float(momentum_close.iloc[-1] / momentum_close.iloc[0] - 1)
        stats["start_price"] = float(close.iloc[0])
        stats["end_price"] = float(close.iloc[-1])
        stats["bars"] = int(len(close))
        return {k: (round(v, 6) if isinstance(v, float) and np.isfinite(v) else v) for k, v in stats.items()}

    @staticmethod
    def _ticker_file(run: SelectorRun, exchange_code: str) -> bytes:
        buf = io.StringIO()
        writer = csv.writer(buf)
        writer.writerow(["rank", "symbol", "display_symbol", "name", "exchange", "currency", "score", "total_return", "sharpe", "volatility", "max_drawdown", "style"])
        for r in run.results:
            t, m = r.ticker, r.metrics
            writer.writerow([r.rank, t.symbol, t.display_symbol, t.company_name, exchange_code, t.currency, float(r.score),
                             m["total_return"], m["sharpe"], m["volatility"], m["max_drawdown"], m.get("style") or ""])
        return buf.getvalue().encode()
