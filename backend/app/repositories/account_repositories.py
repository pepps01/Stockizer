from app.contracts.repositories import IUserActionRepository, IWatchlistRepository
from app.extensions import db
from app.models import UserAction, WatchlistItem


class SqlAlchemyWatchlistRepository(IWatchlistRepository):
    def list_for_user(self, user_id: str) -> list[WatchlistItem]:
        return WatchlistItem.query.filter_by(user_id=user_id).order_by(WatchlistItem.created_at).all()

    def add(self, user_id: str, ticker_id: str) -> None:
        if not WatchlistItem.query.filter_by(user_id=user_id, ticker_id=ticker_id).first():
            db.session.add(WatchlistItem(user_id=user_id, ticker_id=ticker_id))

    def remove(self, user_id: str, ticker_id: str) -> None:
        WatchlistItem.query.filter_by(user_id=user_id, ticker_id=ticker_id).delete()


class SqlAlchemyUserActionRepository(IUserActionRepository):
    def add(self, user_id: str, ticker_id: str, action: str) -> UserAction:
        entry = UserAction(user_id=user_id, ticker_id=ticker_id, action=action)
        db.session.add(entry)
        return entry

    def list_for_user(self, user_id: str, limit: int = 100) -> list[UserAction]:
        return UserAction.query.filter_by(user_id=user_id).order_by(UserAction.created_at.desc()).limit(limit).all()
