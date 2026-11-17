from datetime import datetime

from sqlalchemy import func, or_

from app.contracts.repositories import IAdminRepository
from app.extensions import db
from app.models import (
    AdminAction,
    AdviserSession,
    DeviceToken,
    Exchange,
    OptimizerRun,
    SelectorRun,
    Signal,
    Ticker,
    User,
)


class SqlAlchemyAdminRepository(IAdminRepository):
    """Read models and bulk updates for the admin area."""

    # ---- overview ------------------------------------------------------------------------

    def user_stats(self, since: datetime) -> dict:
        return {
            "total": User.query.count(),
            "verified": User.query.filter(User.is_verified.is_(True)).count(),
            "admins": User.query.filter(User.is_admin.is_(True)).count(),
            "disabled": User.query.filter(User.is_active.is_(False)).count(),
            "new_7d": User.query.filter(User.created_at >= since).count(),
        }

    def pipeline_stats(self, signals_since: datetime) -> dict:
        return {
            "selector_runs": SelectorRun.query.count(),
            "optimizer_runs": OptimizerRun.query.count(),
            "active_sessions": AdviserSession.query.filter_by(status="active").count(),
            "signals_24h": Signal.query.filter(Signal.emitted_at >= signals_since).count(),
            "push_devices": DeviceToken.query.count(),
        }

    # ---- users ---------------------------------------------------------------------------

    def list_users(self, text: str | None, offset: int, limit: int) -> tuple[list, int]:
        query = User.query
        if text:
            like = f"%{text.strip()}%"
            query = query.filter(or_(User.email.ilike(like), User.first_name.ilike(like), User.last_name.ilike(like)))
        total = query.count()
        users = query.order_by(User.created_at.desc()).offset(offset).limit(limit).all()
        return users, total

    def user_activity(self, user_ids: list[str]) -> dict[str, dict]:
        out = {uid: {"selector_runs": 0, "optimizer_runs": 0, "active_sessions": 0} for uid in user_ids}
        if not user_ids:
            return out
        for model, key, extra in (
            (SelectorRun, "selector_runs", None),
            (OptimizerRun, "optimizer_runs", None),
            (AdviserSession, "active_sessions", AdviserSession.status == "active"),
        ):
            query = db.session.query(model.user_id, func.count(model.id)).filter(model.user_id.in_(user_ids))
            if extra is not None:
                query = query.filter(extra)
            for user_id, count in query.group_by(model.user_id).all():
                out[user_id][key] = count
        return out

    def count_admins(self) -> int:
        return User.query.filter(User.is_admin.is_(True), User.is_active.is_(True)).count()

    def stop_sessions_for_user(self, user_id: str, stopped_at: datetime) -> int:
        sessions = AdviserSession.query.filter(AdviserSession.user_id == user_id, AdviserSession.status != "stopped").all()
        for session in sessions:
            session.status = "stopped"
            session.stopped_at = stopped_at
        return len(sessions)

    # ---- monitoring ----------------------------------------------------------------------

    def list_sessions(self, status: str | None, limit: int) -> list[tuple]:
        query = db.session.query(AdviserSession, User.email).join(User, User.id == AdviserSession.user_id)
        if status:
            query = query.filter(AdviserSession.status == status)
        return query.order_by(AdviserSession.started_at.desc()).limit(limit).all()

    def get_session(self, session_id: str):
        return db.session.get(AdviserSession, session_id)

    def recent_signals(self, limit: int) -> list[tuple]:
        return (
            db.session.query(Signal, User.email)
            .join(AdviserSession, AdviserSession.id == Signal.session_id)
            .join(User, User.id == AdviserSession.user_id)
            .order_by(Signal.emitted_at.desc())
            .limit(limit)
            .all()
        )

    # ---- catalog -------------------------------------------------------------------------

    def exchanges_with_counts(self) -> list[tuple]:
        counts = dict(
            db.session.query(Ticker.exchange_id, func.count(Ticker.id)).filter(Ticker.kind == "stock").group_by(Ticker.exchange_id).all()
        )
        active = dict(
            db.session.query(Ticker.exchange_id, func.count(Ticker.id))
            .filter(Ticker.kind == "stock", Ticker.active.is_(True))
            .group_by(Ticker.exchange_id)
            .all()
        )
        exchanges = Exchange.query.order_by(Exchange.code).all()
        return [(e, active.get(e.id, 0), counts.get(e.id, 0)) for e in exchanges]

    def tickers_for_exchange(self, exchange_code: str) -> list:
        return (
            Ticker.query.join(Exchange)
            .filter(func.upper(Exchange.code) == exchange_code.upper())
            .order_by(Ticker.kind.desc(), Ticker.display_order, Ticker.display_symbol)
            .all()
        )

    # ---- audit ---------------------------------------------------------------------------

    def add_action(self, action: AdminAction) -> None:
        db.session.add(action)

    def recent_actions(self, limit: int) -> list:
        return AdminAction.query.order_by(AdminAction.created_at.desc()).limit(limit).all()
