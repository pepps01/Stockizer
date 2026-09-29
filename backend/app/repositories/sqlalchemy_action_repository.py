from app.contracts.repositories import UserActionRepository
from app.extensions import db
from app.models.user_action import UserAction


class SqlAlchemyUserActionRepository(UserActionRepository):
    def add(self, *, user_id: int, symbol: str, action: str) -> UserAction:
        entry = UserAction(user_id=user_id, symbol=symbol.upper(), action=action)
        db.session.add(entry)
        db.session.commit()
        return entry

    def list_for_user(self, user_id: int) -> list[dict]:
        actions = (
            UserAction.query.filter_by(user_id=user_id)
            .order_by(UserAction.created_at.desc())
            .all()
        )
        return [a.to_dict() for a in actions]
