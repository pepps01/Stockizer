from datetime import datetime

from app.contracts.repositories import (
    IAdviserSessionRepository,
    IArtifactRepository,
    IOptimizerRunRepository,
    ISelectorRunRepository,
    ISignalRepository,
)
from app.extensions import db
from app.models import AdviserSession, Artifact, OptimizerRun, SelectorRun, Signal


class _OwnedLookup:
    """Shared helper: fetch a row by id only if it belongs to the user."""

    model = None

    def get_for_user(self, user_id: str, row_id: str):
        row = db.session.get(self.model, row_id)
        return row if row is not None and row.user_id == user_id else None


class SqlAlchemySelectorRunRepository(_OwnedLookup, ISelectorRunRepository):
    model = SelectorRun

    def add(self, run: SelectorRun) -> None:
        db.session.add(run)

    def list_for_user(self, user_id: str, limit: int = 20) -> list[SelectorRun]:
        return SelectorRun.query.filter_by(user_id=user_id).order_by(SelectorRun.created_at.desc()).limit(limit).all()


class SqlAlchemyOptimizerRunRepository(_OwnedLookup, IOptimizerRunRepository):
    model = OptimizerRun

    def add(self, run: OptimizerRun) -> None:
        db.session.add(run)

    def list_for_user(self, user_id: str, *, ticker_id: str | None = None, limit: int = 30) -> list[OptimizerRun]:
        query = OptimizerRun.query.filter_by(user_id=user_id)
        if ticker_id:
            query = query.filter_by(ticker_id=ticker_id)
        return query.order_by(OptimizerRun.created_at.desc()).limit(limit).all()

    def latest_completed(self, user_id: str, ticker_id: str) -> OptimizerRun | None:
        return (
            OptimizerRun.query.filter_by(user_id=user_id, ticker_id=ticker_id, status="completed")
            .order_by(OptimizerRun.created_at.desc())
            .first()
        )


class SqlAlchemyAdviserSessionRepository(_OwnedLookup, IAdviserSessionRepository):
    model = AdviserSession

    def add(self, session: AdviserSession) -> None:
        db.session.add(session)

    def list_open_for_user(self, user_id: str) -> list[AdviserSession]:
        return (
            AdviserSession.query.filter_by(user_id=user_id)
            .filter(AdviserSession.status != "stopped")
            .order_by(AdviserSession.started_at.desc())
            .all()
        )

    def count_active(self, user_id: str) -> int:
        return AdviserSession.query.filter_by(user_id=user_id, status="active").count()

    def list_active(self) -> list[AdviserSession]:
        return AdviserSession.query.filter_by(status="active").all()


class SqlAlchemySignalRepository(ISignalRepository):
    def add(self, signal: Signal) -> None:
        db.session.add(signal)

    def list_for_user(self, user_id: str, *, session_id: str | None = None, since: datetime | None = None, limit: int = 50) -> list[Signal]:
        query = Signal.query.join(AdviserSession).filter(AdviserSession.user_id == user_id)
        if session_id:
            query = query.filter(Signal.session_id == session_id)
        if since is not None:
            query = query.filter(Signal.emitted_at > since)
        return query.order_by(Signal.emitted_at.desc()).limit(limit).all()


class SqlAlchemyArtifactRepository(IArtifactRepository):
    def add(self, artifact: Artifact) -> None:
        db.session.add(artifact)

    def get(self, artifact_id: str) -> Artifact | None:
        return db.session.get(Artifact, artifact_id)
