from sqlalchemy.dialects import mysql

from app.extensions import db
from app.models.base import iso, new_uuid, num, utcnow

SELECTOR_METRICS = ("total_return", "sharpe", "sortino", "momentum", "low_volatility", "max_drawdown", "calmar")
OPTIMIZER_OBJECTIVES = ("sharpe", "total_return", "sortino", "calmar")
STOCK_TYPES = ("equity", "growth", "value")
DEFAULT_STRATEGY = "algebraic"
RUN_STATUSES = ("completed", "failed")
SESSION_STATUSES = ("active", "paused", "stopped")
SIGNAL_TYPES = ("BUY", "SELL", "HOLD")
ARTIFACT_KINDS = ("ticker_file", "params_json", "model")


class SelectorRun(db.Model):
    __tablename__ = "selector_runs"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    exchange_id = db.Column(db.String(36), db.ForeignKey("exchanges.id"), nullable=False)
    period_start = db.Column(db.Date, nullable=False)
    period_end = db.Column(db.Date, nullable=False)
    metric = db.Column(db.Enum(*SELECTOR_METRICS, name="selector_metric"), nullable=False)
    top_n = db.Column(db.Integer, nullable=False)
    # equity = every stock; growth / value = that style, judged against the exchange's other stocks.
    stock_type = db.Column(db.String(16), nullable=False, default="equity", server_default="equity")
    universe_size = db.Column(db.Integer, nullable=False, default=0)
    artifact_id = db.Column(db.String(36), db.ForeignKey("artifacts.id"))
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    exchange = db.relationship("Exchange", lazy="joined")
    results = db.relationship(
        "SelectorResult", order_by="SelectorResult.rank", cascade="all, delete-orphan", lazy="selectin"
    )

    def to_dict(self, *, with_results: bool = True) -> dict:
        data = {
            "id": self.id,
            "exchange": self.exchange.code,
            "exchange_name": self.exchange.name,
            "period_start": self.period_start.isoformat(),
            "period_end": self.period_end.isoformat(),
            "metric": self.metric,
            "top_n": self.top_n,
            "stock_type": self.stock_type,
            "universe_size": self.universe_size,
            "artifact_id": self.artifact_id,
            "created_at": iso(self.created_at),
        }
        if with_results:
            data["results"] = [r.to_dict() for r in self.results]
        return data


class SelectorResult(db.Model):
    __tablename__ = "selector_results"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    run_id = db.Column(db.String(36), db.ForeignKey("selector_runs.id"), nullable=False, index=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False)
    rank = db.Column(db.Integer, nullable=False)
    score = db.Column(db.Numeric(18, 6), nullable=False)
    metrics = db.Column(db.JSON, nullable=False)

    ticker = db.relationship("Ticker", lazy="joined")

    def to_dict(self) -> dict:
        return {"rank": self.rank, "score": num(self.score), "metrics": self.metrics, **ticker_brief(self.ticker)}


class OptimizerRun(db.Model):
    __tablename__ = "optimizer_runs"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False, index=True)
    selector_run_id = db.Column(db.String(36), db.ForeignKey("selector_runs.id"))
    training_start = db.Column(db.Date, nullable=False)
    training_end = db.Column(db.Date, nullable=False)
    bounds = db.Column(db.JSON, nullable=False)
    objective = db.Column(db.Enum(*OPTIMIZER_OBJECTIVES, name="optimizer_objective"), nullable=False)
    # Which signal engine was tuned (see app/analytics/strategies.py).
    strategy = db.Column(db.String(32), nullable=False, default=DEFAULT_STRATEGY, server_default=DEFAULT_STRATEGY)
    best_score = db.Column(db.Numeric(10, 6))
    metrics = db.Column(db.JSON)  # train / out-of-sample / buy-and-hold statistics + equity curves
    status = db.Column(db.Enum(*RUN_STATUSES, name="run_status"), nullable=False, default="completed")
    error = db.Column(db.Text)
    artifact_id = db.Column(db.String(36), db.ForeignKey("artifacts.id"))
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    ticker = db.relationship("Ticker", lazy="joined")
    parameters = db.relationship("OptimalParameter", cascade="all, delete-orphan", lazy="selectin")

    def params_dict(self) -> dict:
        return {p.param_name: num(p.param_value) for p in self.parameters}

    def to_dict(self, *, with_curves: bool = False) -> dict:
        metrics = dict(self.metrics or {})
        if not with_curves:
            metrics.pop("curves", None)
        return {
            "id": self.id,
            **ticker_brief(self.ticker),
            "selector_run_id": self.selector_run_id,
            "training_start": self.training_start.isoformat(),
            "training_end": self.training_end.isoformat(),
            "bounds": self.bounds,
            "objective": self.objective,
            "strategy": self.strategy,
            "best_score": num(self.best_score),
            "parameters": self.params_dict(),
            "metrics": metrics,
            "status": self.status,
            "error": self.error,
            "artifact_id": self.artifact_id,
            "created_at": iso(self.created_at),
        }


