from app.extensions import db
from app.models.base import iso, new_uuid, utcnow

RISK_PROFILES = ("conservative", "moderate", "aggressive")
ALERT_CHANNELS = ("in_app", "email", "push")
DEVICE_PLATFORMS = ("android", "ios", "web")
ACCESS_EVENTS = ("register", "login", "resume")
USER_ACTIONS = ("hold", "buy", "sell", "view")
STANCES = ("buy", "hold", "sell")


class User(db.Model):
    __tablename__ = "users"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    email = db.Column(db.String(255), nullable=False, unique=True)
    password_hash = db.Column(db.String(255), nullable=False)
    first_name = db.Column(db.String(80), nullable=False)
    last_name = db.Column(db.String(80), nullable=False)
    is_verified = db.Column(db.Boolean, nullable=False, default=False)
    # Admins manage the application from the web admin area (granted with `flask make-admin`).
    is_admin = db.Column(db.Boolean, nullable=False, default=False, server_default=db.false())
    # Disabled accounts can't log in and their tokens stop working.
    is_active = db.Column(db.Boolean, nullable=False, default=True, server_default=db.true())
    risk_profile = db.Column(db.Enum(*RISK_PROFILES, name="risk_profile"), nullable=False, default="moderate")
    alert_channels = db.Column(db.JSON, nullable=False, default=lambda: ["in_app"])
    default_exchange_id = db.Column(db.String(36), db.ForeignKey("exchanges.id"))
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
    # Where the account was opened and last used from (an IPv6 address fits in 45).
    signup_ip = db.Column(db.String(45))
    last_ip = db.Column(db.String(45))
    last_seen_at = db.Column(db.DateTime)

    default_exchange = db.relationship("Exchange")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "email": self.email,
            "first_name": self.first_name,
            "last_name": self.last_name,
            "is_verified": self.is_verified,
            "is_admin": bool(self.is_admin),
            "is_active": self.is_active is not False,
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


class DeviceToken(db.Model):
    """A phone (or browser) registered for push notifications. The token is the
    FCM registration token; it is dropped when FCM reports it as unregistered."""

    __tablename__ = "device_tokens"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    token = db.Column(db.String(512), nullable=False, unique=True)
    platform = db.Column(db.String(16), nullable=False, default="android")
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
    last_seen_at = db.Column(db.DateTime, nullable=False, default=utcnow)


class AdminAction(db.Model):
    """Audit trail: who changed what in the admin area, and when."""

    __tablename__ = "admin_actions"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    admin_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    action = db.Column(db.String(40), nullable=False)
    target_type = db.Column(db.String(20), nullable=False)
    target_id = db.Column(db.String(64), nullable=False)
    detail = db.Column(db.JSON)
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow, index=True)

    admin = db.relationship("User", lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "admin_email": self.admin.email if self.admin else None,
            "action": self.action,
            "target_type": self.target_type,
            "target_id": self.target_id,
            "detail": self.detail or {},
            "created_at": iso(self.created_at),
        }


class Assumption(db.Model):
    """A position the investor assumes on a ticker (buy, hold or sell), with the
    price when they set it, so they can follow how the call is doing. One per
    ticker per user; setting it again replaces it. Never an order."""

    __tablename__ = "assumptions"
    __table_args__ = (db.UniqueConstraint("user_id", "ticker_id", name="uq_assumption_user_ticker"),)

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False)
    stance = db.Column(db.Enum(*STANCES, name="assumption_stance"), nullable=False)
    price = db.Column(db.Numeric(18, 6))
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=utcnow, onupdate=utcnow)

    ticker = db.relationship("Ticker", lazy="joined")

    def to_dict(self) -> dict:
        t = self.ticker
        return {
            "id": self.id,
            **t.to_dict(),
            "stance": self.stance,
            "price": float(self.price) if self.price is not None else None,
            "created_at": iso(self.created_at),
            "updated_at": iso(self.updated_at),
        }


class UserAccess(db.Model):
    """One sign-up, sign-in or app launch on a saved session: when, from which
    IP and on which platform. Only the newest entries per user are kept."""

    __tablename__ = "user_access"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    user_id = db.Column(db.String(36), db.ForeignKey("users.id"), nullable=False, index=True)
    event = db.Column(db.Enum(*ACCESS_EVENTS, name="access_event"), nullable=False)
    ip = db.Column(db.String(45))
    platform = db.Column(db.String(16), nullable=False, default="other")
    user_agent = db.Column(db.String(255))
    created_at = db.Column(db.DateTime, nullable=False, default=utcnow, index=True)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "event": self.event,
            "ip": self.ip,
            "platform": self.platform,
            "user_agent": self.user_agent,
            "created_at": iso(self.created_at),
        }
