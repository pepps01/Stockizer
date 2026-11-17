"""Admin area: who uses Stockiser, what the Adviser is doing, which listings are
offered, and the switches to manage them. Every change is written to the
admin_actions audit trail."""

from datetime import timedelta

from app.contracts.repositories import ICatalogRepository, IAdminRepository, IUnitOfWork, IUserRepository
from app.contracts.services import IAdminService, IPushService
from app.domain.errors import ConflictError, NotFoundError, ValidationError
from app.models import AdminAction
from app.models.base import utcnow
from app.models.pipeline import SESSION_STATUSES


class AdminService(IAdminService):
    MAX_PAGE_SIZE = 100
    USER_FLAGS = ("is_admin", "is_active", "is_verified")

    def __init__(
        self,
        admin: IAdminRepository,
        users: IUserRepository,
        catalog: ICatalogRepository,
        push: IPushService,
        uow: IUnitOfWork,
        *,
        market_data_mode: str,
        email_enabled: bool,
        adviser_worker: bool,
    ):
        self._admin = admin
        self._users = users
        self._catalog = catalog
        self._push = push
        self._uow = uow
        self._system = {"market_data_mode": market_data_mode, "email_enabled": email_enabled, "adviser_worker": adviser_worker}

    # ---- overview ------------------------------------------------------------------------

    def overview(self) -> dict:
        now = utcnow()
        users, _ = self._admin.list_users(None, 0, 5)
        return {
            "users": self._admin.user_stats(now - timedelta(days=7)),
            "pipeline": self._admin.pipeline_stats(now - timedelta(hours=24)),
            "system": {**self._system, "push_enabled": self._push.enabled},
            "recent_users": [u.to_dict() for u in users],
            "recent_signals": [{**s.to_dict(), "user_email": email} for s, email in self._admin.recent_signals(8)],
            "recent_actions": [a.to_dict() for a in self._admin.recent_actions(8)],
        }

    # ---- users ---------------------------------------------------------------------------

    def list_users(self, *, query: str | None, page: int, page_size: int) -> dict:
        page_size = max(1, min(page_size, self.MAX_PAGE_SIZE))
        page = max(1, page)
        users, total = self._admin.list_users(query, (page - 1) * page_size, page_size)
        activity = self._admin.user_activity([u.id for u in users])
        return {
            "users": [{**u.to_dict(), "activity": activity[u.id]} for u in users],
            "total": total,
            "page": page,
            "page_size": page_size,
        }

    def update_user(self, admin_id: str, user_id: str, changes: dict) -> dict:
        user = self._users.get_by_id(user_id)
        if user is None:
            raise NotFoundError("User not found")
        unknown = set(changes) - set(self.USER_FLAGS)
        if unknown:
            raise ValidationError(f"Only {', '.join(self.USER_FLAGS)} can be changed")
        if any(not isinstance(v, bool) for v in changes.values()):
            raise ValidationError("Values must be true or false")
        if user_id == admin_id and (changes.get("is_admin") is False or changes.get("is_active") is False):
            raise ValidationError("You can't remove your own admin access or disable your own account")
        losing_admin = user.is_admin and user.is_active and (changes.get("is_admin") is False or changes.get("is_active") is False)
        if losing_admin and self._admin.count_admins() <= 1:
            raise ConflictError("Stockiser needs at least one active admin")

        before = {flag: bool(getattr(user, flag)) for flag in changes}
        self._users.update(user_id, **changes)
        stopped = 0
        if changes.get("is_active") is False:
            stopped = self._admin.stop_sessions_for_user(user_id, utcnow())
        self._audit(admin_id, "user.update", "user", user_id, {"email": user.email, "before": before, "after": changes, "sessions_stopped": stopped})
        self._uow.commit()
        return user.to_dict()

    # ---- adviser sessions ----------------------------------------------------------------

    def list_sessions(self, *, status: str | None, limit: int = 200) -> list[dict]:
        if status and status not in SESSION_STATUSES:
            raise ValidationError(f"status must be one of {', '.join(SESSION_STATUSES)}")
        return [{**s.to_dict(), "user_email": email} for s, email in self._admin.list_sessions(status, limit)]

    def set_session_status(self, admin_id: str, session_id: str, status: str) -> dict:
        if status not in SESSION_STATUSES:
            raise ValidationError(f"status must be one of {', '.join(SESSION_STATUSES)}")
        session = self._admin.get_session(session_id)
        if session is None:
            raise NotFoundError("Session not found")
        before = session.status
        session.status = status
        session.stopped_at = utcnow() if status == "stopped" else None
        self._audit(admin_id, "session.status", "session", session_id,
                    {"symbol": session.ticker.symbol, "before": before, "after": status})
        self._uow.commit()
        return session.to_dict()

    # ---- catalog -------------------------------------------------------------------------

    def exchanges(self) -> list[dict]:
        return [
            {**e.to_dict(), "active_stocks": active, "total_stocks": total}
            for e, active, total in self._admin.exchanges_with_counts()
        ]

    def tickers(self, exchange_code: str) -> list[dict]:
        if self._catalog.exchange(exchange_code or "") is None:
            raise NotFoundError("Exchange not found")
        return [{**t.to_dict(), "active": bool(t.active)} for t in self._admin.tickers_for_exchange(exchange_code)]

    def set_ticker_active(self, admin_id: str, symbol: str, active: bool) -> dict:
        if not isinstance(active, bool):
            raise ValidationError("active must be true or false")
        ticker = self._catalog.ticker(symbol or "")
        if ticker is None:
            raise NotFoundError("Symbol not found")
        before = bool(ticker.active)
        ticker.active = active
        self._audit(admin_id, "ticker.active", "ticker", ticker.symbol, {"before": before, "after": active})
        self._uow.commit()
        return {**ticker.to_dict(), "active": active}

    # ---- audit ---------------------------------------------------------------------------

    def audit_log(self, limit: int = 100) -> list[dict]:
        return [a.to_dict() for a in self._admin.recent_actions(min(max(limit, 1), 500))]

    def _audit(self, admin_id: str, action: str, target_type: str, target_id: str, detail: dict) -> None:
        self._admin.add_action(AdminAction(admin_id=admin_id, action=action, target_type=target_type, target_id=target_id, detail=detail))