class OptimalParameter(db.Model):
    __tablename__ = "optimal_parameters"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    run_id = db.Column(db.String(36), db.ForeignKey("optimizer_runs.id"), nullable=False, index=True)
    param_name = db.Column(db.String(40), nullable=False)
    param_value = db.Column(db.Numeric(18, 8), nullable=False)


class AdviserSession(db.Model):
    __tablename__ = "adviser_sessions"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False)
    optimizer_run_id = db.Column(db.String(36), db.ForeignKey("optimizer_runs.id"))
    interval_sec = db.Column(db.Integer, nullable=False)
    status = db.Column(db.Enum(*SESSION_STATUSES, name="session_status"), nullable=False, default="active", index=True)
    started_at = db.Column(db.DateTime, nullable=False, default=utcnow)
    stopped_at = db.Column(db.DateTime)
    last_evaluated_at = db.Column(db.DateTime)
    last_signal_type = db.Column(db.Enum(*SIGNAL_TYPES, name="signal_type"))
    last_price = db.Column(db.Numeric(18, 6))
    last_score = db.Column(db.Numeric(10, 6))
    last_confidence = db.Column(db.Numeric(4, 3))

    ticker = db.relationship("Ticker", lazy="joined")
    optimizer_run = db.relationship("OptimizerRun")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            **ticker_brief(self.ticker),
            "optimizer_run_id": self.optimizer_run_id,
            "parameters": self.optimizer_run.params_dict() if self.optimizer_run else None,
            "strategy": self.optimizer_run.strategy if self.optimizer_run else DEFAULT_STRATEGY,
            "interval_sec": self.interval_sec,
            "status": self.status,
            "started_at": iso(self.started_at),
            "stopped_at": iso(self.stopped_at),
            "last_evaluated_at": iso(self.last_evaluated_at),
            "last_signal_type": self.last_signal_type,
            "last_price": num(self.last_price),
            "last_score": num(self.last_score),
            "last_confidence": num(self.last_confidence),
        }


class Signal(db.Model):
    __tablename__ = "signals"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    session_id = db.Column(db.String(36), db.ForeignKey("adviser_sessions.id"), nullable=False, index=True)
    signal_type = db.Column(db.Enum(*SIGNAL_TYPES, name="signal_type"), nullable=False)
    confidence = db.Column(db.Numeric(4, 3), nullable=False)
    price = db.Column(db.Numeric(18, 6), nullable=False)
    score = db.Column(db.Numeric(10, 6), nullable=False)
    reason = db.Column(db.Text, nullable=False)
    # Microsecond precision: the live stream pages through signals by emitted_at.
    emitted_at = db.Column(
        db.DateTime().with_variant(mysql.DATETIME(fsp=6), "mysql"), nullable=False, default=utcnow, index=True
    )

    session = db.relationship("AdviserSession", lazy="joined")

    def to_dict(self) -> dict:
        ticker = self.session.ticker
        return {
            "id": self.id,
            "session_id": self.session_id,
            "symbol": ticker.symbol,
            "display_symbol": ticker.display_symbol,
            "name": ticker.company_name,
            "currency": ticker.currency,
            "logo_url": ticker.logo_url,
            "signal_type": self.signal_type,
            "confidence": num(self.confidence),
            "price": num(self.price),
            "score": num(self.score),
            "reason": self.reason,
            "emitted_at": iso(self.emitted_at),
        }


class Artifact(db.Model):
    """A file produced by the pipeline (ticker file, parameter set). The bytes live
    on disk under ARTIFACT_DIR/storage_key; sha256 lets consumers detect tampering."""

    __tablename__ = "artifacts"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    owner_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    kind = db.Column(db.Enum(*ARTIFACT_KINDS, name="artifact_kind"), nullable=False)
    storage_key = db.Column(db.String(255), nullable=False)
    filename = db.Column(db.String(160), nullable=False)
    content_type = db.Column(db.String(80), nullable=False)
    sha256 = db.Column(db.String(64), nullable=False)
    size_bytes = db.Column(db.Integer, nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "kind": self.kind,
            "filename": self.filename,
            "content_type": self.content_type,
            "sha256": self.sha256,
            "size_bytes": self.size_bytes,
            "created_at": iso(self.created_at),
        }


def ticker_brief(ticker) -> dict:
    return {
        "symbol": ticker.symbol,
        "display_symbol": ticker.display_symbol,
        "name": ticker.company_name,
        "exchange": ticker.exchange.code,
        "currency": ticker.currency,
        "data_source": ticker.data_source,
        "logo_url": ticker.logo_url,
    }
