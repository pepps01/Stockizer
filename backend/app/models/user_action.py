from datetime import datetime, timezone

from app.extensions import db

VALID_ACTIONS = ("hold", "buy", "sell", "view")


class UserAction(db.Model):
    __tablename__ = "user_actions"

    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("users.id"), nullable=False, index=True)
    symbol = db.Column(db.String(20), nullable=False, index=True)
    action = db.Column(db.String(10), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=lambda: datetime.now(timezone.utc))

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "symbol": self.symbol,
            "action": self.action,
            "created_at": self.created_at.isoformat(),
        }
