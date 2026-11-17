"""Adviser module: watch a ticker at a set interval and emit colour-coded
BUY / SELL / HOLD decision signals. It never executes trades — signals are
advice the user may act on through their own broker."""

import logging
from datetime import date, timedelta

import pandas as pd

from app.contracts.analytics import ISignalEngine, IStrategyRegistry
from app.contracts.repositories import (
    IAdviserSessionRepository,
    ICatalogRepository,
    IDeviceTokenRepository,
    IOptimizerRunRepository,
    ISignalRepository,
    IUnitOfWork,
    IUserRepository,
)
from app.contracts.services import IAdviserService, IEmailService, IMarketDataService, IPushService
from app.domain.errors import NotFoundError, UnprocessableError, ValidationError
from app.models import AdviserSession, Signal
from app.models.base import utcnow
from app.models.pipeline import SESSION_STATUSES

logger = logging.getLogger(__name__)


class AdviserService(IAdviserService):
    HISTORY_DAYS = 700
    MIN_INTERVAL_SEC = 60
    MAX_INTERVAL_SEC = 86_400
    MAX_ACTIVE_SESSIONS = 25

    def __init__(
        self,
        catalog: ICatalogRepository,
        market_data: IMarketDataService,
        strategies: IStrategyRegistry,
        sessions: IAdviserSessionRepository,
        signals: ISignalRepository,
        optimizer_runs: IOptimizerRunRepository,
        users: IUserRepository,
        email: IEmailService,
        push: IPushService,
        devices: IDeviceTokenRepository,
        uow: IUnitOfWork,
    ):
        self._catalog = catalog
        self._data = market_data
        self._strategies = strategies
        self._sessions = sessions
        self._signals = signals
        self._optimizer_runs = optimizer_runs
        self._users = users
        self._email = email
        self._push = push
        self._devices = devices
        self._uow = uow

    # ---- evaluation ----------------------------------------------------------------------

    def signal_for(self, symbol: str, *, user_id: str | None, optimizer_run_id: str | None) -> dict:
        ticker = self._require_ticker(symbol)
        params, run = self._params_for(user_id, ticker, optimizer_run_id)
        result = self._evaluate(ticker, self._engine_for(run), params)
        if result is None:
            raise UnprocessableError("Not enough price history to compute a signal")
        return {"signal": result, "optimizer_run_id": run.id if run else None}

    def _engine_for(self, run) -> ISignalEngine:
        """The engine an optimizer run tuned; the default engine when there is no run."""
        return (self._strategies.get(run.strategy) if run else None) or self._strategies.default

    def _evaluate(self, ticker, engine: ISignalEngine, params: dict) -> dict | None:
        params = engine.clean_params(params)
        bars = self._data.history_one(ticker, date.today() - timedelta(days=self.HISTORY_DAYS))
        close = self._with_live_price(bars["close"] if len(bars) else pd.Series(dtype=float), ticker)
        if len(close) < engine.warmup_bars(params) // 2:
            return None
        result = engine.latest_signal(close, params)
        if result:
            quote = self._data.quotes([ticker]).get(ticker.symbol)
            result["data_source"] = self._data.source_name(ticker)
            result["market_open"] = bool(quote and quote.get("market_open"))
        return result

    def _with_live_price(self, close: pd.Series, ticker) -> pd.Series:
        """Replace/append today's close with the latest quote so signals track intraday moves."""
        quote = self._data.quotes([ticker]).get(ticker.symbol)
        if not quote or quote.get("price") is None:
            return close
        as_of = date.fromisoformat(quote["as_of"])
        if len(close) and close.index[-1] == as_of:
            close = close.copy()
            close.iloc[-1] = quote["price"]
            return close
        if not len(close) or close.index[-1] < as_of:
            return pd.concat([close, pd.Series([quote["price"]], index=[as_of])])
        return close

    def _params_for(self, user_id: str | None, ticker, optimizer_run_id: str | None):
        run = None
        if user_id and optimizer_run_id:
            run = self._optimizer_runs.get_for_user(user_id, optimizer_run_id)
            if run is None or run.ticker_id != ticker.id or run.status != "completed":
                raise ValidationError("Optimizer run not found for this ticker")
        elif user_id:
            run = self._optimizer_runs.latest_completed(user_id, ticker.id)
        return (run.params_dict() if run else self._strategies.default.default_params()), run

    # ---- sessions ------------------------------------------------------------------------

    def create_session(self, *, user_id: str, symbol: str, interval_sec: int, optimizer_run_id: str | None) -> AdviserSession:
        ticker = self._require_ticker(symbol)
        if not self.MIN_INTERVAL_SEC <= interval_sec <= self.MAX_INTERVAL_SEC:
            raise ValidationError(f"interval_sec must be between {self.MIN_INTERVAL_SEC} and {self.MAX_INTERVAL_SEC}")
        if self._sessions.count_active(user_id) >= self.MAX_ACTIVE_SESSIONS:
            raise ValidationError(f"You can monitor at most {self.MAX_ACTIVE_SESSIONS} tickers at once")
        _, run = self._params_for(user_id, ticker, optimizer_run_id)

        session = AdviserSession(user_id=user_id, ticker=ticker, ticker_id=ticker.id, optimizer_run=run,
                                 optimizer_run_id=run.id if run else None, interval_sec=interval_sec)
        self._sessions.add(session)
        self._uow.commit()
        self.evaluate_session(session)
        return session

    def list_sessions(self, user_id: str) -> list[AdviserSession]:
        return self._sessions.list_open_for_user(user_id)

    def get_session(self, user_id: str, session_id: str) -> AdviserSession:
        session = self._sessions.get_for_user(user_id, session_id)
        if session is None:
            raise NotFoundError("Session not found")
        return session

    def set_status(self, session: AdviserSession, status: str) -> AdviserSession:
        if status not in SESSION_STATUSES:
            raise ValidationError(f"status must be one of {', '.join(SESSION_STATUSES)}")
        session.status = status
        session.stopped_at = utcnow() if status == "stopped" else None
        self._uow.commit()
        return session

    def signals(self, user_id: str, *, session_id=None, since=None, limit: int = 50) -> list[Signal]:
        return self._signals.list_for_user(user_id, session_id=session_id, since=since, limit=limit)

    # ---- monitoring loop -----------------------------------------------------------------

    def run_due(self) -> int:
        now = utcnow()
        due = [
            s for s in self._sessions.list_active()
            if s.last_evaluated_at is None or (now - s.last_evaluated_at).total_seconds() >= s.interval_sec
        ]
        for session in due:
            try:
                self.evaluate_session(session)
            except Exception:
                self._uow.rollback()
                logger.exception("adviser evaluation failed for session %s", session.id)
        return len(due)

    def evaluate_session(self, session: AdviserSession) -> Signal | None:
        run = session.optimizer_run
        engine = self._engine_for(run)
        result = self._evaluate(session.ticker, engine, run.params_dict() if run else engine.default_params())
        session.last_evaluated_at = utcnow()
        if result is None:
            self._uow.commit()
            return None

        changed = result["signal_type"] != session.last_signal_type
        session.last_signal_type = result["signal_type"]
        session.last_price = result["price"]
        session.last_score = result["score"]
        session.last_confidence = result["confidence"]

        signal = None
        if changed:
            signal = Signal(session=session, session_id=session.id, signal_type=result["signal_type"], confidence=result["confidence"],
                            price=result["price"], score=result["score"], reason=result["reason"])
            self._signals.add(signal)
        self._uow.commit()
        if signal is not None:
            self._notify(session, signal)
        return signal

    def _notify(self, session: AdviserSession, signal: Signal) -> None:
        user = self._users.get_by_id(session.user_id)
        if user is None:
            return
        channels = user.alert_channels or []
        if "email" in channels:
            try:
                self._email.send_signal_alert(to=user.email, first_name=user.first_name, signal=signal.to_dict())
            except Exception:
                logger.warning("signal email failed for %s", user.email, exc_info=True)
        if "push" in channels and self._push.enabled:
            self._send_push(user.id, signal)

    def _send_push(self, user_id: str, signal: Signal) -> None:
        tokens = self._devices.tokens_for_user(user_id)
        if not tokens:
            return
        data = signal.to_dict()
        confidence = round((data["confidence"] or 0) * 100)
        title = f"{data['signal_type']} · {data['display_symbol']}"
        body = f"{data['name']} at {data['price']:,.2f} {data['currency']} · {confidence}% confidence"
        payload = {"type": "signal", "signal_id": data["id"], "symbol": data["symbol"], "signal_type": data["signal_type"]}
        try:
            invalid = self._push.send(tokens, title=title, body=body, data=payload)
        except Exception:
            logger.warning("signal push failed for user %s", user_id, exc_info=True)
            return
        for token in invalid:
            self._devices.remove(token)
        if invalid:
            self._uow.commit()

    def _require_ticker(self, symbol: str):
        ticker = self._catalog.ticker(symbol or "")
        if ticker is None:
            raise NotFoundError("Symbol not found")
        return ticker
