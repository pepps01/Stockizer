from app.extensions import db
from app.models.base import iso, new_uuid, utcnow

RISK_PROFILES = ("conservative", "moderate", "aggressive")
ALERT_CHANNELS = ("in_app", "email")
USER_ACTIONS = ("hold", "buy", "sell", "view")


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    email = db.Column(db.String(255), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(80), nullable=False)
    last_name = db.Column(db.String(80), nullable=False)
    is_verified = db.Column(db.Boolean, nullable=False, default=False)
    risk_profile = db.Column(db.Enum(*RISK_PROFILES, name="risk_profile"), nullable=False, default="moderate")
    alert_channels = db.Column(db.JSON, nullable=False, default=lambda: ["in_app"])
    default_exchange_id = db.Column(db.String(36), db.ForeignKey("exchanges.id"))
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    default_exchange = db.relationship("Exchange")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "email": self.email,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "is_verified": self.is_verified,
            "risk_profile": self.risk_profile,
            "alert_channels": self.alert_channels or [],
            "default_exchange": self.default_exchange.code if self.default_exchange else None,
            "created_at": iso(self.created_at),
        }


class UserAction(db.Model):
    """A user's own buy/sell/hold/view note on a ticker — a journal, never an order."""

    __tablename__ = "user_actions"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False)
    action = db.Column(db.Enum(*USER_ACTIONS, name="user_action"), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    ticker = db.relationship("Ticker")

    def to_dict(self) -> dict:
        return {"id": self.id, "symbol": self.ticker.symbol, "action": self.action, "created_at": iso(self.created_at)}


class WatchlistItem(db.Model):
    __tablename__ = "watchlist_items"
    __table_args__ = (db.UniqueConstraint("user_id", "ticker_id", name="uq_watchlist_user_ticker"),)

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False)
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    ticker = db.relationship("Ticker", lazy="joined")
