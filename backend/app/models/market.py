from urllib.parse import urlsplit

from app.extensions import db
from app.models.base import new_uuid, num, utcnow

REGIONS = ("North America", "Europe", "Asia", "Pacific", "Middle East / Africa", "Mexico and South America")
DATA_SOURCES = ("yahoo", "synthetic")
TICKER_KINDS = ("stock", "index")


class Country(db.Model):
    __tablename__ = "countries"

    code = db.Column(db.String(2), primary_key=True)  # ISO 3166-1 alpha-2
    name = db.Column(db.String(80), nullable=False, unique=True)
    region = db.Column(db.Enum(*REGIONS, name="region"), nullable=False, index=True)
    currency = db.Column(db.String(3), nullable=False)

    def to_dict(self) -> dict:
        return {"code": self.code, "name": self.name, "region": self.region, "currency": self.currency}


class Exchange(db.Model):
    __tablename__ = "exchanges"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    code = db.Column(db.String(16), nullable=False, unique=True)
    name = db.Column(db.String(120), nullable=False)
    country_code = db.Column(db.String(2), db.ForeignKey("countries.code"), nullable=False, index=True)
    timezone = db.Column(db.String(64), nullable=False)
    opens_at = db.Column(db.Time, nullable=False)
    closes_at = db.Column(db.Time, nullable=False)
    trading_days = db.Column(db.JSON, nullable=False)  # weekday numbers, Monday=0
    currency = db.Column(db.String(3), nullable=False)
    data_source = db.Column(db.Enum(*DATA_SOURCES, name="data_source"), nullable=False, default="yahoo")

    country = db.relationship("Country", lazy="joined")

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "code": self.code,
            "name": self.name,
            "country_code": self.country_code,
            "country": self.country.name if self.country else None,
            "region": self.country.region if self.country else None,
            "timezone": self.timezone,
            "opens_at": self.opens_at.strftime("%H:%M"),
            "closes_at": self.closes_at.strftime("%H:%M"),
            "trading_days": self.trading_days,
            "currency": self.currency,
            "data_source": self.data_source,
        }


class Ticker(db.Model):
    __tablename__ = "tickers"

    id = db.Column(db.String(36), primary_key=True, default=new_uuid)
    exchange_id = db.Column(db.String(36), db.ForeignKey("exchanges.id"), nullable=False, index=True)
    # Provider-qualified symbol (e.g. RY.TO, 005930.KS, ^GSPC, DANGCEM.NGX) — globally unique
    # and used in URLs. display_symbol is the bare exchange symbol shown to users.
    symbol = db.Column(db.String(32), nullable=False, unique=True)
    display_symbol = db.Column(db.String(32), nullable=False)
    company_name = db.Column(db.String(160), nullable=False)
    sector = db.Column(db.String(80))
    kind = db.Column(db.Enum(*TICKER_KINDS, name="ticker_kind"), nullable=False, default="stock", index=True)
    currency = db.Column(db.String(3), nullable=False)
    data_source = db.Column(db.Enum(*DATA_SOURCES, name="data_source"), nullable=False, default="yahoo")
    # Anchor price for the synthetic generator; unused for Yahoo-sourced tickers.
    base_price = db.Column(db.Numeric(18, 6))
    # Catalog position: headline indices and largest companies first.
    display_order = db.Column(db.Integer, nullable=False, default=0)
    active = db.Column(db.Boolean, nullable=False, default=True)
    # Company website (from Yahoo's profile), used to show the company's logo.
    website = db.Column(db.String(200))

    exchange = db.relationship("Exchange", lazy="joined")

    @property
    def logo_url(self) -> str | None:
        """The company's site icon at 128 px, or None when no website is known."""
        domain = logo_domain(self.website)
        return f"https://www.google.com/s2/favicons?domain={domain}&sz=128" if domain else None

    def to_dict(self) -> dict:
        exchange = self.exchange
        return {
            "id": self.id,
            "symbol": self.symbol,
            "display_symbol": self.display_symbol,
            "name": self.company_name,
            "sector": self.sector,
            "kind": self.kind,
            "currency": self.currency,
            "data_source": self.data_source,
            "exchange": exchange.code if exchange else None,
            "exchange_name": exchange.name if exchange else None,
            "country": exchange.country.name if exchange and exchange.country else None,
            "country_code": exchange.country_code if exchange else None,
            "logo_url": self.logo_url,
        }


def logo_domain(website: str | None) -> str | None:
    """'https://www.apple.com/uk/' -> 'apple.com'."""
    if not website:
        return None
    host = urlsplit(website if "//" in website else f"//{website}").hostname or ""
    host = host.lower().removeprefix("www.")
    return host or None


class MarketData(db.Model):
    """Cached daily OHLCV bars. Yahoo bars are cached here on first request so
    ranking/optimisation don't re-download history; synthetic bars are
    regenerated deterministically and cached the same way."""

    __tablename__ = "market_data"
    __table_args__ = (db.UniqueConstraint("ticker_id", "ts", name="uq_market_data_ticker_ts"),)

    id = db.Column(db.BigInteger().with_variant(db.Integer, "sqlite"), primary_key=True, autoincrement=True)
    ticker_id = db.Column(db.String(36), db.ForeignKey("tickers.id"), nullable=False)
    ts = db.Column(db.Date, nullable=False)
    open = db.Column(db.Numeric(18, 6), nullable=False)
    high = db.Column(db.Numeric(18, 6), nullable=False)
    low = db.Column(db.Numeric(18, 6), nullable=False)
    close = db.Column(db.Numeric(18, 6), nullable=False)
    volume = db.Column(db.Numeric(20, 2), nullable=False, default=0)
    source = db.Column(db.Enum(*DATA_SOURCES, name="data_source"), nullable=False)
    fetched_at = db.Column(db.DateTime, nullable=False, default=utcnow)

    def to_dict(self) -> dict:
        return {
            "time": self.ts.isoformat(),
            "open": num(self.open),
            "high": num(self.high),
            "low": num(self.low),
            "close": num(self.close),
            "volume": num(self.volume),
        }
